import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stressScore: StressScore?
    @Published var recoveryScore: RecoveryScore?
    @Published var baseline: Baseline?
    @Published var todayHR: [HealthMetric]
    @Published var todayHRV: [HealthMetric]
    @Published var recentMetrics: [HealthMetric]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var needsMoreData: Bool
    @Published var dataSourceLabel: String

    private let healthDataProvider: any HealthKitDataProvider
    private let demoDataProvider: any HealthKitDataProvider
    private let baselineEngine: any BaselineCalculating
    private let stressModel: any StressComputing
    private let recoveryModel: any RecoveryComputing
    private let storage: any LocalStorageProtocol
    private let calendar: Calendar

    init(
        healthDataProvider: any HealthKitDataProvider,
        demoDataProvider: any HealthKitDataProvider = MockHealthKitService(),
        baselineEngine: any BaselineCalculating,
        stressModel: any StressComputing,
        recoveryModel: any RecoveryComputing,
        storage: any LocalStorageProtocol,
        calendar: Calendar = .current
    ) {
        self.healthDataProvider = healthDataProvider
        self.demoDataProvider = demoDataProvider
        self.baselineEngine = baselineEngine
        self.stressModel = stressModel
        self.recoveryModel = recoveryModel
        self.storage = storage
        self.calendar = calendar
        self.todayHR = []
        self.todayHRV = []
        self.recentMetrics = []
        self.isLoading = false
        self.errorMessage = nil
        self.needsMoreData = false
        self.dataSourceLabel = "Demo Data"
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        needsMoreData = false

        do {
            let baselineWindowDays = try storage.fetchBaselineWindowDays()
            let preferredDataSource = try storage.fetchPreferredDataSource()
            let now = Date()
            let endDate = calendar.endOfDay(for: now)
            let startDate = calendar.date(
                byAdding: .day,
                value: -(baselineWindowDays - 1),
                to: calendar.startOfDay(for: now)
            ) ?? now
            let fetchResult = try await fetchMetrics(
                preferredDataSource: preferredDataSource,
                from: startDate,
                to: endDate
            )
            let metrics = fetchResult.metrics

            guard let baseline = baselineEngine.calculate(from: metrics), baseline.isValid else {
                self.baseline = nil
                self.needsMoreData = true
                self.isLoading = false
                return
            }

            let todayMetrics = metricsForDay(now, in: metrics)
            let stressScore = stressModel.compute(current: todayMetrics, baseline: baseline)
            let recoveryScore = recoveryModel.compute(current: todayMetrics, baseline: baseline)

            try storage.saveBaseline(baseline)
            try storage.saveStressScore(stressScore)

            self.baseline = baseline
            self.stressScore = stressScore
            self.recoveryScore = recoveryScore
            self.todayHR = todayMetrics.filter { $0.type == .heartRate }
            self.todayHRV = todayMetrics.filter { $0.type == .hrv }
            self.recentMetrics = metrics
            self.dataSourceLabel = fetchResult.source == .appleHealth ? "Apple Health" : "Demo Data"
            self.isLoading = false
        } catch {
            errorMessage = "无法加载趋势参考数据"
            isLoading = false
        }
    }

    func loadCachedData() {
        do {
            baseline = try storage.fetchBaseline()

            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            stressScore = try storage.fetchStressScores(from: startDate, to: calendar.endOfDay(for: endDate)).last
        } catch {
            errorMessage = "无法读取本地缓存"
        }
    }

    private func fetchMetrics(
        preferredDataSource: AppDataSource,
        from: Date,
        to: Date
    ) async throws -> (metrics: [HealthMetric], source: AppDataSource) {
        if preferredDataSource == .appleHealth {
            do {
                try await healthDataProvider.requestAuthorization()
                let metrics = try await healthDataProvider.fetchMetrics(
                    types: MetricType.allCases,
                    from: from,
                    to: to
                )

                if !metrics.isEmpty {
                    return (metrics, .appleHealth)
                }
            } catch {
                // Fall through to demo data so the dashboard remains usable.
            }
        }

        try await demoDataProvider.requestAuthorization()
        let demoMetrics = try await demoDataProvider.fetchMetrics(
            types: MetricType.allCases,
            from: from,
            to: to
        )
        return (demoMetrics, .demo)
    }

    private func metricsForDay(_ date: Date, in metrics: [HealthMetric]) -> [HealthMetric] {
        metrics.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
