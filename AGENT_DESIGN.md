# StressWatch Agent 架构设计文档（v0.1 草案）

> 状态：设计评审中（尚未实现）
> 决策（2026-08-15）：推理后端 **先走云端 MiniMax（function calling）**；端上 Apple Foundation Models 作为 Phase 3 的备用后端。
> 目标：在 app 内构建一个 **数据驱动的智能分析 Agent**——能多步推理、调用端上数据工具、跨会话记忆，产出比「一次性 LLM 总结」更强的个性化洞察。

---

## 1. 背景与动机

当前 app 已具备三层能力：

1. **Core ML 分类器**（`StressWatchWellnessClassifier`，7 类）——单点预测。
2. **个性化引擎**（`PersonalizationEngine` + `GoalOptimizer` + `PersonalizedAdviceGenerator`）——基于个人基线的确定性优化/建议。
3. **一次性 LLM 分析**（`LLMPersonalizationService` + `MiniMaxClient`）——把聚合快照发 MiniMax，返回 `LLMInsight`（summary/suggestions/tone）。

痛点：第 3 层是「**一问一答、一次性**」——模型只看到我们**预先算好**的快照，无法主动深挖（"HRV 和睡眠到底相关性多大？"、"上周三异常是哪天开始的？"），也没有记忆。

**Agent 是对第 3 层的进化，而非推翻 1/2**：把 1/2 的确定性计算封装成 **工具（tools）**，让 LLM 在 ReAct 循环里按需调用，从而把"灵活推理"与"可靠计算"组合起来。

---

## 2. 设计原则

1. **复用而非重写**：Core ML、个性化引擎、Keychain、MiniMax 接入全部复用。它们变成 agent 的底层工具。
2. **工具端上、推理可插拔**：所有"查数据/算数据"的动作在设备本地跑（HealthKit/存储）；只有工具**结果**（已最小化）送到云端推理后端。
3. **隐私默认**：不发送任何原始 HealthKit 采样、姓名、精确日期；key 存 Keychain（已完成）。
4. **渐进交付**：Phase 1 即有用，后续 Phase 可叠加。
5. **接缝一致**：沿用现有 `WellnessAnalyzing` / `PersonalizationEngineing` 的"协议 + 多实现"哲学，新增 `AnalysisAgent` 协议。

---

## 3. 总体架构

```
┌───────────────────────── 设备（iPhone） ─────────────────────────┐
│                                                                   │
│  用户输入 / 定时触发                                               │
│       │                                                           │
│       ▼                                                           │
│  ┌──────────────── AnalysisAgent（编排 + ReAct 循环） ────────┐   │
│  │  1. 规划（LLM 拆子问题）                                      │   │
│  │  2. 选工具 → 调用（本地执行）                                  │   │
│  │  3. 观察结果 → 迭代（≤ N 步）                                  │   │
│  │  4. 产出 AgentAnalysis                                         │   │
│  └───────┬───────────────────────────┬────────────────────────┘   │
│          │ 工具调用（本地）            │ 推理请求（仅工具结果）       │
│          ▼                           ▼                           │
│  ┌──────────── 数据工具层 ──────────┐    ┌── AgentReasoningBackend ──┐ │
│  │ FetchBaseline                   │    │ (协议，可插拔)            │ │
│  │ FetchTrend(metric,window)       │    │  • MiniMaxBackend(云端)   │ │
│  │ FetchCheckIns(days)             │    │  • OnDeviceBackend(Phase3)│ │
│  │ ComputeCorrelation(a,b)         │    └──────────┬───────────────┘ │
│  │ DetectAnomalies                 │               │ HTTPS          │
│  │ RunPersonalization（复用引擎）  │               ▼                │
│  └────────────┬────────────────────┘        MiniMax API             │
│               ▼  (HealthKit / LocalStorage)  (function calling)     │
│        基线 / 趋势 / 打卡 / 特征                                      │
│                                                                   │
│  AgentMemory（持久化：历史洞察 / 用户目标 / 过往问答）              │
└───────────────────────────────────────────────────────────────────┘
```

---

## 4. 核心协议：`AnalysisAgent`

沿用现有接缝风格（参考 `WellnessAnalyzing` / `PersonalizationEngineing`）：

```swift
/// Agent 对外暴露的统一入口（协议，便于 Mock / 多实现 / 测试）
protocol AnalysisAgent: Sendable {
    /// 异步执行一次分析对话。
    /// - query: 用户问题（可为空 → 主动洞察模式）
    /// - history: 当前会话历史（多轮）
    /// - context: 已加载的个性化上下文（基线/趋势/打卡）
    func run(
        query: String?,
        history: [AgentMessage],
        context: PersonalizationContext
    ) async -> AgentRunResult
}

/// 一次运行的结果
struct AgentRunResult {
    let analysis: AgentAnalysis          // 结构化产出
    let transcript: [AgentMessage]      // 完整对话轨迹（含工具调用，便于调试/复盘）
    let stepsUsed: Int
    let backend: AgentBackendID
}
```

`AgentAnalysis`（结构化产出，替代/扩展现有 `LLMInsight`）：

```swift
struct AgentAnalysis {
    let summary: String                  // 自然语言总览
    let findings: [AgentFinding]         // 有证据支撑的发现
    let recommendations: [AgentRecommendation]
    let confidence: Double               // 0..1，由工具覆盖度推导
    let followUpQuestions: [String]      // 引导用户继续追问
    let evidence: [AgentEvidence]        // 每条 finding 引用的工具+数据
}

struct AgentFinding {
    let claim: String
    let severity: FindingSeverity        // info / caution / warning
    let evidenceRefs: [String]           // → AgentEvidence.id
}

struct AgentEvidence {
    let id: String
    let tool: String                     // 如 "ComputeCorrelation"
    let summary: String                  // 人类可读的数据结论
    let payload: Data?                  // 可选原始数值（仅本地展示）
}
```

> 与现有 `LLMInsight` 的关系：`LLMInsight`（summary/suggestions/tone）保留为**兜底/简化路径**；`AgentAnalysis` 是增强路径。Phase 1 可让 `AnalysisViewModel` 同时持有两者，UI 优先展示 `AgentAnalysis`。

---

## 5. 工具层（全部端上、确定性、可单测）

统一工具协议，让 agent 循环以一致方式调用：

```swift
protocol AgentTool: Sendable {
    var name: String { get }             // 与 MiniMax tools[].function.name 对应
    var description: String { get }      // 给 LLM 看的自然语言说明
    var jsonSchema: [String: Any] { get }// 参数 JSON Schema（MiniMax tools[].function.parameters）
    /// 执行；返回给 LLM 的结果字符串（已最小化，无原始 PII）
    func run(_ arguments: [String: Any]) async throws -> String
}
```

**Phase 1 工具清单（复用已有能力）：**

| 工具 | 参数 | 复用来源 | 说明 |
|------|------|----------|------|
| `FetchBaseline` | 无 | `LocalStorage.fetchBaseline()` | 返回个人基线（HRV/静息心率/步数/睡眠） |
| `FetchTrend` | `metric`, `windowDays` | `HealthMetric` 序列计算 | 某指标近 N 天均值/斜率/极值 |
| `FetchCheckIns` | `days` | `LocalStorage.fetchDailyCheckIns()` | 近 N 天打卡标签分布 |
| `ComputeCorrelation` | `metricA`, `metricB`, `windowDays` | 本地 Pearson | 两指标相关性（如 HRV vs 睡眠） |
| `DetectAnomalies` | `metric`, `windowDays`, `zThreshold` | 基线 + z-score | 偏离基线≥阈值的具体日期 |
| `RunPersonalization` | 无 | `PersonalizationEngine.personalize(...)` | 直接复用现有目标/建议引擎结果 |

> 工具执行**全部在设备本地**；工具结果只含聚合数值/标签，不含原始采样。

---

## 6. 推理后端（可插拔）

```swift
protocol AgentReasoningBackend: Sendable {
    var id: AgentBackendID { get }
    /// 跑一轮 ReAct：输入消息（含 assistant 的 tool_calls 与 tool 结果），
    /// 返回下一动作（要么继续调工具，要么结束并给最终内容）。
    func step(messages: [AgentMessage], tools: [AgentTool]) async throws -> BackendStepResult
}

enum AgentBackendID { case miniMax, onDevice }

/// 一轮后端返回：要么"要调工具"，要么"给出最终内容"
enum BackendStepResult {
    case toolCall(AgentToolCall)         // name + arguments
    case finished(content: String)       // 最终自然语言
}
```

### 6.1 `MiniMaxReasoningBackend`（Phase 1 实现）

基于现有 `MiniMaxClient`，**扩展以支持 function calling**：

- 端点不变：`https://api.minimax.io/v1/chat/completions`
- 请求增加 `tools` 字段（OpenAI 风格，非旧 `function_call`）：
  ```json
  {
    "model": "MiniMax-M3",
    "messages": [ ... ],
    "tools": [
      { "type": "function",
        "function": { "name": "ComputeCorrelation",
                      "description": "计算两个健康指标在指定窗口内的相关系数",
                      "parameters": { "type": "object",
                        "properties": { "metricA": {"type":"string"},
                                         "metricB": {"type":"string"},
                                         "windowDays": {"type":"integer"} },
                        "required": ["metricA","metricB","windowDays"] } } }
    ],
    "tool_choice": "auto"
  }
  ```
- 响应解析：若 `choices[0].message.tool_calls` 非空 → 本地执行对应 `AgentTool`，把结果作为 `role: "tool"` 消息回传，再请求下一轮（标准 ReAct）。
- 模型默认 `MiniMax-M3`（1M 上下文，官方标注"for agents/tools"）；追求低延迟可切 `MiniMax-M2.7-highspeed`（设置里已有模型 Picker 可复用）。
- 流式 / JSON mode 留待后续；Phase 1 用非流式保证循环简单可靠。
- **关键改造点**：现有 `MiniMaxClient.complete(messages:model:apiKey:) -> String` 需新增 `completeWithTools(...)` 变体，返回 `BackendStepResult` 兼容结构（content 或 tool_calls）。

### 6.2 `OnDeviceFoundationModelBackend`（Phase 3，预留）

- 使用 iOS 18.1+ `FoundationModels.framework`（`SystemLanguageModel`），端上推理 + 工具调用。
- 适用隐私/离线场景；中文质量取决于 iOS 版本，复杂分析仍回退 MiniMax。
- 同一 `AgentReasoningBackend` 协议，无需改动 agent 循环即可切换。

---

## 7. Agent 循环（ReAct，在 `AnalysisAgent` 实现内）

```
func run(query, history, context):
    messages = systemPrompt + history + (query ?? proactiveTrigger)
    tools    = registry.allTools
    steps = 0
    loop:
        steps += 1
        if steps > MAX_STEPS(=6): break → 强制收尾
        result = backend.step(messages, tools)
        switch result:
          case .toolCall(call):
              output = toolRegistry[call.name].run(call.arguments)   // 本地执行
              messages.append(assistant(tool_calls: [call]))
              messages.append(tool(name: call.name, content: output))
              continue loop
          case .finished(content):
              analysis = parseAgentAnalysis(content)   // 要求 JSON / 结构化
              return AgentRunResult(analysis, messages, steps, backend)
```

- **终止条件**：后端返回 `finished`、或达到 `MAX_STEPS`、或连续同工具死循环检测。
- **结构化产出**：要求后端以 JSON（或严格格式）返回 `AgentAnalysis`；解析失败回退为纯 `summary`。
- **可观测**：`transcript` 完整保留，便于调试与日后复盘。

---

## 8. 记忆层 `AgentMemory`

把"一次性"变成"连续"的关键。

```swift
struct AgentMemory {
    var userGoals: [String]              // 用户自述目标（如"想睡够 7.5h"）
    var persistentFacts: [String]        // 稳定事实（如"周三是高强度训练日"）
    var pastInsights: [InsightRecord]    // 历史洞察摘要（带日期，已去标识）
    var lastRunSummary: String?
}

struct InsightRecord {
    let date: String                     // 仅"相对日期/周次"，不含精确生日等 PII
    let summary: String
    let keyFindings: [String]
}
```

- **持久化**：经 `LocalStorageProtocol` 新增 `fetchAgentMemory() / saveAgentMemory(_:)`（与现有 `enableAIAnalysis` 同位置存储）。
- **喂给 prompt**：`systemPrompt` 注入 `userGoals` + 最近 `pastInsights`，让 agent"记得"历史，避免每次从零。
- **写入时机**：每次 `run` 成功后，把 `analysis.summary + findings` 摘要追加进 `pastInsights`（上限 N 条，滚动丢弃）。

> 与 `PersonalizationContext` 的关系：后者是**当次分析的输入快照**（基线/趋势/打卡）；`AgentMemory` 是**跨会话的长期记忆**。两者互补，都在设备本地。

---

## 9. 隐私边界（明确约定）

| 数据 | 是否离设备 | 说明 |
|------|-----------|------|
| 原始 HealthKit 采样 | ❌ 否 | 永不离开设备 |
| 工具结果（聚合数值/标签） | ✅ 是（仅云端后端） | 已最小化，无姓名/精确日期 |
| 用户问题 / 对话 | ✅ 是（仅云端后端） | 不含 PII；建议 UI 提示 |
| API Key | ❌ 否 | Keychain（已实现） |
| AgentMemory | ❌ 否 | 本地存储 |

- 云端后端仅在用户**开启 AI 分析 + 粘贴 Key** 后工作（现有开关复用）。
- UI 在 agent 卡片明确标注"分析会发送至 MiniMax 云端"。

---

## 10. 与现有 UI 的衔接

- 复用 `AnalysisViewModel` 的 `LLMInsightState` 状态机（`off/idle/loading/success/failure`），扩展为同时驱动 `AgentAnalysis`。
- 在已建的「AI 个性化分析」卡片（`AnalysisView.aiAnalysisCard`）内增加：
  - 一个**输入框**（用户提问，如"为什么我这周这么累？"）
  - 展示 `AgentAnalysis.findings`（带证据展开）/ `recommendations` / `followUpQuestions`（可点击追问）
  - 展示工具调用轨迹（调试/透明度，可折叠）
- 设置页无需大改（Key/开关/模型 Picker 已就绪）。

---

## 11. 分阶段交付

### Phase 1（本次实现目标，高价值低风险）
- [ ] `AgentTool` 协议 + 6 个工具实现（§5）
- [ ] `AgentReasoningBackend` 协议 + `MiniMaxReasoningBackend`（扩展 `MiniMaxClient` 支持 `tools`）
- [ ] `AnalysisAgent` 协议 + ReAct 循环实现
- [ ] `AgentAnalysis` / `AgentMemory` 数据模型
- [ ] `LocalStorageProtocol` 增加 `AgentMemory` 读写
- [ ] `AnalysisViewModel` 接入（状态机扩展 + `runAgent(query:)`）
- [ ] `AnalysisView` agent 卡片（输入框 + findings + 追问）
- [ ] 复用：Keychain、MiniMaxClient、PersonalizationEngine、PersonalizationContext
- 验收：用户在 Analysis 页提问 → agent 多步调工具 → 返回带证据的分析；`swiftc -typecheck` 全绿。

### Phase 2
- [ ] `AgentMemory` 持久化落地 + 跨会话记忆注入
- [ ] 主动/定时洞察（后台任务触发 `run(query:nil)`）

### Phase 3
- [ ] `OnDeviceFoundationModelBackend`（iOS 18.1+ 端侧推理 + 工具调用）
- [ ] 分层路由：简单问题端侧答，复杂走 MiniMax

### Phase 4（可选）
- [ ] agent 自反思/验证步（对结论再查数据交叉验证）
- [ ] 多轮对话 UI 完善 + 追问连贯性

---

## 12. 风险与开放问题

1. **MiniMax function calling 字段细节**：文档基于 2026-08 官方文档（`tools` + `tool_choice` auto/none/required）。实现前需实跑一次确认 `tool_calls` 响应结构与 `tool` 消息回传格式无误。
2. **工具结果体积**：若一轮拉取过大窗口，消息可能膨胀；用 M3（1M 上下文）可缓解，但需对工具结果做长度上限。
3. **循环失控**：必须 `MAX_STEPS` + 死循环检测，避免无限调用/费用失控。
4. **结构化解析**：依赖后端稳定产出 JSON；需健壮的 fallback（整段当 summary）。
5. **端上模型中文**：Phase 3 前不依赖；仅作备用。

---

## 13. 验收标准（Phase 1）

- 给定模拟 `PersonalizationContext`，agent 能针对"我这周压力为什么高"自动调用 `FetchTrend(HRV)` + `ComputeCorrelation(HRV, sleep)` + `DetectAnomalies`，并产出带 `evidence` 的 `AgentAnalysis`。
- 不开启 Key / 关闭开关时，agent 完全不联网（沿用现有隐私开关）。
- 全量 `swiftc -typecheck`（含 iOS simulator SDK）零错误。
