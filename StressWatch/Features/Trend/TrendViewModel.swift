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
    @Published var selectedRange: TrendRange
    @Published var analysis: TrendDashboardAnalysis
    @Published var selectedTrendBar: StressTrendBar?
    @Published var isLoading: Bool

    private let storage: any LocalStorageProtocol
    private let calendar: Calendar
    private let analyzer: any WellnessAnalyzing

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
            let previousStartDate = calendar.date(byAdding: .day, value: -days, to: startDate) ?? startDate
            let previousEndDate = calendar.date(byAdding: .day, value: -1, to: startDate) ?? startDate

            stressHistory = try storage.fetchStressScores(from: startDate, to: endDate)
            previousStressHistory = try storage.fetchStressScores(from: previousStartDate, to: calendar.endOfDay(for: previousEndDate))
            analysis = makeAnalysis(current: stressHistory, previous: previousStressHistory, range: selectedRange)
            selectedTrendBar = analysis.trendBars.last
            print("[TrendViewModel] loadHistory range=\(selectedRange.rawValue) current=\(stressHistory.count) previous=\(previousStressHistory.count)")
        } catch {
            stressHistory = []
            previousStressHistory = []
            analysis = .init()
            selectedTrendBar = nil
            print("[TrendViewModel] loadHistory failed: \(error)")
        }
    }

    private func makeAnalysis(
        current: [StressScore],
        previous: [StressScore],
        range: TrendRange
    ) -> TrendDashboardAnalysis {
        let displayScores = normalizedScores(current, range: range)
        let previousScores = previous.isEmpty
            ? makeReferenceScores(days: max(7, min(range.days, 31)), offset: -range.days)
            : normalizedScores(previous, range: range, offset: -range.days)
        let features = makeWellnessFeatures(from: displayScores)
        let wellnessAnalysis = analyzer.analyze(features: features)

        return TrendDashboardAnalysis(
            distribution: makeDistribution(current: displayScores, previous: previousScores),
            trendBars: makeTrendBars(from: displayScores, range: range),
            heatmapRows: makeHeatmapRows(from: Array(displayScores.suffix(14))),
            recoveryTrend: makeRecoveryTrend(from: displayScores),
            sleepConsistency: makeSleepConsistency(from: displayScores),
            insights: makeInsights(from: displayScores, wellnessAnalysis: wellnessAnalysis),
            wellnessState: wellnessAnalysis.state,
            confidence: wellnessAnalysis.confidence
        )
    }

    private func makeDistribution(
        current: [StressScore],
        previous: [StressScore]
    ) -> [StressDistributionBucket] {
        let total = max(current.count, 1)

        return StressBand.allCases.map { band in
            let count = current.filter { StressBand.band(for: $0.value) == band }.count
            let previousCount = previous.filter { StressBand.band(for: $0.value) == band }.count

            return StressDistributionBucket(
                id: band.rawValue,
                title: band.title,
                count: count,
                percentage: Double(count) / Double(total),
                previousCount: previousCount
            )
        }
    }

    private func makeTrendBars(from scores: [StressScore], range: TrendRange) -> [StressTrendBar] {
        if range == .year {
            let grouped = Dictionary(grouping: scores) { score in
                let components = calendar.dateComponents([.year, .month], from: score.date)
                return calendar.date(from: components) ?? calendar.startOfDay(for: score.date)
            }

            return grouped.keys.sorted().compactMap { monthStart in
                guard let values = grouped[monthStart] else { return nil }
                let average = Int(round(values.map { Double($0.value) }.reduce(0, +) / Double(values.count)))
                return StressTrendBar(date: monthStart, value: average, status: StressBand.band(for: average).title, level: StressBand.band(for: average))
            }
        }

        return scores.map { score in
            let band = StressBand.band(for: score.value)
            return StressTrendBar(date: score.date, value: score.value, status: band.title, level: band)
        }
    }

    private func normalizedScores(_ scores: [StressScore], range: TrendRange, offset: Int = 0) -> [StressScore] {
        let reference = makeReferenceScores(days: range.days, offset: offset)
        guard !scores.isEmpty else {
            return reference
        }

        var mergedByDay = Dictionary(uniqueKeysWithValues: reference.map { (calendar.startOfDay(for: $0.date), $0) })
        for score in scores {
            mergedByDay[calendar.startOfDay(for: score.date)] = score
        }

        let targetStart = reference.first.map { calendar.startOfDay(for: $0.date) } ?? calendar.startOfDay(for: Date())
        let targetEnd = reference.last.map { calendar.endOfDay(for: $0.date) } ?? calendar.endOfDay(for: Date())

        return mergedByDay.values
            .filter { $0.date >= targetStart && $0.date <= targetEnd }
            .sorted { $0.date < $1.date }
    }

    private func makeHeatmapRows(from scores: [StressScore]) -> [StressHeatmapRow] {
        scores.map { score in
            let cells = (0..<24).map { hour in
                let value = estimatedHourlyStress(score: score, hour: hour)
                return StressHeatmapCell(hour: hour, value: value, level: StressBand.band(for: value))
            }

            return StressHeatmapRow(date: score.date, cells: cells)
        }
    }

    private func makeRecoveryTrend(from scores: [StressScore]) -> RecoveryTrendSummary {
        let hrvPoints = scores.map { estimatedHRV($0) }
        let restingHRPoints = scores.map { estimatedRestingHR($0) }
        let baseline = rollingAverage(hrvPoints, window: 7)
        let weekdayScores = scores.filter { !calendar.isDateInWeekend($0.date) }
        let weekendScores = scores.filter { calendar.isDateInWeekend($0.date) }

        return RecoveryTrendSummary(
            hrvPoints: hrvPoints,
            restingHRPoints: restingHRPoints,
            rollingBaseline: baseline,
            weekdayAverageHRV: average(weekdayScores.map { estimatedHRV($0) }),
            weekendAverageHRV: average(weekendScores.map { estimatedHRV($0) }),
            weekdayAverageRestingHR: average(weekdayScores.map { estimatedRestingHR($0) }),
            weekendAverageRestingHR: average(weekendScores.map { estimatedRestingHR($0) })
        )
    }

    private func makeSleepConsistency(from scores: [StressScore]) -> SleepConsistencySummary {
        let sleepDebtAverage = average(scores.map(\.components.sleepDebtFactor))
        let activityAverage = average(scores.map(\.components.activityLoadFactor))
        let variance = Int(round(clamp(sleepDebtAverage * 3.2, 8, 95)))
        let wakeVariance = Int(round(clamp((sleepDebtAverage + activityAverage) * 2.2, 6, 90)))
        let weeklyScore = Int(round(clamp(92 - sleepDebtAverage * 1.8, 40, 96)))

        return SleepConsistencySummary(
            bedtimeVarianceMinutes: variance,
            wakeVarianceMinutes: wakeVariance,
            remPercent: Int(round(clamp(22 - sleepDebtAverage * 0.10, 14, 25))),
            corePercent: 54,
            deepPercent: Int(round(clamp(18 - sleepDebtAverage * 0.08, 10, 22))),
            awakePercent: Int(round(clamp(6 + sleepDebtAverage * 0.12, 4, 14))),
            weeklyScore: weeklyScore
        )
    }

    private func makeInsights(from scores: [StressScore], wellnessAnalysis: WellnessAnalysis) -> [WeeklyInsight] {
        let highHours = mostCommonHighStressWindow(from: scores)
        let hrvTrend = (scores.last.map { estimatedHRV($0) } ?? 0) - (scores.first.map { estimatedHRV($0) } ?? 0)
        let avgSleepDebt = average(scores.map(\.components.sleepDebtFactor))
        let avgActivityLoad = average(scores.map(\.components.activityLoadFactor))

        return [
            WeeklyInsight(
                title: "综合状态",
                detail: "\(wellnessAnalysis.state.displayName)：\(wellnessAnalysis.state.shortSummary)",
                systemImage: "sparkles"
            ),
            WeeklyInsight(
                title: "HRV 变化",
                detail: "估计 HRV 趋势约 \(hrvTrend >= 0 ? "+" : "")\(Int(round(hrvTrend))) ms，仅用于趋势参考。",
                systemImage: "waveform"
            ),
            WeeklyInsight(
                title: "睡眠稳定性",
                detail: avgSleepDebt > 12 ? "睡眠负债因子可能偏高，建议关注连续作息。" : "睡眠相关趋势较平稳，可继续观察。",
                systemImage: "moon.zzz"
            ),
            WeeklyInsight(
                title: "压力高峰时段",
                detail: "近期压力估计高峰多出现在 \(highHours)，可作为安排休息的参考。",
                systemImage: "clock"
            ),
            WeeklyInsight(
                title: "活动提示",
                detail: avgActivityLoad < 8 ? "活动负荷可能偏低，可以尝试轻量步行。" : "活动负荷有一定波动，建议结合恢复趋势调整强度。",
                systemImage: "figure.walk"
            )
        ]
    }

    private func makeWellnessFeatures(from scores: [StressScore]) -> WellnessFeatures {
        let hrv = scores.map { estimatedHRV($0) }
        let restingHR = scores.map { estimatedRestingHR($0) }
        let sleep = scores.map { clamp(8.0 - $0.components.sleepDebtFactor / 8.0, 4.5, 8.8) }
        let stressAverage = average(scores.map { Double($0.value) })
        let recoveryAverage = clamp(100 - stressAverage * 0.72, 15, 92)

        return WellnessFeatures(
            avgHRV: average(hrv),
            hrvTrend: (hrv.last ?? 0) - (hrv.first ?? 0),
            avgHeartRate: nil,
            avgRestingHR: average(restingHR),
            sleepAverage: average(sleep),
            sleepConsistency: clamp(1 - average(scores.map(\.components.sleepDebtFactor)) / 35, 0, 1),
            remSleepAverage: nil,
            coreSleepAverage: nil,
            deepSleepAverage: nil,
            awakeAverage: nil,
            stepsAverage: nil,
            activeEnergyAverage: nil,
            exerciseMinutesAverage: nil,
            standHoursAverage: nil,
            activityLevel: clamp(average(scores.map(\.components.activityLoadFactor)) / 25, 0, 1),
            recoveryAverage: recoveryAverage,
            stressAverage: stressAverage,
            availableFeatureCount: scores.isEmpty ? 0 : 7,
            dataConfidence: scores.isEmpty ? 0.25 : clamp(Double(scores.count) / 14, 0.35, 0.92)
        )
    }

    private func estimatedHourlyStress(score: StressScore, hour: Int) -> Int {
        let workdayLoad: Double
        switch hour {
        case 0..<6: workdayLoad = -18
        case 6..<9: workdayLoad = -6
        case 9..<12: workdayLoad = 8
        case 12..<15: workdayLoad = 14
        case 15..<19: workdayLoad = 10
        case 19..<22: workdayLoad = -2
        default: workdayLoad = -10
        }

        let componentPressure = score.components.hrDeviationFactor * 0.35
            + score.components.inverseHRVFactor * 0.42
            + score.components.sleepDebtFactor * 0.30
            + score.components.activityLoadFactor * 0.18
        let value = Double(score.value) * 0.62 + componentPressure + workdayLoad
        return Int(round(clamp(value, 8, 96)))
    }

    private func estimatedHRV(_ score: StressScore) -> Double {
        clamp(74 - score.components.inverseHRVFactor * 1.25 - Double(score.value) * 0.16, 18, 92)
    }

    private func estimatedRestingHR(_ score: StressScore) -> Double {
        clamp(58 + score.components.hrDeviationFactor * 0.88 + Double(score.value) * 0.10, 52, 92)
    }

    private func mostCommonHighStressWindow(from scores: [StressScore]) -> String {
        let buckets = [(0, 6), (6, 9), (9, 12), (12, 15), (15, 18), (18, 21), (21, 24)]
        let best = buckets.max { lhs, rhs in
            let lhsAverage = average(scores.flatMap { score in
                (lhs.0..<lhs.1).map { Double(estimatedHourlyStress(score: score, hour: $0)) }
            })
            let rhsAverage = average(scores.flatMap { score in
                (rhs.0..<rhs.1).map { Double(estimatedHourlyStress(score: score, hour: $0)) }
            })
            return lhsAverage < rhsAverage
        } ?? (12, 15)

        return "\(best.0)-\(best.1) 时"
    }

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

    private func makeReferenceScores(days: Int, offset: Int = 0) -> [StressScore] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).map { index in
            let date = calendar.date(byAdding: .day, value: offset - (days - index - 1), to: today) ?? today
            let value = Int(round(52 + sin(Double(index) * 0.72) * 14 + Double(index % 5) * 2))
            return StressScore(
                id: UUID(),
                value: max(18, min(86, value)),
                level: value < 36 ? .low : (value < 67 ? .medium : .high),
                date: date,
                components: StressComponents(
                    hrDeviationFactor: Double(max(0, value - 42)) * 0.22,
                    inverseHRVFactor: Double(max(0, value - 35)) * 0.28,
                    activityLoadFactor: Double((index * 7) % 18),
                    sleepDebtFactor: Double(max(0, value - 48)) * 0.20
                )
            )
        }
    }
}
