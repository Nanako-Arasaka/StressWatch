import XCTest
@testable import StressWatch

final class PersonalStressEngineTests: XCTestCase {

    private let engine = PersonalStressEngine()
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 性质测试：HRV 越低压力越高

    func test_score_hrvLower_meansHigherStress() {
        let baselines = makeBaselines()

        var lowHRV = makeToday(hrv: 30, rhr: 62, sleep: 7.0)
        var midHRV = makeToday(hrv: 50, rhr: 60, sleep: 7.5)
        var highHRV = makeToday(hrv: 75, rhr: 58, sleep: 8.0)

        let low = engine.compute(today: lowHRV, history: [], baselines: baselines)
        let mid = engine.compute(today: midHRV, history: [], baselines: baselines)
        let high = engine.compute(today: highHRV, history: [], baselines: baselines)

        XCTAssertNotNil(low.score)
        XCTAssertNotNil(mid.score)
        XCTAssertNotNil(high.score)
        // HRV 低 → 压力高
        XCTAssertGreaterThan(low.score!, mid.score!)
        XCTAssertGreaterThan(mid.score!, high.score!)
    }

    // MARK: - 活动不再误判为压力

    func test_highSteps_notTreatedAsStress() {
        let baselines = makeBaselines(steps: 8000)

        var moderate = makeToday(hrv: 50, rhr: 60, sleep: 7.5, steps: 8000)
        var high = makeToday(hrv: 50, rhr: 60, sleep: 7.5, steps: 16000)

        let moderateScore = engine.compute(today: moderate, history: [], baselines: baselines)
        let highScore = engine.compute(today: high, history: [], baselines: baselines)

        XCTAssertNotNil(moderateScore.score)
        XCTAssertNotNil(highScore.score)
        // 高步数日的分数不应显著高于中等步数日（活动不该被当成压力）
        XCTAssertLessThanOrEqual(highScore.score!, moderateScore.score! + 10)
    }

    // MARK: - 全缺失 → nil

    func test_allMissing_returnsNilScore() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = nil
        b.restingHR = nil
        b.sleepHours = nil
        b.steps = nil
        b.activeEnergy = nil
        b.exerciseMinutes = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let result = engine.compute(today: day, history: [], baselines: makeBaselines())
        XCTAssertNil(result.score)
        XCTAssertEqual(result.confidence, .insufficient)
        XCTAssertFalse(result.warnings.isEmpty)
    }

    // MARK: - 不变式：Σ contributions == score

    func test_contributionsSum_equalsScore() {
        let baselines = makeBaselines()
        let today = makeToday(hrv: 42, rhr: 68, sleep: 6.4)
        let result = engine.compute(today: today, history: [], baselines: baselines)

        XCTAssertNotNil(result.score)
        let sum = result.contributions.reduce(0) { $0 + $1.points }
        XCTAssertEqual(sum, Double(result.score!), accuracy: 1.0)
    }

    // MARK: - Confidence 联动

    func test_missingRHR_warnsAndLowersConfidence() {
        let baselines = makeBaselines()
        let today = makeToday(hrv: 50, rhr: nil, sleep: 7.5)

        let result = engine.compute(today: today, history: [], baselines: baselines)
        XCTAssertNotNil(result.score)
        XCTAssertTrue(result.warnings.contains { $0.contains("静息心率") })
        // 扣 0.15 → 0.85，仍是 high 但不是满分
        XCTAssertLessThanOrEqual(result.confidence, .high)
    }

    func test_disagreement_compressesTowardNeutral() {
        // 极端分歧：HRV 远低于基线（压力高）+ RHR 远低于基线（压力低）
        let baselines = makeBaselines(hrv: 80, rhr: 75, hrvDisp: 0.5, rhrDisp: 2)
        let today = makeToday(hrv: 20, rhr: 55, sleep: 7.5)

        let result = engine.compute(today: today, history: [], baselines: baselines)
        XCTAssertNotNil(result.score)
        XCTAssertTrue(result.warnings.contains { $0.contains("不一致") || $0.contains("压缩") })
    }

    // MARK: - Provisional

    func test_provisional_firstDay() {
        // 基线只有 1 天 → 不可靠
        let weakBaselines = makeBaselines(hrvDays: 1)
        let today = makeToday(hrv: 50, rhr: 60, sleep: 7.5)

        let result = engine.compute(today: today, history: [], baselines: weakBaselines)
        XCTAssertTrue(result.isProvisional)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertNotNil(result.score) // provisional 仍有分数
    }

    // MARK: - Sedentary 过滤

    func test_filterSedentary_removesWorkoutPeriod() {
        let samples: [(Date, Double)] = [
            (TestCalendar.time(dayOffset: 0, hour: 8), 65),
            (TestCalendar.time(dayOffset: 0, hour: 10), 70),
            (TestCalendar.time(dayOffset: 0, hour: 14), 120), // 运动中
            (TestCalendar.time(dayOffset: 0, hour: 15), 110), // 运动后冷却
            (TestCalendar.time(dayOffset: 0, hour: 18), 68)
        ]
        let workouts = [
            WorkoutInterval(
                start: TestCalendar.time(dayOffset: 0, hour: 13),
                end: TestCalendar.time(dayOffset: 0, hour: 14, minute: 30)
            )
        ]

        let filtered = engine.filterSedentary(samples, workoutIntervals: workouts, maxHR: 190)
        // 14:00 和 15:00 应被剔除（运动 + 冷却）
        XCTAssertEqual(filtered.count, 3)
    }

    func test_filterSedentary_removesHighEffort() {
        let samples: [(Date, Double)] = [
            (TestCalendar.time(dayOffset: 0, hour: 8), 65),
            (TestCalendar.time(dayOffset: 0, hour: 10), 150) // 超过 50% maxHR = 95
        ]
        let filtered = engine.filterSedentary(samples, workoutIntervals: [], maxHR: 190)
        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - Helpers

    private func makeToday(
        hrv: Double?, rhr: Double?, sleep: Double?,
        steps: Double? = 8000
    ) -> DailyHealthMetrics {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.hrv = hrv
        b.restingHR = rhr
        b.sleepHours = sleep
        b.steps = steps
        b.activeEnergy = steps != nil ? 450 : nil
        b.exerciseMinutes = steps != nil ? 30 : nil
        return DailyHealthMetricsFixture.day(TestCalendar.day(0), b)
    }

    private func makeBaselines(
        hrv: Double = 50, rhr: Double = 60, sleep: Double = 7.5,
        steps: Double = 8000, hrvDays: Int = 10,
        hrvDisp: Double = 10, rhrDisp: Double = 5
    ) -> PersonalBaselineSet {
        func make(_ metric: BaselineMetric, _ value: Double, _ disp: Double, _ days: Int, _ req: Int) -> PersonalBaseline {
            PersonalBaseline(
                metric: metric, windowDays: 14, value: value,
                dispersion: disp, sampleDays: days, requiredDays: req,
                computedAt: now, method: metric == .hrv ? .logEWMA : .median
            )
        }
        return PersonalBaselineSet(
            hrv: make(.hrv, hrv, hrvDisp, hrvDays, 7),
            restingHeartRate: make(.restingHeartRate, rhr, rhrDisp, 10, 5),
            sleepHours: make(.sleepHours, sleep, 1, 10, 5),
            steps: make(.steps, steps, 1000, 10, 5),
            activeEnergyKcal: make(.activeEnergyKcal, 450, 50, 10, 5),
            exerciseMinutes: make(.exerciseMinutes, 30, 10, 10, 5),
            standHours: make(.standHours, 11, 2, 10, 5)
        )
    }
}
