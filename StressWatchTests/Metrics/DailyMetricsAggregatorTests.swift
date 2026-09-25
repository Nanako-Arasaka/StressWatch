import XCTest
@testable import StressWatch
final class DailyMetricsAggregatorTests: XCTestCase {

    private let calendar = TestCalendar.utc
    private lazy var aggregator = DailyMetricsAggregator(calendar: calendar)
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 空输入

    func test_emptyMetrics_returnsEmptyArray() {
        let result = aggregator.aggregate(metrics: [], dataSource: .appleHealth, now: now)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 单日

    func test_singleDay_aggregatesAllMetrics() {
        let metrics: [HealthMetric] = [
            HealthMetricFixture.metric(.hrv, 48, at: TestCalendar.time(dayOffset: 0, hour: 3)),
            HealthMetricFixture.metric(.hrv, 52, at: TestCalendar.time(dayOffset: 0, hour: 7)),
            HealthMetricFixture.metric(.restingHeartRate, 58, at: TestCalendar.time(dayOffset: 0, hour: 6)),
            HealthMetricFixture.metric(.sleep, 7.2, at: TestCalendar.time(dayOffset: 0, hour: 6)),
            HealthMetricFixture.metric(.steps, 9_400, at: TestCalendar.time(dayOffset: 0, hour: 21))
        ]

        let result = aggregator.aggregate(metrics: metrics, dataSource: .appleHealth, now: now)

        XCTAssertEqual(result.count, 1)
        let day = result[0]
        XCTAssertEqual(day.hrv?.value, 50)              // median(48, 52)
        XCTAssertEqual(day.restingHeartRate?.value, 58)
        XCTAssertEqual(day.sleepHours?.value, 7.2)
        XCTAssertEqual(day.steps?.value, 9_400)
        // 未提供指标的当天应为 nil，而不是 0
        XCTAssertNil(day.activeEnergyKcal)
        XCTAssertNil(day.exerciseMinutes)
    }

    // MARK: - 睡眠归属

    func test_sleepRecordedJustAfterMidnight_belongsToWakeDay() {
        // 23:00 入睡、06:30 醒来：HealthKitService 会把这条记录落在醒来日 06:30
        let sleep = HealthMetricFixture.metric(.sleep, 7.0, at: TestCalendar.time(dayOffset: 0, hour: 6, minute: 30))
        let previousDayHRV = HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: -1, hour: 22))

        let result = aggregator.aggregate(metrics: [sleep, previousDayHRV], dataSource: .appleHealth, now: now)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].day, TestCalendar.day(-1))
        XCTAssertNil(result[0].sleepHours)
        XCTAssertEqual(result[1].day, TestCalendar.day(0))
        XCTAssertEqual(result[1].sleepHours?.value, 7.0)
    }

    // MARK: - 缺口补齐

    func test_missingDaysAreFilledWithNilMetrics() {
        // 只有 day(-5) 和 day(-2) 有数据，now = day(0)
        let oldest = HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: -5, hour: 7))
        let recent = HealthMetricFixture.metric(.hrv, 41, at: TestCalendar.time(dayOffset: -2, hour: 7))

        let result = aggregator.aggregate(metrics: [oldest, recent], dataSource: .appleHealth, now: now)

        XCTAssertEqual(result.count, 6)                 // -5 ... 0
        XCTAssertEqual(result.map { $0.day }, (-5...0).map { TestCalendar.day($0) })
        XCTAssertEqual(result[0].hrv?.value, 45)
        XCTAssertNil(result[1].hrv)                     // -4 缺失
        XCTAssertNil(result[2].hrv)                     // -3 缺失
        XCTAssertEqual(result[3].hrv?.value, 41)
        XCTAssertNil(result[4].hrv)                     // -1 缺失
        XCTAssertNil(result[5].hrv)                     //  0 缺失
    }

    func test_filledDaysReportNoMetrics() {
        let only = HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: -3, hour: 7))
        let result = aggregator.aggregate(metrics: [only], dataSource: .appleHealth, now: now)

        XCTAssertTrue(result[0].hasAnyMetric)
        XCTAssertFalse(result[1].hasAnyMetric)
        XCTAssertFalse(result[2].hasAnyMetric)
    }

    // MARK: - 来源与溯源

    func test_demoSource_propagatesDemoProvenance() {
        let metrics = [HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: 0, hour: 7))]
        let result = aggregator.aggregate(metrics: metrics, dataSource: .demo, now: now)
        XCTAssertEqual(result[0].dataSource, .demo)
        XCTAssertEqual(result[0].hrv?.source, .demo)
        XCTAssertFalse(result[0].hrv?.isMeasured ?? true)
    }

    func test_appleHealthSource_propagatesMeasuredProvenance() {
        let metrics = [HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: 0, hour: 7))]
        let result = aggregator.aggregate(metrics: metrics, dataSource: .appleHealth, now: now)
        XCTAssertEqual(result[0].dataSource, .appleHealth)
        XCTAssertEqual(result[0].hrv?.source, .measured)
        XCTAssertTrue(result[0].hrv?.isMeasured ?? false)
    }

    // MARK: - 离群点

    func test_implausibleHRVIsDropped_notAveragedIn() {
        // 一个 400ms 的伪值不应把当天 HRV 拉高（旧的算术平均会）
        let metrics = [
            HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: 0, hour: 3)),
            HealthMetricFixture.metric(.hrv, 46, at: TestCalendar.time(dayOffset: 0, hour: 7)),
            HealthMetricFixture.metric(.hrv, 400, at: TestCalendar.time(dayOffset: 0, hour: 9))
        ]
        let result = aggregator.aggregate(metrics: metrics, dataSource: .appleHealth, now: now)
        XCTAssertEqual(result[0].hrv?.value, 45)        // median(44, 46)
        XCTAssertEqual(result[0].hrv?.sampleCount, 2)
    }

    // MARK: - 顺序

    func test_resultIsSortedAscendingByDay() {
        let metrics = [
            HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: -2, hour: 7)),
            HealthMetricFixture.metric(.hrv, 41, at: TestCalendar.time(dayOffset: 0, hour: 7)),
            HealthMetricFixture.metric(.hrv, 43, at: TestCalendar.time(dayOffset: -1, hour: 7))
        ]
        let result = aggregator.aggregate(metrics: metrics, dataSource: .appleHealth, now: now)
        let days = result.map { $0.day }
        XCTAssertEqual(days, days.sorted())
        XCTAssertEqual(result.compactMap { $0.hrv?.value }, [45, 43, 41])
    }

    // MARK: - 未来数据

    func test_futureData_extendsWindowToLatestDataDay() {
        // 数据跨越到"今天之后"时，窗口应延伸到最晚数据日
        let past = HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: -1, hour: 7))
        let future = HealthMetricFixture.metric(.hrv, 41, at: TestCalendar.time(dayOffset: 2, hour: 7))

        let result = aggregator.aggregate(metrics: [past, future], dataSource: .appleHealth, now: now)

        XCTAssertEqual(result.count, 4)                 // -1, 0, 1, 2
        XCTAssertEqual(result.first?.day, TestCalendar.day(-1))
        XCTAssertEqual(result.last?.day, TestCalendar.day(2))
        XCTAssertEqual(result.last?.hrv?.value, 41)
    }
}
