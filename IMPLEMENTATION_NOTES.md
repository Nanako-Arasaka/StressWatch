# StressWatch SwiftUI 实现记录

## 当前状态

当前活跃路线是原生 SwiftUI 版本，核心源码位于 `StressWatch/`。Expo React Native 文件暂时保留在仓库中，但不是当前构建目标。

## 已完成内容

### 1. baselineWindowDays 生效

`LocalStorageProtocol` 新增持久化方法：

- `saveBaselineWindowDays(_:)`
- `fetchBaselineWindowDays()`

`SettingsViewModel` 切换 7/14/30 天时写入本地 JSON。

`DashboardViewModel.refresh()` 每次刷新前读取当前 baseline window，并用该窗口决定 HealthKit / Demo 数据查询范围。

### 2. 外部注入 ViewModel 改为 ObservedObject

以下 View 接收外部注入的 ViewModel，因此改为 `@ObservedObject`：

- `DashboardView`
- `TrendView`
- `SettingsView`

App 根部仍用 `@StateObject` 持有 ViewModel 生命周期。

### 3. MetricDetailView 接入导航

`DashboardView` 现在使用 `NavigationLink` 接入 `MetricDetailView`：

- 点击压力趋势参考卡片进入 HR 指标详情
- 点击恢复趋势参考卡片进入 HRV 指标详情
- 今日 HR / HRV 卡片下方提供 HR / HRV 趋势参考入口

### 4. HealthKit MVP 接入

`HealthKitService` 已实现：

- 请求读取权限
- 读取 HR
- 读取 HRV SDNN
- 读取 resting heart rate
- 读取 step count
- 读取 sleep analysis 并转换为 sleep duration

使用经典 `HKSampleQuery`，避免依赖较新的 descriptor API。

### 5. Mock fallback

`DashboardViewModel` 支持两个 provider：

- `HealthKitService`
- `MockHealthKitService`

Settings 中选择 Apple Health 后，Dashboard 会优先读 HealthKit。若授权失败、HealthKit 不可用、读取异常或返回空数据，会 fallback 到 Demo Data，并在 Dashboard 显示当前使用的数据源。

### 6. App Store 安全文案

页面文案改为趋势参考表达，固定免责声明为：

```text
本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。
```

### 7. iOS 26 Liquid Glass UI

已新增 `StressWatch/Views/Components/`，集中放置通用 UI 组件：

- `GlassCardView`
- `LiquidMetricCard`
- `AnimatedScoreRing`
- `GlassSectionHeader`
- `DataSourceBadge`

Dashboard、Trend、Settings、Metric Detail 已改为 Liquid Glass 风格，并加入卡片入场、圆环分数、Badge、图表淡入等 SwiftUI 原生动画。

### 8. 工程和文件可读性整理

Xcode project group 已按磁盘目录整理为：

- App
- Models
- Protocols
- Services
- Storage
- ViewModels
- Views
- Utils
- Supporting Files

主要 SwiftUI 页面增加了 `MARK` 分段，页面动作从 body 中提取为小方法，便于后续维护。

## Xcode 工程壳

已生成：

- `StressWatch.xcodeproj`
- `StressWatch.xcodeproj/xcshareddata/xcschemes/StressWatch.xcscheme`
- `StressWatch/Info.plist`
- `StressWatch/StressWatch.entitlements`

工程配置：

- iOS Deployment Target 26.0
- SwiftUI / Swift
- Bundle Identifier `com.stresswatch.demo`
- HealthKit capability
- HealthKit / Charts framework
- 使用现有 `StressWatchApp.swift` 作为唯一 `@main` 入口

## 当前边界

- 没有实现 Apple Watch target。
- 没有后台采集。
- 没有网络请求。
- 没有云同步。
- 没有登录。
- 没有复杂 ML。
- 本环境没有 macOS `xcodebuild`，无法在这里执行真实 Xcode 编译。

## 真机验证建议

1. 先用 Demo Data 验证 UI。
2. Settings 请求 HealthKit 授权。
3. 切换到 Apple Health。
4. Dashboard 下拉刷新。
5. 验证有数据时显示 Apple Health，无数据/失败时回到 Demo Data。
