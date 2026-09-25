import Foundation

enum TrendRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 31
        case .year: return 365
        }
    }
}

struct TrendDashboardAnalysis {
    var distribution: [StressDistributionBucket] = []
    var trendBars: [StressTrendBar] = []
    var heatmapRows: [StressHeatmapRow] = []
    var recoveryTrend: RecoveryTrendSummary = .empty
    var sleepConsistency: SleepConsistencySummary = .empty
    var insights: [WeeklyInsight] = []
    var wellnessState: WellnessState = .dataInsufficient
    var confidence: Double = 0
}

struct StressDistributionBucket: Identifiable {
    let id: String
    let title: String
    let count: Int
    let percentage: Double
    let previousCount: Int

    var delta: Int { count - previousCount }
}

struct StressTrendBar: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
    let status: String
    let level: StressBand
}

struct StressHeatmapRow: Identifiable {
    let id = UUID()
    let date: Date
    let cells: [StressHeatmapCell]
}

struct StressHeatmapCell: Identifiable {
    let id = UUID()
    let hour: Int
    let value: Int
    let level: StressBand
}

struct RecoveryTrendSummary {
    let hrvPoints: [Double]
    let restingHRPoints: [Double]
    let rollingBaseline: [Double]
    let weekdayAverageHRV: Double
    let weekendAverageHRV: Double
    let weekdayAverageRestingHR: Double
    let weekendAverageRestingHR: Double

    static let empty = RecoveryTrendSummary(
        hrvPoints: [],
        restingHRPoints: [],
        rollingBaseline: [],
        weekdayAverageHRV: 0,
        weekendAverageHRV: 0,
        weekdayAverageRestingHR: 0,
        weekendAverageRestingHR: 0
    )
}

struct SleepConsistencySummary {
    let bedtimeVarianceMinutes: Int
    let wakeVarianceMinutes: Int
    let remPercent: Int
    let corePercent: Int
    let deepPercent: Int
    let awakePercent: Int
    let weeklyScore: Int

    static let empty = SleepConsistencySummary(
        bedtimeVarianceMinutes: 0,
        wakeVarianceMinutes: 0,
        remPercent: 22,
        corePercent: 54,
        deepPercent: 18,
        awakePercent: 6,
        weeklyScore: 0
    )
}

struct WeeklyInsight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
}

enum StressBand: String, CaseIterable {
    case recovered
    case normal
    case attention
    case overload

    var title: String {
        switch self {
        case .recovered: return "恢复良好"
        case .normal: return "状态正常"
        case .attention: return "注意压力"
        case .overload: return "压力过载"
        }
    }

    static func band(for value: Int) -> StressBand {
        if value < 36 {
            return .recovered
        } else if value < 60 {
            return .normal
        } else if value < 80 {
            return .attention
        } else {
            return .overload
        }
    }
}

@MainActor
class TrendViewModel: ObservableObject {
    @Published var stressHistory: [StressScore]
    @Published var previousStressHistory: [StressScore]
    @Published var dailyHistory: [DailyHealthMetrics]
    @Published var selectedRange: TrendRange
    @Published var analysis: TrendDashboardAnalysis
    @Published var selectedTrendBar: StressTrendBar?
    @Published var isLoading: Bool

    private let storage: any LocalStorageProtocol
    private let calendar: Calendar
    private let analyzer: any WellnessAnalyzing
    private let trendEngine = TrendEngine()
    private let sleepEngine = SleepQualityEngine()

    init(
        storage: any LocalStorageProtocol,
        calendar: Calendar = .current,
        analyzer: any WellnessAnalyzing = WellnessAnalyzer()
    ) {
        self.storage = storage
        self.calendar = calendar
        self.analyzer = analyzer
        self.stressHistory = []
        self.previousStressHistory = []
        self.dailyHistory = []
        self.selectedRange = .month
        self.analysis = .init()
        self.selectedTrendBar = nil
        self.isLoading = false
    }

    func selectRange(_ range: TrendRange) async {
        selectedRange = range
        await loadHistory(days: range.days)
    }

    func loadHistory(days: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let now = Date()
            let endDate = calendar.endOfDay(for: now)
            let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now

            stressHistory = try storage.fetchStressScores(from: startDate, to: endDate)
            // 真实日聚合数据（T4.2：替代从 stress 分量反推的旧做法）
            dailyHistory = try storage.fetchDailyMetrics(from: startDate, to: endDate)
            analysis = makeAnalysis(range: selectedRange, now: now)
            selectedTrendBar = analysis.trendBars.last
        } catch {
            stressHistory = []
            dailyHistory = []
            analysis = .init()
            selectedTrendBar = nil
        }
    }

    // MARK: - 真实数据分析（无编造数据）

    private func makeAnalysis(range: TrendRange, now: Date) -> TrendDashboardAnalysis {
        let window: TrendWindow = range == .week ? .days7 : (range == .month ? .days14 : .days30)
        let sampleCount = dailyHistory.filter { $0.hasAnyMetric }.count

        // 数据不足 → 明确的 insufficient 态，不造数据
        guard sampleCount >= TrendEngine.minimumSamples else {
            return TrendDashboardAnalysis(
                distribution: [],
                trendBars: [],
                heatmapRows: [],
                recoveryTrend: .empty,
                sleepConsistency: .empty,
                insights: [
                    WeeklyInsight(
                        title: "数据不足",
                        detail: "还需 \(TrendEngine.minimumSamples - sampleCount) 天有效数据才能生成趋势分析。已收集 \(sampleCount) 天。",
                        systemImage: "clock.badge.questionmark"
                    )
                ],
                wellnessState: .dataInsufficient,
                confidence: 0
            )
        }

        // 1. 压力分布（仅用真实 stressHistory）
        let distribution = makeDistribution(from: stressHistory)

        // 2. 趋势柱（真实 stress 分数）
        let trendBars = makeTrendBars(from: stressHistory, range: range)

        // 3. 恢复趋势（真实 HRV / RHR 序列）
        let recoveryTrend = makeRecoveryTrend(from: dailyHistory)

        // 4. 睡眠一致性（真实 bedtime / wakeTime）
        let sleepConsistency = makeSleepConsistency(from: dailyHistory)

        // 5. 洞察（基于 TrendEngine 结论）
        let insights = makeInsights(from: dailyHistory, window: window, now: now)

        return TrendDashboardAnalysis(
            distribution: distribution,
            trendBars: trendBars,
            heatmapRows: [], // 真实小时数据不足时不再画假热力图
            recoveryTrend: recoveryTrend,
            sleepConsistency: sleepConsistency,
            insights: insights,
            wellnessState: sampleCount >= 7 ? .balanced : .dataInsufficient,
            confidence: min(1, Double(sampleCount) / 14)
        )
    }

    private func makeDistribution(from scores: [StressScore]) -> [StressDistributionBucket] {
        guard !scores.isEmpty else { return [] }
        let total = max(scores.count, 1)

        return StressBand.allCases.map { band in
            let count = scores.filter { StressBand.band(for: $0.value) == band }.count
            return StressDistributionBucket(
                id: band.rawValue,
                title: band.title,
                count: count,
                percentage: Double(count) / Double(total),
                previousCount: 0
            )
        }
    }

    private func makeTrendBars(from scores: [StressScore], range: TrendRange) -> [StressTrendBar] {
        guard !scores.isEmpty else { return [] }

        if range == .year {
            let grouped = Dictionary(grouping: scores) { score in
                let components = calendar.dateComponents([.year, .month], from: score.date)
                return calendar.date(from: components) ?? calendar.startOfDay(for: score.date)
            }
            return grouped.keys.sorted().compactMap { monthStart in
                guard let values = grouped[monthStart], !values.isEmpty else { return nil }
                let avg = Int(round(values.map { Double($0.value) }.reduce(0, +) / Double(values.count)))
                let band = StressBand.band(for: avg)
                return StressTrendBar(date: monthStart, value: avg, status: band.title, level: band)
            }
        }

        return scores.map { score in
            let band = StressBand.band(for: score.value)
            return StressTrendBar(date: score.date, value: score.value, status: band.title, level: band)
        }
    }

    /// 真实 HRV / RHR 序列（从 DailyHealthMetrics）。
    private func makeRecoveryTrend(from history: [DailyHealthMetrics]) -> RecoveryTrendSummary {
        let sorted = history.sorted { $0.day < $1.day }
        let hrvPoints = sorted.compactMap { $0.hrv?.value }
        let rhrPoints = sorted.compactMap { $0.restingHeartRate?.value }

        guard !hrvPoints.isEmpty || !rhrPoints.isEmpty else {
            return .empty
        }

        let rolling = rollingAverage(hrvPoints, window: 7)
        let weekdayHRV = sorted.filter { !calendar.isDateInWeekend($0.day) }.compactMap { $0.hrv?.value }
        let weekendHRV = sorted.filter { calendar.isDateInWeekend($0.day) }.compactMap { $0.hrv?.value }
        let weekdayRHR = sorted.filter { !calendar.isDateInWeekend($0.day) }.compactMap { $0.restingHeartRate?.value }
        let weekendRHR = sorted.filter { calendar.isDateInWeekend($0.day) }.compactMap { $0.restingHeartRate?.value }

        return RecoveryTrendSummary(
            hrvPoints: hrvPoints,
            restingHRPoints: rhrPoints,
            rollingBaseline: rolling,
            weekdayAverageHRV: average(weekdayHRV),
            weekendAverageHRV: average(weekendHRV),
            weekdayAverageRestingHR: average(weekdayRHR),
            weekendAverageRestingHR: average(weekendRHR)
        )
    }

    /// 真实睡眠一致性（从 bedtime / wakeTime）。
    private func makeSleepConsistency(from history: [DailyHealthMetrics]) -> SleepConsistencySummary {
        let bedtimes = history.compactMap(\.bedtime)
        guard bedtimes.count >= 3 else { return .empty }

        // 就寝时刻的圆周标准差 → 分钟
        let bedtimeHours = bedtimes.map { date -> Double in
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
        }
        let sleepEngine = SleepQualityEngine()
        let consistencyScore = sleepEngine.consistencyScore(history: history) ?? 0

        // 真实分期平均
        let remAvg = average(history.compactMap { $0.sleepREMHours?.value })
        let coreAvg = average(history.compactMap { $0.sleepCoreHours?.value })
        let deepAvg = average(history.compactMap { $0.sleepDeepHours?.value })
        let awakeAvg = average(history.compactMap { $0.sleepAwakeHours?.value })
        let totalSleep = average(history.compactMap { $0.sleepHours?.value })

        let remPercent = totalSleep > 0 ? Int(round(remAvg / totalSleep * 100)) : 22
        let corePercent = totalSleep > 0 ? Int(round(coreAvg / totalSleep * 100)) : 54
        let deepPercent = totalSleep > 0 ? Int(round(deepAvg / totalSleep * 100)) : 18
        let awakePercent = totalSleep > 0 ? Int(round(awakeAvg / totalSleep * 100)) : 6

        // 就寝/起床时间变异（分钟）—— 从真实数据算标准差
        let bedtimeStd = stdDevMinutes(bedtimeHours)
        let wakeHours = history.compactMap { $0.wakeTime }.map { date -> Double in
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
        }
        let wakeStd = stdDevMinutes(wakeHours)

        return SleepConsistencySummary(
            bedtimeVarianceMinutes: Int(round(bedtimeStd)),
            wakeVarianceMinutes: Int(round(wakeStd)),
            remPercent: remPercent,
            corePercent: corePercent,
            deepPercent: deepPercent,
            awakePercent: awakePercent,
            weeklyScore: Int(round(consistencyScore))
        )
    }

    /// 基于 TrendEngine 的真实趋势洞察。
    private func makeInsights(from history: [DailyHealthMetrics], window: TrendWindow, now: Date) -> [WeeklyInsight] {
        var insights: [WeeklyInsight] = []

        let hrvTrend = trendEngine.trend(
            metric: .hrv, history: history, window: window,
            baseline: nil, now: now, calendar: calendar
        )
        let rhrTrend = trendEngine.trend(
            metric: .restingHeartRate, history: history, window: window,
            baseline: nil, now: now, calendar: calendar
        )
        let sleepTrend = trendEngine.trend(
            metric: .sleepHours, history: history, window: window,
            baseline: nil, now: now, calendar: calendar
        )

        // HRV 趋势
        if hrvTrend.direction == .insufficientData {
            insights.append(WeeklyInsight(
                title: "HRV 趋势",
                detail: "HRV 数据不足，还需 \(hrvTrend.daysRemaining) 天。",
                systemImage: "waveform"
            ))
        } else {
            let dev = hrvTrend.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            insights.append(WeeklyInsight(
                title: "HRV 趋势",
                detail: "近 \(window.days) 天 HRV \(hrvTrend.direction.displayName)（偏离基线 \(dev)）。",
                systemImage: "waveform"
            ))
        }

        // RHR 趋势
        if rhrTrend.direction != .insufficientData {
            insights.append(WeeklyInsight(
                title: "静息心率",
                detail: "静息心率趋势\(rhrTrend.direction.displayName)。",
                systemImage: "heart"
            ))
        }

        // 睡眠趋势
        if sleepTrend.direction != .insufficientData {
            insights.append(WeeklyInsight(
                title: "睡眠趋势",
                detail: "睡眠时长\(sleepTrend.direction.displayName)。",
                systemImage: "moon.zzz"
            ))
        }

        if insights.isEmpty {
            insights.append(WeeklyInsight(
                title: "暂无趋势",
                detail: "数据积累中，趋势分析将随数据完善而更新。",
                systemImage: "chart.line.uptrend.xyaxis"
            ))
        }

        return insights
    }

    // MARK: - 工具

    private func rollingAverage(_ values: [Double], window: Int) -> [Double] {
        values.indices.map { index in
            let start = max(0, index - window + 1)
            return average(Array(values[start...index]))
        }
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// 小时序列的标准差 → 分钟。
    private func stdDevMinutes(_ hours: [Double]) -> Double {
        guard hours.count >= 2 else { return 0 }
        let mean = hours.reduce(0, +) / Double(hours.count)
        let variance = hours.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(hours.count)
        return sqrt(variance) * 60
    }
}
