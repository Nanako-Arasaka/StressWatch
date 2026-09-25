# StressWatch Enhancement Architecture（第三阶段 · 设计，不改代码）

> 目标：在**不破坏现有架构**的前提下，把 Raw → Metrics → Baseline → Score → Trend → Correlation → Structured Analysis → LLM → UI 这条链路补完整。
> 原则：**加文件，不改协议；加协议，不改实现；加实现，不改调用方签名（能加默认值就不改）**。

---

## 0. 核心设计决策（先说结论）

| 决策 | 选择 | 理由 |
|---|---|---|
| 是否引入 `DailyHealthMetrics` 日聚合层 | ✅ **是** | 没有它，Baseline/Trend/Correlation 全部要反复扫原始样本数组，且 Trends 造假问题无法根治 |
| 是否替换 `Baseline` 结构体 | ⚠️ **扩展，不替换** | `Baseline` 被 `LocalStorage` Codable 持久化、被 `PersonalizationContext` 引用。新增 `PersonalBaseline`，`Baseline` 保留为兼容壳 |
| 是否替换 `StressModel` / `RecoveryModel` | ⚠️ **新增，保留旧的** | 同协议 `StressComputing` / `RecoveryComputing`，DI 处切换。旧实现留在仓库供回滚 |
| 是否引入 SwiftData | ❌ **否** | 现有 FileManager + JSON 够用（Whoordan 同样方案）；改 persistence 风险大于收益 |
| 是否改 `HealthKitDataProvider` 签名 | ❌ **否** | 只加一个新方法（workout 区间），带默认实现 |
| 是否引入第三方依赖 | ❌ **否** | 全部用 Foundation + Swift Charts + HealthKit |
| 相关性是否用 LLM 算 | ❌ **否** | 端上 Pearson/Spearman，LLM 只做解读 |
| 是否让 LLM 参与分数计算 | ❌ **否** | 端上算完 → 结构化 → LLM 只解读 |

---

## 1. 目标分层（含每层落地的文件）

```
┌─ HealthKit ────────────────────────────────────────────────┐
│  HealthKitDataProvider (协议，不改)                          │
│  HealthKitService      (真实，只加 workout 读取)             │
│  MockHealthKitService  (Demo，不改)                          │
└────────────────────────────────────────────────────────────┘
                          ↓  [HealthMetric]
┌─ L1 · Raw → Daily Metrics ─────────────────────────────────┐
│  NEW  Core/Analysis/Metrics/DailyHealthMetrics.swift         │
│  NEW  Core/Analysis/Metrics/DailyMetricsAggregator.swift     │
│  NEW  Core/Analysis/Metrics/MetricAggregation.swift          │
└────────────────────────────────────────────────────────────┘
                          ↓  [DailyHealthMetrics]  按天、按指标带 source+confidence
┌─ L2 · Baseline ────────────────────────────────────────────┐
│  KEEP Core/Models/Baseline.swift                            │
│  KEEP Core/Analysis/BaselineEngine.swift (兼容)              │
│  NEW  Core/Analysis/Baseline/PersonalBaseline.swift          │
│  NEW  Core/Analysis/Baseline/PersonalBaselineEngine.swift    │
│  NEW  Core/Analysis/Baseline/RobustStatistics.swift          │
└────────────────────────────────────────────────────────────┘
                          ↓  [PersonalBaseline]  value / sd / n / calibration
┌─ L3 · Score ───────────────────────────────────────────────┐
│  KEEP Core/Analysis/StressModel.swift   (旧，保留)           │
│  KEEP Core/Analysis/RecoveryModel.swift (旧，保留)           │
│  NEW  Core/Analysis/Scoring/PersonalStressEngine.swift       │
│  NEW  Core/Analysis/Scoring/PersonalRecoveryEngine.swift     │
│  NEW  Core/Analysis/Scoring/SleepQualityEngine.swift         │
│  NEW  Core/Analysis/Scoring/ScoreContribution.swift          │
│  NEW  Core/Analysis/Scoring/DataCompleteness.swift           │
└────────────────────────────────────────────────────────────┘
                          ↓  [StressAnalysis / RecoveryAnalysis]  score + contributions + confidence + warnings
┌─ L4 · Trend ───────────────────────────────────────────────┐
│  NEW  Core/Analysis/Trend/TrendDirection.swift               │
│  NEW  Core/Analysis/Trend/TrendEngine.swift                  │
└────────────────────────────────────────────────────────────┘
                          ↓  [MetricTrend]  direction + slope + zScore + window + sampleCount
┌─ L5 · Correlation ─────────────────────────────────────────┐
│  NEW  Core/Analysis/Correlation/CorrelationPair.swift        │
│  NEW  Core/Analysis/Correlation/CorrelationEngine.swift      │
└────────────────────────────────────────────────────────────┘
                          ↓  [ObservedAssociation]  只表达关联，类型上禁止因果
┌─ L6 · Structured Analysis ─────────────────────────────────┐
│  NEW  Core/Analysis/Insight/StructuredAnalysisResult.swift   │
│  NEW  Core/Analysis/Insight/AnalysisInsightBuilder.swift     │
│  NEW  Core/Analysis/Insight/LocalInsightComposer.swift       │
└────────────────────────────────────────────────────────────┘
                          ↓  [StructuredAnalysisResult]  Codable，就是用户要的那个 JSON
┌─ L7 · LLM ─────────────────────────────────────────────────┐
│  KEEP Core/Analysis/LLM/MiniMaxClient.swift                  │
│  EDIT Core/Analysis/LLM/LLMPersonalizationService.swift      │
│       （buildPayload 改为消费 StructuredAnalysisResult）       │
└────────────────────────────────────────────────────────────┘
                          ↓  [PersonalizationInsight]
┌─ L8 · UI ──────────────────────────────────────────────────┐
│  EDIT Features/Dashboard/DashboardViewModel.swift            │
│  EDIT Features/Trend/TrendViewModel.swift  （去造假）          │
│  EDIT Features/Analysis/AnalysisViewModel.swift              │
│  NEW  Features/Analysis/Views/... （KeyChanges / Patterns / Related）│
└────────────────────────────────────────────────────────────┘
```

---

## 2. L1 · Raw → Daily Metrics（新增层，本次升级的地基）

### 2.1 为什么必须有

StressWatch 现在把所有 `[HealthMetric]` 原样丢给 `BaselineEngine` / `StressModel` / `FeatureExtractor`，导致：

- `BaselineEngine` 对 HR（一天几百条）和 Sleep（一天 1 条）**同一个 average 函数** → 采样频率决定权重
- `StressModel` 用 `latestValue` 取"最后一个样本" → 可能是运动后的瞬时值
- `TrendViewModel` 因为没有日聚合历史，只能从 stress 分量**反推 HRV**（造假根因）
- Correlation 无从下手

### 2.2 `DailyHealthMetrics`（新文件）

```swift
/// 一天的聚合健康指标。所有值都可能为 nil —— nil 表示"缺失"，绝不表示 0。
struct DailyHealthMetrics: Codable, Equatable, Identifiable {
    var id: Date { day }                 // 用 day 作 id，天然按天唯一
    let day: Date                        // calendar.startOfDay
    let dataSource: AppDataSource        // .appleHealth / .demo —— 关键：来源不再丢失

    // MARK: - 心血管
    let hrv: MetricSample?               // 当日 HRV（睡眠期优先，否则全天中位数）
    let restingHeartRate: MetricSample?
    let heartRateMedian: MetricSample?
    let heartRateMin: MetricSample?

    // MARK: - 睡眠
    let sleepHours: MetricSample?
    let sleepREMHours: MetricSample?
    let sleepCoreHours: MetricSample?
    let sleepDeepHours: MetricSample?
    let sleepAwakeHours: MetricSample?
    let bedtime: Date?                   // 新增（对齐 HealthKit Exporter）
    let wakeTime: Date?                  // 新增

    // MARK: - 活动
    let steps: MetricSample?
    let activeEnergyKcal: MetricSample?
    let exerciseMinutes: MetricSample?
    let standHours: MetricSample?
    let workoutIntervals: [ClosedRange<Date>]   // 新增（Soma sedentary 过滤需要）
}

/// 单指标当日聚合值 + 溯源 + 质量。
struct MetricSample: Codable, Equatable {
    let value: Double
    let unit: String
    let source: MetricProvenance         // .measured / .estimated / .demo
    let sampleCount: Int                 // 当日参与聚合的原始样本数（0 表示缺失）
}
```

### 2.3 `MetricProvenance`（关键：解决 LLM 过宣称风险）

```swift
enum MetricProvenance: String, Codable {
    case measured    // 来自 HealthKit 真实样本
    case estimated   // 由其它指标推算（如由 stress 分量反推 —— 原则上禁止，但保留通道）
    case demo        // Mock 数据
}
```

> `HealthMetric.sourceName` 现在有值但被全部下游丢弃。聚合时把它压成 `MetricProvenance`，一路带到 LLM payload。

### 2.4 `MetricAggregation`（纯函数，可测）

规则表（集中、可测、可改）：

| 指标 | 聚合方式 | 生理合法区间 | 备注 |
|---|---|---|---|
| HRV | **睡眠期样本中位数**优先，否则全天中位数 | 1...300 ms | 对齐 Soma `sleepingHRV ?? todayHRV` |
| RHR | 当日最后一条 | 25...180 bpm | |
| HR | 中位数 / 最小值 | 25...240 bpm | |
| Sleep | 累计 asleep* 小时；**InBed 兜底** | 0...24 h | 新增 HealthKit Exporter 的兜底 |
| 分期 | 累计 | 0...24 h | |
| Steps / Energy / Exercise / Stand | 当日 sum | 各自区间 | |
| Workouts | 原始区间数组 | — | 新增 |

**缺失判定**：`sampleCount == 0` → `nil`。**绝不写 0。**

### 2.5 `DailyMetricsAggregator`

```swift
protocol DailyMetricsAggregating {
    func aggregate(_ metrics: [HealthMetric],
                   calendar: Calendar,
                   now: Date) -> [DailyHealthMetrics]
}
```

**输入是 `[HealthMetric]`，输出按天升序数组。纯函数，无 IO。**

### 2.6 🔴 顺带修掉：Demo 混入问题

`DashboardViewModel.fetchMetrics` 现在把 demo 数据补进 apple 数组。改为：

```swift
struct DataSourceSeparatedMetrics {
    let appleHealth: [HealthMetric]
    let demo: [HealthMetric]
    let activeSource: AppDataSource      // 二选一，不再混合
}
```

聚合时**两套数据分别聚合**，产物各自带 `dataSource`。UI 只展示 `activeSource` 那一套；另一套不参与任何分数计算。

---

## 3. L2 · Baseline

### 3.1 `PersonalBaseline`（新）

```swift
struct PersonalBaseline: Codable, Equatable {
    let metric: BaselineMetric           // .hrv / .restingHR / .sleepHours / .steps / ...
    let windowDays: Int                  // 7 / 14 / 30
    let value: Double                    // 中心值（中位数 或 log 域 EWMA 还原值）
    let dispersion: Double?              // SD（或 MAD×1.4826）/ log 域 sdLn
    let sampleDays: Int                  // 实际参与的有效天数
    let requiredDays: Int                // 该指标要求的天数
    let computedAt: Date
    let method: BaselineMethod           // .median / .logEWMA / .p75

    var isReliable: Bool { sampleDays >= requiredDays && (dispersion ?? 0) > 0 }
    var calibrationProgress: Double { min(1, Double(sampleDays) / Double(requiredDays)) }
    var daysRemaining: Int { max(requiredDays - sampleDays, 0) }

    /// 稳健 z 值。不可靠时返回 nil —— 调用方必须处理 nil，不许默认 0。
    func zScore(of value: Double) -> Double?
}

enum BaselineMetric: String, Codable {
    case hrv, restingHeartRate, sleepHours, sleepREMHours, sleepDeepHours,
         steps, activeEnergyKcal, exerciseMinutes, standHours
}
```

### 3.2 各指标的方法选择

| 指标 | 方法 | 窗口 | requiredDays | 理由 |
|---|---|---|---|---|
| HRV | **log 域 EWMA（α=0.25）+ 样本 SD**（Soma） | 14/30 | 7 | HRV 对数正态；需个人变异度做 z |
| RHR | **中位数 + MAD** | 14/30 | 5 | 绝对波动小，中位数抗离群 |
| Sleep | **中位数 + MAD** | 14/30 | 5 | |
| Steps / Energy / Exercise / Stand | 中位数 | 14 | 5 | |
| **HRV 基线锚点** | **P75**（Thump） | 14 | 7 | 防长期压力期基线被拖低（"越病越正常"） |

> **HRV 用双值**：`value` 存 log-EWMA 中心（用于 z-score），另存 `anchorP75` 用于"相对好日子"的比值展示。

### 3.3 `PersonalBaselineEngine`

```swift
protocol PersonalBaselineComputing {
    func compute(metric: BaselineMetric,
                 from history: [DailyHealthMetrics],
                 windowDays: Int,
                 now: Date) -> PersonalBaseline
    func baselineSet(from history: [DailyHealthMetrics],
                     windowDays: Int,
                     now: Date) -> PersonalBaselineSet
}

struct PersonalBaselineSet {
    let hrv, restingHeartRate, sleepHours: PersonalBaseline
    let steps, activeEnergy, exerciseMinutes, standHours: PersonalBaseline
    var coreDayCount: Int { min(hrv.sampleDays, restingHeartRate.sampleDays) }  // 取短板
}
```

### 3.4 `RobustStatistics`（纯函数，可测）

```swift
enum RobustStatistics {
    static func median(_ v: [Double]) -> Double?
    static func mad(_ v: [Double]) -> Double?            // × 1.4826
    static func robustZ(_ value: Double, in baseline: [Double]) -> Double?   // MAD==0 → nil
    static func logDomainStats(_ v: [Double]) -> (meanLn: Double, sdLn: Double)?  // EWMA α=0.25
    static func logZScore(_ today: Double, history: [Double]) -> Double?
    static func percentile(_ v: [Double], _ p: Double) -> Double?            // P75
    static func dropOutliers(_ v: [Double], method: OutlierMethod) -> [Double]  // MAD 3σ / IQR
}
```

> **Soma 没有 outlier 剔除，这是必须补的**：HealthKit 里有大量戴表不严/设备切换导致的离群点。

### 3.5 与旧 `Baseline` 的兼容

```swift
extension PersonalBaselineSet {
    /// 生成旧结构，供 PersonalizationContext / LocalStorage 继续用，不破坏现有调用方。
    func legacyBaseline() -> Baseline
}
```

`BaselineEngine`（旧）**保留不删**，DI 处改为注入 `PersonalBaselineEngine`，但 `PersonalizationContext.baseline` 字段类型不变。

---

## 4. L3 · Score

### 4.1 `ScoreContribution`（可解释性的一等公民）

```swift
struct ScoreContribution: Codable, Equatable {
    let signal: SignalKind                 // .hrv / .restingHR / .sleep / .activityLoad / ...
    let rawScore: Double                   // 该信号自己的 0-100 分
    let weight: Double                     // 实际生效权重（已重归一化）
    let points: Double                     // rawScore * weight —— 对总分的实际贡献
    let direction: ContributionDirection   // .favorable / .normal / .unfavorable
    let detail: String                     // 人类可读，如 "HRV 42 ms，低于个人基线 17.6%"
}

enum ContributionDirection: String, Codable {
    case favorable, normal, unfavorable
    var symbol: String { "↑" / "→" / "↓" }
}
```

**不变式（必须写测试）**：`Σ contributions.points == finalScore`。这样解释层永远不可能与实际分数漂移。

### 4.2 `PersonalStressEngine`

```swift
protocol PersonalStressComputing {
    func compute(today: DailyHealthMetrics?,
                 history: [DailyHealthMetrics],
                 baselines: PersonalBaselineSet) -> StressAnalysis
}

struct StressAnalysis: Codable {
    let score: Int?                        // nil = 数据不足，不给分数
    let level: StressLevel?                // 复用现有枚举
    let contributions: [ScoreContribution]
    let confidence: AnalysisConfidence     // 新增枚举
    let warnings: [String]                 // 每个扣分项一条可读原因
    let isProvisional: Bool                // 基线未成型
}
```

**算法（综合 Soma + Thump）**：

```
1.  sedentary 过滤（Soma）
    dayHR = 当日 HR 样本
        .filter { hr < 0.5 * maxHR }                          // 努力度阈值
        .filter { !inWorkout(t) && !inCooldown(t, 15min) }     // workout 窗口 + 运动后尾巴
    → 过滤后为空则 RHR 分量退出（不是记 0）

2.  各信号 z-score（Thump / Soma）
    hrvZ     = baselines.hrv.zScore(today.hrv)                 // log 域
    rhrDev   = (today.rhr - baselines.rhr.value)               // 绝对 bpm 差（RHR 人群差异小）
    sleepGap = baselines.sleepHours.value - today.sleepHours   // 小时

3.  分量归一化（双向，不是只罚不奖）
    hrvComponent   = clamp(50 - hrvZ * 20, 0, 100)     // z = -2 → 90；z = 0 → 50；z = +2 → 10
    rhrComponent   = clamp(50 + rhrDev * 3, 0, 100)    // ±~16 bpm 打满
    sleepComponent = clamp(50 + sleepGap * 12, 0, 100)
    loadComponent  = activityLoadScore(today, history)  // 近 3 日负荷 / 个人 14 日均值

4.  权重重分配（Soma MovementScore 模式）
    weights = [hrv: .35, rhr: .25, sleep: .25, load: .15]
    缺失信号 → 退出并把权重按比例分给剩余
    全缺失 → score = nil

5.  disagreement damping（Thump）
    hrv 说压力高但 rhr 说正常（或反之）→ score = score*0.7 + 50*0.3，confidence -= 0.30

6.  confidence 扣分制（Thump）
    mode 不明 -0.25 / 缺 RHR -0.15 / 缺 CV -0.10 / 基线 SD 缺失 -0.10 /
    近期样本 < 5 -0.15 / disagreement penalty
    ≥0.70 → .high；≥0.40 → .medium；否则 .low
    每次扣分同时 append 到 warnings

7.  provisional（Thump）
    基线未成型 → 用人群参考值（HRV 40ms / RHR 60bpm / Sleep 7.5h），
    isProvisional = true，confidence 强制 .low，warnings += "基线形成中…"
```

### 4.3 `PersonalRecoveryEngine`

```
hrvComponent   = clamp(50 + hrvZ * 25, 0, 100)          // ±2SD → 0/100（Soma 系数）
rhrComponent   = clamp(50 + (base.rhr - today.rhr) * 4, 0, 100)   // 双向
sleepComponent = sleepQualityEngine.score(...)           // 见 4.4
loadComponent  = clamp(100 - activityLoadRatio * 60, 0, 100)

权重：hrv .40 / rhr .20 / sleep .25 / load .15
     （比 StressWatch 现有版本多了 load 项，且天花板不再是"基线即满分"）
```

**关键修正**：现有 `baseline/current * 40` 让"等于基线" = 满分。改成 `50 + z*25` 后，"等于基线" = 50 分（中性），**高于基线才能拿高分**。

### 4.4 `SleepQualityEngine`

```
durationScore = min(100, hours / sleepNeed * 100)                    // 30%
stageScore    = 0.4*deepScore + 0.4*remScore + 0.2*coreScore         // 30%
                 deepScore = min(100, deepRatio / deepTarget * 100)  // target 20%，下限 10%
consistencyScore = 从 bedtime/wakeTime 的圆周标准差（Whoordan 法）     // 20%
                   或 stddev + 跨午夜负偏移（Soma 法），≥3 晚
hrvScore      = 睡眠期 HRV 相对基线                                    // 20%
```

> 需要 `bedtime` / `wakeTime`（L1 新增）。数据不足时 consistency 项退出并重新分配权重。

### 4.5 `ActivityLoadEngine`（轻量，非训练）

```
load = 0.5 * normalize(steps, baseline.steps)
     + 0.3 * normalize(activeEnergy, baseline.activeEnergy)
     + 0.2 * normalize(exerciseMinutes, baseline.exerciseMinutes)
ATL = EWMA(load, 7)      // 急性
CTL = EWMA(load, 28)     // 慢性
ACR = ATL / CTL          // > 1.3 视为近期负荷异常升高
```

> **只借统计骨架（ATL/CTL/ACR），不引入任何训练概念。** 这是 WorkoutTracker 完全没有、但统计上很成熟的工具。

### 4.6 `AnalysisConfidence` + `DataCompleteness`

```swift
enum AnalysisConfidence: String, Codable {
    case high, medium, directional, low, insufficient
    // .directional：方向可信、量级不确定（Whoordan 的六值简化版）
}

struct DataCompleteness: Codable {
    let availableMetrics: Set<BaselineMetric>
    let missingMetrics: Set<BaselineMetric>
    let coreCompleteness: Double     // 核心四项的加权可用性 0...1
    let overallCompleteness: Double  // 全部指标
    let historyDays: Int
}
```

> **对应 LLM 必须知道的**：`"今天的分析主要基于 HRV、睡眠和静息心率，活动数据不足，因此活动因素未纳入判断。"`

---

## 5. L4 · Trend

### 5.1 `TrendDirection`

```swift
enum TrendDirection: String, Codable {
    case improving, stable, declining, volatile, insufficientData
    var displayName: String   // "改善" / "平稳" / "下降" / "波动" / "数据不足"
}
```

> Thump 只有三态且无 `volatile`/顶层 `insufficientData`；用户明确要求五态，这里补齐。

### 5.2 `MetricTrend`

```swift
struct MetricTrend: Codable, Equatable {
    let metric: BaselineMetric
    let window: TrendWindow              // .days7 / .days14 / .days30
    let direction: TrendDirection
    let currentValue: Double?
    let baselineValue: Double?
    let deviationPercent: Double?        // (current - baseline) / baseline * 100
    let slopePerDay: Double?             // OLS 斜率
    let robustZ: Double?                 // 当前值相对窗口的 robust Z
    let volatility: Double?              // 残差标准差 / 均值 = CV
    let sampleCount: Int
    let minimumRequired: Int
}
```

### 5.3 `TrendEngine`

```swift
protocol TrendComputing {
    func trend(metric: BaselineMetric,
               history: [DailyHealthMetrics],
               window: TrendWindow,
               baseline: PersonalBaseline,
               now: Date) -> MetricTrend
}
```

**判定顺序（综合 Thump + Soma）**：

```
1. sampleCount < minimumRequired(7)      → .insufficientData（不再造数据）
2. baselineStd < 死区(0.5)               → .stable（防除零/防噪声放大）
3. |robustZ| > 2.0                       → 用 z 的符号定 improving/declining
4. OLS 斜率：
     RHR：slope > +0.3/天 → declining（只对坏方向敏感，Thump 法）
     HRV：slope < -0.3/天 → declining
5. 前后段均值差（Soma WeeklySummary 法，±3 死区）
     lastHalf - firstHalf > +threshold → improving
6. volatility = CV > 0.25               → .volatile（覆盖上面任何结论）
7. 否则 → .stable
```

**窗口**：7 / 14 / 30 三档，与 `baselineWindowDays` 设置项联动。

### 5.4 🔴 顺带修掉：Trends 造假

| 现有 | 改为 |
|---|---|
| `makeReferenceScores`（sin 造数据） | 删除。`sampleCount < 7` → 显示 "数据不足，还需 N 天" |
| `estimatedHRV` / `estimatedRestingHR`（反推） | 删除。改用 `DailyHealthMetrics` 真实历史 |
| `makeSleepConsistency`（从 sleepDebtFactor 反推） | 改为 `SleepQualityEngine` 的真实圆周标准差；不足 3 晚则显示数据不足 |
| `makeHeatmapRows`（硬编码时段表） | 改为真实小时聚合；数据不足则不显示该区块 |

---

## 6. L5 · Correlation

### 6.1 `CorrelationPair`（声明式表驱动）

```swift
struct CorrelationPair: Identifiable {
    let id: String
    let x: BaselineMetric
    let y: BaselineMetric
    let lagDays: Int                     // ⭐ 0 = 同日，1 = 次日（Thump 没有，Soma 用了）
    let expectedDirection: ExpectedDirection   // .positive / .negative
    let minimumPairs: Int                // 默认 10（比 Thump 的 7 保守）
    let displayTitle: String
}

// 初始 6 对（对应用户要求）
sleepHours ↔ hrv             lag 1   .positive
sleepHours ↔ stressScore     lag 0   .negative
activeEnergy ↔ recoveryScore lag 1   .positive
exerciseMinutes ↔ hrv        lag 1   .positive
restingHeartRate ↔ stressScore lag 0 .positive
sleepHours ↔ recoveryScore   lag 1   .positive
```

### 6.2 `ObservedAssociation`（类型上禁止因果）

```swift
struct ObservedAssociation: Codable, Identifiable {
    let pairId: String
    let coefficient: Double?             // Pearson r
    let strength: AssociationStrength    // .none / .weak / .noticeable / .clear / .strong
    let isBeneficial: Bool
    let pairedDays: Int
    let lagDays: Int
    let description: String              // 由 LocalInsightComposer 生成，语气受枚举约束
}

enum AssociationStrength: String, Codable {
    case none, weak, noticeable, clear, strong
    // 阈值：|r| < .2 none / .2-.4 weak / .4-.6 noticeable / .6-.8 clear / > .8 strong
}

/// ⭐ 语气由枚举驱动，不是自由字符串 —— 类型上无法写出 "导致"
enum AssociationWording: String {
    case observed      = "数据中可观察到"
    case tendsToCooccur = "倾向于同时出现"
    case tracksWith    = "与…同步变化"
    case notYetClear   = "目前还没有观察到清晰关联"
}
```

**硬性约束**：`ObservedAssociation` **不提供**任何 `causal` / `because` / `causes` 字段，`description` 只能由 `AssociationWording` + 数值拼装。这是从 Thump 的教训（文案声称次日因果但算法是同日配对）反推的**结构性修复**。

### 6.3 `CorrelationEngine`

```swift
protocol CorrelationComputing {
    func analyze(pairs: [CorrelationPair],
                 history: [DailyHealthMetrics],
                 scores: [DailyScoreHistory]) -> [ObservedAssociation]
}
```

算法：
1. 按 `lagDays` 配对：`x(t)` 与 `y(t + lag)`，缺任一侧则跳过
2. `pairedDays < minimumPairs` → 返回 `strength = .none` + "数据不足"（**不隐藏，明确说**）
3. Pearson r；`|denominator| < 1e-12` → nil
4. **额外做一次 Spearman**（rank）作为鲁棒性交叉验证 —— 两者方向不一致则降级为 `.weak`
5. `isBeneficial = (r.sign == expectedDirection.sign)` —— **颜色按是否有益，不按符号**

---

## 7. L6 · Structured Analysis（用户要的那个 JSON）

### 7.1 `StructuredAnalysisResult`

```swift
struct StructuredAnalysisResult: Codable {
    let generatedAt: Date
    let dataSource: AppDataSource
    let baselineWindowDays: Int

    let stress: StressAnalysis
    let recovery: RecoveryAnalysis
    let sleepQuality: SleepQualityAnalysis?

    let metrics: [MetricDeviation]        // HRV / RHR / Sleep / Steps / Activity 的偏离+趋势
    let trends: [MetricTrend]
    let associations: [ObservedAssociation]

    let confidence: AnalysisConfidence
    let completeness: DataCompleteness
    let warnings: [String]
}
```

`MetricDeviation` 就是用户给的那个形状：

```swift
struct MetricDeviation: Codable, Identifiable {
    let metric: BaselineMetric
    let value: Double?
    let unit: String
    let baseline: Double?
    let deviationPercent: Double?
    let trend: TrendDirection
    let provenance: MetricProvenance
}
```

### 7.2 产出的 JSON 形状（对齐用户需求）

```json
{
  "stressScore": 64,
  "recoveryScore": 71,
  "hrv": { "value": 42, "baseline": 51, "deviationPercent": -17.6, "trend": "declining" },
  "restingHeartRate": { "value": 68, "baseline": 63, "deviationPercent": 7.9, "trend": "elevated" },
  "sleep": { "duration": 6.4, "baseline": 7.3, "deviationPercent": -12.3, "quality": "belowBaseline" },
  "activity": { "level": "moderate" },
  "confidence": 0.86,
  "dataCompleteness": 0.92
}
```

### 7.3 `AnalysisInsightBuilder`

```swift
protocol StructuredAnalysisBuilding {
    func build(today: DailyHealthMetrics?,
               history: [DailyHealthMetrics],
               baselines: PersonalBaselineSet,
               windowDays: Int,
               now: Date) -> StructuredAnalysisResult
}
```

**编排层**：调 L2/L3/L4/L5，组装成 `StructuredAnalysisResult`。纯函数。

### 7.4 `LocalInsightComposer`（LLM 失败时的兜底）

对应 Soma 的 `buildExplanation` + Thump 的 `RecoveryContext`：

```swift
struct LocalInsight {
    let summary: String
    let keyChanges: [String]        // "HRV 42 ms，低于个人基线 17.6%"
    let possibleFactors: [String]   // "近 14 天睡眠较短的日子，HRV 倾向于更低"
    let trendsSummary: [String]
    let confidenceNote: String      // "本次分析主要基于 HRV、睡眠、静息心率；活动数据不足未纳入"
    let disclaimer: String
}

enum LocalInsightComposing {
    static func compose(_ result: StructuredAnalysisResult) -> LocalInsight
}
```

**价值**：LLM 关闭 / 失败 / 无 Key 时，UI 仍有完整可读分析。这也是"非云端依赖"的体现。

---

## 8. L7 · LLM 层改造

### 8.1 改什么

`LLMPersonalizationService.buildPayload` 现在消费 `PersonalizationContext` + `PersonalizedAnalysis`。改为**优先消费 `StructuredAnalysisResult`**：

```swift
protocol LLMPersonalizationAnalyzing {
    func generateInsight(
        structured: StructuredAnalysisResult,     // 新增（首选）
        context: PersonalizationContext,
        fallback: PersonalizedAnalysis?,
        model: String,
        apiKey: String
    ) async throws -> PersonalizationInsight
}
```

> 旧签名保留（带默认参数），不破坏 `AnalysisViewModel` 现有调用。

### 8.2 System Prompt 升级（现在缺的补上）

现有 prompt 已有"不做医疗诊断""严禁重新计算"。**新增五条**：

```
5. 相关性与因果：数据中的 "association" 只表示"同时观察到"，
   不得使用「导致」「因为」「说明」「证明」「引起」等因果动词。
   必须使用「可能」「与…相关」「数据显示」「可以观察到」「倾向于」。
6. 数据边界：载荷中 provenance = estimated 的值是估算值，不得描述为「你的实测…」。
   provenance = demo 的值是演示数据，必须在文案中说明。
7. 缺失处理：dataCompleteness 中标记为 missing 的指标，
   必须在文案中说明"该因素未纳入本次判断"，不得推断。
8. 不编造：只允许引用载荷中出现的数值。任何载荷中不存在的数值、日期、趋势都不得生成。
9. 输出：只能返回一个 JSON 对象。summary 2-4 句，findings ≤ 4 条，suggestions ≤ 3 条。
```

### 8.3 输出后置校验（新增，Thump 只在测试层做）

```swift
enum InsightSafetyValidator {
    static func validate(_ insight: PersonalizationInsight,
                         against result: StructuredAnalysisResult) -> ValidationResult
    // 1. banned terms 四类（医疗 / jargon / AI 腔 / 拟人化）
    // 2. 因果动词黑名单：导致 / 因为 / 说明 / 证明 / 引起 / 造成
    // 3. 数值回溯：insight 中出现的每个数字必须能在 result 中找到（±0.5 容差）
    //    → 找不到则标记 suspect，UI 提示"该解读可能包含未经验证的内容"
}
```

### 8.4 缓存（Soma InsightCache 模式）

```
LocalStorageProtocol 新增：
  saveInsightCache(_ insight: PersonalizationInsight, generatedAt: Date)
  fetchInsightCache() -> (insight: PersonalizationInsight, generatedAt: Date)?
  invalidateInsightCache()
失效判定：
  - 缓存不存在
  - 不是今天生成的
  - 最新 metrics 日期 > 缓存生成时间（自愈）
```

### 8.5 隐私谓词（Whoordan 模式）

```swift
enum AnalysisPrivacyGuard {
    static func canSendHealthDataToLLM(enabled: Bool, hasKey: Bool,
                                       consent: Bool, dataSource: AppDataSource) -> Bool
    // 新增一条：dataSource == .demo 时禁止发送（演示数据不该上云）
}
```

---

## 9. L8 · UI 信息层级

### 9.1 Analysis 页（目标形态，对应用户 §12）

```
① Today's Analysis
   Stress 64   Recovery 71
   [confidence badge]  [dataSource badge]

② Key Changes                          ← 来自 MetricDeviation
   HRV        42 ms   ↓ 17.6% vs baseline
   Sleep      6.4 h   ↓ 0.9 h vs baseline
   Resting HR 68 bpm  ↑ 5 bpm vs baseline
   （每项带 trend pill：declining / stable / improving）

③ What stands out                       ← LLM 生成；无 LLM 时 LocalInsightComposer 兜底
   [summary]
   [findings ×≤4]

④ Recent Pattern                        ← TrendEngine
   7 / 14 / 30 天分段控件
   每个指标一行：方向 + deviationPercent + sparkline
   数据不足 → "还需 N 天"

⑤ Related Factors                       ← CorrelationEngine
   Sleep ↔ HRV       [lag 1 天] [clear] [有益·绿]
   Activity ↔ Recovery
   措辞：数据中可观察到…（不是"导致"）

⑥ Data Quality                          ← DataCompleteness
   核心指标可用性 86%
   缺失：活动数据（未纳入本次判断）
   [warnings 列表]

⑦ Disclaimer                            ← 保留现有
```

### 9.2 Dashboard

- 现有 7 张卡**不增不减**（用户要求不堆 Card）。
- 只做两处修正：
  - `recovery` 卡的 sparkline 从 `hrvTrend` 改为真实的 recovery 历史
  - `stress` sparkline 从 `demoStressTrendScores` 改为真实历史；不足 3 天则不画（显示"—"）
- Hero 区增加一行 confidence + completeness chip。

### 9.3 Trends

- **去造假**（§5.4）
- 数据源从 `stress_scores.json` 切换到 `daily_metrics.json`
- 新增 stress / recovery / HRV / RHR / sleep / activity 六条趋势（现在只有 stress）
- 不足 7 天 → 明确的 insufficient 态

---

## 10. 文件落地总表

### 10.1 新增文件（21 个）

| 路径 | 依赖 | 可测 |
|---|---|---|
| `Core/Analysis/Metrics/DailyHealthMetrics.swift` | Foundation | — |
| `Core/Analysis/Metrics/MetricAggregation.swift` | Foundation | ✅ |
| `Core/Analysis/Metrics/DailyMetricsAggregator.swift` | Foundation | ✅ |
| `Core/Analysis/Baseline/RobustStatistics.swift` | Foundation | ✅ |
| `Core/Analysis/Baseline/PersonalBaseline.swift` | Foundation | — |
| `Core/Analysis/Baseline/PersonalBaselineEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Scoring/ScoreContribution.swift` | Foundation | — |
| `Core/Analysis/Scoring/DataCompleteness.swift` | Foundation | ✅ |
| `Core/Analysis/Scoring/ActivityLoadEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Scoring/SleepQualityEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Scoring/PersonalStressEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Scoring/PersonalRecoveryEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Trend/TrendDirection.swift` | Foundation | — |
| `Core/Analysis/Trend/TrendEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Correlation/CorrelationPair.swift` | Foundation | — |
| `Core/Analysis/Correlation/CorrelationEngine.swift` | Foundation | ✅ |
| `Core/Analysis/Insight/StructuredAnalysisResult.swift` | Foundation | — |
| `Core/Analysis/Insight/AnalysisInsightBuilder.swift` | Foundation | ✅ |
| `Core/Analysis/Insight/LocalInsightComposer.swift` | Foundation | ✅ |
| `Core/Analysis/Insight/InsightSafetyValidator.swift` | Foundation | ✅ |
| `Core/Analysis/Privacy/AnalysisPrivacyGuard.swift` | Foundation | ✅ |

> **全部只 `import Foundation`**（Soma 纪律）。这是可测试性的唯一来源。

### 10.2 修改文件（最小化）

| 路径 | 改动 | 风险 |
|---|---|---|
| `Core/HealthKit/HealthKitService.swift` | 加 `fetchWorkoutIntervals`；加 InBed 兜底；加 bedtime/wakeTime | 低（新增函数） |
| `Core/HealthKit/HealthKitDataProvider.swift` | 加一个带默认实现的方法 | 低 |
| `Core/Storage/LocalStorageProtocol.swift` | 加 4 个方法（daily metrics / insight cache） | 低 |
| `Core/Storage/LocalStorage.swift` | 实现上述；加 `.completeUnlessOpen`；加 `schemaVersion` | 中（持久化） |
| `Features/Dashboard/DashboardViewModel.swift` | 数据源分离；注入新 engine | 中 |
| `Features/Trend/TrendViewModel.swift` | **重写 makeAnalysis**（去造假） | 中 |
| `Features/Analysis/AnalysisViewModel.swift` | 接入 `StructuredAnalysisResult` + LocalInsight | 中 |
| `Features/Analysis/Views/AnalysisView.swift` | 新增 3 个 section | 低 |
| `Core/Analysis/LLM/LLMPersonalizationService.swift` | payload 改消费 structured result；prompt 加 5 条；加后置校验 | 中 |
| `App/StressWatchApp.swift` | DI 装配新 engine | 低 |
| `StressWatch.xcodeproj/project.pbxproj` | 加 `StressWatchTests` target + 新文件引用 | 中 |

### 10.3 不改动

`MockHealthKitService` / `WellnessAnalyzer` / `CoreMLWellnessAnalyzer` / `WellnessAnalysis` / `PersonalizationEngine` / `GoalOptimizer` / `PersonalizedAdviceGenerator` / `AdviceGenerator` / `KeychainStore` / `MiniMaxClient` / `AppColors` / `GlassCardView` / `AppMotion` / `FloatingTabBar` / Widget Extension / `HealthSourceClassifier`。

---

## 11. 测试架构

### 11.1 新建 `StressWatchTests` target

```
StressWatchTests/
├── Support/
│   ├── TestCalendar.swift                 // Calendar.gregorianUTC + 固定 TimeZone
│   ├── DailyHealthMetricsFixture.swift    // builder + 确定性序列
│   └── SyntheticPersonas.swift            // 5 个 life-story persona
├── Metrics/
│   ├── MetricAggregationTests.swift
│   └── DailyMetricsAggregatorTests.swift
├── Baseline/
│   ├── RobustStatisticsTests.swift
│   └── PersonalBaselineEngineTests.swift
├── Scoring/
│   ├── PersonalStressEngineTests.swift
│   ├── PersonalRecoveryEngineTests.swift
│   ├── SleepQualityEngineTests.swift
│   ├── ActivityLoadEngineTests.swift
│   └── DataCompletenessTests.swift
├── Trend/
│   └── TrendEngineTests.swift
├── Correlation/
│   └── CorrelationEngineTests.swift
├── Insight/
│   ├── AnalysisInsightBuilderTests.swift
│   ├── LocalInsightComposerTests.swift
│   └── InsightSafetyValidatorTests.swift
└── Architecture/
    ├── ArchitectureConstraintTests.swift   // Features/ 禁 import HealthKit
    └── CopyContractTests.swift             // 免责文案必须存在；禁止因果动词
```

### 11.2 测试模式（综合三个参考项目）

| 模式 | 来源 | 用法 |
|---|---|---|
| `now: () -> Date` 注入 | Whoordan | 所有按天逻辑 |
| `Calendar.gregorianUTC` | Whoordan | 所有日历逻辑 |
| 每用例独立临时 store URL | Whoordan | 持久化测试 |
| 性质测试（单调性） | Soma | `XCTAssertGreaterThan(score(hrv:75), score(hrv:50))` |
| 差分测试（锁权重×增量） | Soma | `XCTAssertEqual(a - b, 6, accuracy: 0.1)` |
| 退化边界（合法但会除零） | Soma | `hrvZScore` 零方差 → nil |
| 不变式（Σ contributions == score） | 自建（修 Thump 的坑） | 每个 scoring 测试都断言 |
| `stride` 全域扫描 | Thump | `for score in stride(from:0, through:100, by:5)` |
| 负面测试优先 | Whoordan | `testXDoesNotY` |
| 合成人格 + 期望区间 | Thump | 5 persona × EngineExpectation |
| 确定性 DJB2 种子 | Thump | **绝不用 `String.hashValue`** |
| 架构约束（读 pbxproj / 源码文本） | Whoordan | 50 行，长期防腐 |
| 文案契约（必须词/禁止词） | Whoordan + Thump | 因果动词黑名单 |

---

## 12. 风险与回滚

| 风险 | 缓解 |
|---|---|
| 新算法给出的分数与旧版差异大，用户困惑 | 旧 `StressModel` / `RecoveryModel` 保留在仓库；DI 处一行切换；可加 `useLegacyScoring` 开关灰度 |
| `DailyHealthMetrics` 持久化 schema 演进 | 加 `schemaVersion: Int`；`decodeIfPresent` + 默认值；decode 失败备份原文件而非丢弃 |
| 聚合层引入的性能开销 | 日聚合结果缓存到本地，只在有新数据时重算最近 3 天 |
| 去造假后 Trends 页在数据少时"空了" | 用 Thump 的 provisional 思路：显示"还需 N 天"+ 已有天数的真实小图，不显示编造图 |
| 新增 workout 读取扩大 HealthKit 权限范围 | 只对已有 workout 数据生效；无授权时该过滤器自动失效并降级 |
| LLM payload 变大 | `StructuredAnalysisResult` 只取 UI/解读需要的字段；payload 生成处做 round + 字段裁剪 |
