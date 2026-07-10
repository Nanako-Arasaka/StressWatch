import SwiftUI
import UIKit
import UserNotifications

final class StressWatchAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var hrvNotificationCoordinator: HRVNotificationCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Self.hrvNotificationCoordinator?.start()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

final class HRVNotificationCoordinator {
    private let healthService: HealthKitService
    private let storage: LocalStorageProtocol
    private let baselineEngine: BaselineCalculating
    private let stressModel: StressComputing
    private let recoveryModel: RecoveryComputing
    private let notificationCenter: UNUserNotificationCenter
    private let calendar: Calendar
    private let lastProcessedHRVKey = "StressWatch.LastNotifiedHRVDate"
    private var isStarted = false

    init(
        healthService: HealthKitService,
        storage: LocalStorageProtocol,
        baselineEngine: BaselineCalculating,
        stressModel: StressComputing,
        recoveryModel: RecoveryComputing,
        notificationCenter: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.healthService = healthService
        self.storage = storage
        self.baselineEngine = baselineEngine
        self.stressModel = stressModel
        self.recoveryModel = recoveryModel
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    func start() {
        guard !isStarted else {
            return
        }

        guard healthService.authorizationStatus() == .authorized else {
            print("[HRVNotification] waiting for HealthKit authorization")
            return
        }

        isStarted = true
        Task {
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    print("[HRVNotification] notification authorization denied")
                    return
                }

                try healthService.startObservingHRVUpdates { [weak self] in
                    await self?.processLatestHRV()
                }
            } catch {
                isStarted = false
                print("[HRVNotification] setup failed: \(error)")
            }
        }
    }

    private func processLatestHRV() async {
        do {
            let now = Date()
            let windowDays = (try? storage.fetchBaselineWindowDays()) ?? 7
            let startDate = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
            let metrics = try await healthService.fetchMetrics(
                types: [.heartRate, .hrv, .restingHeartRate, .steps, .sleep],
                from: startDate,
                to: now
            )

            guard let latestHRV = metrics
                .filter({ $0.type == .hrv })
                .max(by: { $0.date < $1.date }) else {
                print("[HRVNotification] observer fired without a readable HRV sample")
                return
            }

            let defaults = UserDefaults.standard
            if let lastProcessedDate = defaults.object(forKey: lastProcessedHRVKey) as? Date,
               latestHRV.date <= lastProcessedDate {
                print("[HRVNotification] ignored duplicate sample at \(latestHRV.date)")
                return
            }

            guard let baseline = baselineEngine.calculate(from: metrics), baseline.isValid else {
                print("[HRVNotification] insufficient data for baseline")
                return
            }

            let todayMetrics = metrics.filter { calendar.isDate($0.date, inSameDayAs: now) }
            let stressScore = stressModel.compute(current: todayMetrics, baseline: baseline)
            let recoveryScore = recoveryModel.compute(current: todayMetrics, baseline: baseline)

            try storage.saveBaseline(baseline)
            try storage.saveStressScore(stressScore)

            if defaults.object(forKey: lastProcessedHRVKey) == nil {
                defaults.set(latestHRV.date, forKey: lastProcessedHRVKey)
                print("[HRVNotification] initial HRV checkpoint saved at \(latestHRV.date)")
                return
            }

            try await sendNotification(
                hrv: latestHRV.value,
                stressScore: stressScore,
                recoveryScore: recoveryScore,
                sampleDate: latestHRV.date
            )
            defaults.set(latestHRV.date, forKey: lastProcessedHRVKey)
            print("[HRVNotification] notification scheduled for sample at \(latestHRV.date)")
        } catch {
            print("[HRVNotification] processing failed: \(error)")
        }
    }

    private func sendNotification(
        hrv: Double,
        stressScore: StressScore,
        recoveryScore: RecoveryScore,
        sampleDate: Date
    ) async throws {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            print("[HRVNotification] notifications are not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "HRV 已更新：\(Int(round(hrv))) ms"
        content.body = "压力 \(stressScore.value)（\(stressScore.level.displayName)） · 恢复 \(recoveryScore.value)（\(recoveryScore.level.displayName)）"
        content.sound = .default
        content.threadIdentifier = "stresswatch.hrv"

        let request = UNNotificationRequest(
            identifier: "stresswatch.hrv.\(Int(sampleDate.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        try await notificationCenter.add(request)
    }
}

@main
struct StressWatchApp: App {
    @UIApplicationDelegateAdaptor(StressWatchAppDelegate.self) private var appDelegate
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var trendViewModel: TrendViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    private let hrvNotificationCoordinator: HRVNotificationCoordinator
    @State private var selectedTab: AppTab = .dashboard
    @State private var shouldOpenAnalysisFromWidget = false

    init() {
        let storage = LocalStorage()
        let healthDataProvider = HealthKitService()
        let demoDataProvider = MockHealthKitService(daysOfData: 30)
        let baselineEngine = BaselineEngine()
        let stressModel = StressModel()
        let recoveryModel = RecoveryModel()
        let hrvNotificationCoordinator = HRVNotificationCoordinator(
            healthService: healthDataProvider,
            storage: storage,
            baselineEngine: baselineEngine,
            stressModel: stressModel,
            recoveryModel: recoveryModel
        )
        self.hrvNotificationCoordinator = hrvNotificationCoordinator
        StressWatchAppDelegate.hrvNotificationCoordinator = hrvNotificationCoordinator

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
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(
                        viewModel: dashboardViewModel,
                        shouldOpenAnalysis: $shouldOpenAnalysisFromWidget
                    )

                case .trend:
                    TrendView(viewModel: trendViewModel)

                case .settings:
                    SettingsView(viewModel: settingsViewModel)
                }
            }
            .transition(.opacity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingTabBar(selection: $selectedTab)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onOpenURL(perform: handleWidgetURL)
            .task {
                hrvNotificationCoordinator.start()
            }
        }
    }

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "stresswatch" else {
            return
        }

        switch url.host {
        case "analysis":
            selectedTab = .dashboard
            shouldOpenAnalysisFromWidget = true
        case "dashboard":
            selectedTab = .dashboard
            shouldOpenAnalysisFromWidget = false
        default:
            break
        }
    }
}
