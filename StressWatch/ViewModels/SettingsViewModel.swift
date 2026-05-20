import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var baselineWindowDays: Int
    @Published var useMockData: Bool
    @Published var healthKitStatusText: String
    @Published var errorMessage: String?

    private let storage: any LocalStorageProtocol
    private let healthDataProvider: any HealthKitDataProvider

    init(
        storage: any LocalStorageProtocol,
        healthDataProvider: any HealthKitDataProvider
    ) {
        self.storage = storage
        self.healthDataProvider = healthDataProvider
        self.baselineWindowDays = (try? storage.fetchBaselineWindowDays()) ?? 7
        let preferredDataSource = (try? storage.fetchPreferredDataSource()) ?? .demo
        self.useMockData = preferredDataSource == .demo
        self.healthKitStatusText = Self.statusText(for: healthDataProvider.authorizationStatus())
        self.errorMessage = nil
    }

    func updateBaselineWindow(_ days: Int) {
        baselineWindowDays = days
        do {
            try storage.saveBaselineWindowDays(days)
        } catch {
            errorMessage = "无法保存基线窗口设置"
        }
    }

    func clearAllData() {
        let cutoff = Date.distantFuture
        try? storage.deleteOldData(before: cutoff)
    }

    func requestHealthKitAuthorization() async {
        do {
            try await healthDataProvider.requestAuthorization()
            healthKitStatusText = Self.statusText(for: healthDataProvider.authorizationStatus())
            errorMessage = nil
        } catch {
            healthKitStatusText = Self.statusText(for: healthDataProvider.authorizationStatus())
            errorMessage = "HealthKit 授权不可用，当前可继续使用演示数据"
        }
    }

    func useAppleHealth() {
        do {
            try storage.savePreferredDataSource(.appleHealth)
            useMockData = false
            errorMessage = nil
        } catch {
            errorMessage = "无法保存数据源设置"
        }
    }

    func useDemoData() {
        do {
            try storage.savePreferredDataSource(.demo)
            useMockData = true
            errorMessage = nil
        } catch {
            errorMessage = "无法保存数据源设置"
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
}
