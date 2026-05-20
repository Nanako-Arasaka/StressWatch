# StressWatch

原生 SwiftUI 健康趋势参考 App。当前活跃实现位于 `StressWatch/`，Expo React Native 文件仅作为历史阶段保留，不是当前路线。

本项目用于展示 Apple Watch / Apple Health 相关健康数据趋势，当前支持 Demo Data fallback。应用只做个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。

## 架构

```text
SwiftUI Views
  -> DashboardViewModel / TrendViewModel / SettingsViewModel
  -> HealthKitDataProvider
  -> HealthKitService / MockHealthKitService
  -> BaselineEngine
  -> StressModel / RecoveryModel
  -> LocalStorage
```

## 目录结构

```text
StressWatch/
├── App/                         # @main 入口和依赖注入
│   └── StressWatchApp.swift
├── Models/                      # Codable 数据模型和展示枚举
│   ├── HealthMetric.swift
│   ├── Baseline.swift
│   ├── StressScore.swift
│   └── RecoveryScore.swift
├── Protocols/                   # Service / Storage 抽象协议
│   ├── HealthKitDataProvider.swift
│   └── LocalStorageProtocol.swift
├── Services/                    # HealthKit、Mock、Baseline、评分模型
│   ├── HealthKitService.swift
│   ├── MockHealthKitService.swift
│   ├── BaselineEngine.swift
│   ├── StressModel.swift
│   └── RecoveryModel.swift
├── Storage/                     # FileManager + Codable 本地 JSON 存储
│   └── LocalStorage.swift
├── ViewModels/                  # 页面状态编排
│   ├── DashboardViewModel.swift
│   ├── TrendViewModel.swift
│   └── SettingsViewModel.swift
├── Views/                       # SwiftUI 页面与组件
│   ├── Components/              # Liquid Glass 通用组件
│   ├── Dashboard/
│   ├── Trend/
│   ├── Detail/
│   └── Settings/
└── Utils/                       # 数学和日期工具
```

## 当前功能

- iOS 26 Liquid Glass 风格 SwiftUI UI
- Dashboard / Trend / Settings / Metric Detail 页面
- Apple Health / Demo Data 数据源切换
- HealthKit 授权入口和失败 fallback
- 7/14/30 天 baseline window 设置
- HR、HRV、静息心率、步数、睡眠读取
- 7 天压力趋势参考
- JSON 本地存储
- 固定医疗免责声明

## Xcode 打开方式

```bash
open StressWatch.xcodeproj
```

真机运行前确认：

- 选择 `StressWatch` scheme
- Signing Team 已设置
- Bundle Identifier 唯一
- Deployment Target 为 iOS 26.0
- HealthKit capability 已启用
- `Info.plist` 包含 `NSHealthShareUsageDescription` 和 `NSHealthUpdateUsageDescription`

## 真机测试顺序

1. 先保持 Demo Data，打开 Dashboard 验证 UI 和图表。
2. 进入 Settings，点击请求 HealthKit 授权。
3. 授权后切换到 Apple Health。
4. 回 Dashboard 下拉刷新。
5. 有数据时显示 Apple Health；无权限、无数据或读取失败时 fallback 到 Demo Data。

## 免责声明

```text
本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。
```
