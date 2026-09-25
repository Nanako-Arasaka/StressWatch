import XCTest
@testable import StressWatch

final class SleepQualityEngineTests: XCTestCase {

    private let engine = SleepQualityEngine()
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 全缺失

    func test_score_allMissing_returnsNil() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.sleepHours = nil
        b.sleepREM = nil
        b.sleepCore = nil
        b.sleepDeep = nil
        b.hrv = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)
        XCTAssertNil(engine.score(today: day, history: [day], baselines: emptyBaselines()))
    }

    // MARK: - Duration

    func test_score_goodDuration_highScore() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.sleepHours = 8.0
        b.sleepREM = 1.8
        b.sleepCore = 4.5
        b.sleepDeep = 1.5
        b.hrv = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let score = engine.score(today: day, history: [day], baselines: emptyBaselines())
        XCTAssertNotNil(score)
        // 8h / 7.5h → duration 满分附近；分期也合理 → 总分应 > 70
        XCTAssertGreaterThan(score!, 70)
    }

    func test_score_shortSleep_lowScore() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.sleepHours = 3.0
        b.sleepREM = 0.2
        b.sleepCore = 2.0
        b.sleepDeep = 0.2
        b.hrv = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let score = engine.score(today: day, history: [day], baselines: emptyBaselines())
        XCTAssertNotNil(score)
        // 3h 极短睡眠 + 差分期 → 应明显低于正常睡眠
        XCTAssertLessThan(score!, 50)
    }

    // MARK: - Stages 缺失时退出

    func test_score_stagesMissing_componentExits_notZero() {
        var b = DailyHealthMetricsFixture.Blueprint()
        b.sleepHours = 7.5
        b.sleepREM = nil
        b.sleepCore = nil
        b.sleepDeep = nil
        b.hrv = nil
        let day = DailyHealthMetricsFixture.day(TestCalendar.day(0), b)

        let score = engine.score(today: day, history: [day], baselines: emptyBaselines())
        XCTAssertNotNil(score)
        // 分期缺失不应把分数压到 0，duration 单独应对 ≈ 100
        XCTAssertGreaterThan(score!, 60)
    }

    // MARK: - Consistency 需 ≥ 3 晚

    func test_consistency_nilWhenFewerThanThreeNights() {
        let twoNights = seriesWithBedtimes(hours: [23, 0])
        XCTAssertNil(engine.consistencyScore(history: twoNights))
    }

    func test_consistency_stableBedtimes_highScore() {
        // 三晚都在 23:00-23:30
        let stable = seriesWithBedtimes(hours: [23, 23.25, 23.5])
        let score = engine.consistencyScore(history: stable)
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 70)
    }

    func test_consistency_scatteredBedtimes_lowScore() {
        // 三晚分散在 21 / 24 / 3（即 21:00 / 00:00 / 03:00）
        let scattered = seriesWithBedtimes(hours: [21, 0, 3])
        let score = engine.consistencyScore(history: scattered)
        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 50)
    }

    // MARK: - 圆周标准差

    func test_circularStdDev_identicalHours_isZero() {
        let std = engine.circularStdDevHours([23, 23, 23])
        XCTAssertNotNil(std)
        XCTAssertEqual(std!, 0, accuracy: 0.01)
    }

    func test_circularStdDev_midnightBoundary_isSmall() {
        // 23:30 和 00:30 在圆周上只差 1 小时
        let std = engine.circularStdDevHours([23.5, 0.5])
        XCTAssertNotNil(std)
        XCTAssertLessThan(std!, 1.5)
    }

    // MARK: - HRV 分量

    func test_score_hrvBoostsScore() {
        let baselines = baselinesWithReliableHRV()

        var lowHRV = DailyHealthMetricsFixture.Blueprint()
        lowHRV.sleepHours = 7.5
        lowHRV.sleepREM = 1.6
        lowHRV.sleepCore = 4.2
        lowHRV.sleepDeep = 1.2
        lowHRV.hrv = 30 // 远低于基线 50
        let lowDay = DailyHealthMetricsFixture.day(TestCalendar.day(0), lowHRV)

        var highHRV = lowHRV
        highHRV.hrv = 80 // 远高于基线
        let highDay = DailyHealthMetricsFixture.day(TestCalendar.day(0), highHRV)

        let lowScore = engine.score(today: lowDay, history: [lowDay], baselines: baselines)!
        let highScore = engine.score(today: highDay, history: [highDay], baselines: baselines)!
        XCTAssertLessThan(lowScore, highScore)
    }

    // MARK: - Helpers

    private func emptyBaselines() -> PersonalBaselineSet {
        let stub = PersonalBaseline(
            metric: .hrv, windowDays: 14, value: 50,
            dispersion: 10, sampleDays: 0, requiredDays: 7,
            computedAt: now, method: .logEWMA
        )
        return PersonalBaselineSet(
            hrv: stub, restingHeartRate: stub, sleepHours: stub,
            steps: stub, activeEnergyKcal: stub,
            exerciseMinutes: stub, standHours: stub
        )
    }

    private func baselinesWithReliableHRV() -> PersonalBaselineSet {
        let hrv = PersonalBaseline(
            metric: .hrv, windowDays: 14, value: 50,
            dispersion: 10, sampleDays: 10, requiredDays: 7,
            computedAt: now, method: .logEWMA
        )
        let sleep = PersonalBaseline(
            metric: .sleepHours, windowDays: 14, value: 7.5,
            dispersion: 1, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        let stub = PersonalBaseline(
            metric: .steps, windowDays: 14, value: 8000,
            dispersion: 1000, sampleDays: 10, requiredDays: 5,
            computedAt: now, method: .median
        )
        return PersonalBaselineSet(
            hrv: hrv, restingHeartRate: stub, sleepHours: sleep,
            steps: stub, activeEnergyKcal: stub,
            exerciseMinutes: stub, standHours: stub
        )
    }

    /// 构造带指定就寝小时（0-24）的多天历史。
    private func seriesWithBedtimes(hours: [Double]) -> [DailyHealthMetrics] {
        let days = TestCalendar.recentDays(hours.count)
        return days.enumerated().map { index, date in
            var b = DailyHealthMetricsFixture.Blueprint()
            b.sleepHours = 7.5
            let hour = hours[index]
            let wholeHour = Int(hour)
            let minute = Int((hour - Double(wholeHour)) * 60)
            let bedtime = TestCalendar.time(dayOffset: -(hours.count - 1 - index), hour: wholeHour == 24 ? 0 : wholeHour, minute: minute)
            return DailyHealthMetrics(
                day: date,
                dataSource: .appleHealth,
                hrv: DailyHealthMetricsFixture.sample(b.hrv, unit: "ms", source: .measured),
                sleepHours: DailyHealthMetricsFixture.sample(b.sleepHours, unit: "hours", source: .measured),
                bedtime: bedtime,
                wakeTime: bedtime.addingTimeInterval(7.5 * 3600)
            )
        }
    }
}
