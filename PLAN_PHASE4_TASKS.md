# StressWatch 分阶段实施任务（第四阶段）

> 每个任务：**修改范围明确 / 文件明确 / 目标明确 / 不影响其他模块 / 可独立编译 / 可独立测试**。
> 每个任务完成后必须走完 6 步验收：① 编译 ② 测试 ③ 检查 Mock ④ 检查 Real HealthKit ⑤ 检查 UI ⑥ 检查数据不足情况。

---

## 全局约定

### 验收清单（每个任务都要走）

| # | 项 | 怎么做 |
|---|---|---|
| 1 | 编译 | Xcode build（iOS Simulator）。本机无 iOS SDK 时用 `swiftc -typecheck` 兜底并标注 |
| 2 | 测试 | 对应 XCTest 全绿 |
| 3 | Mock | `MockHealthKitService` 数据下跑通，UI 无空崩 |
| 4 | Real | 真机 Apple Health 下跑通；权限被拒时不崩 |
| 5 | UI | 相关页面渲染正常，深色/浅色都看 |
| 6 | 数据不足 | 空数据 / 1 天 / 3 天 / 7 天四种情形都不崩、不造假、有明确文案 |

### 六条硬约束（写在每个任务里）

1. 新增 engine 只 `import Foundation`
2. 缺失值用 `nil`，**禁止 `?? baseline.xxx` 兜底**
3. 不新增造假兜底数据
4. 分数必须有 contributions
5. 相关性只能用 `AssociationWording` 枚举措辞
6. 不动 `MockHealthKitService` / `WellnessAnalyzer` / `MiniMaxClient` / 视觉组件 / Widget

### 任务编号规则

`T{阶段}.{序号}` —— 例：`T1.3` = 阶段 1 第 3 个任务。

---

# 阶段 0 · 地基（必须先做）

## T0.1 新建 `StressWatchTests` target

- **文件**：`StressWatch.xcodeproj/project.pbxproj`（新增 target + 目录引用）、新建 `StressWatchTests/`
- **目标**：项目现在**零测试 target**。没有它，后续所有"可测试"要求都无法落地
- **范围**：只加 target，不写业务代码
- **验收**：target 能编译；一个占位 `XCTestCase` 能跑通
- **风险**：pbxproj 手工编辑易错 → 优先用 Xcode GUI 新建 target 后 `git diff` 检查
- ⚠️ **这是阻塞性任务，未完成前不启动 T1.x**

## T0.2 测试基础设施

- **文件**：`StressWatchTests/Support/TestCalendar.swift`、`DailyHealthMetricsFixture.swift`
- **目标**：确定性时间 + 日历 + 指标构造器
- **内容**：

```swift
enum TestCalendar {
    static var gregorianUTC: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    /// 固定基准时间，绝不用 Date()
    static let referenceNow = Date(timeIntervalSince1970: 1_760_000_000)
    static func day(_ offset: Int) -> Date   // 相对 referenceNow 的第 N 天
}

enum Fixture {
    static func day(hrv: Double? = nil, rhr: Double? = nil, sleep: Double? = nil,
                    steps: Double? = nil, ...) -> DailyHealthMetrics
    static func series(_ n: Int, _ build: (Int) -> DailyHealthMetrics) -> [DailyHealthMetrics]
}
```

- **验收**：`TestCalendar` 在任意时区下结果一致
- **注意**：DJB2 种子，**绝不用 `String.hashValue`**（Thump 踩过的坑）

---

# 阶段 1 · 日聚合层（地基中的地基）

## T1.1 `DailyHealthMetrics` + `MetricSample` + `MetricProvenance` 模型

- **新增**：`Core/Analysis/Metrics/DailyHealthMetrics.swift`
- **依赖**：Foundation only
- **目标**：定义日粒度聚合结构与溯源三态（measured / estimated / demo）
- **不做**：不写聚合逻辑，纯模型
- **验收**：编译通过；`Codable` round-trip 测试

## T1.2 `MetricAggregation` 规则表 + 生理区间校验

- **新增**：`Core/Analysis/Metrics/MetricAggregation.swift`
- **目标**：纯函数，把某天的 `[HealthMetric]` 聚合成单个 `MetricSample`
- **内容**：
  - HRV：睡眠期样本中位数优先，否则全天中位数；合法区间 1...300 ms
  - RHR：当日最后一条；25...180 bpm
  - HR：中位数 / 最小值；25...240 bpm
  - Sleep：累计 asleep*；**InBed 兜底**（新增，对齐 HealthKit Exporter）
  - Steps/Energy/Exercise/Stand：sum
  - `sampleCount == 0` → `nil`（**绝不写 0**）
- **测试**：`MetricAggregationTests`
  - 空输入 → nil
  - 单样本 → 该值
  - 越界值（HRV 500ms）→ 剔除后重算或 nil
  - InBed 兜底（只有 inBed 时不为 0）
  - steps 多段累加正确
- **验收**：6 步清单（本任务无 UI 改动，⑤ 跳过）

## T1.3 `DailyMetricsAggregator`

- **新增**：`Core/Analysis/Metrics/DailyMetricsAggregator.swift`
- **目标**：`[HealthMetric]` → `[DailyHealthMetrics]`（按天升序，纯函数）
- **测试**：`DailyMetricsAggregatorTests`
  - 跨午夜睡眠归属到醒来日
  - 缺失日仍然占位（`day` 存在但指标为 nil）—— **这是 correlation/trend 需要连续序列的前提**
  - demo 与 apple 数据分别聚合，`dataSource` 正确
  - 空数组 → 空数组（不崩）
- **验收**：6 步

## T1.4 HealthKit 补齐：bedtime / wakeTime / workouts / InBed 兜底

- **修改**：`Core/HealthKit/HealthKitService.swift`
- **目标**：
  - `fetchDailySleepAnalysis` 增加 `bedtime`（最早 start）/ `wakeTime`（最晚 end）
  - 增加 `fetchWorkoutIntervals(from:to:)` → `[(start: Date, end: Date)]`
  - `makeReadTypes` 增加 `HKWorkoutType.workoutType()`
  - `fetchDailyStandTimeTotals` 之外补 `HKActivitySummaryQuery` 读用户真实目标（可选，做不了就跳过）
- **不改**：现有 8 类指标的查询实现
- **测试**：手工验证（真机）
- **验收**：6 步；重点看权限被拒时返回空而非崩

## T1.5 持久化 `DailyHealthMetrics` + schemaVersion

- **修改**：`Core/Storage/LocalStorageProtocol.swift`（加 3 个方法）、`LocalStorage.swift`
- **新增方法**：

```swift
func saveDailyMetrics(_ metrics: [DailyHealthMetrics]) throws
func fetchDailyMetrics(from: Date, to: Date) throws -> [DailyHealthMetrics]
func fetchDailyMetrics(limitDays: Int) throws -> [DailyHealthMetrics]
```

- **同时**：
  - 写文件加 `FileProtectionType.completeUnlessOpen`
  - 新增 `schema_version.json`；decode 失败时**备份原文件**再返回空（现在静默丢数据）
- **不改**：现有 8 个方法的语义
- **测试**：`LocalStorageTests`（upsert 幂等、跨实例重读、损坏文件不崩）
- **验收**：6 步

---

# 阶段 2 · Baseline

## T2.1 `RobustStatistics`

- **新增**：`Core/Analysis/Baseline/RobustStatistics.swift`
- **内容**：`median` / `mad`(×1.4826) / `robustZ` / `logDomainStats`(EWMA α=0.25) / `logZScore` / `percentile`(P75) / `dropOutliers`(MAD 3σ & IQR) / `stddev`
- **测试**：`RobustStatisticsTests`
  - 空数组 / 单元素 / 偶数个 / 全等值（MAD=0 → robustZ 返回 nil）
  - `logZScore` 零方差 → nil（**Soma 的 `test_hrvZScore_nilWhenNoSpread` 必抄**）
  - EWMA 近因性：把最新值改高，EWMA 中心 > 算术均值
  - `dropOutliers` 剔除单个极端值
  - P75 在压力螺旋序列（50→25ms）下**不被拖低**（Thump 的回归测试）
- **验收**：①②⑥

## T2.2 `PersonalBaseline` + `PersonalBaselineEngine`

- **新增**：`Core/Analysis/Baseline/PersonalBaseline.swift`、`PersonalBaselineEngine.swift`
- **目标**：按 `BaselineMetric` × 窗口（7/14/30）产出 `value / dispersion / sampleDays / requiredDays / calibrationProgress / isReliable / zScore()`
- **方法选择**（见设计 §3.2）：HRV → logEWMA + P75 锚点；RHR/Sleep/活动 → 中位数 + MAD
- **关键**：`isReliable == false` 时 `zScore()` 返回 nil，**调用方必须处理**
- **兼容**：提供 `legacyBaseline() -> Baseline`，供 `PersonalizationContext` 继续使用
- **不改**：`Baseline.swift` / `BaselineEngine.swift`（保留，DI 后续切换）
- **测试**：`PersonalBaselineEngineTests`
  - 0/1/4/6/7/14 天阶梯：`isReliable` 在第 7 天翻转
  - `daysRemaining` 正确
  - 缺失日不占位（序列有洞时 sampleDays < 窗口天数）
  - 极端值被剔除后中心值稳定
  - `legacyBaseline()` 字段映射正确
- **验收**：①②⑥

---

# 阶段 3 · Score

## T3.1 `ScoreContribution` + `AnalysisConfidence` + `DataCompleteness`

- **新增**：`Core/Analysis/Scoring/ScoreContribution.swift`、`DataCompleteness.swift`
- **目标**：可解释性的数据结构 + 置信度枚举（high/medium/directional/low/insufficient）+ 完整度
- **测试**：`DataCompletenessTests`
  - 全缺失 → 0.0 且 coreCompleteness = 0
  - 只缺活动 → 核心完整度 1.0，overall < 1.0
  - `missingMetrics` 正确列出
- **验收**：①②

## T3.2 `ActivityLoadEngine`（ATL/CTL/ACR）

- **新增**：`Core/Analysis/Scoring/ActivityLoadEngine.swift`
- **目标**：把 steps/energy/exercise 归一成 0-100 日负荷；算 7 天 EWMA（ATL）、28 天 EWMA（CTL）、ACR
- **不是训练功能** —— 纯统计，无 workout 概念
- **测试**：`ActivityLoadEngineTests`
  - 全缺失 → nil
  - 冷启动（< 7 天）→ CTL 用固定参考值
  - 连续高负荷 → ACR > 1.3
  - 负荷恒定时 ACR ≈ 1.0
- **验收**：①②⑥

## T3.3 `SleepQualityEngine`

- **新增**：`Core/Analysis/Scoring/SleepQualityEngine.swift`
- **目标**：duration 30% / stage 30% / consistency 20% / sleepHRV 20%
- **consistency** 用圆周标准差（Whoordan 法），需 ≥ 3 晚；不足则该项退出并权重重分配
- **测试**：`SleepQualityEngineTests`
  - 8h + 理想分期 → 高分
  - 分期数据缺失 → 该项退出，分数不被压到 0
  - 只有 2 晚 → consistency 不参与
  - 差分测试：`score(clean) - score(fragmented) == 预期增量`
- **验收**：①②⑥

## T3.4 `PersonalStressEngine`

- **新增**：`Core/Analysis/Scoring/PersonalStressEngine.swift`
- **目标**：替换 `StressModel`（旧的保留不删）
- **算法**：sedentary 过滤 → z-score → 双向归一化 → 权重重分配 → disagreement damping → confidence 扣分 + warnings → provisional 兜底
- **测试**：`PersonalStressEngineTests`
  - **性质测试**：`score(hrv 高于基线) < score(hrv 等于基线) < score(hrv 低于基线)`
  - **sedentary 过滤**：运动时段 + 15 分钟 cooldown 的四段时序用例（抄 Soma `StressCalculatorTests:143-155`）
  - **全缺失 → score == nil**（不是 50，不是 0）
  - **不变式**：`Σ contributions.points == score`（±0.5）
  - **confidence 联动**：缺 RHR 时 warnings 含 "No resting heart rate data"
  - **provisional**：第 1 天有分数但 `isProvisional == true` 且 confidence == .low
  - **disagreement**：HRV 高 + RHR 高 → 分数被压缩向 50
  - **活动不再误判为压力**：高步数日子的分数 ≤ 中等步数日子
- **验收**：①②⑥

## T3.5 `PersonalRecoveryEngine`

- **新增**：`Core/Analysis/Scoring/PersonalRecoveryEngine.swift`
- **目标**：替换 `RecoveryModel`（旧的保留不删）
- **关键修正**：`50 + z*25` 取代 `current/baseline*40` —— **等于基线 = 50 分（中性），不再是满分**
- **分量**：hrv .40 / rhr .20 / sleep .25 / load .15
- **测试**：`PersonalRecoveryEngineTests`
  - **天花板修正**：`recovery(hrv == baseline)` ≈ 50，不是 100
  - **性质测试**：`recovery(hrv: 1.5×baseline) > recovery(hrv: baseline) > recovery(hrv: 0.5×baseline)`
  - 高负荷（ACR > 1.3）→ 分数下降
  - 不变式：Σ contributions == score
  - 全缺失 → nil
- **验收**：①②⑥

---

# 阶段 4 · Trend

## T4.1 `TrendDirection` + `TrendEngine`

- **新增**：`Core/Analysis/Trend/TrendDirection.swift`、`TrendEngine.swift`
- **五态**：improving / stable / declining / volatile / insufficientData
- **判定顺序**（见设计 §5.3）：sampleCount < 7 → 噪声死区 → robustZ → OLS（单边）→ 前后段均值 → volatility 覆盖 → stable
- **测试**：`TrendEngineTests`
  - `< 7` 天 → `.insufficientData`（**不返回任何编造值**）
  - 零方差基线 → `.stable`（不是 NaN）
  - HRV 28 天 62 → 末 7 天 72 → `.elevated`/`.declining`（方向按指标语义）
  - 2 天尖峰 → 不算趋势（日历连续性）
  - 间隔的尖峰（第 3 天断一天）→ 不算连续
  - 高波动序列（CV > 0.25）→ `.volatile`
  - 三条路径一致：OLS / 前后段 / robustZ 在同一数据上方向不矛盾
- **验收**：①②⑥

## T4.2 🔴 Trends 去造假（高优先级）

- **修改**：`Features/Trend/TrendViewModel.swift`
- **删除**：
  - `makeReferenceScores`（sin 造数据，`:453-471`）
  - `estimatedHRV` / `estimatedRestingHR`（从 stress 分量反推，`:418-424`）
  - `makeSleepConsistency` 的反推逻辑（`:315-331`）
  - `estimatedHourlyStress` 的硬编码时段表（`:398-416`）
  - `normalizedScores` 与假数据的合并（`:267-284`）
- **替换为**：读 `DailyHealthMetrics` 历史 + `TrendEngine` + `SleepQualityEngine`
- **数据源切换**：`stress_scores.json` → `daily_metrics.json`
- **新增**：不足 7 天时显示 "还需 N 天"，并展示已有天数的真实小图（Thump provisional 思路）
- **测试**：`TrendViewModelTests`
  - 空历史 → 所有区块为 insufficientData 态，**无任何编造数值**
  - 3 天历史 → 显示 "还需 4 天"
  - 30 天历史 → 六条趋势都有真实值
- **验收**：6 步全走。**这是用户信任度最关键的一个任务**

## T4.3 🔴 Dashboard 数据源分离（去 Demo 混入）

- **修改**：`Features/Dashboard/DashboardViewModel.swift`
- **改**：

```swift
// 现在
let fallbackMetrics = demoMetrics.filter { !appleMetricTypes.contains($0.type) }
return (appleMetrics + fallbackMetrics, displaySource, ...)

// 改为
struct DataSourceSeparatedMetrics {
    let appleHealth: [HealthMetric]
    let demo: [HealthMetric]
    let activeSource: AppDataSource        // 二选一，绝不混合
}
```

- 两套数据分别聚合，`dataSource` 一路带到 UI
- **顺带修**：`recovery` 卡 sparkline 从 `hrvTrend` 改为真实 recovery 历史
- **顺带修**：`demoStressTrendScores` 硬编码 `[42,46,51,...]` → 数据不足时不画 sparkline
- **测试**：`DashboardViewModelTests`
  - `.appleHealth` 模式下 demo 数据不参与任何分数计算
  - 混合来源时 `dataSource` 标签正确
- **验收**：6 步

---

# 阶段 5 · Correlation

## T5.1 `CorrelationPair` + `ObservedAssociation`

- **新增**：`Core/Analysis/Correlation/CorrelationPair.swift`
- **目标**：6 对初始配置；`ObservedAssociation` 结构上**不提供任何因果字段**
- **`AssociationWording` 枚举**：observed / tendsToCooccur / tracksWith / notYetClear —— 措辞只能从这里取
- **测试**：编译期约束检查（grep 测试：代码中不得出现 "causes" / "because" 字面量）
- **验收**：①②

## T5.2 `CorrelationEngine`

- **新增**：`Core/Analysis/Correlation/CorrelationEngine.swift`
- **算法**：lag 配对 → minimumPairs 门槛 → Pearson + **Spearman 交叉验证** → strength 分档 → `isBeneficial` 按 expectedDirection 判定
- **关键**：`pairedDays < minimumPairs` → 返回 `.none` + "目前还没有观察到清晰关联，再多记录 N 天"（**不隐藏弱结果**）
- **测试**：`CorrelationEngineTests`
  - 用不同频率 sin/cos 构造**已知 r 值**的序列（抄 Thump `makeLinearHistory`）
  - lag=1 的睡眠→HRV 关系能被检出，lag=0 检不出（验证 lag 真的生效）
  - 配对数不足 → `.none` 且文案含"还没观察到"
  - 方向：Pearson 与 Spearman 不一致 → 降级为 `.weak`
  - `isBeneficial`：steps↔RHR 的 r = -0.7 → `isBeneficial == true`
- **验收**：①②⑥

---

# 阶段 6 · Structured Analysis + Insight

## T6.1 `StructuredAnalysisResult` + `AnalysisInsightBuilder`

- **新增**：`Core/Analysis/Insight/StructuredAnalysisResult.swift`、`AnalysisInsightBuilder.swift`
- **目标**：产出用户要求的那个 JSON 形状（分数 + 各指标 value/baseline/deviationPercent/trend + confidence + dataCompleteness）
- **测试**：`AnalysisInsightBuilderTests`
  - 输出的 JSON 结构与需求文档 §8 的形状逐字段比对
  - 数据不足时 `stressScore == nil` 且 `warnings` 非空
  - `completeness.coreCompleteness` 与缺失指标一致
- **验收**：①②⑥

## T6.2 `LocalInsightComposer`（LLM 兜底）

- **新增**：`Core/Analysis/Insight/LocalInsightComposer.swift`
- **目标**：纯本地生成 summary / keyChanges / possibleFactors / trendsSummary / confidenceNote
- **测试**：`LocalInsightComposerTests`
  - 无 LLM 时产出非空、可读、无编造
  - 措辞不含因果动词（由 `CopyContractTests` 强制）
  - 缺失活动数据时 confidenceNote 明确说明"活动因素未纳入"
- **验收**：①②⑥

## T6.3 LLM payload 升级 + prompt 强化

- **修改**：`Core/Analysis/LLM/LLMPersonalizationService.swift`
- **改**：
  - `buildPayload` 优先消费 `StructuredAnalysisResult`（旧签名保留带默认值）
  - system prompt 加 5 条（因果措辞 / provenance 边界 / 缺失处理 / 不编造 / 输出）
  - payload 中 provenance 字段随每个数值一起传
- **不改**：`MiniMaxClient`、`PersonalizationInsight` 结构
- **测试**：`LLMPersonalizationServiceTests`
  - payload JSON 含 `deviationPercent` / `trend` / `dataCompleteness` / `provenance`
  - payload 中**不含任何原始 HealthMetric 样本**
  - `usedFallback` 路径仍工作
- **验收**：①②⑥（⑥ = 无 Key / 无网络时不崩）

## T6.4 `InsightSafetyValidator`（输出后置校验）

- **新增**：`Core/Analysis/Insight/InsightSafetyValidator.swift`
- **校验**：
  1. banned terms 四类（医疗 / jargon / AI 腔 / 拟人化）
  2. 因果动词黑名单：导致 / 因为 / 说明 / 证明 / 引起 / 造成
  3. **数值回溯**：insight 中出现的每个数字必须能在 `StructuredAnalysisResult` 中找到（±0.5）
- **测试**：`InsightSafetyValidatorTests`
  - 构造含 "导致" 的 insight → 校验失败
  - 构造含载荷中不存在的数字（如 "你的 HRV 是 99ms" 而实际 42）→ 标记 suspect
- **验收**：①②

## T6.5 Insight 缓存 + 隐私谓词

- **新增**：`Core/Analysis/Privacy/AnalysisPrivacyGuard.swift`
- **修改**：`LocalStorageProtocol` + `LocalStorage`（3 个方法）
- **缓存失效**：无缓存 / 非今天 / 最新 metrics 日期 > 缓存生成时间（自愈）
- **隐私谓词**：`canSendHealthDataToLLM(enabled:hasKey:consent:dataSource:)` —— **`.demo` 数据源禁止发送**
- **测试**：`AnalysisPrivacyGuardTests`、`InsightCacheTests`
- **验收**：①②⑥

---

# 阶段 7 · UI 信息层级

## T7.1 Analysis 页新增三个 section

- **修改**：`Features/Analysis/Views/AnalysisView.swift`、`AnalysisViewModel.swift`
- **新增 section**（插在现有 `assessmentCard` 之后、`aiAnalysisCard` 之前）：
  - `keyChangesCard` —— 来自 `MetricDeviation`（value + baseline + deviationPercent + trend pill）
  - `patternCard` —— 7/14/30 分段 + TrendEngine 结果
  - `relatedFactorsCard` —— CorrelationEngine 结果（带 lag 标签 + 强度条 + 有益/无益配色）
  - `dataQualityCard` —— completeness + warnings
- **LLM 关闭时**：`aiAnalysisCard` 位置显示 `LocalInsight` 内容（不再是"尚未开启 AI 分析"一句话）
- **不改**：现有 8 个 section 的结构与视觉
- **验收**：6 步

## T7.2 Dashboard 微调

- **修改**：`Features/Dashboard/DashboardViewModel.swift`、`Views/DashboardView.swift`
- **只做三处**：
  - Hero 加 confidence + completeness chip
  - recovery 卡 sparkline 换真实数据
  - 数据不足时 sparkline 不画（显示 "—"）
- **不新增卡片**（用户明确要求不堆 Card）
- **验收**：6 步

## T7.3 Trends 页重构

- **修改**：`Features/Trend/Views/TrendView.swift`（承接 T4.2）
- **目标**：六条真实趋势 + 明确的 insufficient 态
- **验收**：6 步

---

# 阶段 8 · 架构纪律与防腐

## T8.1 架构约束测试

- **新增**：`StressWatchTests/Architecture/ArchitectureConstraintTests.swift`
- **内容**（抄 Whoordan）：
  - `Core/Analysis/{Metrics,Baseline,Scoring,Trend,Correlation,Insight}/` 下所有文件**只含 `import Foundation`**
  - `Features/` 下禁止 `import HealthKit` / `HKHealthStore` / `FileManager.default`
  - pbxproj 分组结构与磁盘目录一致
- **验收**：①②

## T8.2 文案契约测试

- **新增**：`StressWatchTests/Architecture/CopyContractTests.swift`
- **内容**：
  - 免责声明文案必须存在于 AnalysisView
  - 全项目 `Core/Analysis/**` 源码中禁止出现因果动词字面量（"导致"/"因为"/"说明"/"证明"）
  - 禁止 "No data" / "暂无数据" 这类哑空状态（必须带可执行引导）
- **验收**：①②

## T8.3 全量回归 + 文档更新

- **内容**：
  - 跑全部测试
  - 更新 `ARCHITECTURE.md`：补充新分层
  - 更新 `README.md`：说明 Personal Baseline / Trend / Correlation / Data Quality 能力
- **验收**：全绿

---

# 任务依赖图

```
T0.1 ──▶ T0.2 ──┬──▶ T1.1 ──▶ T1.2 ──▶ T1.3 ──┬──▶ T1.5 ──┐
                 │                              │            │
                 │      T1.4 (HealthKit 补齐) ──┘            │
                 │                                            │
                 └──▶ T2.1 ──▶ T2.2 ─────────────────────────┤
                                                              ▼
                 T3.1 ──▶ T3.2 ──▶ T3.3 ──▶ T3.4 ──▶ T3.5 ──▶ T4.1
                                                              │
                 T4.2 (去造假) ◀────────────────────────────────┤
                 T4.3 (数据源分离) ◀────────────────────────────┤
                                                              ▼
                 T5.1 ──▶ T5.2 ──▶ T6.1 ──▶ T6.2 ──▶ T6.3 ──▶ T6.4 ──▶ T6.5
                                                              ▼
                 T7.1 ──▶ T7.2 ──▶ T7.3 ──▶ T8.1 ──▶ T8.2 ──▶ T8.3
```

**关键路径**：`T0.1 → T0.2 → T1.3 → T2.2 → T3.4/T3.5 → T4.1 → T6.1 → T7.1`

**可并行的**：T1.4 ∥ T1.5；T3.2 ∥ T3.3；T4.2 ∥ T4.3

---

# 建议的提交粒度

| 提交 | 包含任务 | 说明 |
|---|---|---|
| `feat(test): add StressWatchTests target + fixtures` | T0.1, T0.2 | 纯新增，零风险 |
| `feat(metrics): daily aggregation layer` | T1.1–T1.5 | 地基，无 UI 变化 |
| `feat(baseline): personal baseline with robust stats` | T2.1, T2.2 | 无 UI 变化 |
| `feat(scoring): personal stress & recovery engines` | T3.1–T3.5 | 无 UI 变化 |
| `fix(trend): remove synthetic data, add TrendEngine` | T4.1–T4.3 | ⚠️ UI 可见变化，重点回归 |
| `feat(correlation): association analysis` | T5.1, T5.2 | 无 UI 变化 |
| `feat(insight): structured analysis + LLM upgrade` | T6.1–T6.5 | |
| `feat(ui): analysis page info hierarchy` | T7.1–T7.3 | |
| `chore(guard): architecture & copy contract tests` | T8.1–T8.3 | |

---

# 每个任务的完成判定（DoD）

- [ ] 代码已写，编译无 warning（新增文件）
- [ ] 对应测试文件已写且全绿
- [ ] Mock 数据源下 UI 正常
- [ ] 真机 Apple Health 下 UI 正常
- [ ] 权限被拒 / 空数据下不崩且文案明确
- [ ] 0 天 / 1 天 / 3 天 / 7 天四种数据量都验证过
- [ ] 未修改任何"不改动清单"里的文件
- [ ] 新增文件头部注释说明了算法依据与参考来源
- [ ] `git diff --stat` 只包含本任务声明的文件
