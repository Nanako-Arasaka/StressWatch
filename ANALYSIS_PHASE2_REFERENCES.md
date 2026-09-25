# 参考项目评估（第二阶段）

> 6 个仓库已克隆到 `/tmp/sw-refs/`，全部读完算法层与测试层。
> 本文只回答两件事：**可以借鉴什么** / **不应该复制什么**。不复制任何代码。

| 仓库 | 规模 | 定位 | 对 StressWatch 的价值 |
|---|---|---|---|
| Soma | 84 文件 / 18.7k 行 | 男性向 readiness App，计算层极工整 | ⭐⭐⭐⭐⭐ 算法与测试纪律 |
| Whoordan | 48 文件 / 36k 行 | BLE 手环 + Apple Health 导出 | ⭐⭐⭐⭐ Provenance / Confidence / 隐私谓词 |
| Thump | 255 文件（95 个测试） | 心率分析 + Buddy 养成 | ⭐⭐⭐⭐⭐ 数据分析产品层 + 测试矩阵 |
| WorkoutTracker | 226 文件 | 健身 + AI Coach | ⭐⭐⭐ AI 与聚合数据结合的隐私工程 |
| Health Dashboard | 8 文件 / 388 行 | 极简 HealthKit 展示 | ⭐⭐ 反面参照为主 |
| HealthKit Exporter | 5 文件 / 942 行 | HealthKit → API 导出 | ⭐⭐⭐ 睡眠归属与数据完整性核对 |

---

## 1. Soma

### 1.1 ✅ 可以借鉴

**① log 域 HRV 统计 + EWMA + z-score（最高价值）**

`Soma/Calculators/BaselineCalculator.swift:64-105`

```swift
static func logHRVStats(values: [Double]) -> (meanLn: Double, sdLn: Double)? {
    let positives = values.filter { $0 > 0 }
    guard positives.count >= minDaysRequired else { return nil }   // 7
    let lns = positives.map { log($0) }
    let alpha = 2.0 / (7.0 + 1.0)     // EWMA α = 0.25，近因加权
    var ewma = lns[0]
    for i in 1..<lns.count { ewma = alpha * lns[i] + (1 - alpha) * ewma }
    // 样本 SD（n-1），衡量"这个人自己的日间变异"
    let mean = lns.reduce(0,+) / Double(lns.count)
    let variance = lns.reduce(0) { $0 + pow($1 - mean, 2) } / Double(lns.count - 1)
    return (meanLn: ewma, sdLn: sqrt(variance))
}

static func hrvZScore(today: Double, values: [Double]) -> Double? {
    guard today > 0, let stats = logHRVStats(values: values), stats.sdLn > 0 else { return nil }
    return (log(today) - stats.meanLn) / stats.sdLn
}
```

**为什么值得学**：HRV 呈对数正态分布，算术均值偏向长尾；`sdLn` 天然就是"这个人的正常波动幅度"，用它做分母才能判断"这次偏离是否真的异常"。StressWatch 现在的算术平均 + 百分比偏差缺的正是这一层。

映射关系（Recovery 分量）：`score = clamp(50 + z * 25, 0, 100)` ⇒ ±2 SD 对应 0/100。

**② `filterSedentary`：别把活动当成压力（最高价值的单点改动）**

`Soma/Calculators/StressCalculator.swift:59-90`

```swift
static func filterSedentary(
    _ samples: [(Date, Double)],
    workoutIntervals: [(start: Date, end: Date)],
    maxHR: Double,
    cooldownMinutes: Double = 15,
    effortThresholdRatio: Double = 0.5
) -> [(Date, Double)] {
    let cooldown = cooldownMinutes * 60.0
    return samples.filter { (time, hr) in
        if maxHR > 0, hr >= effortThresholdRatio * maxHR { return false }   // 努力度阈值
        for w in workoutIntervals {
            if time >= w.start && time <= w.end.addingTimeInterval(cooldown) { return false }
        }
        return true
    }
}
```

**直接对应 StressWatch 现存的 §4.2-1 与 §4.2-2 两个 bug**：用日间平均 HR 对比静息基线时，一个爱走路的人会被永久误判为高压。三条规则（努力度阈值 / workout 窗口 / 运动后 15 分钟尾巴）解决这个。

**③ `weightedSum / totalWeight` 权重重归一化（优于 `return 50` 降级）**

`Soma/Calculators/MovementScoreCalculator.swift:36-56`

```swift
var weightedSum = 0.0
var totalWeight = 0.0
if let h = standHours       { weightedSum += standWeight   * standComponent(h);     totalWeight += standWeight }
if let steps = stepCount    { weightedSum += stepWeight    * stepComponent(steps);  totalWeight += stepWeight }
if let bpm = walkingHRAverage { weightedSum += walkingWeight * walkingHRComponent(bpm); totalWeight += walkingWeight }
guard totalWeight > 0 else { return nil }        // 真无数据
return min(100, max(0, weightedSum / totalWeight))
```

缺失信号的权重**按比例分给剩余信号**，而不是补 0（压低分数）或补 50（稀释真实信号）。且区分两种 nil：**分量 nil**（重归一化）vs **全部 nil**（返回 nil）。

**④ Recovery 的三级降级链**

`Soma/Calculators/RecoveryCalculator.swift:82-97`

| 级 | 条件 | 结果 |
|---|---|---|
| 1 | HRV 历史 ≥ 7 天且有变异 | z-score 路径（个人化） |
| 2 | 历史不足但有 scalar 基线 | ratio [0.5, 1.5] → [0, 100] |
| 3 | 连基线都没有 | `return 50`（中性） |

**⑤ 有界惩罚 vs 硬封顶**

- ACR 惩罚：ACR > 1.3 时 `penalty = min(acr - 1.3, 0.7) / 0.7 * 10`，**上限 -10 分**。
- 睡眠剥夺硬封顶（Thump 更彻底）：3h→20 / 4h→35 / 5h→50。

**⑥ 睡眠一致性用 stddev + 跨午夜负偏移**

`Soma/Calculators/SleepConsistencyCalculator.swift:33-53`：把 `hour >= 18` 的入睡时刻映射成**负的 minutes-from-midnight**（23:00 → -60，00:00 → 0），这样 23:30 和 00:30 在数轴上连续，stddev 不被午夜断层炸掉。窗口 ≥ 3 晚，120 分钟 stddev → 0 分。

**⑦ Insight 的 A/B 对照统计（而非模板树）**

`Soma/Calculators/BehaviorEngine.swift:223-263`：对每个 (行为, 指标) 组合算 `有该行为的日子的次日指标均值` vs `没有的日子`，三重门槛（两组各 ≥ 5 次观测 + |delta| ≥ 2.0），按 |delta| 降序。

- ⭐ **次日滞后是关键**：喝酒/咖啡因/晚睡的影响在**第二天**的生理指标上才显现。
- ⭐ **措辞极克制**：`"After \(behavior), your \(metric) tends to be \(x) \(unit) \(direction)."` —— 用 "tends to be"，注释明写 "Associative framing, not causal"。

**⑧ 测试纪律（12 个测试文件，零 mock）**

```swift
// 性质测试（抗重构，符号写反就红）
XCTAssertGreaterThan(score(todayHRV: 75), score(todayHRV: 50))
XCTAssertLessThan(score(todayHRV: 32), score(todayHRV: 50))

// 差分测试（锁死权重×分量增量）
XCTAssertEqual(scoreClean - scoreInterrupted, 6, accuracy: 0.1)

// 退化边界（输入合法但数学上会除零）
func test_hrvZScore_nilWhenNoSpread() {
    XCTAssertNil(BaselineCalculator.hrvZScore(today: 60, values: Array(repeating: 50.0, count: 7)))
}
```

**⑨ 架构纪律：`Calculators/` 全部只有 `import Foundation`**

这是它能零 mock 完整单测、且能在非 iOS 平台跑测试的唯一原因。**StressWatch 应立刻确立同款规矩。**

**⑩ 冷启动容量模式**

`StrainCalculator.swift:114-126`：前 7 天用固定常量 `500`，之后切到滚动 14 天个人均值。天然解决"新用户第一天没有历史"。

### 1.2 ❌ 不应该复制

| 模块 | 原因 |
|---|---|
| `AyurvedicSleepCalculator`（163 行） | 阿育吠陀"生物钟窗口"加分，无循证依据，与非医疗定位冲突 |
| `SomaAgeCalculator`（372 行，生物年龄） | 硬编码"男性参考曲线"，争议大，属类医疗声明 |
| `MenstrualCycleCalculator`（102 行） | 依赖 menstrual 权限，Soma 自己都注释 "app is men-only" 且未接线 |
| `TrainingGuidanceEngine` / `ActivityLevel` / `suggestWorkouts` | "HIIT / deload / heavy strength" 是训练向语言 |
| `BehaviorEngine` 的 **8 个自报行为打卡** | 需要一整套打卡 UI + 每日提醒。**相关性分析可以抄，行为来源要换成 HealthKit 已有信号**（mindful minutes / workout 时段 / stand hours） |
| `mindfulMinutes` 打折（-5 分） | 产品 hack，且没数据时硬塞 15 分钟代理值 |
| 0–100 与 0–21 双单位制 | 每个交叉点手动换算，纯架构债 |
| `computeBaseline` 的门槛 bug | doc 说要 7 天，实际 1 天就返回值；测试反而固化了这个 bug |
| 用 `Calendar.current` 写测试 | DST / 时区会 flaky |

---

## 2. Whoordan

### 2.1 ✅ 可以借鉴

**① Provenance 四层模型（最值得抄的一块）**

```swift
// 层 1：粗粒度来源 + 优先级
enum DataSource: String { case appleHealth, wearableBLE, localManual, whoordanEstimate, ...
    var deviceFirstRank: Int { ... } }   // 同级取最新

// 层 2：派生方式（直接回答"这个数是测的还是算的"）
enum WhoordanMetricSource: String {
    case direct, legacyWearable, calculated, mlEstimated, imported, unavailable
}

// 层 3：metadata 白名单（算法级溯源）
// metric_policy / device_only_derivation / source_label / contact_detected

// 层 4：MetricVisibilityRegistry（每个指标一张"档案卡"）
//   sourceKind / formulaOrDerivation / minimumDataRequired /
//   baselineWindowRequired / confidenceThreshold /
//   emptyStateCopy / insufficientDataCopy / productionVerdict
```

> **对 StressWatch 的直接影响**：LLM 层必须能区分"实测值"和"回退到基线的占位值"，否则有过宣称风险。当前 `AnalysisPayload` 完全没有这个维度。

**② `ConfidenceLevel` 六值（比三值更诚实）**

```swift
case high, medium, directional, low, blocked, unavailable
// .directional = "有方向但量级不确定"
```

`.directional` 这一档对 wellness app 特别合适 —— HRV 低是确定的，但"低多少意味着什么"不确定。

**③ "宁缺勿滥"的解析器 + 带原因的 nil**

```swift
guard let selected = candidates.first else {
    return ResolvedHealthMetric(
        type: type, value: nil, ..., status: .missing,
        reason: missingReason(for: type)     // 人类可读的缺失原因
    )
}
// status: available / missing / stale / unsupported
```

不是返回裸 `nil`，而是返回一个**带 `reason` 的缺失值对象**。UI 可以直接渲染"为什么没有这个数"。

**④ 生理合法性表（集中、可测）**

```swift
case .heartRate, .restingHeartRate:  return (25...240).contains(sample.value)
case .heartRateVariabilitySDNN:      return sample.unit == "ms" && (1...300).contains(sample.value)
case .respiratoryRate:               return (4...60).contains(sample.value)
```

**⑤ "缺失 ⇒ 地板值，不跳过"**

`ReadinessEngine.swift:70-81`（Thump 也有同款）：睡眠缺失时不排除该分量，而是给地板分 40。若跳过并重归一化，用户不戴手表反而得分更高（幸存者偏差）。

**⑥ Baseline：中位数 + 5 天门槛 + 取短板**

```swift
hrv: hrvValues.count >= 5 ? median(hrvValues.suffix(28)) : nil
var coreDayCount: Int { min(hrvCount, restingHeartRateCount) }   // 不取平均，取最弱环节
```

**⑦ 校准进度三元组**

```swift
var eligibleDayCount: Int
var requiredDayCount: Int
var daysRemaining: Int { max(requiredDayCount - eligibleDayCount, 0) }
// 状态机：无基线 → 临时基线(.temporaryCustom) → 攒够 → 自动切 .automatic（此后禁止手改）
```

UI 能显示"还需 3 天完成校准"，比现在的 `needsMoreData = true` 友好得多。

**⑧ 谓词集中化的隐私门禁 + 解码时强制归一化**

```swift
struct PrivacyAccessGuard {                     // 无状态 struct，纯谓词
    func canUploadHealthData(approval:, consent:) -> Bool { ... }
}

var normalizedForCurrentPrivacyModel: ConsentState {
    var normalized = self
    if !normalized.cloudSyncEnabled { normalized.healthDataCloudConsent = false }
    return normalized
}
// 在 LocalStore 每次 decode 时强制执行
```

**收紧隐私策略时，老用户的数据自动跟着收紧，不需要写迁移代码。** StressWatch 应把"能否发数据给 LLM"做成同款谓词。

**⑨ 本地持久化（与 StressWatch 同构，可直接吸收）**

```swift
try data.write(to: fileURL, options: [.atomic])
try? FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: fileURL.path)
// schema 演进：decodeIfPresent(...) ?? 默认值，手写 init(from:)
```

**⑩ 架构约束写成测试（强烈建议抄）**

```swift
// ProjectArchitectureTests.swift:4-28 —— 读 pbxproj 文本断言工程分组与磁盘一致
// DesignContractTests.swift:23-48 —— Features/ 层禁止 import HealthKit / HKHealthStore / FileManager.default
// DesignContractTests.swift:64-118 —— UI 文案契约：必须含 "Not medical advice"，禁止 "No data" 哑空状态
```

成本 ~50 行，长期防腐化。

**⑪ 睡眠一致性用圆周标准差**

```swift
let angles = hours.map { (($0.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)) / 24 * 2 * .pi }
let resultant = hypot(sinMean, cosMean)
return sqrt(max(-2 * log(resultant), 0)) * 24 / (2 * .pi)
```
比 Soma 的负偏移法更数学正确（Soma 的 `hour >= 18` 阈值对下午睡的人有副作用）。

### 2.2 ❌ 不应该复制

| 模块 | 原因 |
|---|---|
| **HealthKit 读链路** | Whoordan 是 **export-only**，`supportedReadTypes() -> []`，`importSamples` 直接返回 `.unavailable`。它的主数据源是自家 BLE 手环。**读链路没有可参考的实现** |
| `DeviceMetricSourcePolicy` | BLE 优先策略，`queryableProductionSources` 排除 `.appleHealth`。**抄了会把 StressWatch 的主数据源全部过滤掉** |
| `hasUsableContactSignal` | 依赖手环佩戴检测 metadata |
| `estimatedStageSegments`（HR+IMU 猜睡眠分期） | Apple Watch 已直接给分期，不需要 |
| Supabase / Auth / ApprovalGate / 离线宽限期 | 云端 + 账号 + 审批门禁，与本地优先冲突 |
| BLE 协议（3426 + 1824 行）、震动/触觉、来电震动、闹钟 | 硬件相关 |
| `ScoringServicing` 的双实现割裂 | 一条路径 recovery 基线全是 nil（测试锁死了这个行为），另一条才真算。**反面教材：scoring protocol 应显式接收 baseline 作为输入参数** |
| Confidence 判定权分散 | engine 给 `.high`，UI 层又压到 `.directional`。**应统一在一处判定** |
| 40+ 字段的单体 `DailyMetrics` | init 有 45 个参数；无 schemaVersion；decode 失败静默清空全部历史 |

---

## 3. Thump

> **这是"数据分析产品层"最完整的参考。用户提的五个问题（为什么是 63 / 相比平时变了什么 / 哪些数据相关 / 近期趋势 / 可信度）Thump 都有对应实现。**

### 3.1 ✅ 可以借鉴

**① "为什么是这个分数" ——双层 explainability**

- Readiness 五支柱，每根柱子自带 `detail` 字符串（`ReadinessEngine.swift:174-185`）：

```swift
} else if hours >= 5.0 {
    detail = "%.1f hours — well below the 7+ hours your body needs"
} else {
    detail = "%.1f hours — very low. Even if other metrics look good, sleep debt overrides them."
}
```

- HRV pillar 最后一层带**时间预期**：`"well below your usual. Rest and sleep are the best levers — this typically rebounds within a day or two."` —— 给出恢复窗口能显著降低焦虑。

- `PillarWhySheet` 下钻：**weakest-pillar-wins**，只归因于最弱的那根柱子。

**② `RecoveryContext` 四元组 —— 这是最接近用户需求的现有结构**

`HeartTrendEngine.swift:192-219`

```swift
RecoveryContext(
    driver: "HRV",                                    // 主要原因
    reason: "Your HRV is below your recent baseline…", // 相比平时发生了什么变化
    tonightAction: "Aim for 8 hours of sleep tonight…",// 建议
    bedtimeTarget: "10 PM"                             // 可执行的具体目标
)
```

**③ Robust Z（median + MAD）—— 抗离群点**

```swift
func robustZ(value: Double, baseline: [Double]) -> Double {
    let med = median(baseline); let madValue = mad(baseline)
    guard madValue > 0 else { return abs(value - med) < 1e-9 ? 0 : (value > med ? 3 : -3) }
    return (value - med) / madValue
}
func mad(_ v: [Double]) -> Double { let m = median(v); return median(v.map { abs($0 - m) }) * 1.4826 }
```

**④ ⭐ 基线用 P75 而非均值 —— 抗"基线归一化"**

`ReadinessEngine.swift:388-394`

```swift
// Use the 75th percentile instead of the mean. This anchors the baseline
// closer to the user's "good days" so that a sustained stress spiral
// doesn't drag the reference point down with it.
let sorted = recentHRVs.sorted()
let avgHRV = sorted[Int(Double(sorted.count - 1) * 0.75)]
```

**这是 StressWatch 必须吸收的一条**：滚动均值做基线，长期压力用户会看到自己的分数"越病越正常"。对应回归测试 `TextSafetyTests.swift:356-383` 模拟 14 天 HRV 从 50→25ms 的压力螺旋，断言仍输出 "well below" 而非 "noticeably lower"。

**⑤ 噪声死区 + 分层统计**

| 方法 | 窗口 | 统计 |
|---|---|---|
| `anomalyScore` | 21 天 | median + MAD 的 robust Z |
| `detectRegression` | 7 天 | OLS 斜率，**只对坏方向敏感** |
| `weekOverWeekTrend` | 基线 28 / 当前 7 | 前后段均值 + Z，**`baselineStd > 0.5` 死区** |
| 连续抬升 | ≥ 7 天 | **日历连续性** `gap > 1.5 days` 打断（不是数组下标） |

```swift
guard baselineStd > 0.5 else { return WeekOverWeekTrend(zScore: 0, direction: .stable, ...) }
```

**⑥ 置信度扣分制 + `warnings: [String]`**

```swift
var score = 1.0
if !hasRHR { score -= 0.15; warnings.append("No resting heart rate data") }
if baselineHRVSD == nil { score -= 0.10; warnings.append("Limited baseline history") }
if disagreementPenalty > 0 { score -= disagreementPenalty; warnings.append("Heart rate and HRV signals show mixed patterns") }
```

**每个扣分同时产出一条人类可读的原因** —— UI 可以直接渲染"为什么只有低置信度"。StressWatch 现在的 confidence 是个裸 Double。

**⑦ 置信度参与计算，不只是展示**

- Readiness 的 stress 支柱：`attenuated = (100 - clamped) * confidenceWeight + 50 * (1 - confidenceWeight)`
- `determineStatus`：`confidence != .low` 才允许判 `.improving`

**⑧ disagreement damping —— 信号互搏时向中性压缩**

```swift
if rhrDisagrees || hrvDisagrees {
    return (rawComposite * 0.70 + 50.0 * 0.30, 0.30)   // 分数压缩 + 返回 penalty 降置信度
}
```

**⑨ Provisional 分数（不用空态阻塞）**

```swift
// 第 1 天：用人群平均 HRV 基线 40ms，让用户立即看到 provisional 读数，
// 而不是"等 3 天"空态。confidence 强制 .low
if isProvisional {
    warnings.append("Baseline forming — score will refine over the next few days")
    result = StressResult(..., confidence: .low, ...)
}
```

**⑩ severity ladder 而非加权平均**

```swift
if consecutiveDays >= 5 { return .medicalCheck }
if sleepDeprivation == .severity || overtraining >= .deload { return .fullRest }
if stressElevated && readiness < 45 { return .fullRest }
...
```
多个建议相加会变成噪音，**取最严重的那个才安全**。

**⑪ 跨层级一致性硬约束**

```swift
// 限制性模式下目标必须降级（防止 UI 一边说"今天休息"一边显示"目标 10000 步"）
if mode == .fullRest || mode == .medicalCheck {
    cappedGoals = goals.map { $0.target > cap ? spec.with(target: cap) : $0 }
}
// 跨 Tab：stress 可以 .relaxed，但只要 readiness 是 .recovering，
// 就不能出现 Workout / Focus Time / push hard / high-intensity
```

**⑫ 措辞护栏（四类 banned terms）—— 分类法值得抄**

```swift
medicalTerms       = ["diagnose","treat","cure","prescribe","clinical","pathological"]
jargonTerms        = ["SDNN","RMSSD","coefficient","z-score","p-value","regression analysis"]
aiSlopTerms        = ["crushing it","on fire","killing it","smashing it","rock solid"]
anthropomorphTerms = ["your heart loves","your body is asking","your heart is telling you"]
```

**⑬ 合成人格测试矩阵（最有价值的测试基础设施）**

```swift
// MockData.Persona：10 种生理一致的人格，每个指标一个区间
case .athleticMale:  rhr:(46,54)  hrv:(55,95) steps:(8000,18000) sleep:(7.0,9.0)
case .couchPotatoMale: rhr:(72,84) hrv:(18,35) steps:(1500,5000) sleep:(5.0,7.0)

// ⭐ 生理相关性注入 —— 生成的数据天然带已知的真实相关结构
let hrvBase = ranges.hrv.0 + (activitySignal * 0.4 + sleepSignal * 0.6) * (ranges.hrv.1 - ranges.hrv.0)

// ⭐ 每指标不同缺失率（recoveryHR 25-30%，因为真实场景最难采到）
hrvSDNN: nilRoll(..., 0.08) ? nil : max(5, hrv)
recoveryHR1m: nilRoll(..., 0.25) ? nil : ...

// ⭐ 确定性种子：绝不能用 String.hashValue（每进程随机化）
let personaSeed = persona.rawValue.unicodeScalars.reduce(5381) { (acc &* 33) &+ Int(c.value) } & 0xFFFF
```

**带预期结果的 persona**（`SyntheticPersonaProfiles.swift:14-40`）：

```swift
struct EngineExpectation {
    let stressScoreRange: ClosedRange<Double>
    let expectedTrendStatus: Set<TrendStatus>        // 用 Set 表达"允许解空间"，避免脆断言
    let readinessLevelRange: Set<ReadinessLevel>
    let minBuddyPriority: RecommendationPriority
}
```

**life-story 命名**（`newMom` / `recoveringIllness` / `weekendWarrior`）—— 测试失败时你立刻知道哪个场景坏了。

**⑭ 相关性文案的关联语气清单**

`tends to` / `tracks with` / `lines up with` / `in your data` / `this pattern`
**从不使用** `causes` / `because` / `makes` / `improves`

且 `|r| < 0.2` 时**不隐藏弱结果**，而是明确说"还没找到清晰关联，再多记录几天会更清楚"。

**⑮ 颜色按"是否有益"而非"符号正负"**

```swift
// 步数 vs 静息心率的 r = -0.7 是好事，不能显示红色
return correlation.isBeneficial ? .green : .red
```

### 3.2 ❌ 不应该复制

| 模块 | 原因 |
|---|---|
| **相关性引擎的实现** | 纯 Pearson、**无 lag**、且**文案声称次日因果但算法是同日配对**（"sleep more → RHR the next day tends to be lower"，而 `pairedValues` 取的是同一天的 sleepHours 和 RHR）。**这是文案与算法不一致的真实 bug —— 绝不能复制** |
| 措辞护栏只在测试层（8 份重复的 banned list，零运行时强制） | 应提到引擎层：用类型/枚举约束，而非 CI grep 字符串 |
| `StressSignalBreakdown` 存的是**加权前**的分数，权重是 private | UI 无法还原"RHR 贡献了 50% × 72 = 36 分"。**应让 Σ contributions == finalScore 成为可断言的不变式** |
| ThumpBuddy 宠物养成、Conquering Flag、Mission 游戏化、Coach Streak | 游戏化，与 wellness trend 定位冲突 |
| BioAge（生物年龄，523 行） | 监管高危区，不符合非医疗定位 |
| 疾病前兆预测（"precedes illness onset by 1-3 days"） | 健康预测声明 |
| Watch 双端同步、Firebase/Firestore 反馈回流 | 无 watch；与本地优先冲突 |
| 训练阶段阈值上调（tapering 时 stressed 阈值 44→54） | 运动员定向；普通用户会变成"长期高压不报警" |
| `TrendStatus` 只有三态，无 `volatile`、无顶层 `insufficientData` | 需自建 |
| oversleep → "mention it to your care team" | 从睡眠时长直接跳到就医建议，逻辑跳跃大 |

---

## 4. WorkoutTracker

### 4.1 ✅ 可以借鉴

**① ⭐ `buildStatsContext()` —— 4 行聚合摘要喂给 LLM（最有价值的一段）**

`Features/AICoach/Views/AIWeeklyReviewSheet.swift:194-205`

```swift
return """
    THIS WEEK: \(currentStats.workoutCount) workouts, \(Int(currentStats.totalVolume)) \(safeUnits) total volume.
    PREVIOUS WEEK: \(previousStats.workoutCount) workouts, \(Int(previousStats.totalVolume)) \(safeUnits) total volume.
    NEW PERSONAL RECORDS THIS WEEK: \(prNames).
    IDENTIFIED WEAK POINTS: \(weakNames).
    """
```

**证明了：不需要把原始样本喂给 LLM，只要喂几行结构化聚合摘要，就能产出高质量个性化叙述。** StressWatch 对等形态：

```
TODAY: stress 64, recovery 71
HRV: 42 ms (7d baseline 51 ms, -17.6%, trend declining 4 days)
RHR: 68 bpm (baseline 63, +7.9%)
SLEEP: 6.4 h (baseline 7.3 h, -0.9 h)
ACTIVITY: moderate
DATA COMPLETENESS: 0.86 (activity missing)
```

**② 隐私：端上零密钥 + 服务端代理 + 网络层守卫**

```swift
// 端上：App Check 证明"这是真 App"，匿名 Firebase ID Token 证明"这是真人"
// 密钥留在 Cloud Run 服务账号，端上不持有
request.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")

// 同意门放在 network client 层，UI 绕过也会抛错
guard UserDefaults.standard.bool(forKey: hasConsentedToAI) else { throw AILogicError.aiConsentRequired }

// 服务端强制 safety settings，客户端无法覆盖
body.safetySettings = SAFETY_SETTINGS_USER;
```

> ⚠️ StressWatch 目前是**用户自带 MiniMax Key 直连**（Keychain 存 key）。这条路径对"隐私优先"其实更好（数据只到用户自己的账号），**不需要改成代理**。但"同意门放在网络层"这一条值得抄。

**③ 数据最小化：敏感字段根本不进 DTO**

```swift
// [5.1.3] Privacy: body weight (Health data) is NEVER sent to the server.
// System prompts rely on experience level + PRs only.
```
> 但它 `UserProfileContext` 里仍有 `weightKg` 字段（只是 prompt 构建时不用）—— **字段存在即风险**。StressWatch 应根本不放进 DTO。

**④ LLM 输出值域钳制**

```swift
return min(max(response.recommendedHours, 12.0), 120.0)   // 防模型吐 9999 或负数
```
StressWatch 若让 LLM 输出分数/天数，必须同样钳制。

**⑤ JSON Schema 强约束 + 温度分档 + 三层解析兜底**

```
确定性任务 temperature 0.1（classify / 参数反推）
创造性任务 temperature 0.7（chat / 标题）

兜底：① 剥 ```json``` 围栏  ② 业务有效性校验（数组非空）  ③ 值域钳制
```

**⑥ 服务端滚动窗口限流 + 客户端指数退避**

```javascript
const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 10;
// 事务原子计数，先计数后执行（aborted 调用也计数，防滥用）
// 限额可从 Firestore 远程调
```
⚠️ 但客户端对"周限额"类 429 也退避重试 3 次 —— **不会成功，白等 14 秒**。应对周限额直接失败并给明确文案。

**⑦ 睡眠读取：分期过滤 + InBed 兜底 + 区间合并防重复计时**

```swift
let asleepSamples = sleepSamples.filter { [.asleep, .asleepCore, .asleepDeep, .asleepREM].contains($0.value) }
let samplesToProcess = asleepSamples.isEmpty ? sleepSamples.filter { $0.value == .inBed } : asleepSamples
// 区间合并：多段睡眠叠加时不会重复累加
if sample.startDate <= last.end { merged[last].end = max(last.end, sample.endDate) }
else { merged.append((sample.startDate, sample.endDate)) }
```

**⑧ 四态 UI 降级（loading / error / empty / success）** + 显式按钮触发（用户点一次才花一次配额）

### 4.2 ❌ 不应该复制

| 模块 | 原因 |
|---|---|
| **`CNSCalculator` 的算法** | ① HRV/RHR **只罚不奖**（`dev = 0` 就是满分，HRV 高于基线无奖励，生理学错误）② `fetchAverageHRV(days:)` **写了但从未被调用** ⇒ baseline 恒为 nil，退化成硬编码 40ms/60bpm，"相对个人基线"在运行时是假的 ③ 生产根本没调用它，UI 用的是 View 内联的 `20 + 睡眠缺口×10 + 饮水缺口×2`（**HRV/RHR 权重为 0**） |
| `HealthKitManager` 单例（`actor.shared` + `private init`） | **无 protocol、无 mock、无法测试**。StressWatch 已有 `HealthKitDataProvider`，不要倒退 |
| 把 HealthKit 派生值存 `@AppStorage` | 无历史、无法画趋势。对 "trend app" 是致命的 |
| 肌肉群疲劳模型（12-96h 线性衰减 + 22 个肌群） | 无训练即无肌群维度 |
| 动作库（900+ 动作）、组数×次数×重量、1RM（Epley/Brzycki/Lander）、PR 记录、器械、Superset、休息计时器 | 健身专属 |
| XP / 成就 / Streak | 游戏化，对健康 App 有负面心理压力 |
| system prompt 无任何医疗免责或反幻觉约束 | 一行都没有，StressWatch 必须自建 |
| 无内容缓存 | 重复烧钱 |

---

## 5. Health Dashboard（`hmnshudhmn24/health-dashboard-app-swift`）

> 388 行，极简 Demo 级项目。**主要用于反面参照与 UI 层级核对。**

### 5.1 ✅ 可以借鉴

**① 空态给出可执行引导，而不是"哑空状态"**

```swift
if !healthManager.steps.isEmpty { stepsCard }
else { placeholderCard(title: "Steps",
        subtitle: "No data yet — grant HealthKit permission and open Health app data.") }
```

**② 按指标类型选图表形态**

- Steps / Sleep（累计量）→ `BarMark`
- Heart Rate（连续量）→ `LineMark` + `PointMark`

**③ `discreteAverage` 取日平均心率**（`HealthDataManager.swift:90-94`）—— StressWatch 目前用 `latestValue`，离散平均更适合做日聚合。

**④ 目标完成度的即时反馈**（`GoalTracker`）—— 已在 StressWatch 的 Activity 卡有类似形态，可保留。

### 5.2 ❌ 不应该复制

| 问题 | 说明 |
|---|---|
| **心率和睡眠用 `.strictEndDate` 谓词** | 与 steps 用同一 predicate，跨午夜睡眠会漏 |
| **睡眠按 `startDate` 归日** | `byDay[Calendar.startOfDay(for: s.startDate)]` —— 23:00 入睡算前一天，与主流（按醒来日归属）相反 |
| **`DispatchQueue.main.async` 回调式** | 未用 async/await，与 StressWatch 现风格不符 |
| **无个人基线、无任何分析** | 纯展示，无参考价值的算法 |
| **卡片直接堆砌** | 3 张等权卡片平铺，无信息层级。**用户明确要求"不要为了增加功能而堆大量 Card"** |
| 授权失败静默 `print` | 用户看不到任何反馈 |
| 无 confidence / provenance | — |

---

## 6. HealthKit Exporter（`jinsoowhang/healthkit-exporter`）

> 942 行，5 个文件。**主要用于核对 StressWatch 的 HealthKit 数据层完整性。**

### 6.1 ✅ 可以借鉴

**① ⭐ 睡眠按醒来日（endDate）归属 —— 与 StressWatch 一致 ✅**

```swift
// Group by wake-up date (use endDate's calendar day)
let key = dateFormatter.string(from: sample.endDate)
```
StressWatch `HealthKitService.fetchDailySleepAnalysis` 用 `calendar.startOfDay(for: sample.endDate)` —— **已正确，不用改**。

**② InBed 兜底（StressWatch 缺）**

```swift
// If we only have inBed (no stage breakdown), use inBed as total
let totalHours = asleepMins > 0 ? asleepMins / 60.0 : inBedMins / 60.0
```
StressWatch 只累计 `asleep*` 五值，**如果设备只写 InBed 会得到 0 小时**。

**③ 同时产出 `totalHours / inBedHours / asleepHours / bedTime / wakeTime`**

StressWatch 目前只有 duration + 分期，**没有 bedTime / wakeTime**，因此做不了睡眠规律性（Soma/Whoordan 的 stddev / 圆周 SD）。

**④ `HKActivitySummaryQuery` 拿 Move/Exercise/Stand 目标值**

StressWatch 的 `activityEnergyGoal: "500 kcal"` 是硬编码字符串。改成读用户的真实 Apple Watch 目标更合理。

**⑤ `async let` 并行拉取**（`HealthKitManager.swift:10-18`）—— 9 个指标并发。StressWatch 是串行 for 循环，可优化。

**⑥ 输出前的数值规整**

```swift
durationMinutes: (durationMinutes * 10).rounded() / 10
distanceKm: distanceKm.map { ($0 * 10).rounded() / 10 }
```
避免浮点毛刺出现在 UI / payload 里。

### 6.2 数据完整性核对结论

| 指标 | StressWatch | Exporter | 结论 |
|---|---|---|---|
| HR / RHR / HRV | ✅ | ✅ | 一致 |
| Steps / Active Energy / Exercise | ✅ cumulativeSum | ✅ | 一致 |
| Stand Time | ✅ iOS18+ | ✅ via ActivitySummary | Exporter 方案兼容性更好 |
| Sleep 分期 | ✅ | ✅ | 一致，但 **Exporter 多 InBed 兜底** |
| Sleep bedTime/wakeTime | ❌ | ✅ | **建议补** |
| ActivitySummary 目标值 | ❌ 硬编码 | ✅ | **建议补** |
| Workouts | ❌ | ✅ | **建议补**（Soma sedentary 过滤需要） |
| SpO2 / 呼吸率 | ❌ | ✅ | 本轮不引入 |
| 并行拉取 | ❌ 串行 | ✅ | 可优化 |

### 6.3 ❌ 不应该复制

- 无 protocol / 无 mock（`enum HealthKitManager` + `static`，直接依赖 `HealthKitExporterApp.healthStore`）
- 数据是**导出到远端 API**（`APIClient.swift` 364 行），与本地优先冲突
- 无聚合、无分析（原样搬运样本）

---

## 7. 六项目横向对比：同一个问题各家怎么解

### 7.1 Baseline

| 项目 | 窗口 | 聚合函数 | 最小样本 | 抗异常值 | 个人变异度 | 校准进度 |
|---|---|---|---|---|---|---|
| **StressWatch** | 7/14/30 | **算术平均（样本级）** | 3 天 | ❌ | ❌ | ❌ |
| Soma | 30 | log 域 EWMA(α=.25) | 7 | ❌ | ✅ sdLn | 部分 |
| Whoordan | 28 | **中位数** | 5 | ✅（中位数） | ❌ | ✅ |
| Thump | 14 | log(SDNN) z / **P75** | 3（provisional） | ✅ | ✅ SD | ✅ |
| WorkoutTracker | 30（**未调用**） | 平均 | — | ❌ | ❌ | ❌ |

→ **StressWatch 目标**：日聚合 → 中位数/MAD 或 log 域 EWMA → 7/14/30 多窗口 → `n` + `sd` + `calibration`。

### 7.2 Stress

| 项目 | 输入 | 相对基线 | 分量权重 | 冲突处理 | 活动过滤 | confidence 联动 |
|---|---|---|---|---|---|---|
| **StressWatch** | HR/HRV/Steps/Sleep | 百分比偏差 | 4×25 线性 | ❌ | ❌（**abs 方向错**） | ❌ |
| Soma | HRV/HR | `1 - hrv/base`、`(hr-base)/base` | .60/.40 | ❌ | ✅ filterSedentary | ❌ |
| Whoordan | 6 信号 | 混合 | 动态重分配 | ❌ | — | ✅ |
| Thump | RHR/HRV/CV | log z-score | 急性 .50/.30/.20；久坐 .20/.50/.30 | ✅ damping | ✅ 模式识别 | ✅ |
| WorkoutTracker | Sleep/Water（**HRV/RHR 未接线**） | 名义上 | 40/10 | ❌ | ❌ | ❌ |

### 7.3 Recovery

| 项目 | 分量 | 天花板 | components 输出 | 封顶 |
|---|---|---|---|---|
| **StressWatch** | HRV/RHR/Sleep | **基线即满分** | ❌ | ❌ |
| Soma | HRV.40/RHR.25/Sleep.25/Strain.10 | ±2SD→0/100 | ❌（private） | ACR -10 |
| Whoordan | HRV.35/RHR.20/Sleep.17/Resp.20/Temp.08 | 50 中心 ±80 | ✅ contributors | 不许只有 SpO2 |
| Thump | 五支柱 | 加权/TOTAL | ✅ pillars + detail | 睡眠 3/4/5h 硬封顶 |
| WorkoutTracker | Sleep40/HRV30/RHR20/Water10 | 只罚不奖 | ❌ | ❌ |

### 7.4 缺失值处理

| 项目 | 做法 |
|---|---|
| **StressWatch** | `?? baseline.xxx` ⇒ **静默"正常"** ❌ |
| Soma | 分量 `return 50`（稀释）/ MovementScore `totalWeight` 重归一化（更优） |
| Whoordan | `compactMap` 直接丢弃，不插补；`missingReason` 给用户看 |
| Thump | **地板值 40**（缺失即惩罚，防幸存者偏差）—— 最保守也最安全 |

> **结论**：StressWatch 的 `?? baseline.xxx` 是最危险的降级方式。应改为：核心信号缺失 → 该分量退出计算 + 权重重分配 + confidence 扣减 + warnings 追加。

---

## 8. 最终取舍清单

### 8.1 立刻采纳（P0）

1. 日聚合层 `DailyHealthMetrics`（谁都有，StressWatch 没有）
2. Baseline：中位数/MAD 或 log 域 EWMA + `n`/`sd`/`calibration`
3. Stress：z-score + `filterSedentary` + 权重重分配 + disagreement damping
4. Recovery：双向映射（不是只罚不奖）+ components 输出 + activity 项
5. `warnings: [String]` 与 confidence 同步产出
6. 缺失值：地板值 / 重归一化 / 显式 insufficient，**禁止 `?? baseline`**
7. 架构纪律：新增 engine 只 `import Foundation`
8. 新建单元测试 target

### 8.2 第二阶段采纳（P1）

9. TrendEngine：robust Z + OLS（单边）+ 前后段均值 + 噪声死区 + 日历连续性
10. CorrelationEngine：**带 lag**（Thump 没有）+ 关联语气枚举约束（Thump 只靠措辞）
11. `StructuredAnalysisResult`（用户要求的那个 JSON）
12. Provenance：实测 / 估算 / 缺失三态
13. 本地 fallback 文案（LLM 失败降级）
14. 架构约束测试 + 文案契约测试

### 8.3 明确不采纳（P2 / 否）

- ❌ 任何游戏化（Buddy / Streak / XP / Mission）
- ❌ 生物年龄（BioAge / SomaAge）
- ❌ 训练相关（ATL/CTL 除外——这个是纯统计，可以借；其余全部剔除）
- ❌ 阿育吠陀 / 经期 / 疾病预测
- ❌ 云端账号 / 代理 / 审批门禁（保留用户自带 Key 直连，隐私更好）
- ❌ 自报行为打卡 UI（相关性分析改为基于 HealthKit 已有信号）
- ❌ SwiftData 迁移（现有 FileManager + JSON 够用，改动风险大于收益）
- ❌ 复制任何一家的相关性实现（Thump 无 lag 有 bug；Soma 依赖打卡；自建）
