import XCTest
@testable import StressWatch

final class CorrelationEngineTests: XCTestCase {

    private let engine = CorrelationEngine()
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 样本不足

    func test_insufficientPairs_returnsNoneWithClearMessage() {
        // 只有 5 天，门槛 10
        let history = series(days: 5) { _, b in
            b.sleepHours = 7
            b.hrv = 50
        }
        let pair = CorrelationPair(x: .sleepHours, y: .hrv, lagDays: 0, expectedDirection: .positive)
        let result = engine.analyze(pair: pair, history: history)

        XCTAssertEqual(result.strength, .none)
        XCTAssertNil(result.coefficient)
        XCTAssertTrue(result.description.contains("还没有"))
        XCTAssertEqual(result.pairedDays, 5)
    }

    // MARK: - 已知正相关

    func test_strongPositiveCorrelation_detected() {
        // sleep 和 hrv 同步线性上升 → r ≈ +1
        let history = series(days: 15) { i, b in
            b.sleepHours = 5 + Double(i) * 0.3
            b.hrv = 30 + Double(i) * 2.0
        }
        let pair = CorrelationPair(x: .sleepHours, y: .hrv, lagDays: 0, expectedDirection: .positive)
        let result = engine.analyze(pair: pair, history: history)

        XCTAssertNotNil(result.coefficient)
        XCTAssertGreaterThan(result.coefficient!, 0.8)
        XCTAssertEqual(result.strength, .strong)
        XCTAssertTrue(result.isBeneficial) // 正相关 + expected positive → beneficial
        XCTAssertTrue(result.spearmanAgrees)
    }

    // MARK: - 已知负相关

    func test_strongNegativeCorrelation_detected() {
        // steps 和 RHR 反向 → r ≈ -1
        let history = series(days: 15) { i, b in
            b.steps = 3000 + Double(i) * 800
            b.restingHR = 75 - Double(i) * 1.0
        }
        let pair = CorrelationPair(x: .steps, y: .restingHeartRate, lagDays: 0, expectedDirection: .negative)
        let result = engine.analyze(pair: pair, history: history)

        XCTAssertNotNil(result.coefficient)
        XCTAssertLessThan(result.coefficient!, -0.8)
        XCTAssertTrue(result.isBeneficial) // 负相关 + expected negative → beneficial（步数多→RHR低是好事）
    }

    // MARK: - lag 配对

    func test_lag1_pairsXtodayWithYtomorrow() {
        // sleep(t) → hrv(t+1)：HRV 滞后一天响应睡眠
        var metrics: [DailyHealthMetrics] = []
        for i in 0..<15 {
            var b = DailyHealthMetricsFixture.Blueprint()
            b.sleepHours = 5 + Double(i) * 0.3
            // HRV 在下一天才跟上
            let hrvDayIndex = i - 1
            b.hrv = hrvDayIndex >= 0 ? 30 + Double(hrvDayIndex) * 2.0 : nil
            metrics.append(DailyHealthMetricsFixture.day(TestCalendar.day(i - 14), b))
        }

        let pair = CorrelationPair(x: .sleepHours, y: .hrv, lagDays: 1, expectedDirection: .positive)
        let result = engine.analyze(pair: pair, history: metrics)

        // lag=1 应能检出正相关（sleep(t) 与 hrv(t+1) 同步）
        XCTAssertNotNil(result.coefficient)
        XCTAssertGreaterThan(result.coefficient!, 0.5)
        XCTAssertEqual(result.lagDays, 1)
    }

    // MARK: - 无相关

    func test_randomData_weakOrNone() {
        // 独立正弦波 → 无相关
        let history = series(days: 20) { i, b in
            b.sleepHours = 7 + sin(Double(i) * 1.1) * 1.5
            b.hrv = 50 + cos(Double(i) * 0.37) * 10
        }
        let pair = CorrelationPair(x: .sleepHours, y: .hrv, lagDays: 0, expectedDirection: .positive)
        let result = engine.analyze(pair: pair, history: history)

        if let r = result.coefficient {
            XCTAssertLessThan(abs(r), 0.6)
        }
    }

    // MARK: - Pearson / Spearman

    func test_pearson_perfectPositive() {
        let x: [Double] = [1, 2, 3, 4, 5]
        let y: [Double] = [2, 4, 6, 8, 10]
        let r = engine.pearson(x, y)
        XCTAssertNotNil(r)
        XCTAssertEqual(r!, 1.0, accuracy: 0.001)
    }

    func test_pearson_perfectNegative() {
        let x: [Double] = [1, 2, 3, 4, 5]
        let y: [Double] = [10, 8, 6, 4, 2]
        let r = engine.pearson(x, y)
        XCTAssertNotNil(r)
        XCTAssertEqual(r!, -1.0, accuracy: 0.001)
    }

    func test_pearson_zeroVariance_returnsNil() {
        let x: [Double] = [5, 5, 5, 5, 5]
        let y: [Double] = [1, 2, 3, 4, 5]
        XCTAssertNil(engine.pearson(x, y))
    }

    func test_pearson_tooFewSamples_returnsNil() {
        XCTAssertNil(engine.pearson([1, 2], [3, 4]))
    }

    func test_spearman_monotonicAgrees() {
        // 非线性但单调 → Spearman ≈ 1
        let x: [Double] = [1, 2, 3, 4, 5]
        let y: [Double] = [1, 4, 9, 16, 25]
        let s = engine.spearman(x, y)
        XCTAssertNotNil(s)
        XCTAssertEqual(s!, 1.0, accuracy: 0.01)
    }

    // MARK: - isBeneficial 判定

    func test_isBeneficial_negativeR_expectedNegative_true() {
        // steps ↑ RHR ↓ = r < 0, expectedDirection = negative → beneficial
        let history = series(days: 15) { i, b in
            b.steps = 3000 + Double(i) * 800
            b.restingHR = 75 - Double(i) * 1.0
        }
        let pair = CorrelationPair(x: .steps, y: .restingHeartRate, lagDays: 0, expectedDirection: .negative)
        let result = engine.analyze(pair: pair, history: history)
        XCTAssertTrue(result.isBeneficial)
    }

    func test_isBeneficial_negativeR_expectedPositive_false() {
        // sleep ↑ HRV ↓ = r < 0, expectedDirection = positive → NOT beneficial
        let history = series(days: 15) { i, b in
            b.sleepHours = 5 + Double(i) * 0.3
            b.hrv = 70 - Double(i) * 2.0
        }
        let pair = CorrelationPair(x: .sleepHours, y: .hrv, lagDays: 0, expectedDirection: .positive)
        let result = engine.analyze(pair: pair, history: history)
        XCTAssertFalse(result.isBeneficial)
    }

    // MARK: - 描述不含因果词

    func test_description_containsNoCausalWords() {
        let history = series(days: 15) { i, b in
            b.sleepHours = 5 + Double(i) * 0.3
            b.hrv = 30 + Double(i) * 2.0
        }
        let pair = CorrelationPair(x: .sleepHours, y: .hrv, lagDays: 0, expectedDirection: .positive)
        let result = engine.analyze(pair: pair, history: history)

        let banned = ["导致", "因为", "证明", "引起", "造成", "causes", "because"]
        for word in banned {
            XCTAssertFalse(result.description.contains(word), "描述不应包含因果词: \(word)")
        }
    }

    // MARK: - defaultPairs

    func test_defaultPairs_hasSixEntries() {
        XCTAssertEqual(CorrelationPair.defaultPairs.count, 6)
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
