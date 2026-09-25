import XCTest
@testable import StressWatch

final class DataCompletenessTests: XCTestCase {

    // MARK: - ScoreContribution 不变式

    func test_contribution_pointsEqualsRawTimesWeight() {
        let c = ScoreContribution(
            signal: .hrv, rawScore: 72, weight: 0.35,
            direction: .favorable, detail: "HRV 高于基线"
        )
        XCTAssertEqual(c.points, 72 * 0.35, accuracy: 0.0001)
    }

    func test_contributionsSum_matchesFinalScore() {
        // 模拟三个分量：Σ points 必须等于总分（可解释性不变式）
        let contributions = [
            ScoreContribution(signal: .hrv, rawScore: 70, weight: 0.4, direction: .favorable, detail: ""),
            ScoreContribution(signal: .restingHeartRate, rawScore: 50, weight: 0.3, direction: .normal, detail: ""),
            ScoreContribution(signal: .sleep, rawScore: 40, weight: 0.3, direction: .unfavorable, detail: "")
        ]
        let total = contributions.reduce(0) { $0 + $1.points }
        // 70*0.4 + 50*0.3 + 40*0.3 = 28 + 15 + 12 = 55
        XCTAssertEqual(total, 55, accuracy: 0.01)
    }

    // MARK: - AnalysisConfidence

    func test_confidence_fromScore_thresholds() {
        XCTAssertEqual(AnalysisConfidence.from(score: 0.0), .insufficient)
        XCTAssertEqual(AnalysisConfidence.from(score: 0.10), .insufficient)
        XCTAssertEqual(AnalysisConfidence.from(score: 0.20), .low)
        XCTAssertEqual(AnalysisConfidence.from(score: 0.50), .directional)
        XCTAssertEqual(AnalysisConfidence.from(score: 0.60), .medium)
        XCTAssertEqual(AnalysisConfidence.from(score: 0.85), .high)
    }

    func test_confidence_comparable() {
        XCTAssertLessThan(AnalysisConfidence.low, .medium)
        XCTAssertLessThan(AnalysisConfidence.directional, .high)
        XCTAssertFalse(AnalysisConfidence.high < .low)
    }

    // MARK: - DataCompleteness 全缺失

    func test_empty_allMissing() {
        let c = DataCompleteness.empty
        XCTAssertTrue(c.availableMetrics.isEmpty)
        XCTAssertEqual(c.missingMetrics.count, BaselineMetric.allCases.count)
        XCTAssertEqual(c.coreCompleteness, 0)
        XCTAssertEqual(c.overallCompleteness, 0)
    }

    func test_todayNil_everythingMissing() {
        let c = DataCompleteness(today: nil, historyDays: 0)
        XCTAssertTrue(c.availableMetrics.isEmpty)
        XCTAssertEqual(c.coreCompleteness, 0)
        XCTAssertNotNil(c.missingSummary)
    }

    // MARK: - 核心 vs 整体

    func test_onlyActivityMissing_coreComplete() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = 50
        b.restingHR = 60
        b.sleepHours = 7.5
        b.steps = 8000
        b.activeEnergy = nil
        b.exerciseMinutes = nil
        b.standHours = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let c = DataCompleteness(today: day, historyDays: 5)
        // 核心四项全在 → coreCompleteness = 1.0
        XCTAssertEqual(c.coreCompleteness, 1.0, accuracy: 0.01)
        // 但 overall < 1（活动三项缺失）
        XCTAssertLessThan(c.overallCompleteness, 1.0)
        XCTAssertTrue(c.missingMetrics.contains(.activeEnergyKcal))
        XCTAssertTrue(c.missingMetrics.contains(.exerciseMinutes))
        XCTAssertFalse(c.missingMetrics.contains(.hrv))
    }

    func test_missingHrv_lowersCoreCompleteness() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = nil
        b.restingHR = 60
        b.sleepHours = 7.5
        b.steps = 8000
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let c = DataCompleteness(today: day, historyDays: 5)
        // 核心四项缺 1 → 3/4
        XCTAssertEqual(c.coreCompleteness, 0.75, accuracy: 0.01)
        XCTAssertTrue(c.missingMetrics.contains(.hrv))
    }

    func test_missingSummary_namesMissingMetrics() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = nil
        b.restingHR = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let c = DataCompleteness(today: day, historyDays: 3)
        let summary = c.missingSummary
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("HRV"))
        XCTAssertTrue(summary!.contains("静息心率"))
        XCTAssertTrue(summary!.contains("未纳入"))
    }

    func test_fullData_noMissingSummary() {
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0))
        let c = DataCompleteness(today: day, historyDays: 10)
        XCTAssertNil(c.missingSummary)
        XCTAssertEqual(c.coreCompleteness, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.overallCompleteness, 1.0, accuracy: 0.01)
    }
}
