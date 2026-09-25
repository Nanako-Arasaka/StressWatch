import XCTest
@testable import StressWatch

final class AnalysisInsightBuilderTests: XCTestCase {

    private let builder = AnalysisInsightBuilder()
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - JSON 形状（逐字段）

    func test_outputContainsRequiredFields() {
        let (today, history, baselines) = makeScenario()
        let result = builder.build(today: today, history: history, baselines: baselines, windowDays: 14, now: now)

        // 分数
        XCTAssertNotNil(result.stressScore)
        XCTAssertNotNil(result.recoveryScore)

        // 指标
        XCTAssertNotNil(result.hrvDeviation)
        XCTAssertNotNil(result.rhrDeviation)
        XCTAssertNotNil(result.sleepDeviation)

        // HRV 形状
        if let hrv = result.hrvDeviation {
            XCTAssertNotNil(hrv.value)
            XCTAssertNotNil(hrv.baseline)
            // deviationPercent 可能为 nil（baseline 不可靠时）
        }

        // 数据质量
        XCTAssertNotEqual(result.confidence, .insufficient)
        XCTAssertGreaterThan(result.completeness.overallCompleteness, 0)
    }

    func test_compactSummary_containsKeyNumbers() {
        let (today, history, baselines) = makeScenario()
        let result = builder.build(today: today, history: history, baselines: baselines, windowDays: 14, now: now)
        let summary = result.compactSummary

        XCTAssertTrue(summary.contains("Stress"))
        XCTAssertTrue(summary.contains("Recovery"))
        XCTAssertTrue(summary.contains("HRV"))
        XCTAssertTrue(summary.contains("Confidence"))
        XCTAssertTrue(summary.contains("Data completeness"))
    }

    // MARK: - 数据不足

    func test_emptyData_insufficientConfidence() {
        let result = builder.build(today: nil, history: [], baselines: makeBaselines(hrvDays: 0), windowDays: 14, now: now)
        XCTAssertEqual(result.confidence, .insufficient)
        XCTAssertNil(result.stressScore)
        XCTAssertNil(result.recoveryScore)
    }

    func test_missingMetrics_listedInCompleteness() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = 50
        b.restingHR = nil
        b.sleepHours = nil
        let today = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let result = builder.build(today: today, history: [today], baselines: makeBaselines(), windowDays: 14, now: now)
        XCTAssertTrue(result.completeness.missingMetrics.contains(.restingHeartRate))
        XCTAssertTrue(result.completeness.missingMetrics.contains(.sleepHours))
    }

    // MARK: - trends 数组

    func test_trends_includeMultipleWindows() {
        let (_, history, baselines) = makeScenario()
        let result = builder.build(today: nil, history: history, baselines: baselines, windowDays: 14, now: now)
        // 至少有 7 天和 14 天窗口的 HRV/RHR/Sleep 趋势
        XCTAssertGreaterThanOrEqual(result.trends.count, 6)
    }

    // MARK: - associations

    func test_associations_fromDefaultPairs() {
        let (_, history, baselines) = makeScenario()
        let result = builder.build(today: nil, history: history, baselines: baselines, windowDays: 14, now: now)
        XCTAssertEqual(result.associations.count, CorrelationPair.defaultPairs.count)
    }

    // MARK: - Helpers

    private func makeScenario() -> (DailyHealthMetrics?, [DailyHealthMetrics], PersonalBaselineSet) {
        let history = TestCalendar.recentDays(15).enumerated().map { i, date in
            var b = DailyHealthMetricsFixture.Blueprint()
            b.hrv = 45 + Double(i) * 0.5
            b.restingHR = 62 - Double(i) * 0.2
            b.sleepHours = 7 + sin(Double(i) * 0.5) * 0.5
            return DailyHealthMetricsFixture.day(date, b)
        }
        let today = history.last
        return (today, history, makeBaselines())
    }

    private func makeBaselines(hrvDays: Int = 10) -> PersonalBaselineSet {
        func make(_ metric: BaselineMetric, _ value: Double, _ disp: Double, _ days: Int, _ req: Int) -> PersonalBaseline {
            PersonalBaseline(
                metric: metric, windowDays: 14, value: value,
                dispersion: disp, sampleDays: days, requiredDays: req,
                computedAt: now, method: metric == .hrv ? .logEWMA : .median
            )
        }
        return PersonalBaselineSet(
            hrv: make(.hrv, 50, 10, hrvDays, 7),
            restingHeartRate: make(.restingHeartRate, 60, 5, 10, 5),
            sleepHours: make(.sleepHours, 7.5, 1, 10, 5),
            steps: make(.steps, 8000, 1000, 10, 5),
            activeEnergyKcal: make(.activeEnergyKcal, 450, 50, 10, 5),
            exerciseMinutes: make(.exerciseMinutes, 30, 10, 10, 5),
            standHours: make(.standHours, 11, 2, 10, 5)
        )
    }
}

final class LocalInsightComposerTests: XCTestCase {

    private let builder = AnalysisInsightBuilder()
    private var now: Date { TestCalendar.referenceNow }

    func test_compose_producesNonEmptySections() {
        let (today, history, baselines) = makeScenario()
        let result = builder.build(today: today, history: history, baselines: baselines, windowDays: 14, now: now)
        let insight = LocalInsightComposer.compose(result)

        XCTAssertFalse(insight.summary.isEmpty)
        XCTAssertFalse(insight.keyChanges.isEmpty)
        XCTAssertFalse(insight.possibleFactors.isEmpty)
        XCTAssertFalse(insight.trendsSummary.isEmpty)
        XCTAssertFalse(insight.confidenceNote.isEmpty)
        XCTAssertTrue(insight.disclaimer.contains("不提供医疗诊断"))
    }

    func test_compose_insufficientData_hasClearMessage() {
        let result = builder.build(today: nil, history: [], baselines: makeWeakBaselines(), windowDays: 14, now: now)
        let insight = LocalInsightComposer.compose(result)

        XCTAssertTrue(insight.summary.contains("数据不足") || insight.summary.contains("积累"))
    }

    func test_compose_missingMetrics_confidenceNoteMentionsThem() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = 50
        b.restingHR = nil
        b.sleepHours = nil
        b.steps = nil
        b.activeEnergy = nil
        b.exerciseMinutes = nil
        let today = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let result = builder.build(today: today, history: [today], baselines: makeBaselines(), windowDays: 14, now: now)
        let insight = LocalInsightComposer.compose(result)

        XCTAssertTrue(insight.confidenceNote.contains("未纳入") || insight.confidenceNote.contains("缺失"))
    }

    func test_compose_noCausalWords() {
        let (today, history, baselines) = makeScenario()
        let result = builder.build(today: today, history: history, baselines: baselines, windowDays: 14, now: now)
        let insight = LocalInsightComposer.compose(result)

        let banned = ["导致", "因为", "证明", "引起", "造成", "causes", "because"]
        for text in [insight.summary, insight.confidenceNote] + insight.keyChanges + insight.possibleFactors + insight.trendsSummary {
            for word in banned {
                XCTAssertFalse(text.contains(word), "洞察文本不应包含因果词: \(word)")
            }
        }
    }

    // MARK: - Helpers

    private func makeScenario() -> (DailyHealthMetrics?, [DailyHealthMetrics], PersonalBaselineSet) {
        let history = TestCalendar.recentDays(15).enumerated().map { i, date in
            var b = DailyHealthMetricsFixture.Blueprint()
            b.hrv = 45 + Double(i) * 0.5
            b.restingHR = 62 - Double(i) * 0.2
            b.sleepHours = 7 + sin(Double(i) * 0.5) * 0.5
            return DailyHealthMetricsFixture.day(date, b)
        }
        return (history.last, history, makeBaselines())
    }

    private func makeBaselines() -> PersonalBaselineSet {
        func make(_ metric: BaselineMetric, _ value: Double, _ disp: Double, _ days: Int, _ req: Int) -> PersonalBaseline {
            PersonalBaseline(
                metric: metric, windowDays: 14, value: value,
                dispersion: disp, sampleDays: days, requiredDays: req,
                computedAt: now, method: metric == .hrv ? .logEWMA : .median
            )
        }
        return PersonalBaselineSet(
            hrv: make(.hrv, 50, 10, 10, 7),
            restingHeartRate: make(.restingHeartRate, 60, 5, 10, 5),
            sleepHours: make(.sleepHours, 7.5, 1, 10, 5),
            steps: make(.steps, 8000, 1000, 10, 5),
            activeEnergyKcal: make(.activeEnergyKcal, 450, 50, 10, 5),
            exerciseMinutes: make(.exerciseMinutes, 30, 10, 10, 5),
            standHours: make(.standHours, 11, 2, 10, 5)
        )
    }

    private func makeWeakBaselines() -> PersonalBaselineSet {
        func make(_ metric: BaselineMetric) -> PersonalBaseline {
            PersonalBaseline(
                metric: metric, windowDays: 14, value: 0,
                dispersion: nil, sampleDays: 0, requiredDays: 7,
                computedAt: now, method: .median
            )
        }
        return PersonalBaselineSet(
            hrv: make(.hrv), restingHeartRate: make(.restingHeartRate),
            sleepHours: make(.sleepHours), steps: make(.steps),
            activeEnergyKcal: make(.activeEnergyKcal),
            exerciseMinutes: make(.exerciseMinutes), standHours: make(.standHours)
        )
    }
}
