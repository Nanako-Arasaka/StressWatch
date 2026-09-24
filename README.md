# StressWatch / 心境

> 基于 SwiftUI、HealthKit 与 Liquid Glass 风格界面的本地优先 Apple Watch 健康趋势 App。  
> 基于 Apple Watch / Apple Health 数据的本地优先健康趋势参考 App。

StressWatch（心境）用于帮助用户观察压力、恢复、HRV、心率、睡眠、活动量等健康趋势。项目不提供医疗诊断、治疗建议或紧急用途，只作为个人健康趋势参考。

---

## 项目状态

当前主实现：

- 原生 SwiftUI iOS App
- HealthKit 集成
- 本地优先数据处理
- Demo Data 兜底
- MVVM 架构
- Core / Features / Shared 模块化结构
- iOS Liquid Glass 风格 UI
- Wellness Analysis 模块（可用于机器学习课程扩展）
- 官网 / 落地页位于 `stresswatch-web/`

仓库中可能仍保留 Expo / React Native 历史原型文件，但它们不是当前主线。

---

## 产品官网

独立前端落地页位于：

```text
stresswatch-web/
```

官网定位为 StressWatch 产品介绍页，包含：

- Apple Health / 健康仪表盘风格
- 薄荷绿 / 青色 Liquid Glass 视觉语言
- 功能介绍
- 隐私与本地优先说明
- 便于 App Store / GitHub Pages 的结构

推荐部署方式：

```text
GitHub Pages / Vercel / Netlify
```

建议的 GitHub Pages 地址格式：

```text
https://nanako-arasaka.github.io/StressWatch/
```

---

## 核心功能

### iOS App

- Dashboard：每日健康趋势概览
- 压力分（Stress Score）与恢复分（Recovery Score）
- HRV、心率、静息心率
- 睡眠时长与睡眠阶段
- 步数、活动能量、运动时间、站立时间
- 7 天趋势可视化
- Apple Health / Demo Data 数据源切换
- 单项 HealthKit 指标缺失时按卡片兜底
- 本地 JSON 存储（`FileManager + Codable`）
- 隐私优先：不上传服务器

### HealthKit 数据

StressWatch 当前支持：

- 心率（Heart Rate）
- 静息心率（Resting Heart Rate）
- 心率变异性 HRV SDNN
- 步数（Step Count）
- 睡眠分析（Sleep Analysis）
- 活动能量（Active Energy Burned）
- Apple 运动时间（Apple Exercise Time）
- Apple 站立时间（Apple Stand Time，含 iOS 可用性保护）

若 HealthKit 不可用、权限被拒绝，或部分指标缺失，App 会安全回退到 Demo Data，不会崩溃。

### Wellness Analysis

项目包含轻量分析模块，便于机器学习课程与后续 Core ML 扩展。

当前流水线：

```text
健康指标
  -> FeatureExtractor
  -> WellnessAnalyzer
  -> AdviceGenerator
  -> AnalysisViewModel
  -> AnalysisView
```

示例提取特征：

- 平均 HRV
- HRV 趋势
- 平均静息心率
- 睡眠均值
- 睡眠规律性
- 步数均值
- 活动水平
- 恢复均值
- 压力均值
- 数据置信度

当前输出状态：

- Balanced（平衡）
- Need Recovery（需要恢复）
- High Strain（高负荷）
- Low Activity（活动偏低）
- Sleep Debt（睡眠负债）
- Data Insufficient（数据不足）

当前实现为可解释的规则模型，并预留了 `CoreMLWellnessAnalyzer` 替换接口，无需重写 UI。

---

## 架构

StressWatch 采用模块化 MVVM 架构。

```text
SwiftUI View
  -> ViewModel
  -> Protocol
  -> Service / Engine
  -> LocalStorage / HealthKit / Analysis
```

高层结构：

```text
StressWatch/
├── App/
│   └── StressWatchApp.swift
├── Core/
│   ├── Analysis/
│   ├── Extensions/
│   ├── HealthKit/
│   ├── Models/
│   ├── Storage/
│   └── Utils/
├── Features/
│   ├── Analysis/
│   ├── Dashboard/
│   ├── Detail/
│   ├── Settings/
│   └── Trend/
├── Shared/
│   ├── Charts/
│   ├── Components/
│   ├── Glass/
│   ├── Motion/
│   └── Theme/
└── Resources/
```

### Core

业务逻辑与框架对接层：

- HealthKit 数据提供方
- Mock 健康数据提供方
- 本地存储
- 基线计算
- 压力与恢复模型
- Wellness 特征提取与分析
- 共享数据模型与工具

### Features

功能级 SwiftUI 页面与 ViewModel：

- Dashboard（今日）
- Trend（趋势）
- Settings（设置）
- Metric Detail（指标详情）
- Analysis（分析）

### Shared

可复用 UI 与设计系统：

- 玻璃卡片
- 浮动 Tab 栏
- 共享图表
- App 色板
- 动效系统
- Liquid Glass 风格组件

---

## 设计系统

StressWatch 视觉方向对齐 Apple Health / Liquid Glass：

- 薄荷绿 / 青色语义色系
- 磨砂玻璃卡片
- 大圆角
- 柔和阴影与轻微光晕
- 浮动 Liquid Glass Tab 栏
- 以 Dashboard 为主的移动布局
- 支持「减弱动态效果」（Reduce Motion）
- 适配深色 / 浅色模式

UI 系统主要通过以下入口组织：

- `AppColors`
- `AppMotion`
- `GlassCardView`
- `FloatingTabBar`
- Dashboard 与图表共享组件

---

## 隐私

StressWatch 按本地优先设计。

当前版本：

- 无需账号
- 不上传服务器
- 无第三方后端
- 健康数据在设备本地处理
- HealthKit 不可用时可使用 Demo Data
- 用户可在「健康」App 中撤销读取权限

官网隐私政策页应说明：

- 读取了哪些 Apple Health 数据
- 为何读取
- 是否上传数据
- 数据如何存储
- 用户如何撤销权限

---

## 医疗免责声明

StressWatch 仅用于个人健康趋势参考。

不提供：

- 医疗诊断
- 治疗建议
- 紧急服务
- 疾病检测
- 心理健康诊断

如有健康问题，请咨询合格专业人士。

```text
本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。
```

---

## 环境要求

推荐开发环境：

- macOS
- Xcode
- iPhone 真机
- Apple Developer 账号
- Apple Watch（推荐，便于真实数据测试）
- 已启用 HealthKit capability

当前部署目标：

```text
iOS 16.0
```

HealthKit 必须在真机上验证，模拟器不足以做最终验收。

---

## 用 Xcode 打开

```bash
open StressWatch.xcodeproj
```

真机运行前请检查：

- 已选择 `StressWatch` scheme
- 已配置 Signing Team
- Bundle Identifier 唯一
- 已启用 HealthKit capability
- 存在 `NSHealthShareUsageDescription`
- 如需写入，存在 `NSHealthUpdateUsageDescription`
- App Icon 已在资源目录配置
- Launch Screen 已配置

---

## 真机测试流程

1. 在 Xcode 中 Clean Build Folder。
2. 在真机 iPhone 上运行 App。
3. 先用 Demo Data 打开 Dashboard。
4. 进入「设置」。
5. 点击 HealthKit 授权按钮。
6. 授予 Apple Health 读取权限。
7. 将数据源切换为 Apple Health。
8. 返回 Dashboard 并刷新。
9. 确认 HealthKit 数据、按卡片兜底与 Demo 回退行为。
10. 测试深色模式、浅色模式与「减弱动态效果」。

---

## TestFlight 准备

上传 TestFlight 前请确认：

- App Icon
- Launch Screen
- Bundle Identifier
- 版本号与 Build 号
- 签名与 capabilities
- HealthKit entitlement
- 隐私政策 URL
- App Store 截图
- 医疗免责声明
- 未提交私钥或描述文件
- 未提交真实健康数据
- 未提交 `.env`、token、API key 或证书文件

建议忽略的敏感文件：

```text
DerivedData/
*.xcuserstate
*.mobileprovision
*.p12
*.cer
.env
.env.*
node_modules/
dist/
build/
```

---

## 官网开发

若开发前端落地页：

```bash
cd stresswatch-web
npm install
npm run dev
```

官网与 iOS App 相互独立，不需要 HealthKit。

推荐用途：

- 产品介绍
- 隐私政策入口
- GitHub Pages 部署
- App Store Connect 隐私政策 URL
- 作品集 / 比赛展示

---

## 路线图

计划中的下一步：

- Xcode clean build 与真机 QA
- HealthKit 授权回归测试
- TestFlight 内部构建
- 隐私政策页完善
- App Store 截图
- Apple Watch 伴侣 App
- Widget / 锁屏 Widget
- Core ML wellness 分析器
- 官网部署到 GitHub Pages

---

## 仓库说明

当前活跃路线是 `StressWatch/` 下的原生 SwiftUI App。

仓库中可能包含历史 Expo / React Native 原型与前端官网项目，它们不是 iOS 主实现路线。

---

## 许可证

本项目目前定位为个人学习、产品原型与课程项目仓库。若要更大范围分发，请先补充正式许可证。
