import XCTest
@testable import StressWatch

final class ActivityLoadEngineTests: XCTestCase {

    private let engine = ActivityLoadEngine()
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - dailyLoad

    func test_dailyLoad_allMissing_returnsNil() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.steps = nil
        b.activeEnergy = nil
        b.exerciseMinutes = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)
        let set = engineBaselineSet()
        XCTAssertNil(engine.dailyLoad(day, baselines: set))
    }

    func test_dailyLoad_onlySteps_usesFullWeight() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.steps = 8000 // 与基线一致 → ratio = 1 → load ≈ 33.33
        b.activeEnergy = nil
        b.exerciseMinutes = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)
        let set = engineBaselineSet(steps: 8000)
        let load = engine.dailyLoad(day, baselines: set)
        XCTAssertNotNil(load)
        // ratio=1 → value=33.33, weight 全给 steps → load = 33.33
        XCTAssertEqual(load!, 33.33, accuracy: 1.0)
    }

    func test_dailyLoad_highSteps_scoresHigher() {
        let set = engineBaselineSet(steps: 8000)

        var low = DailyHealthMetricsFixture.Blueprint()
        low.steps = 4000
        low.activeEnergy = nil
        low.exerciseMinutes = nil
        let lowDay = DailyHealthMetricsFixture.day(TestCalendar.day(0), low)

        var high = DailyHealthMetricsFixture.Blueprint()
        high.steps = 16000
        high.activeEnergy = nil
        high.exerciseMinutes = nil
        let highDay = DailyHealthMetricsFixture.day(TestCalendar.day(0), high)

        let lowLoad = engine.dailyLoad(lowDay, baselines: set)!
        let highLoad = engine.dailyLoad(highDay, baselines: set)!
        XCTAssertLessThan(lowLoad, highLoad)
    }

    // MARK: - ATL / CTL / ACR

    func test_acr_nilWhenNoData() {
        let set = engineBaselineSet()
        XCTAssertNil(engine.acr(history: [], baselines: set, now: now))
    }

    func test_coldStart_usesFixedReference() {
        // 只有 3 天数据 → CTL 用固定 50
        let set = engineBaselineSet(steps: 8000)
        let history = series(days: 3) { _, b in
            b.steps = 8000
            b.activeEnergy = nil
            b.exerciseMinutes = nil
        }
        let ctl = engine.chronicLoad(history: history, baselines: set, now: now)
        XCTAssertNotNil(ctl)
        XCTAssertEqual(ctl!, 50, accuracy: 0.1)
    }

    func test_constantLoad_acrNearOne() {
        // 负荷恒定 14 天 → ACR ≈ 1
        let set = engineBaselineSet(steps: 8000)
        let history = series(days: 14) { _, b in
            b.steps = 8000
            b.activeEnergy = nil
            b.exerciseMinutes = nil
        }
        let ratio = engine.acr(history: history, baselines: set, now: now)
        XCTAssertNotNil(ratio)
        XCTAssertEqual(ratio!, 1.0, accuracy: 0.15)
    }

    func test_sustainedHighLoad_acrElevated() {
        // 前 14 天正常，后 7 天翻倍 → ACR > 1.3
        let set = engineBaselineSet(steps: 8000)
        let history = series(days: 21) { index, b in
            b.steps = index < 14 ? 8000 : 16000
            b.activeEnergy = nil
            b.exerciseMinutes = nil
        }
        let ratio = engine.acr(history: history, baselines: set, now: now)
        XCTAssertNotNil(ratio)
        XCTAssertGreaterThan(ratio!, 1.0)
        XCTAssertTrue(engine.isElevated(history: history, baselines: set, now: now))
    }

    // MARK: - Helpers

    private func engineBaselineSet(steps: Double = 8000) -> PersonalBaselineSet {
        let baseline = PersonalBaseline(
            metric: .steps, windowDays: 14, value: steps,
            dispersion: 1000, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        let energy = PersonalBaseline(
            metric: .activeEnergyKcal, windowDays: 14, value: 450,
            dispersion: 50, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        let exercise = PersonalBaseline(
            metric: .exerciseMinutes, windowDays: 14, value: 30,
            dispersion: 10, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        let hrv = PersonalBaseline(
            metric: .hrv, windowDays: 14, value: 50,
            dispersion: 10, sampleDays: 10, requiredDays: 7,
            computedAt: now, method: .logEWMA
        )
        let rhr = PersonalBaseline(
            metric: .restingHeartRate, windowDays: 14, value: 60,
            dispersion: 5, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        let sleep = PersonalBaseline(
            metric: .sleepHours, windowDays: 14, value: 7.5,
            dispersion: 1, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        let stand = PersonalBaseline(
            metric: .standHours, windowDays: 14, value: 11,
            dispersion: 2, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        return PersonalBaselineSet(
            hrv: hrv, restingHeartRate: rhr, sleepHours: sleep,
            steps: baseline, activeEnergyKcal: energy,
            exerciseMinutes: exercise, standHours: stand
        )
    }

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
