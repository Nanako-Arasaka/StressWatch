# StressWatch / 心境

> A local-first Apple Watch wellness trend app built with SwiftUI, HealthKit, and a Liquid Glass inspired interface.  
> 基于 Apple Watch / Apple Health 数据的本地优先健康趋势参考 App。

StressWatch（心境）用于帮助用户观察压力、恢复、HRV、心率、睡眠、活动量等健康趋势。项目不提供医疗诊断、治疗建议或紧急用途，只作为个人健康趋势参考。

---

## Project Status

Current main implementation:

- Native SwiftUI iOS app
- HealthKit integration
- Local-first data processing
- Demo Data fallback
- MVVM architecture
- Core / Features / Shared modular structure
- iOS Liquid Glass inspired UI
- Wellness Analysis module for machine-learning course extension
- Website / landing page included under `stresswatch-web/`

Legacy Expo / React Native prototype files may still exist in the repository, but they are not the current main route.

---

## Product Website

A separate front-end landing page is included in:

```text
stresswatch-web/
```

The website is designed as a product introduction page for StressWatch, with:

- Apple Health / wellness dashboard style
- Mint / teal Liquid Glass visual language
- Feature introduction
- Privacy and local-first messaging
- App Store / GitHub Pages friendly structure

Recommended deployment:

```text
GitHub Pages / Vercel / Netlify
```

Suggested GitHub Pages URL format:

```text
https://nanako-arasaka.github.io/StressWatch/
```

---

## Core Features

### iOS App

- Dashboard for daily wellness overview
- Stress Score and Recovery Score
- HRV, heart rate, resting heart rate
- Sleep duration and sleep stages
- Steps, active energy, exercise time, stand time
- 7-day trend visualization
- Apple Health / Demo Data source switching
- Per-card fallback when individual HealthKit metrics are missing
- Local JSON storage using `FileManager + Codable`
- Privacy-first design with no server upload

### HealthKit Data

StressWatch currently works with:

- Heart Rate
- Resting Heart Rate
- Heart Rate Variability SDNN
- Step Count
- Sleep Analysis
- Active Energy Burned
- Apple Exercise Time
- Apple Stand Time, with iOS availability protection

If HealthKit is unavailable, permission is denied, or some metrics are missing, the app falls back safely to Demo Data without crashing.

### Wellness Analysis

The project includes a lightweight analysis module for machine-learning coursework and future Core ML extension.

Current pipeline:

```text
Health Metrics
  -> FeatureExtractor
  -> WellnessAnalyzer
  -> AdviceGenerator
  -> AnalysisViewModel
  -> AnalysisView
```

Example extracted features:

- Average HRV
- HRV trend
- Average resting heart rate
- Sleep average
- Sleep consistency
- Step average
- Activity level
- Recovery average
- Stress average
- Data confidence

Current output states:

- Balanced
- Need Recovery
- High Strain
- Low Activity
- Sleep Debt
- Data Insufficient

The current implementation uses an explainable rule-based model. It is designed so a future `CoreMLWellnessAnalyzer` can replace the rule model without rewriting the UI.

---

## Architecture

StressWatch uses a modular MVVM architecture.

```text
SwiftUI View
  -> ViewModel
  -> Protocol
  -> Service / Engine
  -> LocalStorage / HealthKit / Analysis
```

High-level structure:

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

Business logic and framework-facing services:

- HealthKit data provider
- Mock health data provider
- Local storage
- Baseline calculation
- Stress and recovery models
- Wellness feature extraction and analysis
- Shared data models and utilities

### Features

Feature-level SwiftUI screens and ViewModels:

- Dashboard
- Trend
- Settings
- Metric Detail
- Analysis

### Shared

Reusable UI and design system elements:

- Glass cards
- Floating tab bar
- Shared charts
- App colors
- Motion system
- Liquid Glass inspired components

---

## Design System

StressWatch follows an Apple Health / Liquid Glass inspired visual direction:

- Mint / teal semantic color system
- Frosted glass cards
- Large rounded corners
- Soft shadows and subtle glow
- Floating Liquid Glass tab bar
- Dashboard-first mobile layout
- Reduced Motion support
- Dark and light mode aware styling

The UI system is organized through:

- `AppColors`
- `AppMotion`
- `GlassCardView`
- `FloatingTabBar`
- Shared dashboard and chart components

---

## Privacy

StressWatch is designed as a local-first app.

Current version:

- No account required
- No server upload
- No third-party backend
- Health data is processed locally on device
- Demo Data is available when HealthKit data is unavailable
- Users can revoke Health permissions in the Apple Health app settings

The website should link to a privacy policy page that explains:

- What Apple Health data is read
- Why the app reads it
- Whether data is uploaded
- How data is stored
- How users can revoke permissions

---

## Medical Disclaimer

StressWatch is for personal wellness trend reference only.

It does not provide:

- Medical diagnosis
- Treatment advice
- Emergency services
- Disease detection
- Mental health diagnosis

If you have health concerns, please consult a qualified professional.

中文声明：

```text
本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。
```

---

## Requirements

Recommended development environment:

- macOS
- Xcode
- iPhone physical device
- Apple Developer account
- Apple Watch, recommended for real data testing
- HealthKit capability enabled

Current target:

```text
iOS 26.0
```

Because HealthKit behavior must be tested on a physical device, the simulator is not enough for final validation.

---

## Open in Xcode

```bash
open StressWatch.xcodeproj
```

Before running on device, check:

- `StressWatch` scheme is selected
- Signing Team is configured
- Bundle Identifier is unique
- HealthKit capability is enabled
- `NSHealthShareUsageDescription` exists
- `NSHealthUpdateUsageDescription` exists, if required
- App Icon is configured in the asset catalog
- Launch Screen is configured

---

## Real Device Test Flow

1. Clean Build Folder in Xcode.
2. Run the app on a real iPhone.
3. Open Dashboard with Demo Data.
4. Go to Settings.
5. Tap the HealthKit authorization button.
6. Grant Apple Health read permission.
7. Switch data source to Apple Health.
8. Return to Dashboard and refresh.
9. Confirm HealthKit data, per-card fallback, and Demo fallback behavior.
10. Test dark mode, light mode, and Reduce Motion.

---

## TestFlight Preparation

Before uploading to TestFlight, verify:

- App Icon
- Launch Screen
- Bundle Identifier
- Version and Build Number
- Signing and capabilities
- HealthKit entitlement
- Privacy policy URL
- App Store screenshots
- Medical disclaimer
- No private keys or provisioning profiles committed
- No real Health data committed
- No `.env`, token, API key, or certificate files committed

Recommended sensitive files to ignore:

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

## Website Development

If working on the front-end landing page:

```bash
cd stresswatch-web
npm install
npm run dev
```

The website is separate from the iOS app and does not require HealthKit.

Recommended use:

- Product introduction
- Privacy Policy entry
- GitHub Pages deployment
- App Store Connect Privacy Policy URL
- Portfolio / competition display

---

## Roadmap

Planned next steps:

- Xcode clean build and real-device QA
- HealthKit authorization regression testing
- TestFlight internal build
- Privacy Policy page refinement
- App Store screenshots
- Apple Watch companion app
- Widget / Lock Screen widget
- Core ML wellness analyzer
- Website deployment to GitHub Pages

---

## Repository Notes

The current active route is the native SwiftUI app under `StressWatch/`.

The repository may also contain historical Expo / React Native prototype files and the front-end website project. Those are not the main iOS implementation route.

---

## License

This project is currently intended as a personal learning, product prototype, and course project repository. Add a formal license before wider distribution.
