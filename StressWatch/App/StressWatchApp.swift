import SwiftUI

@main
struct StressWatchApp: App {
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var trendViewModel: TrendViewModel
    @StateObject private var settingsViewModel: SettingsViewModel

    init() {
        let storage = LocalStorage()
        let healthDataProvider = HealthKitService()
        let demoDataProvider = MockHealthKitService(daysOfData: 30)
        let baselineEngine = BaselineEngine()
        let stressModel = StressModel()
        let recoveryModel = RecoveryModel()

        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(
                healthDataProvider: healthDataProvider,
                demoDataProvider: demoDataProvider,
                baselineEngine: baselineEngine,
                stressModel: stressModel,
                recoveryModel: recoveryModel,
                storage: storage
            )
        )
        _trendViewModel = StateObject(wrappedValue: TrendViewModel(storage: storage))
        _settingsViewModel = StateObject(
            wrappedValue: SettingsViewModel(
                storage: storage,
                healthDataProvider: healthDataProvider
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(viewModel: dashboardViewModel)
                    .tabItem {
                        Label("今日", systemImage: "gauge.with.dots.needle.33percent")
                    }

                TrendView(viewModel: trendViewModel)
                    .tabItem {
                        Label("趋势", systemImage: "chart.xyaxis.line")
                    }

                SettingsView(viewModel: settingsViewModel)
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
            }
        }
    }
}
