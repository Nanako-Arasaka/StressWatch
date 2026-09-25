import Foundation

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
