#!/usr/bin/env bash
# StressWatch 端到端联调：拉起模型 → 测分析代理 → 关模型释放显存
set -euo pipefail

LLAMA="systemctl --user start llama-qwen.service"
LLAMA_STOP="systemctl --user stop llama-qwen.service"
PROXY="http://127.0.0.1:8090"
LLM="http://127.0.0.1:8080"
TOKEN="${API_TOKEN:-stresswatch-dev}"

cleanup() {
  echo "==== stop model ===="
  systemctl --user stop llama-qwen.service || true
  sleep 2
  nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
}
trap cleanup EXIT

echo "==== GPU before ===="
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader

echo "==== start llama-server ===="
systemctl --user start llama-qwen.service
ready=0
for i in $(seq 1 30); do
  if curl -sf "${LLM}/health" >/dev/null 2>&1; then ready=1; echo "MODEL_READY (${i})"; break; fi
  sleep 3
done
if [ "$ready" != "1" ]; then
  echo "MODEL_FAIL"; journalctl --user -u llama-qwen.service -n 40 --no-pager; exit 1
fi

echo "==== model / health ===="
curl -sS "${LLM}/health"; echo
curl -sS "${PROXY}/health"; echo

echo "==== chat smoke ===="
curl -sS "${LLM}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"回复两个字：就绪"}],"max_tokens":64,"chat_template_kwargs":{"reasoning_budget":80}}'
echo

echo "==== tool smoke ===="
curl -sS "${LLM}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model":"qwen3.8-27b",
    "messages":[
      {"role":"system","content":"今天是 2026-09-26。有工具就直接调用。"},
      {"role":"user","content":"查询今天的压力分"}
    ],
    "tools":[{"type":"function","function":{"name":"get_stress_score","description":"Get stress score","parameters":{"type":"object","properties":{"date":{"type":"string"}},"required":["date"]}}}],
    "tool_choice":"auto",
    "max_tokens":128
  }' | python3 -m json.tool | head -40
echo

echo "==== analyze (structured) ===="
curl -sS -X POST "${PROXY}/v1/analyze" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "kind":"auto",
    "windowDays":7,
    "data":{
      "stressScore":64,
      "recoveryScore":71,
      "metrics":[
        {"metric":"hrv","value":42,"unit":"ms","baseline":51,"deviationPercent":-17.6,"trend":"declining","provenance":"measured"}
      ],
      "activityLevel":"moderate",
      "confidence":0.86,
      "completeness":{"overallCompleteness":0.92},
      "warnings":[]
    }
  }' | python3 -m json.tool
echo

echo "==== analyze (payload) ===="
curl -sS -X POST "${PROXY}/v1/analyze" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "kind":"payload",
    "windowDays":7,
    "data":{
      "currentState":"需要恢复",
      "predictedLabel":"Need Recovery",
      "confidencePercent":82,
      "analysisSource":"Core ML",
      "mlSummary":"HRV 低于个人基线，睡眠时长略短。",
      "keyFactors":["HRV 下降","睡眠不足"],
      "features":{"avgHRV":42,"avgRestingHR":61,"sleepAverageHours":6.2,"stressAverage":64,"dataConfidence":0.9},
      "trends7d":{"hrv7dDelta":-8.5,"sleep7dDeltaHours":-0.4},
      "personalizedGoals":{"sleepTargetHours":7.5,"stepsTarget":8000,"exerciseTargetMin":30,"standHours":12,"rationale":["补睡眠优先"]},
      "topRecommendations":[{"title":"提前 30 分钟入睡","detail":"连续 3 天尝试"}]
    }
  }' | python3 -m json.tool
echo

echo "==== auth reject check ===="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${PROXY}/v1/analyze" \
  -H "Content-Type: application/json" \
  -d '{"kind":"auto","data":{"stressScore":1}}')
echo "no-token status=${code} (expect 401 if API_TOKEN set)"
echo "==== ALL DONE ===="
