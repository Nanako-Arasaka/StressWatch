# StressWatch 现状分析（第一阶段 · 只读，未修改任何代码）

> 分析时间：2026-09-24
> 仓库：`/Users/silencecf/code/stresswatch/StressWatch`
> 规模：主 App 63 个 Swift 文件 + Widget 8 个文件，共 **10,041 行**

---

## 0. 结论先行

| 维度 | 现状评级 | 一句话 |
|---|---|---|
| 架构分层 | ⭐⭐⭐⭐ | Protocol + DI + Mock/Real 已经成型，不必重构 |
| HealthKit 数据层 | ⭐⭐⭐ | 12 类指标已覆盖，但**缺失值/来源/授权态**的表达很弱 |
| Baseline | ⭐ | **窗口内算术平均，无异常值剔除、无个人变异度、无校准状态** |
| Stress 算法 | ⭐⭐ | 4×25 线性相加，方向有误、无 z-score、无置信度 |
| Recovery 算法 | ⭐⭐ | 基线即满分（天花板过低）、无 components、无 activity |
| Trend | ⭐ | **Trends 页面存在系统性造假**（见 §8） |
| Correlation | ⭐ | 完全缺失 |
| Insight | ⭐⭐⭐ | 模板化的 `MLWellnessInsight`，无结构化 factors 支撑 |
| LLM 层 | ⭐⭐⭐⭐ | **已经做对了最关键的一件事**：只喂聚合 payload，不喂原始样本 |
| UI 信息层级 | ⭐⭐⭐⭐ | Apple Health 风格成型，已有多段式卡片 |
| 可测试性 | ⭐ | **没有任何单元测试 target** |

**三个最严重的真问题**（优先于此后的任何功能新增）：

1. 🔴 **Trends 页面数据造假** —— `TrendViewModel.makeReferenceScores` 用 `sin()` 造 31/365 天假分数，`estimatedHRV` 从 stress 分量反推 HRV 冒充真实趋势。
2. 🔴 **Demo 数据污染真实数据** —— `DashboardViewModel.fetchMetrics` 把 Apple Health 缺失的指标类型用 demo 数据补位，且 UI 只显示一个合并来源标签。
3. 🔴 **Baseline 不是"个人基线"** —— 对窗口内所有样本取算术平均（HR/HRV 是高频样本、steps 是日累计，混在一起平均），无异常值剔除、无变异度、不区分"数据少"和"数据差"。

---

## 1. 当前项目架构

### 1.1 目录结构

```
StressWatch/
├── App/StressWatchApp.swift                    # 依赖树手工组装 + HRV 通知协调器
├── Core/
│   ├── Analysis/
│   │   ├── WellnessAnalyzer.swift              # 规则模型（WellnessAnalyzing）
│   │   ├── CoreMLWellnessAnalyzer.swift        # Core ML 分类，无模型时 rule fallback
│   │   ├── FeatureExtractor.swift              # 原始 metrics → WellnessFeatures
│   │   ├── WellnessAnalysis.swift              # WellnessState + MLWellnessInsight 工厂
│   │   ├── BaselineEngine.swift                # 基线（BaselineCalculating）
│   │   ├── StressModel.swift                   # 压力（StressComputing）
│   │   ├── RecoveryModel.swift                 # 恢复（RecoveryComputing）
│   │   ├── AdviceGenerator.swift
│   │   ├── GoalOptimizer.swift
│   │   ├── PersonalizationEngine.swift
│   │   ├── PersonalizationContext.swift
│   │   ├── PersonalizedAdviceGenerator.swift
│   │   └── LLM/
│   │       ├── LLMPersonalizationService.swift # payload → MiniMax → 结构化 insight
│   │       └── MiniMaxClient.swift             # 纯网络层
│   ├── HealthKit/
│   │   ├── HealthKitDataProvider.swift         # 协议（3 个方法）
│   │   ├── HealthKitService.swift              # 真实实现
│   │   └── MockHealthKitService.swift          # Demo 实现
│   ├── LiveStress/
│   │   ├── LiveStressEstimator.swift           # ⚠️ 第二套压力算法
│   │   └── LiveStressSnapshot.swift
│   ├── Models/
│   │   ├── HealthMetric.swift                  # 原始样本 + MetricType + HealthSourceClassifier
│   │   ├── Baseline.swift / StressScore.swift / RecoveryScore.swift
│   │   └── DailyWellnessCheckIn.swift
│   ├── Security/KeychainStore.swift            # MiniMax API Key
│   ├── Storage/
│   │   ├── LocalStorageProtocol.swift          # 15 个方法
│   │   └── LocalStorage.swift                  # FileManager + JSON
│   └── Utils/ MathHelpers.swift, TimeFormatting.swift, DateExtensions.swift
├── Features/
│   ├── Dashboard/   DashboardViewModel(639) + 9 个 Components + Views
│   ├── Trend/       TrendViewModel(472) + TrendView(753) + TrendChart
│   ├── Detail/      MetricDetailView(241)
│   ├── Analysis/    AnalysisViewModel(299) + AnalysisView(473)
│   └── Settings/    SettingsViewModel(237) + SettingsView(400)
└── Shared/ Charts/MetricChart.swift, Components/, Glass/, Motion/, Theme/AppColors.swift, Widget/
```

### 1.2 设计模式盘点

| 模式 | 落地情况 |
|---|---|
| MVVM | ✅ 完整。ViewModel 全部 `@MainActor ObservableObject` |
| Protocol-based DI | ✅ 完整。`any HealthKitDataProvider` / `any BaselineCalculating` / `any StressComputing` / `any RecoveryComputing` / `any LocalStorageProtocol` / `any HealthFeatureExtracting` / `any WellnessAnalyzing` / `any PersonalizationEngineing` / `any LLMPersonalizationAnalyzing` / `MiniMaxClientProtocol` |
| Mock / Real 双源 | ✅ `MockHealthKitService(daysOfData: 30)` + `HealthKitService`，由 `AppDataSource` 切换 |
| 接缝替换 | ✅ `WellnessAnalyzer` ↔ `CoreMLWellnessAnalyzer` 同协议可换 |
| 本地优先 | ✅ 除 LLM 外全部端上；LLM 由 `enableAIAnalysis` 开关 + Keychain key 双重门控 |
| 可测试性 | ❌ **无 test target**；核心 engine 是 `class` 而非 `struct`，且 `StressModel.compute` 依赖 `[HealthMetric]` 原始数组 |

### 1.3 依赖装配（`StressWatchApp.swift:177-211`）

```swift
let storage = LocalStorage()
let healthDataProvider = HealthKitService()
let demoDataProvider = MockHealthKitService(daysOfData: 30)
let baselineEngine = BaselineEngine()
let stressModel = StressModel()
let recoveryModel = RecoveryModel()
// → HRVNotificationCoordinator / DashboardViewModel / TrendViewModel / SettingsViewModel
```

> ⚠️ **没有 `now: () -> Date` 注入、没有 `calendar` 注入到 ViewModel 层**。所有时间相关逻辑硬编码 `Date()` / `Calendar.current`，这是无法做确定性测试的直接原因之一。

---

## 2. 当前数据流

### 2.1 主链路（Dashboard）

```
DashboardViewModel.refresh()                                  :65
  ├─ storage.fetchBaselineWindowDays()      → 7 / 14 / 30     :86
  ├─ storage.fetchPreferredDataSource()     → .appleHealth/.demo
  ├─ fetchMetrics(preferred:from:to)                          :234
  │    ├─ 总是先拉 demoMetrics                                 :240
  │    ├─ if .appleHealth → requestAuthorization + fetchMetrics(allCases)
  │    └─ fallbackMetrics = demoMetrics.filter{ !appleTypes.contains($0.type) }   :256
  │       ⚠️ 真实数据 + demo 数据混在一个数组里返回
  ├─ baselineEngine.calculate(from: metrics) → Baseline?      :111
  │    └─ nil → needsMoreData = true，整个 Dashboard 空态
  ├─ todayMetrics = metricsForDay(now, in: metrics)           :124
  ├─ stressModel.compute(current: todayMetrics, baseline:)     :125
  ├─ recoveryModel.compute(current: todayMetrics, baseline:)   :126
  ├─ storage.saveBaseline / saveStressScore                    :128-129
  └─ makeSnapshot(...) → HealthDashboardSnapshot               :287
       ├─ featureExtractor.extract(metrics, stress, recovery, stressTrend)
       ├─ wellnessAnalyzer.analyze(features) → WellnessAnalysis
       └─ 7 张 DashboardMetric 卡片 + WidgetSnapshot
```

### 2.2 分析链路（Analysis 页）

```
AnalysisViewModel.init                                         :29
  ├─ featureExtractor.extract(...) → WellnessFeatures
  ├─ analyzer.analyze(features) → WellnessAnalysis (CoreML or Rule)
  ├─ adviceGenerator.advice(for:) → [String]
  └─ runPersonalization(analysis:)
        ├─ buildPersonalizationContext()  (baseline + 4 个 trend + checkIns)
        ├─ personalizationEngine.personalize(analysis:context:)
        │     ├─ goalOptimizer.optimizeGoals(context:analysis:)
        │     ├─ adviceGenerator.advice(...)
        │     └─ reconcile(打卡 vs 模型)
        └─ ── 用户点按钮 ──▶ generateLLMInsight()
              ├─ KeychainStore.read() → apiKey
              ├─ llmService.generateInsight(context:analysis:model:apiKey:)
              │     ├─ buildPayload()  → AnalysisPayload (Codable)
              │     ├─ buildMessages() → system prompt + JSON
              │     ├─ MiniMaxClient.complete()
              │     └─ parseInsight()  → PersonalizationInsight
              └─ llmInsightState = .success / .failure
```

### 2.3 趋势链路（Trend 页）

```
TrendViewModel.loadHistory(days:)                              :178
  ├─ storage.fetchStressScores(from:to:) → stressHistory
  ├─ storage.fetchStressScores(上一周期) → previousStressHistory
  └─ makeAnalysis(current:previous:range:)                     :203
       ├─ normalizedScores()  → ⚠️ 与 makeReferenceScores() 合并  :273
       ├─ makeWellnessFeatures(from: scores)  ⚠️ 从 stress 分量反推 HRV/RHR
       ├─ analyzer.analyze(features)
       └─ distribution / trendBars / heatmapRows / recoveryTrend /
          sleepConsistency / insights
```

---

## 3. 当前 HealthKit 数据层

### 3.1 已读取的指标（`HealthKitService.swift`）

| MetricType | HK 类型 | 聚合方式 | 备注 |
|---|---|---|---|
| `.heartRate` | `.heartRate` | 样本，limit 600 | bpm |
| `.hrv` | `.heartRateVariabilitySDNN` | 样本，limit 600 | ms |
| `.restingHeartRate` | `.restingHeartRate` | 样本，limit 600 | bpm |
| `.steps` | `.stepCount` | `HKStatisticsCollectionQuery` `.cumulativeSum` 日粒度 | |
| `.sleep` | `.sleepAnalysis` category | 按 `endDate` 归日，累计 asleep* 小时 | |
| `.sleepREM/Core/Deep/Awake` | 同上 | 分期累计 | ✅ 已有 |
| `.activeEnergyBurned` | 同名 | cumulativeSum 日粒度 | kcal |
| `.appleExerciseTime` | 同名 | cumulativeSum 日粒度 | min |
| `.appleStandTime` | iOS 18+ `HKQuantityTypeIdentifierAppleStandTime` | cumulativeSum 日粒度 | h |

**睡眠分期处理是正确的**（`:304-379`）：`asleepUnspecified/REM/Core/Deep` 计入总时长，`awake` 只作阶段摘要不计入总时长。

### 3.2 尚未读取的（参考项目有、StressWatch 没有）

| 指标 | 谁在用 | 用途 |
|---|---|---|
| `HKWorkoutType` | Soma | ** sedentary 过滤**——剔除运动时段的心率，避免误判为压力 |
| `.walkingHeartRateAverage` | Soma / Whoordan | 心肺效率 |
| `.respiratoryRate` | Whoordan | Recovery 的一个分量 |
| `.oxygenSaturation` | Whoordan（权重 0，仅展示） | — |
| `.mindfulSession` | Soma | 正念分钟（stress 折扣） |
| `HKActivitySummary` | HealthKitExporter | Move/Exercise/Stand 目标与完成度 |
| 锚点增量同步 | Whoordan（定义了但没实现） | 后台刷新 |

> **建议**：本轮**只新增 `HKWorkoutType` 读取**（用于 Soma 式 sedentary 过滤），其余不动。

### 3.3 数据层的六个具体问题

| # | 问题 | 位置 | 影响 |
|---|---|---|---|
| 1 | **授权态用 UserDefaults 冒充**。`authorizationStatus()` 只要请求过一次就返回 `.authorized`，不区分 denied | `HealthKitService.swift:29-35` | 权限被拒后仍反复请求，用户看到空数据无解释 |
| 2 | **缺失值用 0 淹没**。`statistics.sumQuantity() ?? 0`，且 `if value > 0` 才写入 | `:412-418` | "没数据" 与 "真的是 0" 不可区分，下游无法计算 completeness |
| 3 | **无样本级来源追踪到聚合层**。`sourceName` 存在 `HealthMetric` 上，但 `BaselineEngine` / `StressModel` 全部丢弃 | `BaselineEngine.swift:33-39` | 无法回答"这个基线来自哪台设备" |
| 4 | **高频样本 limit 600 截断** | `:189` | 30 天窗口下 HRV 可能被截断到只有最近几天 |
| 5 | **无增量/后台同步**，只有 HRV observer 触发通知 | `:107-139` | 冷启动每次全量拉取 |
| 6 | **Demo 数据混填**（架构级） | `DashboardViewModel.swift:256` | 见 §0 |

---

## 4. 当前 Stress 算法

### 4.1 公式（`StressModel.swift:8-32`）

```swift
let currentHR    = current.latestValue(for: .heartRate)     ?? baseline.avgHR
let currentHRV   = current.latestValue(for: .hrv)           ?? baseline.avgHRV
let currentSteps = current.latestValue(for: .steps)         ?? baseline.avgDailySteps
let currentSleep = current.latestValue(for: .sleep)         ?? baseline.avgSleepHours

hrFactor    = clamp(((currentHR - baseline.avgHR) / base.avgHR) * 100, 0, 25)
hrvFactor   = clamp(((baseline.avgHRV - currentHRV) / base.avgHRV) * 100, 0, 25)
activityF   = clamp((abs(currentSteps - base.avgDailySteps) / base.avgDailySteps) * 50, 0, 25)
sleepFactor = clamp(((base.avgSleepHours - currentSleep) / base.avgSleepHours) * 100, 0, 25)

value = clamp(round(Σ), 0, 100)      // 理论上限 100，实际很难超过 60
```

### 4.2 六个问题

| # | 问题 | 说明 |
|---|---|---|
| 1 | **活动因子方向错误** | `abs(steps - baseline)` —— 走得多和走得少都加压力。运动量高的日子会被误判为高压 |
| 2 | **HR 用瞬时最后一条** | `latestValue(for: .heartRate)` 取当天最后一次心率采样，可能是运动后/情绪波动后的值，而非静息基线可比对象 |
| 3 | **缺失即"正常"** | `?? baseline.xxx` → 偏差 0 → 该因子静默记 0 分，且不降低 confidence。**数据缺失被伪装成"状态良好"** |
| 4 | **无个人变异度** | 用百分比偏差的固定线性映射，而非 z-score。HRV 天生日间波动大的人会被长期误报 |
| 5 | **无信号冲突处理** | HRV 高但 RHR 也高时，两个因子相加，不会互相阻尼 |
| 6 | **分数与置信度无联动** | `StressScore` 结构里没有 confidence 字段，UI 显示的"可信度"来自 `FeatureExtractor` 的 feature 计数，与 stress 计算无关 |

### 4.3 ⚠️ 存在第二套并行压力算法

`LiveStressEstimator.estimate(...)`（`Core/LiveStress/LiveStressEstimator.swift:5-93`）用完全不同的逻辑：

```swift
score = initialScore(forHRVDeviation:)     // 分段：20/40/60/78/90
      + (restingDelta > 10 ? 15 : restingDelta > 5 ? 8 : 0)
      + (sleepRatio < 0.70 ? 15 : sleepRatio < 0.85 ? 8 : 0)
```

它**自带 `dataConfidence`（0/60/20/20 加权）**，比 `StressModel` 更讲究。两套算法同时出现在 Dashboard（LiveStressCard + Stress Score 卡），**数值不同、口径不同、解释不同**。这是必须收敛的。

---

## 5. 当前 Recovery 算法

### 5.1 公式（`RecoveryModel.swift:8-24`）

```swift
hrvScore       = clamp((currentHRV / baseline.avgHRV) * 40, 0, 40)
restingHRScore = clamp((baseline.avgRestingHR / currentRestingHR) * 30, 0, 30)
sleepScore     = clamp((currentSleep / baseline.avgSleepHours) * 30, 0, 30)
value = clamp(round(hrvScore + restingHRScore + sleepScore), 0, 100)
```

### 5.2 五个问题

| # | 问题 | 说明 |
|---|---|---|
| 1 | **天花板错位** | `current = baseline` 时得 40+30+30 = **满分 100**。也就是说"和平时一样"就等于"完全恢复"，**高于基线的好状态无法表达，低于基线才掉分** |
| 2 | **RHR 用反比** | `baseline / current`，无死区。RHR 从 60→58（正常波动）就 +1 分 |
| 3 | **无 activity / strain 项** | 昨天跑了个马拉松，Recovery 仍是满分 |
| 4 | **无 components 输出** | `RecoveryScore` 只有 `value / level / date`，**UI 无法解释"为什么是 72"** |
| 5 | **无 confidence / provenance** | 缺失时同样回退 baseline，静默满分 |

> 对比：`StressScore` 至少有 `StressComponents`（4 个因子），`RecoveryScore` 连这个都没有。

---

## 6. 当前 Baseline

### 6.1 实现（`BaselineEngine.swift:16-39`）

```swift
let days = Set(metrics.map { calendar.startOfDay(for: $0.date) })
guard days.count >= minimumDaysRequired   // 默认 3
else { return nil }

Baseline(
  avgHR:        averageValue(for: .heartRate, in: metrics),
  avgHRV:       averageValue(for: .hrv, in: metrics),
  avgRestingHR: averageValue(for: .restingHeartRate, in: metrics),
  avgDailySteps:averageValue(for: .steps, in: metrics),
  avgSleepHours:averageValue(for: .sleep, in: metrics),
  calculatedAt: Date(),
  dataWindowDays: days.count
)
```

`averageValue` = `metrics.filter{ $0.type == type }.map(\.value).reduce(0,+)/count`

### 6.2 七个问题（这是本次升级的核心靶点）

| # | 问题 | 说明 |
|---|---|---|
| 1 | **样本粒度混平均** | HR/HRV 是高频样本（一天可能几十~几百条），steps/sleep 是日累计（一天 1 条）。直接对所有样本取算术平均 ⇒ **样本多的指标权重实际上由采样频率决定** |
| 2 | **无异常值剔除** | 一个戴表不严导致的 HRV=180ms 会直接拉高均值 |
| 3 | **无个人变异度（SD）** | 只有均值，做不出 z-score，也判不出"这个偏离是否显著" |
| 4 | **无缺失填充策略** | 缺失日不占位不插值，`dataWindowDays` 只数"有任意数据的天数"，可能 30 天窗口只有 8 天 HRV |
| 5 | **无校准进度** | 只有 "有 / 无" 二态。新用户看到 `needsMoreData = true`，不知道还要几天 |
| 6 | **`isValid` 门槛过低** | `dataWindowDays >= 3`。3 天算不出有意义的 HRV 基线 |
| 7 | **窗口语义不清** | `dataWindowDays` 记录的是"有多少天有数据"，不是"窗口多长"（7/14/30） |

> 参考项目的做法对比：
> - **Soma**：log 域 EWMA(α=0.25) + 样本 SD，z-score = `(ln(today) - meanLn) / sdLn`，`n >= 7`
> - **Whoordan**：`suffix(28)` + **中位数** + `count >= 5` 门槛，`coreDayCount = min(hrvCount, rhrCount)`
> - **Thump**：log(SDNN) z-score，基线窗口默认 14 天；**HRV 基线用 P75 而非均值**（防止长期压力期基线被拖低）

---

## 7. 当前 Persistence

### 7.1 实现（`LocalStorage.swift`）

`FileManager` + `JSONEncoder`（`.iso8601` 日期、`.prettyPrinted`），目录 `Documents/StressWatch/`。

| 文件 | 内容 |
|---|---|
| `stress_scores.json` | `[StressScore]` 数组，按天 upsert |
| `baseline.json` | 单个 `Baseline` |
| `baseline_window_days.json` | `Int`（7/14/30） |
| `preferred_data_source.json` | `AppDataSource` |
| `daily_check_ins.json` | `[DailyWellnessCheckIn]` |
| `ai_analysis_enabled.json` | `Bool` |
| `minimax_model.json` | `String` |

写文件均用 `options: [.atomic]` ✅

### 7.2 五个问题

| # | 问题 | 影响 |
|---|---|---|
| 1 | **没有持久化 `RecoveryScore`** | 恢复趋势无法画，Trends 页只有 stress |
| 2 | **没有持久化每日聚合健康指标**（`DailyHealthMetrics`） | 每次进 Trends 都要从 `stressScore.components` 反推 HRV/RHR —— 这是造假的根因 |
| 3 | **无 `schemaVersion`、无 migration** | decode 失败即 `catch`，静默丢数据 |
| 4 | **无 `FileProtectionType`** | 健康数据文件未加文件级保护（参考 Whoordan 用 `.completeUnlessOpen`） |
| 5 | **无 Widget 之外的数据共享** | 与主 App 同进程，暂无 App Group 需求 |

### 7.3 已有的好设计

- `saveStressScore` / `saveDailyCheckIn` 用 `calendar.isDate(_:inSameDayAs:)` 做 upsert，天然幂等 ✅
- API Key 不落 storage，只落 Keychain ✅
- `saveBaselineWindowDays` 白名单校验 `[7,14,30]` ✅

---

## 8. 当前 Dashboard / Trends / Metrics（UI 信息层级）

### 8.1 Dashboard ✅ 基本健康

`DashboardViewModel.makeSnapshot` 产出 7 张卡：

| id | 内容 | 数据质量 |
|---|---|---|
| `stress` | 分数 + 状态 + 7 天 sparkline | ⚠️ sparkline 可能是假的（见 8.2） |
| `recovery` | 分数 + 状态 + HRV trend（**用 HRV 序列当 recovery 趋势，口径错**） | ⚠️ |
| `hrv` | 今日值 + `±X% vs baseline` + 趋势 | ✅ 这是全项目最好的一张卡 |
| `heartRate` | 最新 HR + Resting HR | ✅ |
| `sleep` | 时长 + Sleep Score（`(h / baseline) * 84`）+ 分期 | ✅ |
| `steps` | 今日步数 | ✅ |
| `activity` | 能量 / 运动 / 站立 | ✅ |

结构分层（DashboardView）已经是 Apple Health 风格：Hero → DetailGrid → KeySignals → SleepStages → ActivityContext。

### 8.2 🔴 Trends 页面存在系统性造假

| 位置 | 问题 |
|---|---|
| `TrendViewModel.swift:453-471` `makeReferenceScores` | `value = 52 + sin(index * 0.72) * 14 + (index % 5) * 2` —— **用 sin 曲线凭空造 7/31/365 天的分数** |
| `:273-284` `normalizedScores` | 真实数据不足时，用 `makeReferenceScores` 的结果兜底并与之"合并"，**真数据和假数据混在同一个数组里** |
| `:418-424` `estimatedHRV` | `clamp(74 - inverseHRVFactor*1.25 - value*0.16, 18, 92)` —— **从压力分量反推 HRV**，然后画"HRV 趋势" |
| `:422-424` `estimatedRestingHR` | 同上，反推 RHR |
| `:315-331` `makeSleepConsistency` | 从 `sleepDebtFactor` 反推"就寝时间方差 / 起床时间方差 / REM% / Deep%"，**纯伪造** |
| `:286-295` `makeHeatmapRows` | 24 小时热力图由 `estimatedHourlyStress`（含硬编码 `workdayLoad` 时段表）生成，**不是真实小时数据** |
| `:368-396` `makeWellnessFeatures` | `remSleepAverage/coreSleepAverage/deepSleepAverage/stepsAverage` 全部传 `nil`，却把 `availableFeatureCount` 写死为 7 |

**这意味着 Trends 页在真实数据不足时会显示一整套看起来很专业、实际是编造的分析。** 对于一个"非医疗、可信、透明"定位的 App，这是最高优先级要修的问题。

### 8.3 Metrics（MetricDetailView + MetricChart）

从 Dashboard 卡片下钻到单指标详情，用 Swift Charts 画折线 + 基准线。结构合理，但**继承了上游的假数据**。

### 8.4 ⚠️ Dashboard 的另外两处口径问题

- `recoveryMetric(recoveryScore, trend: hrvTrend, ...)`（`DashboardViewModel.swift:327`）—— **用 HRV 序列作为 Recovery 卡的 sparkline**。
- `stressScoresByDay` `:516-529`：缓存分数 < 3 天时走 `demoStressTrendScores` 硬编码 `[42,46,51,56,61,59,...]`。

---

## 9. LLM / Analysis 层现状

### 9.1 已有的（做得好的部分）✅

| 项 | 落地 |
|---|---|
| LLM 不读 HealthKit | ✅ `AnalysisPayload` 只含聚合值 |
| 结构化输入 | ✅ `AnalysisPayload`（BaselineBlock / FeatureBlock / TrendBlock / GoalBlock / RecommendationBlock） |
| 禁止 LLM 重算 | ✅ system prompt 第 2 条："严禁重新计算、推断或改写任何数值" |
| 非医疗声明 | ✅ system prompt 第 1 条："只做生活方式层面的解读，不做医疗诊断" |
| 结构化输出 | ✅ `InsightDTO` + `PersonalizationInsight`（summary/findings/suggestions/tone） |
| 解析兜底 | ✅ `extractJSONObject` 剥 markdown fence + `usedFallback` 纯文本降级 |
| 隐私门控 | ✅ `enableAIAnalysis` 开关 + Keychain key 双门 + 关闭则完全不联网 |
| 错误态 | ✅ `LLMInsightState` 五态（off/idle/loading/success/failure） |

**结论：StressWatch 的 LLM 层架构方向是对的，不需要推倒重来。**

### 9.2 缺失的（本轮要补的）

| # | 缺口 | 说明 |
|---|---|---|
| 1 | **没有 `StructuredAnalysisResult`** | 用户要求的 `{stressScore, recoveryScore, hrv:{value,baseline,deviationPercent,trend}, ..., confidence, dataCompleteness}` 这一层不存在。目前 `AnalysisPayload` 是"平铺的统计值"，不是"带语义的分析结论" |
| 2 | **没有 `deviationPercent` / `trend` 枚举** | `TrendBlock` 只有 4 个 `xxx7dDelta` 裸差值，LLM 需要自己判断方向 |
| 3 | **没有相关性** | 完全没有 correlation |
| 4 | **没有 `dataCompleteness`** | 只有 `dataConfidence`（= 非空 feature 数 / 总 feature 数），不是按核心指标可用性的加权 |
| 5 | **没有本地 fallback 文案** | LLM 失败只显示错误 + 重试按钮。应有一条本地生成的"基线版解读"兜底（Soma 的 `buildExplanation` 思路） |
| 6 | **无缓存** | 每次点按钮都重新调用。参考 Soma `InsightCache` 的"删时间戳即失效"模式 |
| 7 | **措辞护栏只在 prompt 里** | 未区分 correlation/causation；无测试层强制；无输出后置校验 |
| 8 | **provenance 缺失** | LLM 不知道某个值是"实测"还是"回退到基线的占位值"，存在过宣称风险 |

---

## 10. 可直接扩展的点（不改现有结构）

| 扩展点 | 现有接缝 | 新增成本 |
|---|---|---|
| 更强的 Baseline | `BaselineCalculating` 协议 | 低：新增 `PersonalBaselineEngine`，`BaselineEngine` 保留作兼容 |
| 更强的 Stress | `StressComputing` 协议 | 低：新增 `PersonalStressEngine`，旧 `StressModel` 保留 |
| 更强的 Recovery | `RecoveryComputing` 协议 | 低：同上 |
| 日聚合层 | 无（需新增） | 中：新增 `DailyHealthMetrics` + `DailyMetricsAggregator` |
| 趋势引擎 | 无（需新增） | 中：新增 `TrendEngine`，纯函数 |
| 相关性引擎 | 无（需新增） | 中：新增 `CorrelationEngine`，纯函数 |
| 结构化分析结果 | 无（需新增） | 中：新增 `StructuredAnalysisResult`（Codable） |
| AnalysisPayload 升级 | `LLMPersonalizationService.buildPayload` | 低：扩展字段 |
| 本地 fallback 文案 | 无 | 低：新增 `LocalInsightComposer` |
| 单元测试 | **需新建 target** | 中：Xcode 加 `StressWatchTests` target |
| 持久化 `DailyHealthMetrics` | `LocalStorageProtocol` 加方法 | 低 |

---

## 11. 不应该修改的点

| 模块 | 原因 |
|---|---|
| `HealthKitDataProvider` 协议签名 | 3 方法足够，Mock/Real 都稳定；扩需求用新协议而不是改它 |
| `HealthKitService` 的查询实现 | 已跑通真机；本轮只在**必要时新增** workout 读取，不改现有 8 类查询 |
| `MockHealthKitService` | 用户明确要求不破坏。它的 7 天 pattern 数据够用，可作为测试的确定性数据源 |
| `WellnessAnalyzing` / `WellnessState` / `CoreMLWellnessAnalyzer` | 分类体系已定型（6 态），ml_training 管线依赖它 |
| `PersonalizationEngine` / `GoalOptimizer` / `PersonalizedAdviceGenerator` | 个性化目标逻辑合理且已被 AnalysisView 消费 |
| `KeychainStore` | API Key 存储正确 |
| `AppColors` / `GlassCardView` / `AppMotion` / `FloatingTabBar` | 视觉体系成型，UI 只做信息层级增强，不做视觉重构 |
| `WidgetSnapshot` / `WidgetStorage` / Widget Extension | 独立且稳定；只随 Dashboard 数据源自动更新 |
| `MiniMaxClient` | 纯网络层，职责干净。只可能加 `responseFormat` 参数 |
| `AppDataSource` / `fetchBaselineWindowDays` 存储语义 | 设置项语义已被用户使用 |

---

## 12. 升级必须遵守的六条硬约束（从现状反推）

1. **不许新增造假的兜底数据** —— 现有 `makeReferenceScores` / `estimatedHRV` / `demoStressTrendScores` / `makeSleepConsistency` 必须逐步替换为"显式 insufficient data 态"。
2. **不许让 Demo 数据混进 Apple Health 数据集** —— 二者必须在数据结构层面分离（`source` 字段 + 分别的数组）。
3. **缺失必须降级 confidence，不许静默记 0 或回退基线值当"正常"**。
4. **所有新增计算模块必须 `import Foundation` only**，禁止 `import HealthKit` / `import SwiftUI`（Soma `Calculators/` 的纪律，是可测试性的唯一来源）。
5. **每一层的输出都要能被下一层解释** —— 分数必须有 components，基线必须有 `n`/`sd`/`calibration`，分析必须有 `dataCompleteness`。
6. **相关性只能表述为关联，不可表述为因果** —— 且要用类型/枚举约束，不能只靠 prompt。
