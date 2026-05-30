import Foundation
import Combine
import SwiftUI

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
    @Published var snapshot: HealthDashboardSnapshot

    private let healthDataProvider: any HealthKitDataProvider
    private let demoDataProvider: any HealthKitDataProvider
    private let baselineEngine: any BaselineCalculating
    private let stressModel: any StressComputing
    private let recoveryModel: any RecoveryComputing
    private let storage: any LocalStorageProtocol
    private let calendar: Calendar
    private var isRefreshing = false

    var localStorage: any LocalStorageProtocol {
        storage
    }

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
        self.snapshot = .empty
    }

    func refresh() async {
        guard !isRefreshing else {
            print("[DashboardViewModel] refresh skipped: already refreshing")
            return
        }

        isRefreshing = true
        isLoading = true
        errorMessage = nil
        needsMoreData = false
        let refreshStartedAt = Date()
        print("[DashboardViewModel] refresh start")

        defer {
            isRefreshing = false
            isLoading = false
            let elapsed = Date().timeIntervalSince(refreshStartedAt)
            print("[DashboardViewModel] refresh end elapsed=\(String(format: "%.2f", elapsed))s")
        }

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
            print("[DashboardViewModel] refresh fetched metrics=\(metrics.count) source=\(fetchResult.source)")

            guard let baseline = baselineEngine.calculate(from: metrics), baseline.isValid else {
                self.baseline = nil
                self.snapshot = .empty
                self.needsMoreData = true
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
            self.snapshot = makeSnapshot(
                metrics: metrics,
                todayMetrics: todayMetrics,
                baseline: baseline,
                stressScore: stressScore,
                recoveryScore: recoveryScore,
                appleMetricTypes: fetchResult.appleMetricTypes,
                trendStartDate: calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? startDate,
                trendEndDate: endDate
            )
        } catch {
            errorMessage = "无法加载趋势参考数据"
            print("[DashboardViewModel] refresh failed: \(error)")
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
    ) async throws -> (metrics: [HealthMetric], source: AppDataSource, appleMetricTypes: Set<MetricType>) {
        print("[DashboardViewModel] fetchMetrics start preferred=\(preferredDataSource) from=\(from) to=\(to)")
        let demoMetrics = try await fetchDemoMetrics(from: from, to: to)

        guard preferredDataSource == .appleHealth else {
            print("[DashboardViewModel] fetchMetrics demo metrics=\(demoMetrics.count)")
            return (demoMetrics, .demo, [])
        }

        do {
            try await healthDataProvider.requestAuthorization()
            let appleMetrics = try await healthDataProvider.fetchMetrics(
                types: MetricType.allCases,
                from: from,
                to: to
            )

            let appleMetricTypes = Set(appleMetrics.map(\.type))
            let fallbackMetrics = demoMetrics.filter { !appleMetricTypes.contains($0.type) }
            let displaySource: AppDataSource = hasUsableAppleHealthData(appleMetrics) ? .appleHealth : .demo
            print("[DashboardViewModel] fetchMetrics apple=\(appleMetrics.count) fallback=\(fallbackMetrics.count) display=\(displaySource)")
            return (appleMetrics + fallbackMetrics, displaySource, appleMetricTypes)
        } catch {
            print("[DashboardViewModel] fetchMetrics apple failed, using demo: \(error)")
            return (demoMetrics, .demo, [])
        }
    }

    private func fetchDemoMetrics(from: Date, to: Date) async throws -> [HealthMetric] {
        try await demoDataProvider.requestAuthorization()
        return try await demoDataProvider.fetchMetrics(
            types: MetricType.allCases,
            from: from,
            to: to
        )
    }

    private func hasUsableAppleHealthData(_ metrics: [HealthMetric]) -> Bool {
        let metricTypes = Set(metrics.map(\.type))
        let hasRecentData = metrics.contains { metric in
            guard let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()) else {
                return false
            }
            return metric.date >= twoDaysAgo
        }

        return metricTypes.count >= 3 || hasRecentData
    }

    private func makeSnapshot(
        metrics: [HealthMetric],
        todayMetrics: [HealthMetric],
        baseline: Baseline,
        stressScore: StressScore,
        recoveryScore: RecoveryScore,
        appleMetricTypes: Set<MetricType>,
        trendStartDate: Date,
        trendEndDate: Date
    ) -> HealthDashboardSnapshot {
        // 这里将 HealthKit / Demo 原始数据转换为 Dashboard 展示状态。
        let stressTrend = stressScoresByDay(
            from: metrics,
            currentScore: stressScore,
            from: trendStartDate,
            to: trendEndDate
        ).map { Double($0.value) }
        let hrvTrend = dailyLatestValues(for: .hrv, in: metrics)
        let heartTrend = dailyLatestValues(for: .heartRate, in: metrics)
        let activityTrend = dailyLatestValues(for: .activeEnergyBurned, in: metrics)
        let standTrend = dailyLatestValues(for: .appleStandTime, in: metrics)
        let activitySource = source(for: [.activeEnergyBurned, .appleExerciseTime, .appleStandTime], appleMetricTypes: appleMetricTypes, metrics: metrics)
        let sleepStages = makeSleepStages(from: todayMetrics)
        let liveStress = makeLiveStressSnapshot(
            metrics: metrics,
            baseline: baseline,
            source: source(for: [.hrv], appleMetricTypes: appleMetricTypes, metrics: metrics)
        )

        let cards = [
            stressMetric(stressScore, trend: stressTrend, source: source(for: [.heartRate, .hrv, .steps, .sleep], appleMetricTypes: appleMetricTypes, metrics: metrics)),
            recoveryMetric(recoveryScore, trend: hrvTrend, source: source(for: [.hrv, .restingHeartRate, .sleep], appleMetricTypes: appleMetricTypes, metrics: metrics)),
            hrvMetric(todayMetrics: todayMetrics, baseline: baseline, trend: hrvTrend, source: source(for: [.hrv], appleMetricTypes: appleMetricTypes, metrics: metrics)),
            heartRateMetric(todayMetrics: todayMetrics, trend: heartTrend, source: source(for: [.heartRate, .restingHeartRate], appleMetricTypes: appleMetricTypes, metrics: metrics)),
            sleepMetric(todayMetrics: todayMetrics, baseline: baseline, source: source(for: [.sleep], appleMetricTypes: appleMetricTypes, metrics: metrics)),
            stepsMetric(todayMetrics: todayMetrics, source: source(for: [.steps], appleMetricTypes: appleMetricTypes, metrics: metrics)),
            activityMetric(todayMetrics: todayMetrics, source: source(for: [.activeEnergyBurned, .appleExerciseTime, .appleStandTime], appleMetricTypes: appleMetricTypes, metrics: metrics))
        ]

        return HealthDashboardSnapshot(
            metrics: cards,
            stressTrend: stressTrend,
            hrvTrend: hrvTrend,
            heartRateTrend: heartTrend,
            activityEnergyTrend: activityTrend,
            activityStandTrend: standTrend,
            activityEnergyToday: todayMetrics.latestValue(for: .activeEnergyBurned).map { "\(Int(round($0))) kcal" } ?? "暂无",
            activityExerciseToday: todayMetrics.latestValue(for: .appleExerciseTime).map { "\(Int(round($0))) min" } ?? "暂无",
            activityStandToday: todayMetrics.latestValue(for: .appleStandTime).map { "\(Int(round($0))) h" } ?? "暂无",
            activityEnergyGoal: "500 kcal",
            activityExerciseGoal: "30 min",
            activityStandGoal: "12 h",
            activitySource: activitySource,
            sleepStages: sleepStages,
            liveStress: liveStress,
            insight: "分数仅用于个人健康趋势参考，请结合近期睡眠、活动和主观感受一起观察。"
        )
    }

    private func makeLiveStressSnapshot(
        metrics: [HealthMetric],
        baseline: Baseline,
        source: DashboardMetricSource
    ) -> LiveStressSnapshot {
        let dataSource: AppDataSource = source == .appleHealth ? .appleHealth : .demo

        return LiveStressEstimator.estimate(
            recentHRV: metrics.latestValue(for: .hrv),
            baselineHRV: baseline.avgHRV,
            recentRestingHR: metrics.latestValue(for: .restingHeartRate),
            baselineRestingHR: baseline.avgRestingHR,
            sleepHours: metrics.latestValue(for: .sleep),
            baselineSleepHours: baseline.avgSleepHours,
            source: dataSource
        )
    }

    private func stressMetric(_ score: StressScore, trend: [Double], source: DashboardMetricSource) -> DashboardMetric {
        DashboardMetric(
            id: "stress",
            title: "Stress Score",
            value: "\(score.value)",
            unit: "",
            subtitle: "压力趋势参考",
            status: stressStatus(for: score.value),
            systemImage: "waveform.path.ecg",
            color: AppColors.stressWarm,
            trendValues: trend,
            source: source
        )
    }

    private func recoveryMetric(_ score: RecoveryScore, trend: [Double], source: DashboardMetricSource) -> DashboardMetric {
        DashboardMetric(
            id: "recovery",
            title: "Recovery",
            value: "\(score.value)",
            unit: "",
            subtitle: "恢复趋势参考",
            status: recoveryStatus(for: score.value),
            systemImage: "heart.circle",
            color: AppColors.recoveryBlue,
            trendValues: trend,
            source: source
        )
    }

    private func hrvMetric(todayMetrics: [HealthMetric], baseline: Baseline, trend: [Double], source: DashboardMetricSource) -> DashboardMetric {
        let value = todayMetrics.latestValue(for: .hrv)
        let delta = value.map { (($0 - baseline.avgHRV) / safeDenominator(baseline.avgHRV)) * 100 }

        return DashboardMetric(
            id: "hrv",
            title: "HRV",
            value: value.map { "\(Int(round($0)))" } ?? "暂无",
            unit: value == nil ? "" : "ms",
            subtitle: delta.map { "\($0 >= 0 ? "+" : "")\(Int(round($0)))% vs baseline" } ?? "暂无今日数据",
            status: delta.map { $0 >= 0 ? "高于基线" : "低于基线" } ?? "暂无数据",
            systemImage: "waveform",
            color: AppColors.chartPrimary,
            trendValues: trend,
            source: source
        )
    }

    private func heartRateMetric(todayMetrics: [HealthMetric], trend: [Double], source: DashboardMetricSource) -> DashboardMetric {
        let latestHR = todayMetrics.latestValue(for: .heartRate)
        let restingHR = todayMetrics.latestValue(for: .restingHeartRate)

        return DashboardMetric(
            id: "heartRate",
            title: "Heart Rate",
            value: latestHR.map { "\(Int(round($0)))" } ?? "暂无",
            unit: latestHR == nil ? "" : "bpm",
            subtitle: restingHR.map { "Resting \(Int(round($0))) bpm" } ?? "暂无静息心率",
            status: latestTimeText(for: .heartRate, in: todayMetrics),
            systemImage: "heart.fill",
            color: AppColors.primaryBlue,
            trendValues: trend,
            source: source
        )
    }

    private func sleepMetric(todayMetrics: [HealthMetric], baseline: Baseline, source: DashboardMetricSource) -> DashboardMetric {
        let sleep = todayMetrics.latestValue(for: .sleep)
        let sleepScore = sleep.map { Int(round(clamp(($0 / safeDenominator(baseline.avgSleepHours)) * 84, 0, 100))) }

        return DashboardMetric(
            id: "sleep",
            title: "Sleep",
            value: sleep.map(formatHours) ?? "暂无",
            unit: "",
            subtitle: sleepScore.map { "Sleep Score \($0)" } ?? "暂无睡眠数据",
            status: sleep.map { $0 >= baseline.avgSleepHours ? "恢复良好" : "偏少" } ?? "暂无数据",
            systemImage: "moon.zzz.fill",
            color: AppColors.softBlue,
            trendValues: dailyLatestValues(for: .sleep, in: recentMetrics),
            source: source
        )
    }

    private func stepsMetric(todayMetrics: [HealthMetric], source: DashboardMetricSource) -> DashboardMetric {
        let steps = todayMetrics.latestValue(for: .steps)
        let value = steps.map { Int(round($0)) }

        return DashboardMetric(
            id: "steps",
            title: "Steps",
            value: value.map { Self.integerFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? "暂无",
            unit: "",
            subtitle: "今日步数",
            status: value.map(stepsStatus) ?? "暂无数据",
            systemImage: "figure.walk",
            color: AppColors.primaryBlue,
            trendValues: dailyLatestValues(for: .steps, in: recentMetrics),
            source: source
        )
    }

    private func activityMetric(todayMetrics: [HealthMetric], source: DashboardMetricSource) -> DashboardMetric {
        let energy = todayMetrics.latestValue(for: .activeEnergyBurned)
        let exercise = todayMetrics.latestValue(for: .appleExerciseTime)
        let stand = todayMetrics.latestValue(for: .appleStandTime)

        return DashboardMetric(
            id: "activity",
            title: "Activity",
            value: energy.map { "\(Int(round($0)))" } ?? "暂无",
            unit: energy == nil ? "" : "kcal",
            subtitle: exercise.map { "Exercise \(Int(round($0))) min · Stand \(Int(round(stand ?? 0))) h" } ?? "暂无运动分钟",
            status: activityStatus(energy: energy, exercise: exercise, stand: stand),
            systemImage: "flame.fill",
            color: AppColors.primaryBlue,
            trendValues: dailyLatestValues(for: .activeEnergyBurned, in: recentMetrics),
            source: source
        )
    }

    private func makeSleepStages(from todayMetrics: [HealthMetric]) -> [SleepStageSummary] {
        [
            SleepStageSummary(id: "rem", title: "REM", hours: todayMetrics.latestValue(for: .sleepREM) ?? 0, color: AppColors.chartPrimary),
            SleepStageSummary(id: "core", title: "Core", hours: todayMetrics.latestValue(for: .sleepCore) ?? 0, color: AppColors.primaryBlue),
            SleepStageSummary(id: "deep", title: "Deep", hours: todayMetrics.latestValue(for: .sleepDeep) ?? 0, color: AppColors.deepSleep),
            SleepStageSummary(id: "awake", title: "Awake", hours: todayMetrics.latestValue(for: .sleepAwake) ?? 0, color: AppColors.chartSecondary)
        ].filter { $0.hours > 0 }
    }

    private func source(for types: [MetricType], appleMetricTypes: Set<MetricType>, metrics: [HealthMetric]) -> DashboardMetricSource {
        if types.contains(where: { appleMetricTypes.contains($0) }) {
            return .appleHealth
        }

        if metrics.contains(where: { types.contains($0.type) }) {
            return .demo
        }

        return .unavailable
    }

    private func stressScoresByDay(
        from metrics: [HealthMetric],
        currentScore: StressScore,
        from startDate: Date,
        to endDate: Date
    ) -> [StressScore] {
        let cachedScores = (try? storage.fetchStressScores(from: startDate, to: endDate)) ?? []

        if cachedScores.count >= 3 {
            return Array(cachedScores.suffix(7))
        }

        return demoStressTrendScores(from: metrics, fallbackScore: currentScore, startDate: startDate)
    }

    private func demoStressTrendScores(
        from metrics: [HealthMetric],
        fallbackScore: StressScore,
        startDate: Date
    ) -> [StressScore] {
        let fallbackValues = [42, 46, 51, 56, 61, 59, fallbackScore.value]

        return fallbackValues.enumerated().map { index, value in
            let date = calendar.date(byAdding: .day, value: index, to: startDate) ?? fallbackScore.date
            return StressScore(
                id: UUID(),
                value: value,
                level: stressLevel(for: value),
                date: date,
                components: fallbackScore.components
            )
        }
    }

    private func dailyLatestValues(for type: MetricType, in metrics: [HealthMetric]) -> [Double] {
        let grouped = Dictionary(grouping: metrics.filter { $0.type == type }) { metric in
            calendar.startOfDay(for: metric.date)
        }

        let values = grouped.keys.sorted().compactMap { day in
            grouped[day]?.max { $0.date < $1.date }?.value
        }

        return Array(values.suffix(7))
    }

    private func latestTimeText(for type: MetricType, in metrics: [HealthMetric]) -> String {
        guard let date = metrics.filter({ $0.type == type }).max(by: { $0.date < $1.date })?.date else {
            return "暂无数据"
        }

        return "最近 \(Self.timeFormatter.string(from: date))"
    }

    private func metricsForDay(_ date: Date, in metrics: [HealthMetric]) -> [HealthMetric] {
        metrics.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func stressStatus(for value: Int) -> String {
        if value < 36 {
            return "状态稳定"
        } else if value < 70 {
            return "轻微压力"
        } else {
            return "注意压力"
        }
    }

    private func stressLevel(for value: Int) -> StressLevel {
        if value <= 33 {
            return .low
        } else if value <= 66 {
            return .medium
        } else {
            return .high
        }
    }

    private func recoveryStatus(for value: Int) -> String {
        if value >= 70 {
            return "恢复良好"
        } else if value >= 45 {
            return "恢复正常"
        } else {
            return "恢复偏低"
        }
    }

    private func stepsStatus(for value: Int) -> String {
        if value >= 8_000 {
            return "活动活跃"
        } else if value >= 4_000 {
            return "轻量活动"
        } else {
            return "活动偏少"
        }
    }

    private func activityStatus(energy: Double?, exercise: Double?, stand: Double?) -> String {
        guard let energy else {
            return "暂无数据"
        }

        if energy >= 500 || (exercise ?? 0) >= 30 || (stand ?? 0) >= 12 {
            return "活动活跃"
        } else if energy >= 250 {
            return "轻量活动"
        } else {
            return "活动偏少"
        }
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
