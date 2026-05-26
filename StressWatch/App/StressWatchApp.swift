import SwiftUI

@main
struct StressWatchApp: App {
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var trendViewModel: TrendViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var selectedTab: AppTab = .dashboard

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
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView(viewModel: dashboardViewModel)

                    case .trend:
                        TrendView(viewModel: trendViewModel)

                    case .settings:
                        SettingsView(viewModel: settingsViewModel)
                    }
                }
                .transition(.opacity)

                FloatingTabBar(selection: $selectedTab)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}
