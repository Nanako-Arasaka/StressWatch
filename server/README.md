# StressWatch Analysis Proxy

可选的「云端深度解读」代理。端上分析仍是主路径；本服务只接收**已脱敏的聚合 JSON**，调用服务器本地 Qwen，返回结构化洞察。

```
iPhone (聚合 payload) --HTTPS--> 本服务 :8090 --> llama-server :8080 (Qwen3.8-27B)
```

## API

### `GET /health`

```json
{"status": "ok", "llm": "ok", "model": "qwen3.8-27b"}
```

### `POST /v1/analyze`

可选头：`Authorization: Bearer <API_TOKEN>`（设置 `API_TOKEN` 时必填）。

```json
{
  "kind": "auto",
  "windowDays": 7,
  "data": { "...StructuredAnalysisResult 或 AnalysisPayload..." }
}
```

返回 `PersonalizationInsight`（summary / findings / suggestions / tone）+ 安全校验结果。

## 本地运行

```bash
cd server
pip install -r requirements.txt
export LLM_BASE_URL=http://127.0.0.1:8080/v1
uvicorn app.main:app --reload --port 8090
```

## Docker（服务器）

前置：宿主机 `llama-qwen.service` 已监听 `127.0.0.1:8080`。

```bash
cd server
export API_TOKEN=change-me
docker compose up -d --build
curl http://127.0.0.1:8090/health
```

`network_mode: host` 使容器直接访问宿主机回环上的 llama-server。

## 隐私边界

- 只接受聚合/脱敏 JSON，不接收原始 HealthKit 采样
- 不落库、不写日志中的用户载荷（仅错误信息）
- 端上保留 `LocalInsightComposer` 离线兜底；本服务默认可关
