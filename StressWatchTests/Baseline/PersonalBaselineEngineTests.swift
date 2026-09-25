import XCTest
@testable import StressWatch

final class PersonalBaselineEngineTests: XCTestCase {

    private let engine = PersonalBaselineEngine(calendar: TestCalendar.utc)
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 样本量阶梯

    func test_zeroDays_notReliable() {
        let baseline = engine.compute(metric: .hrv, from: [], windowDays: 14, now: now)
        XCTAssertFalse(baseline.isReliable)
        XCTAssertEqual(baseline.sampleDays, 0)
        XCTAssertEqual(baseline.daysRemaining, 7)
        XCTAssertNil(baseline.zScore(of: 50))
    }

    func test_hrv_requiresSevenDays() {
        let six = series(days: 6) { index, b in
            b.hrv = 40 + Double(index)
        }
        let sixBaseline = engine.compute(metric: .hrv, from: six, windowDays: 14, now: now)
        XCTAssertFalse(sixBaseline.isReliable)
        XCTAssertEqual(sixBaseline.daysRemaining, 1)

        let seven = series(days: 7) { index, b in
            b.hrv = 40 + Double(index)
        }
        let sevenBaseline = engine.compute(metric: .hrv, from: seven, windowDays: 14, now: now)
        XCTAssertTrue(sevenBaseline.isReliable)
        XCTAssertEqual(sevenBaseline.daysRemaining, 0)
    }

    func test_rhr_requiresFiveDays() {
        let four = series(days: 4) { index, b in
            b.restingHR = 55 + Double(index)
        }
        XCTAssertFalse(
            engine.compute(metric: .restingHeartRate, from: four, windowDays: 14, now: now).isReliable
        )

        let five = series(days: 5) { index, b in
            b.restingHR = 55 + Double(index)
        }
        XCTAssertTrue(
            engine.compute(metric: .restingHeartRate, from: five, windowDays: 14, now: now).isReliable
        )
    }

    func test_calibrationProgress_scalesWithSampleDays() {
        let three = series(days: 3) { index, b in
            b.hrv = 50 + Double(index)
        }
        let baseline = engine.compute(metric: .hrv, from: three, windowDays: 14, now: now)
        XCTAssertEqual(baseline.calibrationProgress, 3.0 / 7.0, accuracy: 0.01)
    }

    // MARK: - 缺失日不占位

    func test_missingDays_doNotCountTowardSampleDays() {
        let days = TestCalendar.recentDays(10)
        let metrics: [DailyHealthMetrics] = days.enumerated().map { index, date in
            var blueprint = DailyHealthMetricsFixture.Blueprint()
            blueprint.hrv = index % 2 == 0 ? 50 + Double(index) : nil
            return DailyHealthMetricsFixture.day(date, blueprint)
        }
        let baseline = engine.compute(metric: .hrv, from: metrics, windowDays: 14, now: now)
        XCTAssertEqual(baseline.sampleDays, 5)
    }

    func test_windowFiltersOutOfRangeDays() {
        let all = series(days: 20) { _, b in
            b.hrv = 50
        }
        let baseline = engine.compute(metric: .hrv, from: all, windowDays: 7, now: now)
        XCTAssertEqual(baseline.sampleDays, 7)
    }

    // MARK: - 极端值剔除

    func test_outlier_isDroppedFromCenter() {
        // 8 天平稳 50 + 1 天 200 的离群值
        let days = TestCalendar.recentDays(9)
        let metrics: [DailyHealthMetrics] = days.enumerated().map { index, date in
            var blueprint = DailyHealthMetricsFixture.Blueprint()
            blueprint.hrv = index == days.count - 1 ? 200 : 50
            return DailyHealthMetricsFixture.day(date, blueprint)
        }
        let baseline = engine.compute(metric: .hrv, from: metrics, windowDays: 14, now: now)
        // 中心应仍接近 50，而不是被 200 明显拉高
        XCTAssertLessThan(baseline.value, 80)
    }

    // MARK: - HRV 专用：logEWMA + P75 锚点

    func test_hrv_usesLogEWMA_andHasAnchor() {
        let metrics = series(days: 10) { index, b in
            b.hrv = 40 + Double(index) * 3
        }
        let baseline = engine.compute(metric: .hrv, from: metrics, windowDays: 14, now: now)
        XCTAssertEqual(baseline.method, .logEWMA)
        XCTAssertNotNil(baseline.anchorP75)
        XCTAssertGreaterThan(baseline.value, 0)
        XCTAssertNotNil(baseline.dispersion)
    }

    func test_hrv_p75Anchor_notDraggedBySpiral() {
        // 14 天 HRV 从 50 螺旋降到 25（Thump 压力螺旋）
        let spiral = series(days: 14) { index, b in
            b.hrv = 50.0 - Double(index) * (25.0 / 13.0)
        }
        let baseline = engine.compute(metric: .hrv, from: spiral, windowDays: 14, now: now)
        XCTAssertNotNil(baseline.anchorP75)
        // 锚点应接近"好日子"（≈42+），而不是被拖到中位数附近
        XCTAssertGreaterThan(baseline.anchorP75!, 40)
    }

    func test_nonHrv_usesMedianMethod_withoutAnchor() {
        let metrics = series(days: 7) { index, b in
            b.restingHR = 58 + Double(index)
        }
        let baseline = engine.compute(metric: .restingHeartRate, from: metrics, windowDays: 14, now: now)
        XCTAssertEqual(baseline.method, .median)
        XCTAssertNil(baseline.anchorP75)
    }

    // MARK: - zScore

    func test_zScore_nilWhenUnreliable() {
        let metrics = series(days: 3) { _, b in
            b.hrv = 50
        }
        let baseline = engine.compute(metric: .hrv, from: metrics, windowDays: 14, now: now)
        XCTAssertFalse(baseline.isReliable)
        XCTAssertNil(baseline.zScore(of: 40))
    }

    func test_zScore_nilWhenZeroDispersion() {
        let metrics = series(days: 10) { _, b in
            b.restingHR = 60
        }
        let baseline = engine.compute(metric: .restingHeartRate, from: metrics, windowDays: 14, now: now)
        XCTAssertNil(baseline.dispersion)
        XCTAssertFalse(baseline.isReliable)
        XCTAssertNil(baseline.zScore(of: 70))
    }

    func test_zScore_medianMethod_sign() {
        let metrics = series(days: 10) { index, b in
            b.restingHR = 55 + Double(index)
        }
        let baseline = engine.compute(metric: .restingHeartRate, from: metrics, windowDays: 14, now: now)
        XCTAssertTrue(baseline.isReliable)

        let high = baseline.zScore(of: 80)
        let low = baseline.zScore(of: 40)
        XCTAssertNotNil(high)
        XCTAssertNotNil(low)
        XCTAssertGreaterThan(high!, 0)
        XCTAssertLessThan(low!, 0)
    }

    func test_deviationPercent() {
        let varied = series(days: 10) { index, b in
            b.restingHR = 55 + Double(index)
        }
        let baseline = engine.compute(metric: .restingHeartRate, from: varied, windowDays: 14, now: now)
        let dev = baseline.deviationPercent(of: baseline.value * 1.1)
        XCTAssertNotNil(dev)
        XCTAssertEqual(dev!, 10, accuracy: 0.5)
    }

    // MARK: - baselineSet

    func test_baselineSet_containsAllCoreMetrics() {
        let metrics = series(days: 10) { index, b in
            b.hrv = 45 + Double(index)
            b.restingHR = 58
            b.sleepHours = 7 + Double(index) * 0.1
            b.steps = 8000
        }
        let set = engine.baselineSet(from: metrics, windowDays: 14, now: now)
        XCTAssertEqual(set.hrv.metric, .hrv)
        XCTAssertEqual(set.restingHeartRate.metric, .restingHeartRate)
        XCTAssertEqual(set.sleepHours.metric, .sleepHours)
        XCTAssertEqual(set.steps.metric, .steps)
        XCTAssertGreaterThan(set.coreDayCount, 0)
    }

    func test_coreDayCount_takesMinimum() {
        // HRV 10 天、RHR 5 天、Sleep 8 天 → coreDayCount = 5
        let days = TestCalendar.recentDays(10)
        let metrics: [DailyHealthMetrics] = days.enumerated().map { index, date in
            var b = DailyHealthMetricsFixture.Blueprint()
            b.hrv = 50 + Double(index)
            b.restingHR = index < 5 ? 60 : nil
            b.sleepHours = index < 8 ? 7.5 : nil
            return DailyHealthMetricsFixture.day(date, b)
        }
        let set = engine.baselineSet(from: metrics, windowDays: 14, now: now)
        XCTAssertEqual(set.coreDayCount, 5)
    }

    func test_legacyBaseline_mapsFields() {
        let metrics = series(days: 10) { _, b in
            b.hrv = 50
            b.restingHR = 62
            b.sleepHours = 7.2
            b.steps = 9000
        }
        let set = engine.baselineSet(from: metrics, windowDays: 14, now: now)
        let legacy = set.legacyBaseline()
        XCTAssertEqual(legacy.avgHRV, set.hrv.value, accuracy: 0.01)
        XCTAssertEqual(legacy.avgRestingHR, set.restingHeartRate.value, accuracy: 0.01)
        XCTAssertEqual(legacy.avgSleepHours, set.sleepHours.value, accuracy: 0.01)
        XCTAssertEqual(legacy.avgDailySteps, set.steps.value, accuracy: 0.01)
    }

    // MARK: - Helpers

    /// 构造 `count` 天连续历史，最后一天为 `day(0)`。
    private func series(
        days count: Int,
        _ build: (Int, inout DailyHealthMetricsFixture.Blueprint) -> Void
    ) -> [DailyHealthMetrics] {
        let dates = TestCalendar.recentDays(count)
        return dates.enumerated().map { index, date in
            var blueprint = DailyHealthMetricsFixture.Blueprint()
            build(index, &blueprint)
            return DailyHealthMetricsFixture.day(date, blueprint)
        }
    }
}
