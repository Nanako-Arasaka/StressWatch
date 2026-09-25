import Foundation

// MARK: - MetricDeviation

/// 单指标的偏离 + 趋势（用户要求的 JSON 形状）。
struct MetricDeviation: Codable, Identifiable {
    let metric: BaselineMetric
    let value: Double?
    let unit: String
    let baseline: Double?
    let deviationPercent: Double?
    let trend: TrendDirection
    let provenance: MetricProvenance

    var id: String { metric.rawValue }
}

// MARK: - SleepQualityAnalysis

/// 睡眠质量分析结论。
struct SleepQualityAnalysis: Codable {
    let durationHours: Double?
    let baselineHours: Double?
    let deviationPercent: Double?
    let qualityLabel: String
    let remPercent: Double?
    let deepPercent: Double?
}

// MARK: - ActivityLevel

/// 活动水平分级。
enum ActivityLevel: String, Codable {
    case sedentary
    case low
    case moderate
    case high
    case veryHigh

    var displayName: String {
        switch self {
        case .sedentary: return "久坐"
        case .low: return "偏低"
        case .moderate: return "适中"
        case .high: return "较高"
        case .veryHigh: return "很高"
        }
    }
}

// MARK: - StructuredAnalysisResult

/// 一次完整分析的结构化结果 —— LLM 的唯一输入。
///
/// **关键**：LLM 只负责解读，不负责计算。所有数值在这里已经算完。
/// 对应用户需求的 JSON 形状：
/// ```
/// {
///   "stressScore": 64,
///   "recoveryScore": 71,
///   "hrv": { "value": 42, "baseline": 51, "deviationPercent": -17.6, "trend": "declining" },
///   "confidence": 0.86,
///   "dataCompleteness": 0.92
/// }
/// ```
struct StructuredAnalysisResult: Codable {
    let generatedAt: Date
    let dataSource: AppDataSource
    let baselineWindowDays: Int

    // 分数
    let stressScore: Int?
    let stressLevel: StressLevel?
    let recoveryScore: Int?
    let recoveryLevel: RecoveryLevel?

    // 各指标偏离
    let metrics: [MetricDeviation]
    let sleepQuality: SleepQualityAnalysis?
    let activityLevel: ActivityLevel

    // 趋势
    let trends: [MetricTrend]

    // 相关性
    let associations: [ObservedAssociation]

    // 数据质量
    let confidence: AnalysisConfidence
    let completeness: DataCompleteness
    let warnings: [String]

    // MARK: - 便捷访问

    func deviation(for metric: BaselineMetric) -> MetricDeviation? {
        metrics.first { $0.metric == metric }
    }

    var hrvDeviation: MetricDeviation? { deviation(for: .hrv) }
    var rhrDeviation: MetricDeviation? { deviation(for: .restingHeartRate) }
    var sleepDeviation: MetricDeviation? { deviation(for: .sleepHours) }

    /// 生成 LLM 可读的紧凑摘要（WorkoutTracker `buildStatsContext` 思路）。
    var compactSummary: String {
        var lines: [String] = []

        if let s = stressScore {
            lines.append("Stress: \(s)")
        }
        if let r = recoveryScore {
            lines.append("Recovery: \(r)")
        }

        if let hrv = hrvDeviation, let v = hrv.value {
            let baseline = hrv.baseline.map { String(format: "%.0f", $0) } ?? "—"
            let dev = hrv.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("HRV: \(String(format: "%.0f", v)) ms (baseline \(baseline), \(dev), trend \(hrv.trend.rawValue))")
        }

        if let rhr = rhrDeviation, let v = rhr.value {
            let baseline = rhr.baseline.map { String(format: "%.0f", $0) } ?? "—"
            let dev = rhr.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("RHR: \(String(format: "%.0f", v)) bpm (baseline \(baseline), \(dev))")
        }

        if let sleep = sleepDeviation, let v = sleep.value {
            let baseline = sleep.baseline.map { String(format: "%.1f", $0) } ?? "—"
            let dev = sleep.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("Sleep: \(String(format: "%.1f", v)) h (baseline \(baseline), \(dev))")
        }

        lines.append("Activity: \(activityLevel.displayName)")
        lines.append("Confidence: \(confidence.displayName)")
        lines.append("Data completeness: \(String(format: "%.0f%%", completeness.overallCompleteness * 100))")

        if let missing = completeness.missingSummary {
            lines.append("Missing: \(missing)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - AnalysisInsightBuilder

/// 编排层：调 L2/L3/L4/L5，组装 `StructuredAnalysisResult`。纯函数。
protocol StructuredAnalysisBuilding {
    func build(
        today: DailyHealthMetrics?,
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet,
        windowDays: Int,
        now: Date
    ) -> StructuredAnalysisResult
}

struct AnalysisInsightBuilder: StructuredAnalysisBuilding {

    private let stressEngine = PersonalStressEngine()
    private let recoveryEngine = PersonalRecoveryEngine()
    private let trendEngine = TrendEngine()
    private let correlationEngine = CorrelationEngine()

    func build(
        today: DailyHealthMetrics?,
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet,
        windowDays: Int,
        now: Date
    ) -> StructuredAnalysisResult {
        // 1. 分数
        let stress = stressEngine.compute(today: today, history: history, baselines: baselines)
        let recovery = recoveryEngine.compute(today: today, history: history, baselines: baselines)

        // 2. 各指标偏离
        let metrics = buildMetricDeviations(today: today, baselines: baselines)

        // 3. 睡眠质量
        let sleepQuality = buildSleepQuality(today: today, baselines: baselines)

        // 4. 活动水平
        let activityLevel = buildActivityLevel(today: today, baselines: baselines)

        // 5. 趋势（近 7/14/30 天）
        let trends = buildTrends(history: history, baselines: baselines, now: now)

        // 6. 相关性
        let associations = correlationEngine.analyze(
            pairs: CorrelationPair.defaultPairs,
            history: history
        )

        // 7. 数据质量
        let completeness = DataCompleteness(today: today, historyDays: history.count)
        let confidence: AnalysisConfidence
        if stress.score == nil && recovery.score == nil {
            confidence = .insufficient
        } else {
            confidence = max(stress.confidence, recovery.confidence)
        }

        var warnings = stress.warnings
        warnings.append(contentsOf: recovery.warnings)

        return StructuredAnalysisResult(
            generatedAt: now,
            dataSource: today?.dataSource ?? .appleHealth,
            baselineWindowDays: windowDays,
            stressScore: stress.score,
            stressLevel: stress.level,
            recoveryScore: recovery.score,
            recoveryLevel: recovery.level,
            metrics: metrics,
            sleepQuality: sleepQuality,
            activityLevel: activityLevel,
            trends: trends,
            associations: associations,
            confidence: confidence,
            completeness: completeness,
            warnings: warnings
        )
    }

    // MARK: - Private

    private func buildMetricDeviations(
        today: DailyHealthMetrics?,
        baselines: PersonalBaselineSet
    ) -> [MetricDeviation] {
        func deviation(
            _ metric: BaselineMetric,
            value: Double?,
            baseline: PersonalBaseline,
            unit: String
        ) -> MetricDeviation {
            let dev = value.flatMap { baseline.deviationPercent(of: $0) }
            let provenance: MetricProvenance = today?.dataSource == .demo ? .demo : .measured
            return MetricDeviation(
                metric: metric,
                value: value,
                unit: unit,
                baseline: baseline.sampleDays > 0 ? baseline.value : nil,
                deviationPercent: dev,
                trend: .stable, // TrendEngine 的结论在 trends 数组里
                provenance: value != nil ? provenance : .estimated
            )
        }

        return [
            deviation(.hrv, value: today?.hrv?.value, baseline: baselines.hrv, unit: "ms"),
            deviation(.restingHeartRate, value: today?.restingHeartRate?.value, baseline: baselines.restingHeartRate, unit: "bpm"),
            deviation(.sleepHours, value: today?.sleepHours?.value, baseline: baselines.sleepHours, unit: "hours"),
            deviation(.steps, value: today?.steps?.value, baseline: baselines.steps, unit: "steps")
        ]
    }

    private func buildSleepQuality(
        today: DailyHealthMetrics?,
        baselines: PersonalBaselineSet
    ) -> SleepQualityAnalysis? {
        guard let hours = today?.sleepHours?.value else { return nil }

        let baselineHours = baselines.sleepHours.sampleDays > 0 ? baselines.sleepHours.value : 7.5
        let dev = (hours - baselineHours) / baselineHours * 100

        let qualityLabel: String
        if dev > 10 { qualityLabel = "aboveBaseline" }
        else if dev > -10 { qualityLabel = "atBaseline" }
        else { qualityLabel = "belowBaseline" }

        let total = hours
        let rem = today?.sleepREMHours?.value
        let deep = today?.sleepDeepHours?.value

        return SleepQualityAnalysis(
            durationHours: hours,
            baselineHours: baselineHours,
            deviationPercent: dev,
            qualityLabel: qualityLabel,
            remPercent: rem.map { total > 0 ? $0 / total * 100 : 0 },
            deepPercent: deep.map { total > 0 ? $0 / total * 100 : 0 }
        )
    }

    private func buildActivityLevel(
        today: DailyHealthMetrics?,
        baselines: PersonalBaselineSet
    ) -> ActivityLevel {
        guard let steps = today?.steps?.value else { return .sedentary }
        let baseline = baselines.steps.sampleDays > 0 ? baselines.steps.value : 8000
        let ratio = baseline > 0 ? steps / baseline : 0

        switch ratio {
        case ..<0.3: return .sedentary
        case ..<0.6: return .low
        case ..<1.2: return .moderate
        case ..<1.8: return .high
        default: return .veryHigh
        }
    }

    private func buildTrends(
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet,
        now: Date
    ) -> [MetricTrend] {
        let calendar = Calendar.current
        let windows: [TrendWindow] = [.days7, .days14]
        let metrics: [BaselineMetric] = [.hrv, .restingHeartRate, .sleepHours]

        return windows.flatMap { window in
            metrics.map { metric in
                let baseline: PersonalBaseline?
                switch metric {
                case .hrv: baseline = baselines.hrv
                case .restingHeartRate: baseline = baselines.restingHeartRate
                case .sleepHours: baseline = baselines.sleepHours
                default: baseline = nil
                }
                return trendEngine.trend(
                    metric: metric, history: history, window: window,
                    baseline: baseline, now: now, calendar: calendar
                )
            }
        }
    }
}
