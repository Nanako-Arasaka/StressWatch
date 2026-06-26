# StressWatch 接手说明

本文档面向后续接手项目的人，记录当前项目状态、构建入口、关键模块、已踩过的编译坑，以及继续开发时必须优先检查的事项。

## 1. 当前项目定位

StressWatch 是一个原生 SwiftUI iOS 健康趋势参考 App，核心目标是基于 Apple Health / Apple Watch 数据展示压力、恢复、HRV、心率、睡眠、活动量等趋势。项目不提供医疗诊断、治疗建议或紧急用途，只作为个人健康趋势参考。

当前主线是原生 iOS 工程：

```text
StressWatch.xcodeproj
StressWatch/
StressWatchWidgetExtension/
```

仓库里还保留了 Expo / React Native 原型和网页目录，但它们不是当前 Xcode 编译主线：

```text
src/
App.tsx
package.json
stresswatch-web/
```

## 2. 当前构建入口

- Xcode 工程：`StressWatch.xcodeproj`
- Scheme：`StressWatch`
- App 入口：`StressWatch/App/StressWatchApp.swift`
- App target：`StressWatch`
- Widget target：`StressWatchWidgetExtension`
- 当前 iOS Deployment Target：`16.0`

重要提示：

- 本地 Windows 环境没有 `xcodebuild` / `xcrun`，所以这里无法做真实 Xcode 编译验证。
- 最终编译结果必须在 macOS Xcode 里确认。
- Xcode signing 仍需要接手者配置自己的 Apple Developer Team。

## 3. 主要模块

```text
StressWatch/
├── App/                  # SwiftUI App 入口和根导航
├── Core/
│   ├── Analysis/          # Wellness 分析、Core ML fallback、建议生成
│   ├── HealthKit/         # HealthKit 读取和 Demo 数据 fallback
│   ├── LiveStress/        # 实时压力估算
│   ├── Models/            # 核心数据模型
│   ├── Storage/           # FileManager + Codable 本地存储
│   └── Utils/             # 时间和数学工具
├── Features/
│   ├── Dashboard/         # 主面板
│   ├── Trend/             # 趋势页
│   ├── Detail/            # 指标详情页
│   ├── Analysis/          # Wellness 分析页
│   └── Settings/          # 设置页
├── Shared/
│   ├── Charts/            # 通用图表
│   ├── Components/        # 通用 SwiftUI 组件
│   ├── Glass/             # 玻璃拟态卡片
│   ├── Motion/            # 动画封装
│   ├── Theme/             # AppColors 等主题
│   └── Widget/            # App 与 Widget 共享快照数据
└── Resources/
    ├── Assets.xcassets
    └── ML/                # Core ML 模型和标签
```

Widget 代码位于：

```text
StressWatchWidgetExtension/
```

机器学习训练和导出脚本位于：

```text
ml_training/
```

## 4. 当前功能状态

已实现或已接入：

- Dashboard 日常健康趋势概览
- Stress Score / Recovery Score
- HRV、心率、静息心率
- 睡眠时长和睡眠阶段
- 步数、活动能量、运动时间、站立时间
- 7 天趋势和趋势页
- Apple Health / Demo Data 数据源切换
- HealthKit 读取失败或无数据时 fallback 到 Demo Data
- 本地 JSON 存储
- Wellness Analysis 规则模型
- Core ML 模型加载失败时 fallback 到规则分析
- Widget 快照展示
- App Group 用于 App 与 Widget 共享数据

## 5. 需要接手者配置的内容

在 Xcode 里必须检查：

1. Signing & Capabilities
   - `DEVELOPMENT_TEAM` 当前为空，需要选择自己的 Team。
   - App target 和 Widget target 必须使用同一个 Team。

2. Bundle Identifier
   - 当前示例值：
     - `com.stresswatch.demo`
     - `com.stresswatch.demo.StressWatchWidgetExtension`
   - 真机或发布前应改成自己账号下唯一的 bundle id。

3. App Groups
   - 当前示例值：`group.com.stresswatch.demo`
   - 如果 bundle id 改了，App Group 也要同步改，并确保 App 和 Widget entitlements 一致。

4. HealthKit Capability
   - App target 需要 HealthKit capability。
   - 真机测试要授权 Apple Health 数据。

## 6. 先前出现过的编译问题

这些问题是实际踩过的坑，后续修改时要主动避免。

### 6.1 Deployment Target 写成 iOS 26

之前工程里出现过：

```text
IPHONEOS_DEPLOYMENT_TARGET = 26.0
```

这会导致普通 Xcode 版本无法编译。当前已调整为：

```text
IPHONEOS_DEPLOYMENT_TARGET = 16.0
```

后续不要随意改回 26.0，除非明确使用支持该 SDK 的 Xcode，并且所有 API 都按目标系统重新审查。

### 6.2 新 SDK API 残留

降低到 iOS 16 后，以下新 API 曾导致编译风险：

```swift
.contentTransition(.numericText())
.containerBackground(for: .widget)
.chartScrollableAxes(.horizontal)
.chartXVisibleDomain(...)
.onChange(of: value) { _, _ in ... }
```

处理原则：

- 不要只加 `#available` 就认为安全。
- 如果当前 Xcode SDK 根本不认识某个符号，即使放在 availability block 里也可能无法编译。
- 修改 SwiftUI / Charts / WidgetKit API 前，先确认当前 Xcode SDK 和 deployment target 都支持。

### 6.3 多语句函数缺少 return

之前 `CoreMLWellnessAnalyzer.analyze(features:) -> WellnessAnalysis` 出现过：

```text
Missing return in instance method expected to return 'WellnessAnalysis'
```

原因是多语句函数最后构造了 `WellnessAnalysis(...)`，但没有显式 `return`。Swift 只有单表达式函数可以省略 `return`。

正确形式：

```swift
return WellnessAnalysis(...)
```

### 6.4 不存在的 SwiftUI frame 重载

之前 `TrendView.swift` 出现过：

```text
Extra argument 'width' in call
```

问题写法：

```swift
.frame(width: contentWidth, maxHeight: .infinity, alignment: .bottomLeading)
```

SwiftUI 没有 `frame(width:maxHeight:alignment:)` 这个重载。应拆成：

```swift
.frame(width: contentWidth, alignment: .bottomLeading)
.frame(maxHeight: .infinity, alignment: .bottomLeading)
```

## 7. 后续开发规则

这些规则来自前面编译问题的复盘，后续接手者应按这个方式改代码。

1. 不要凭感觉写 SwiftUI API。
   - SwiftUI 很多 modifier 看起来相似，但重载组合并不一定存在。
   - 写之前要核对真实签名，尤其是 `.frame`、`.onChange`、Charts、WidgetKit modifier。

2. 修完一个编译错误后，要搜索同类模式。
   - 不能只修 Xcode 截图里的那一行。
   - 例如修完一个新 SDK API，要用 `rg` 搜同 API 家族是否还有残留。

3. 降 deployment target 后，要重新检查 SDK 可用性。
   - iOS 17+ 的 SwiftUI / Charts / WidgetKit API 不能直接留在 iOS 16 目标里。

4. 本地静态检查不等于 Xcode 编译通过。
   - 如果没有 `xcodebuild`，只能说明文本和模式检查通过。
   - 真正结论以 Xcode 第一条红色 compiler error 为准。

5. 不要改动无关文件。
   - 项目里有原生 iOS、Expo、网页、Python ML 多条线。
   - 修 Xcode 编译问题时，优先只动 `StressWatch/`、`StressWatchWidgetExtension/`、`StressWatch.xcodeproj/`。

## 8. 推荐接手流程

在 macOS 上：

```bash
git clone https://github.com/Nanako-Arasaka/StressWatch.git
cd StressWatch
open StressWatch.xcodeproj
```

然后在 Xcode 中：

1. 选择 `StressWatch` scheme。
2. 配置 App target 和 Widget target 的 Team。
3. 检查 bundle id 和 App Group。
4. 先用 Simulator 编译。
5. 再用真机验证 HealthKit 授权和数据读取。
6. 如果编译失败，优先处理 Issue Navigator 里的第一条红色错误。

## 9. 当前验证边界

已能在当前环境完成的检查：

- Git 状态检查
- 文件结构检查
- 文本级静态搜索
- Git diff 格式检查

当前环境不能完成的检查：

- `xcodebuild`
- iOS Simulator 启动
- HealthKit 真机授权
- Widget 真机展示
- App Store signing / provisioning 验证

因此，接手者第一次在 Xcode 打开项目后，应把编译结果作为新的事实来源。
