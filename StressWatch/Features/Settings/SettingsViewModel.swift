import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var baselineWindowDays: Int
    @Published var useMockData: Bool
    @Published var healthKitStatusText: String
    @Published var authorizationState: SettingsAuthorizationState
    @Published var errorMessage: String?

    private let storage: any LocalStorageProtocol
    private let healthDataProvider: any HealthKitDataProvider
    private let calendar: Calendar

    init(
        storage: any LocalStorageProtocol,
        healthDataProvider: any HealthKitDataProvider,
        calendar: Calendar = .current
    ) {
        self.storage = storage
        self.healthDataProvider = healthDataProvider
        self.calendar = calendar
        self.baselineWindowDays = (try? storage.fetchBaselineWindowDays()) ?? 7
        let preferredDataSource = (try? storage.fetchPreferredDataSource()) ?? .demo
        self.useMockData = preferredDataSource == .demo
        let authStatus = healthDataProvider.authorizationStatus()
        self.healthKitStatusText = Self.statusText(for: authStatus)
        self.authorizationState = Self.state(for: authStatus)
        self.errorMessage = nil
        print("[SettingsViewModel] init healthDataProvider=\(type(of: healthDataProvider))")
    }

    func updateBaselineWindow(_ days: Int) {
        print("[SettingsViewModel] updateBaselineWindow days=\(days)")
        baselineWindowDays = days
        do {
            try storage.saveBaselineWindowDays(days)
            errorMessage = "Baseline 已切换为 \(days) 天"
        } catch {
            errorMessage = "无法保存基线窗口设置"
        }
    }

    func clearAllData() {
        print("[SettingsViewModel] clearAllData")
        let cutoff = Date.distantFuture
        try? storage.deleteOldData(before: cutoff)
        errorMessage = "本地缓存已清除"
    }

    func requestHealthKitAuthorization() async {
        print("[SettingsViewModel] requestHealthKitAuthorization start")
        authorizationState = .requesting
        healthKitStatusText = "正在请求授权..."
        errorMessage = nil

        do {
            try await healthDataProvider.requestAuthorization()
            print("[SettingsViewModel] requestHealthKitAuthorization authorization callback succeeded")
            authorizationState = .authorized
            healthKitStatusText = "已请求授权"
            try await enableAppleHealthIfDataAvailable(context: "授权完成")
            print("[SettingsViewModel] requestHealthKitAuthorization finished useMockData=\(useMockData)")
        } catch {
            print("[SettingsViewModel] requestHealthKitAuthorization failed: \(error)")
            applyAuthorizationFailure(error)
        }
    }

    func useAppleHealth() async {
        print("[SettingsViewModel] useAppleHealth start")
        authorizationState = .requesting
        healthKitStatusText = "正在请求授权..."
        errorMessage = nil

        do {
            try await healthDataProvider.requestAuthorization()
            print("[SettingsViewModel] useAppleHealth authorization callback succeeded")
            authorizationState = .authorized
            healthKitStatusText = "已请求授权"
            try await enableAppleHealthIfDataAvailable(context: "切换 Apple Health")
        } catch {
            print("[SettingsViewModel] useAppleHealth failed: \(error)")
            applyAuthorizationFailure(error)
        }
    }

    func useDemoData() {
        print("[SettingsViewModel] useDemoData")
        do {
            try storage.savePreferredDataSource(.demo)
            useMockData = true
            errorMessage = "已切换到 Demo Data"
        } catch {
            errorMessage = "无法保存数据源设置"
        }
    }

    private func enableAppleHealthIfDataAvailable(context: String) async throws {
        do {
            let metrics = try await fetchLatestAppleHealthMetrics()
            if metrics.isEmpty {
                try storage.savePreferredDataSource(.demo)
                useMockData = true
                authorizationState = .failed
                errorMessage = "\(context)：授权失败或被拒绝，或暂无可读取的 Apple Health 数据。当前继续使用 Demo Data。请确认已授权并且健康 App 中有近期数据。"
                print("[SettingsViewModel] \(context) no HealthKit metrics, fallback Demo Data")
            } else {
                try storage.savePreferredDataSource(.appleHealth)
                useMockData = false
                authorizationState = .authorized
                errorMessage = "\(context)：已读取到 \(metrics.count) 条 Apple Health 数据，已切换到 Apple Health。"
                print("[SettingsViewModel] \(context) fetched metrics count=\(metrics.count), switched Apple Health")
            }
        } catch {
            try storage.savePreferredDataSource(.demo)
            useMockData = true
            authorizationState = .failed
            errorMessage = "\(context)：读取 Apple Health 数据失败，当前继续使用 Demo Data。错误：\(error.localizedDescription)"
            print("[SettingsViewModel] \(context) fetch failed, fallback Demo Data: \(error)")
        }
    }

    private func fetchLatestAppleHealthMetrics() async throws -> [HealthMetric] {
        let endDate = calendar.endOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        return try await healthDataProvider.fetchMetrics(types: MetricType.allCases, from: startDate, to: endDate)
    }

    private func applyAuthorizationFailure(_ error: Error) {
        useMockData = true
        try? storage.savePreferredDataSource(.demo)

        let status = healthDataProvider.authorizationStatus()
        healthKitStatusText = Self.statusText(for: status)

        if case .unavailable = status {
            authorizationState = .unavailable
            errorMessage = "HealthKit 不可用，当前继续使用 Demo Data。请确认使用 iPhone 真机测试。"
        } else {
            authorizationState = .failed
            errorMessage = "授权失败或被拒绝，当前继续使用 Demo Data。错误：\(error.localizedDescription)"
        }
    }

    private static func statusText(for status: HealthKitAuthStatus) -> String {
        switch status {
        case .notDetermined:
            return "未请求"
        case .authorized:
            return "已授权"
        case .denied:
            return "已拒绝"
        case .unavailable:
            return "不可用"
        }
    }

    private static func state(for status: HealthKitAuthStatus) -> SettingsAuthorizationState {
        switch status {
        case .notDetermined:
            return .idle
        case .authorized:
            return .authorized
        case .denied:
            return .failed
        case .unavailable:
            return .unavailable
        }
    }
}

enum SettingsAuthorizationState {
    case idle
    case requesting
    case authorized
    case failed
    case unavailable
}
