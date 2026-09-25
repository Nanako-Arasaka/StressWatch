import XCTest
@testable import StressWatch

final class TrendEngineTests: XCTestCase {

    private let engine = TrendEngine()
    private let calendar = TestCalendar.utc
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 数据不足

    func test_lessThan7Days_insufficientData() {
        let history = series(days: 5) { _, b in b.hrv = 50 }
        let t = engine.trend(metric: .hrv, history: history, window: .days7, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .insufficientData)
        XCTAssertEqual(t.sampleCount, 5)
        XCTAssertEqual(t.daysRemaining, 2)
    }

    func test_zeroDays_insufficientData() {
        let t = engine.trend(metric: .hrv, history: [], window: .days7, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .insufficientData)
    }

    // MARK: - 稳定序列

    func test_constantSeries_stable() {
        let history = series(days: 14) { _, b in b.hrv = 50 }
        let t = engine.trend(metric: .hrv, history: history, window: .days14, baseline: nil, now: now, calendar: calendar)
        // 零方差 → 死区 → stable
        XCTAssertEqual(t.direction, .stable)
    }

    // MARK: - 下降趋势

    func test_decliningHRV_detected() {
        // 14 天 HRV 从 60 降到 40
        let history = series(days: 14) { i, b in
            b.hrv = 60.0 - Double(i) * (20.0 / 13.0)
        }
        let t = engine.trend(metric: .hrv, history: history, window: .days14, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .declining)
    }

    func test_improvingHRV_detected() {
        // 14 天 HRV 从 40 升到 60
        let history = series(days: 14) { i, b in
            b.hrv = 40.0 + Double(i) * (20.0 / 13.0)
        }
        let t = engine.trend(metric: .hrv, history: history, window: .days14, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .improving)
    }

    // MARK: - RHR 方向语义

    func test_risingRHR_isDeclining() {
        // RHR 升高 = 恢复变差 = declining
        let history = series(days: 14) { i, b in
            b.restingHR = 55.0 + Double(i) * (15.0 / 13.0)
        }
        let t = engine.trend(metric: .restingHeartRate, history: history, window: .days14, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .declining)
    }

    func test_fallingRHR_isImproving() {
        let history = series(days: 14) { i, b in
            b.restingHR = 70.0 - Double(i) * (15.0 / 13.0)
        }
        let t = engine.trend(metric: .restingHeartRate, history: history, window: .days14, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .improving)
    }

    // MARK: - 高波动

    func test_highVolatility_overridesToVolatile() {
        // 交替极端值 → CV > 0.25
        let history = series(days: 14) { i, b in
            b.hrv = i % 2 == 0 ? 20 : 80
        }
        let t = engine.trend(metric: .hrv, history: history, window: .days14, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.direction, .volatile)
    }

    // MARK: - 窗口过滤

    func test_windowFiltersOldData() {
        let history = series(days: 20) { _, b in b.hrv = 50 }
        let t = engine.trend(metric: .hrv, history: history, window: .days7, baseline: nil, now: now, calendar: calendar)
        XCTAssertEqual(t.sampleCount, 7)
    }

    // MARK: - deviationPercent

    func test_deviationPercent_fromBaseline() {
        let history = series(days: 10) { _, b in b.hrv = 60 }
        let baseline = PersonalBaseline(
            metric: .hrv, windowDays: 14, value: 50, dispersion: 10,
            sampleDays: 10, requiredDays: 7, computedAt: now, method: .logEWMA
        )
        let t = engine.trend(metric: .hrv, history: history, window: .days14, baseline: baseline, now: now, calendar: calendar)
        XCTAssertNotNil(t.deviationPercent)
        XCTAssertEqual(t.deviationPercent!, 20, accuracy: 1.0) // 60 vs 50 = +20%
    }

    // MARK: - Helpers

    private func series(
        days count: Int,
        _ build: (Int, inout DailyHealthMetricsFixture.Blueprint) -> Void
    ) -> [DailyHealthMetrics] {
        TestCalendar.recentDays(count).enumerated().map { index, date in
            var b = DailyHealthMetricsFixture.Blueprint()
            build(index, &b)
            return DailyHealthMetricsFixture.day(date, b)
        }
    }
}
