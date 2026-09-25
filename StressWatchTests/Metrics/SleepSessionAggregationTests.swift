import XCTest
@testable import StressWatch
final class SleepSessionAggregationTests: XCTestCase {

    private let calendar = TestCalendar.utc
    private lazy var aggregator = DailyMetricsAggregator(calendar: calendar)
    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 睡眠区间

    func test_bedtimeAndWakeTimeArePopulatedFromSleepSession() {
        let session = SleepSession(
            day: TestCalendar.day(0),
            bedtime: TestCalendar.time(dayOffset: -1, hour: 23, minute: 15),
            wakeTime: TestCalendar.time(dayOffset: 0, hour: 7, minute: 5),
            asleepHours: 7.5
        )
        let hrv = HealthMetricFixture.metric(.hrv, 48, at: TestCalendar.time(dayOffset: 0, hour: 6))

        let result = aggregator.aggregate(
            metrics: [hrv], dataSource: .appleHealth, now: now,
            sleepSessions: [session], workoutIntervals: []
        )

        XCTAssertEqual(result[0].bedtime, session.bedtime)
        XCTAssertEqual(result[0].wakeTime, session.wakeTime)
    }

    func test_sleepWindowIsDerivedFromSession() {
        let session = SleepSession(
            day: TestCalendar.day(0),
            bedtime: TestCalendar.time(dayOffset: -1, hour: 23),
            wakeTime: TestCalendar.time(dayOffset: 0, hour: 7),
            asleepHours: 8
        )
        XCTAssertTrue(session.window.contains(TestCalendar.time(dayOffset: -1, hour: 23, minute: 30)))
        XCTAssertFalse(session.window.contains(TestCalendar.time(dayOffset: 0, hour: 12)))
    }

    func test_hrvPrefersSleepingWindowOverDaytime() {
        // 夜间 45ms（真实副交感读数），白天因活动降到 30ms。
        // 若不做睡眠期取样，会误判为"HRV 显著低于基线"。
        let night = HealthMetricFixture.series(.hrv, values: [44, 46], dayOffset: -1, hours: [23, 23])
        let nightFixed = [
            HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: -1, hour: 23, minute: 10)),
            HealthMetricFixture.metric(.hrv, 46, at: TestCalendar.time(dayOffset: -1, hour: 23, minute: 50))
        ]
        _ = night
        let day = [
            HealthMetricFixture.metric(.hrv, 30, at: TestCalendar.time(dayOffset: 0, hour: 9)),
            HealthMetricFixture.metric(.hrv, 28, at: TestCalendar.time(dayOffset: 0, hour: 15))
        ]
        let session = SleepSession(
            day: TestCalendar.day(0),
            bedtime: TestCalendar.time(dayOffset: -1, hour: 23),
            wakeTime: TestCalendar.time(dayOffset: 0, hour: 7),
            asleepHours: 8
        )

        let result = aggregator.aggregate(
            metrics: nightFixed + day, dataSource: .appleHealth, now: now,
            sleepSessions: [session], workoutIntervals: []
        )

        XCTAssertEqual(result[0].hrv?.value, 45)      // median(44, 46)，白天样本未被计入
        XCTAssertEqual(result[0].hrv?.sampleCount, 2)
    }

    func test_hrvFallsBackToWholeDayWhenNoSleepSession() {
        let day = [
            HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: 0, hour: 9)),
            HealthMetricFixture.metric(.hrv, 46, at: TestCalendar.time(dayOffset: 0, hour: 15))
        ]
        let result = aggregator.aggregate(metrics: day, dataSource: .appleHealth, now: now)
        XCTAssertEqual(result[0].hrv?.value, 45)
        XCTAssertNil(result[0].bedtime)
        XCTAssertNil(result[0].wakeTime)
    }

    // MARK: - 运动区间

    func test_workoutIntervalsAreAssignedToOverlappingDays() {
        let workouts = [
            WorkoutInterval(
                start: TestCalendar.time(dayOffset: -1, hour: 20),
                end: TestCalendar.time(dayOffset: -1, hour: 21)
            )
        ]
        let metrics = [
            HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: -1, hour: 7)),
            HealthMetricFixture.metric(.hrv, 43, at: TestCalendar.time(dayOffset: 0, hour: 7))
        ]

        let result = aggregator.aggregate(
            metrics: metrics, dataSource: .appleHealth, now: now,
            sleepSessions: [], workoutIntervals: workouts
        )

        XCTAssertEqual(result[0].workoutIntervals.count, 1)
        XCTAssertTrue(result[1].workoutIntervals.isEmpty)
    }

    func test_workoutSpanningMidnightAppearsOnBothDays() {
        // 23:30 开始、00:30 结束的夜跑：两天都需要它来做 sedentary 过滤
        let workouts = [
            WorkoutInterval(
                start: TestCalendar.time(dayOffset: -1, hour: 23, minute: 30),
                end: TestCalendar.time(dayOffset: 0, hour: 0, minute: 30)
            )
        ]
        let metrics = [
            HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: -1, hour: 7)),
            HealthMetricFixture.metric(.hrv, 43, at: TestCalendar.time(dayOffset: 0, hour: 7))
        ]

        let result = aggregator.aggregate(
            metrics: metrics, dataSource: .appleHealth, now: now,
            sleepSessions: [], workoutIntervals: workouts
        )

        XCTAssertEqual(result[0].workoutIntervals.count, 1)
        XCTAssertEqual(result[1].workoutIntervals.count, 1)
    }

    func test_noWorkouts_leavesEmptyIntervals() {
        let metrics = [HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: 0, hour: 7))]
        let result = aggregator.aggregate(metrics: metrics, dataSource: .appleHealth, now: now)
        XCTAssertTrue(result[0].workoutIntervals.isEmpty)
    }

    // MARK: - 便捷入口

    func test_convenienceEntryPointMatchesFullEntryPoint() {
        let metrics = [HealthMetricFixture.metric(.hrv, 45, at: TestCalendar.time(dayOffset: 0, hour: 7))]
        let viaProtocol: [DailyHealthMetrics] = aggregator.aggregate(
            metrics: metrics, dataSource: .appleHealth, now: now,
            sleepSessions: [], workoutIntervals: []
        )
        let viaConvenience = aggregator.aggregate(metrics: metrics, dataSource: .appleHealth, now: now)
        XCTAssertEqual(viaProtocol, viaConvenience)
    }
}
