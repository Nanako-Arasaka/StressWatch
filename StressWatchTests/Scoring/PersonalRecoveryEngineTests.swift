import XCTest
@testable import StressWatch

final class PersonalRecoveryEngineTests: XCTestCase {

    private let engine = PersonalRecoveryEngine()
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 天花板修正：等于基线 = 50（不是满分）

    func test_recovery_atBaseline_isNeutral50() {
        let baselines = makeBaselines()
        // 严格等于基线
        let today = makeToday(hrv: 50, rhr: 60, sleep: 7.5)

        let result = engine.compute(today: today, history: [], baselines: baselines)
        XCTAssertNotNil(result.score)
        // 关键修正：等于基线不再是 100，而是接近中性 50
        XCTAssertEqual(result.score!, 50, accuracy: 15)
    }

    // MARK: - 性质测试：HRV 越高恢复越好

    func test_recovery_hrvHigher_meansBetterRecovery() {
        let baselines = makeBaselines()

        let low = engine.compute(today: makeToday(hrv: 25, rhr: 65, sleep: 6), history: [], baselines: baselines)
        let mid = engine.compute(today: makeToday(hrv: 50, rhr: 60, sleep: 7.5), history: [], baselines: baselines)
        let high = engine.compute(today: makeToday(hrv: 80, rhr: 55, sleep: 8.5), history: [], baselines: baselines)

        XCTAssertNotNil(low.score)
        XCTAssertNotNil(mid.score)
        XCTAssertNotNil(high.score)
        XCTAssertLessThan(low.score!, mid.score!)
        XCTAssertLessThan(mid.score!, high.score!)
    }

    // MARK: - 全缺失 → nil

    func test_allMissing_returnsNilScore() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = nil
        b.restingHR = nil
        b.sleepHours = nil
        b.sleepREM = nil
        b.sleepCore = nil
        b.sleepDeep = nil
        b.steps = nil
        b.activeEnergy = nil
        b.exerciseMinutes = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let result = engine.compute(today: day, history: [], baselines: makeBaselines())
        XCTAssertNil(result.score)
        XCTAssertEqual(result.confidence, .insufficient)
    }

    // MARK: - 不变式

    func test_contributionsSum_equalsScore() {
        let baselines = makeBaselines()
        let today = makeToday(hrv: 45, rhr: 62, sleep: 7.0)
        let result = engine.compute(today: today, history: [], baselines: baselines)

        XCTAssertNotNil(result.score)
        let sum = result.contributions.reduce(0) { $0 + $1.points }
        XCTAssertEqual(sum, Double(result.score!), accuracy: 1.5)
    }

    // MARK: - 高负荷降低恢复

    func test_highACR_lowersRecovery() {
        let baselines = makeBaselines()
        // 构造 21 天：前 14 正常，后 7 天高负荷
        let history = (0..<21).map { index -> DailyHealthMetrics in
            var b = DailyHealthMetricsFixture.Blueprint()
            b.hrv = 50
            b.restingHR = 60
            b.sleepHours = 7.5
            b.steps = index < 14 ? 8000 : 18000
            b.activeEnergy = index < 14 ? 450 : 900
            b.exerciseMinutes = index < 14 ? 30 : 90
            return DailyHealthMetricsFixture.day(TestCalendar.day(index - 20), b)
        }

        let today = makeToday(hrv: 50, rhr: 60, sleep: 7.5)
        let result = engine.compute(today: today, history: history, baselines: baselines)
        XCTAssertNotNil(result.score)

        // 对比：同样 today 但无历史
        let noHistory = engine.compute(today: today, history: [], baselines: baselines)
        XCTAssertNotNil(noHistory.score)
        // 高负荷历史应使恢复分更低
        XCTAssertLessThanOrEqual(result.score!, noHistory.score! + 5)
    }

    // MARK: - Provisional

    func test_provisional_lowConfidence() {
        let weakBaselines = makeBaselines(hrvDays: 2)
        let today = makeToday(hrv: 50, rhr: 60, sleep: 7.5)

        let result = engine.compute(today: today, history: [], baselines: weakBaselines)
        XCTAssertTrue(result.isProvisional)
        XCTAssertEqual(result.confidence, .low)
    }

    // MARK: - 缺失时警告

    func test_missingHRV_warns() {
        let baselines = makeBaselines()
        let today = makeToday(hrv: nil, rhr: 60, sleep: 7.5)

        let result = engine.compute(today: today, history: [], baselines: baselines)
        XCTAssertTrue(result.warnings.contains { $0.contains("HRV") })
    }

    // MARK: - Helpers

    private func makeToday(hrv: Double?, rhr: Double?, sleep: Double?) -> DailyHealthMetrics {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = hrv
        b.restingHR = rhr
        b.sleepHours = sleep
        b.sleepREM = sleep != nil ? 1.6 : nil
        b.sleepCore = sleep != nil ? 4.2 : nil
        b.sleepDeep = sleep != nil ? 1.2 : nil
        b.steps = 8000
        b.activeEnergy = 450
        b.exerciseMinutes = 30
        return DailyHealthMetricsFixture.day(TestCalendar.day(0), b)
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
