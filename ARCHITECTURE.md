# StressWatch MVP 架构设计文档

## 1. 整体架构说明

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                     │
│  DashboardView  TrendView  MetricDetailView  Settings│
└──────────────────────┬──────────────────────────────┘
                       │ @ObservedObject / @StateObject
┌──────────────────────▼──────────────────────────────┐
│               DashboardViewModel                     │
│  编排 HealthKitService → BaselineEngine → StressModel│
│  对外暴露: stressScore, recoveryScore, metrics, ...  │
└──┬──────────┬──────────┬───────────┬────────────────┘
   │          │          │           │
   ▼          ▼          ▼           ▼
┌──────┐ ┌──────┐ ┌──────────┐ ┌──────────┐
│Health│ │Basel.│ │Stress    │ │Recovery  │
│Kit   │ │Engine│ │Model     │ │Model     │
│Svc   │ │      │ │          │ │          │
└──┬───┘ └──┬───┘ └────┬─────┘ └────┬─────┘
   │        │           │            │
   └────────┴───────────┴────────────┘
                      │
          ┌───────────▼───────────┐
          │     LocalStorage      │
          │  (stress history +    │
          │   baseline cache)     │
          └───────────────────────┘
```

**架构原则**：
- **MVVM**：View 只通过 ViewModel 获取数据，不直接调用 Service
- **Protocol 抽象**：HealthKitService 和 LocalStorage 通过 protocol 暴露，方便 mock 切换
- **单向数据流**：Service → Engine/Model → ViewModel → View
- **本地 only**：所有数据存在本地，不上传云端

## 2. 推荐文件目录结构

```
StressWatch/
├── App/
│   ├── StressWatchApp.swift              # @main 入口
│   └── AppDelegate.swift                 # HealthKit 初始化（如需）
│
├── Models/
│   ├── HealthMetric.swift                # 统一健康指标 struct
│   ├── Baseline.swift                    # 个人基线 struct
│   ├── StressScore.swift                 # 压力分数 struct
│   └── RecoveryScore.swift               # 恢复分数 struct
│
├── Protocols/
│   ├── HealthKitDataProvider.swift       # HealthKit 数据提供协议
│   └── LocalStorageProtocol.swift        # 本地存储协议
│
├── Services/
│   ├── HealthKitService.swift            # 真实 HealthKit 实现
│   ├── MockHealthKitService.swift        # Mock 数据实现（开发用）
│   ├── BaselineEngine.swift              # 基线计算引擎
│   ├── StressModel.swift                 # 压力模型（rule-based）
│   └── RecoveryModel.swift               # 恢复模型
│
├── Storage/
│   └── LocalStorage.swift                # JSON 文件存储实现
│
├── ViewModels/
│   ├── DashboardViewModel.swift          # Dashboard 主 ViewModel
│   ├── TrendViewModel.swift              # 趋势页 ViewModel
│   └── SettingsViewModel.swift           # 设置页 ViewModel
│
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift           # 主仪表盘
│   │   ├── StressGaugeCard.swift         # 压力仪表卡片
│   │   ├── RecoveryCard.swift            # 恢复状态卡片
│   │   └── TodayMiniChart.swift          # 今日迷你趋势
│   ├── Trend/
│   │   ├── TrendView.swift               # 7天趋势页
│   │   └── TrendChart.swift              # 趋势折线图
│   ├── Detail/
│   │   ├── MetricDetailView.swift        # 单指标详情页
│   │   └── MetricChart.swift             # 指标图表
│   └── Settings/
│       └── SettingsView.swift            # 设置页（baseline 窗口等）
│
├── Utils/
│   ├── DateExtensions.swift              # 日期工具
│   └── ScoreFormatter.swift              # 分数格式化
│
└── Resources/
    └── Assets.xcassets                   # 图标资源（SF Symbols 为主）
```

## 3. 每个模块的职责

### 3.1 HealthKitService（实现 `HealthKitDataProvider`）

| 职责 | 说明 |
|------|------|
| 权限请求 | 请求 HR、HRV、Resting HR、Steps、Sleep 的读权限 |
| 数据读取 | 按时间范围查询各类型 HealthKit 数据 |
| 数据归一化 | 将 HealthKit 不同返回格式统一为 `[HealthMetric]` |
| 错误处理 | 权限拒绝、数据为空等情况的统一错误返回 |

**第一版只读这 5 种类型**：heartRate、hrv、restingHeartRate、steps、sleep

### 3.2 BaselineEngine

| 职责 | 说明 |
|------|------|
| 计算基线 | 基于过去 N 天（默认 14 天）数据计算个人均值 |
| 输出 | `Baseline` struct：avgHR, avgHRV, avgRestingHR, avgSteps, avgSleep |
| 基线更新策略 | 每周重新计算一次，新用户至少需要 3 天数据 |
| 数据不足处理 | 数据天数不够时返回 `nil`，ViewModel 提示用户等待 |

### 3.3 StressModel

| 职责 | 说明 |
|------|------|
| 计算压力分 | 纯规则模型，输入当前值 + baseline，输出 0-100 分数 |
| 四级因子 | HR偏差因子、HRV反向因子、活动负荷因子、睡眠负债因子 |
| 分级 | low(0-33)、medium(34-66)、high(67-100) |
| 无副作用 | 纯函数，不保存状态 |

### 3.4 RecoveryModel

| 职责 | 说明 |
|------|------|
| 计算恢复分 | 基于 HRV 恢复、静息心率、睡眠充足度 |
| 输出 | 0-100 恢复分 + poor/fair/good 等级 |
| 简单实现 | MVP 版可以用 HRV 回升 + 睡眠充足 + 静息心率正常 的加权 |

### 3.5 DashboardViewModel

| 职责 | 说明 |
|------|------|
| 编排协调 | 连接 HealthKitService → BaselineEngine → StressModel → RecoveryModel |
| 状态管理 | 管理 loading / error / ready 状态 |
| 数据暴露 | 给 View 暴露 `@Published` 属性 |
| 刷新触发 | 提供 `refresh()` 方法，View 的 onAppear / pull-to-refresh 调用 |
| 历史保存 | 每次计算后调用 LocalStorage 保存当天的 score |

### 3.6 LocalStorage（实现 `LocalStorageProtocol`）

| 职责 | 说明 |
|------|------|
| 保存压力分 | 每天一条 `StressScore`，按日期去重（每天只保留最新计算） |
| 保存基线 | 缓存最新 `Baseline` |
| 读取历史 | 按日期范围查询 `[StressScore]` |
| MVP 实现 | 用 `Codable` + `FileManager` 存 JSON 文件，不用 CoreData |

### 3.7 Views

| View | 职责 |
|------|------|
| DashboardView | 主页面，展示当前压力/恢复状态 + 今日迷你趋势 |
| TrendView | 7 天压力分数折线图 |
| MetricDetailView | 单指标（HR/HRV）原始值 + 趋势 |
| SettingsView | 基线计算窗口设置（7/14/30天），数据源选择 |

## 4. 模块之间的数据流

### 4.1 主流程（App 启动 / 用户刷新）

```
DashboardView.onAppear()
  → DashboardViewModel.refresh()
    ├─ ① HealthKitService.requestAuthorization()
    ├─ ② HealthKitService.fetchHeartRate/HRV/RestingHR/Steps/Sleep(14天)
    ├─ ③ BaselineEngine.calculate(metrics: [HealthMetric])
    │     → 返回 Baseline?
    ├─ ④ StressModel.compute(current: HealthMetric, baseline: Baseline)
    │     → 返回 StressScore
    ├─ ⑤ RecoveryModel.compute(current: HealthMetric, baseline: Baseline)
    │     → 返回 RecoveryScore
    ├─ ⑥ LocalStorage.save(stressScore)
    ├─ ⑦ LocalStorage.save(baseline)
    └─ ⑧ 更新 @Published 属性 → View 自动刷新
```

### 4.2 趋势查询流程

```
TrendView.onAppear()
  → TrendViewModel.loadHistory(days: 7)
    ├─ LocalStorage.fetchStressScores(from: 7天前, to: 今天)
    └─ 更新 @Published history: [StressScore] → TrendChart 渲染
```

### 4.3 数据依赖关系

```
HealthKitService (raw data)
       │
       ▼
BaselineEngine (需要至少 3 天原始数据)
       │
       ├──── StressModel (需要 baseline + 当天数据)
       │         │
       │         ▼
       │      StressScore ──→ LocalStorage
       │
       └──── RecoveryModel (需要 baseline + 当天数据)
                 │
                 ▼
              RecoveryScore ──→ LocalStorage
```

## 5. 关键数据模型 struct 设计

```swift
// MARK: - 统一健康指标

struct HealthMetric: Identifiable, Codable {
    let id: UUID
    let type: MetricType
    let value: Double
    let unit: String
    let date: Date
}

enum MetricType: String, Codable, CaseIterable {
    case heartRate
    case hrv                    // SDNN, ms
    case restingHeartRate
    case steps
    case sleep                  // hours
}

// MARK: - 个人基线

struct Baseline: Codable {
    let avgHR: Double           // bpm
    let avgHRV: Double          // ms
    let avgRestingHR: Double    // bpm
    let avgDailySteps: Double   // steps/day
    let avgSleepHours: Double   // hours/night
    let calculatedAt: Date
    let dataWindowDays: Int     // 用了多少天数据

    var isValid: Bool { dataWindowDays >= 3 }
}

// MARK: - 压力分数

struct StressScore: Identifiable, Codable {
    let id: UUID
    let value: Int              // 0-100
    let level: StressLevel
    let date: Date
    let components: StressComponents
}

enum StressLevel: String, Codable {
    case low                    // 0-33
    case medium                 // 34-66
    case high                   // 67-100
}

struct StressComponents: Codable {
    let hrDeviationFactor: Double       // 0-25
    let inverseHRVFactor: Double        // 0-25
    let activityLoadFactor: Double      // 0-25
    let sleepDebtFactor: Double         // 0-25
}

// MARK: - 恢复分数

struct RecoveryScore: Identifiable, Codable {
    let id: UUID
    let value: Int              // 0-100
    let level: RecoveryLevel
    let date: Date
}

enum RecoveryLevel: String, Codable {
    case poor                   // 0-33
    case fair                   // 34-66
    case good                   // 67-100
}

// MARK: - Dashboard 展示状态

struct DashboardState {
    var stressScore: StressScore?
    var recoveryScore: RecoveryScore?
    var baseline: Baseline?
    var todayHR: [HealthMetric]
    var todayHRV: [HealthMetric]
    var isLoading: Bool
    var errorMessage: String?
    var needsMoreData: Bool     // 数据不足时提示用户
}
```

## 6. Protocol / Interface 设计

```swift
// MARK: - HealthKit 数据提供协议
// 核心抽象：让 mock 和真实 HealthKit 都实现同一接口

protocol HealthKitDataProvider {
    /// 请求所有需要的 HealthKit 权限
    func requestAuthorization() async throws

    /// 检查权限状态
    func authorizationStatus() -> HealthKitAuthStatus

    /// 按类型 + 时间范围查询数据
    func fetchMetrics(
        types: [MetricType],
        from: Date,
        to: Date
    ) async throws -> [HealthMetric]
}

enum HealthKitAuthStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable           // 模拟器 / iPad
}

// MARK: - 本地存储协议

protocol LocalStorageProtocol {
    func saveStressScore(_ score: StressScore) throws
    func fetchStressScores(from: Date, to: Date) throws -> [StressScore]
    func saveBaseline(_ baseline: Baseline) throws
    func fetchBaseline() throws -> Baseline?
    func deleteOldData(before: Date) throws  // 清理 90 天前的数据
}

// MARK: - 基线计算协议

protocol BaselineCalculating {
    func calculate(from metrics: [HealthMetric]) -> Baseline?
}

// MARK: - 压力模型协议

protocol StressComputing {
    func compute(
        current: [HealthMetric],
        baseline: Baseline
    ) -> StressScore
}

// MARK: - 恢复模型协议

protocol RecoveryComputing {
    func compute(
        current: [HealthMetric],
        baseline: Baseline
    ) -> RecoveryScore
}
```

## 7. MVP 开发顺序

### Phase 1：数据模型 + Protocol（第 1 步）
1. 创建 `Models/` 下所有 struct：`HealthMetric`, `Baseline`, `StressScore`, `RecoveryScore`
2. 创建 `Protocols/` 下所有协议

### Phase 2：Mock 数据 + 存储（第 2 步）
3. 实现 `MockHealthKitService`：生成 14 天模拟数据
4. 实现 `LocalStorage`：Codable + FileManager JSON 存取
5. 写几个简单 unit test 验证存取逻辑

### Phase 3：引擎 + 模型（第 3 步）
6. 实现 `BaselineEngine`：计算 14 天均值
7. 实现 `StressModel`：rule-based 四因子计算
8. 实现 `RecoveryModel`：简单的恢复评分
9. 用 mock 数据验证输出合理性

### Phase 4：ViewModel（第 4 步）
10. 实现 `DashboardViewModel`：串联所有 Service
11. 实现 `TrendViewModel`：读取历史
12. 实现 `SettingsViewModel`：配置项

### Phase 5：SwiftUI Views（第 5 步）
13. `DashboardView` + `StressGaugeCard` + `RecoveryCard`
14. `TrendView` + `TrendChart`（可用 Swift Charts 框架）
15. `MetricDetailView`
16. `SettingsView`

### Phase 6：真实 HealthKit 接入（第 6 步，需要 Mac + Xcode）
17. 实现 `HealthKitService`（替换 mock）
18. 真机 / 模拟器测试
19. Info.plist 配置 HealthKit 权限描述

### Phase 7：打磨（第 7 步）
20. 错误处理完善
21. 数据不足状态展示
22. 清理旧数据逻辑

## 8. 哪些部分第一版明确不要做

| 不要做 | 原因 |
|--------|------|
| Apple Watch 独立 App / Companion App | 需要 watchOS target，增加复杂度 |
| Watch 实时 HRV/HR 后台采集 | 需要 HKWorkoutSession / 后台模式 |
| 复杂 ML 模型（CoreML） | MVP 用 rule-based 足够 |
| 云端同步 / iCloud | 隐私风险 + 网络层复杂度 |
| 登录 / 账号系统 | 个人自用不需要 |
| 社交分享 | 非 MVP 范围 |
| 医疗诊断声明 / FDA 合规 | 明确免责即可 |
| 多语言 / 国际化 | 先做中文/英文一种 |
| Widget / Live Activity | 后期再加 |
| 推送通知 | 后期再加 |
| SwiftData / CoreData | MVP 用 JSON 文件足够，后期可迁移 |
| 复杂动画 / 自定义图表 | 用 Swift Charts 原生方案 |
| A/B 测试 / 分析 | 个人自用不需要 |

## 9. 给 Copilot / Codex 实现时的约束规则

这些规则可以直接写入 `.cursorrules` 或 `.github/copilot-instructions.md`：

```markdown
# StressWatch MVP 约束规则

## 架构约束
1. 所有 View 只能通过 ViewModel 获取数据，禁止 View 直接 import HealthKit
2. 所有 ViewModel 只能通过协议接口调用 Service，禁止 ViewModel 直接实例化 HealthKitService
3. 数据流单向：Service → Engine/Model → ViewModel → View，不允许反向
4. 使用 @StateObject 注入 ViewModel，用 @Published 驱动 View 更新

## 数据约束
5. 所有健康数据只存在本地，禁止任何网络请求（包括 analytics）
6. 禁止在 HealthMetric / Baseline / StressScore 之外创建新的数据模型
7. 数据模型用 struct 不用 class（除 ViewModel 外）
8. 所有 model 必须 Codable，所有 model 必须 Identifiable（用 UUID）
9. StressScore.value 范围 0-100，不允许超出

## 表达约束
10. 所有 UI 文案禁止使用"诊断"、"疾病"、"治疗"、"医生"等医疗术语
11. 使用"趋势"、"状态"、"波动"、"恢复"等描述性用语
12. App 内必须显示免责声明："本 App 不提供医疗建议，仅用于个人健康数据可视化"

## 实现约束
13. 先实现 MockHealthKitService，保证 View + ViewModel 可以独立开发测试
14. 不要提前写 HealthKitService 的真实实现（Phase 6 才做）
15. 评分模型是纯函数，禁止有副作用
16. BaselineEngine 数据不足 3 天时返回 nil，由 ViewModel 处理展示
17. 每天只保存一条 StressScore（相同日期覆盖更新）
18. LocalStorage 用 FileManager + Codable，不引入 SwiftData / CoreData

## 代码风格
19. 协议命名：名词 + Protocol 后缀（如 HealthKitDataProvider）
20. View 命名：功能 + View 后缀（如 DashboardView）
21. ViewModel 命名：功能 + ViewModel 后缀（如 DashboardViewModel）
22. 文件组织：按职责分文件夹，不是按类型（Models/ 不是 Structs/）
23. 禁止 force unwrap（!），用 guard let / if let
24. 禁止在 View 的 body 里写复杂计算逻辑
```

## 10. 压力模型 MVP 算法（参考）

stress score 用规则模型，四个因子各贡献 0-25 分，总分 0-100：

```
HR Deviation Factor（心率偏差因子）:
  deviation = (currentHR - baselineHR) / baselineHR
  score = clamp(deviation * 100, 0, 25)

Inverse HRV Factor（HRV 反向因子）:
  deviation = (baselineHRV - currentHRV) / baselineHRV
  score = clamp(deviation * 100, 0, 25)

Activity Load Factor（活动负荷因子）:
  deviation = abs(currentSteps - baselineSteps) / baselineSteps
  score = clamp(deviation * 50, 0, 25)

Sleep Debt Factor（睡眠负债因子）:
  deviation = (baselineSleep - currentSleep) / baselineSleep
  score = clamp(deviation * 100, 0, 25)

StressScore.value = hrFactor + hrvFactor + activityFactor + sleepFactor
StressScore.level = value <= 33 ? .low : value <= 66 ? .medium : .high
```

## 11. Apple Watch 扩展预留设计

虽然 MVP 不做 Watch，但架构已预留扩展点：

1. **`HealthKitDataProvider` 协议**：Watch 数据可新增 `WatchDataProvider` 实现同一协议，与 `HealthKitService` 并行
2. **`HealthMetric` 的 `date` 字段**：精度到秒，支持 Watch 高频数据
3. **`DashboardViewModel.refresh()`**：改为 Combine timer 驱动即可支持实时刷新
4. **WCSession 集成点**：可在 `Services/` 下新增 `WatchConnectivityService`，不改变上层接口
5. **`StressModel` 与 `RecoveryModel`**：输入输出不变，Watch 实时数据可直接传入
