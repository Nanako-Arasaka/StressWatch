import XCTest
@testable import StressWatch
final class LocalStorageTests: XCTestCase {

    private var directory: URL!
    private var storage: LocalStorage!

    override func setUp() {
        super.setUp()
        // 每个用例一个独立临时目录，避免相互污染（Whoordan 测试同款做法）
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StressWatchTests-\(UUID().uuidString)", isDirectory: true)
        storage = LocalStorage(storageDirectory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    // MARK: - 写入与读取

    func test_emptyHistory_returnsEmptyArray() throws {
        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-30), to: TestCalendar.day(0))
        XCTAssertTrue(result.isEmpty)
    }

    func test_saveThenFetch_roundTrips() throws {
        let days = DailyHealthMetricsFixture.series(days: TestCalendar.recentDays(3))
        try storage.saveDailyMetrics(days)

        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-30), to: TestCalendar.day(0))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first?.day, TestCalendar.day(-2))
        XCTAssertEqual(result.last?.hrv?.value, days.last?.hrv?.value)
    }

    func test_savingSameDayTwice_doesNotDuplicate() throws {
        let first = DailyHealthMetricsFixture.series(days: [TestCalendar.day(0)])
        var updated = DailyHealthMetricsFixture.Blueprint()
        updated.hrv = 33
        let second = DailyHealthMetricsFixture.series(days: [TestCalendar.day(0)], updated)

        try storage.saveDailyMetrics(first)
        try storage.saveDailyMetrics(second)

        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-1), to: TestCalendar.day(1))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].hrv?.value, 33)      // 后写的覆盖先写的
    }

    func test_savingEmptyArray_isNoOp() throws {
        try storage.saveDailyMetrics(DailyHealthMetricsFixture.series(days: TestCalendar.recentDays(2)))
        try storage.saveDailyMetrics([])

        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-30), to: TestCalendar.day(0))
        XCTAssertEqual(result.count, 2)
    }

    func test_fetchRangeFiltersByDay() throws {
        try storage.saveDailyMetrics(DailyHealthMetricsFixture.series(days: TestCalendar.recentDays(10)))
        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-3), to: TestCalendar.day(-1))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first?.day, TestCalendar.day(-3))
        XCTAssertEqual(result.last?.day, TestCalendar.day(-1))
    }

    // MARK: - 跨实例持久化

    func test_dataSurvivesNewStorageInstance() throws {
        try storage.saveDailyMetrics(DailyHealthMetricsFixture.series(days: TestCalendar.recentDays(4)))

        let reopened = LocalStorage(storageDirectory: directory)
        let result = try reopened.fetchDailyMetrics(from: TestCalendar.day(-30), to: TestCalendar.day(0))
        XCTAssertEqual(result.count, 4)
    }

    // MARK: - 损坏恢复

    func test_corruptedFile_isBackedUpAndReturnsEmpty() throws {
        try storage.saveDailyMetrics(DailyHealthMetricsFixture.series(days: TestCalendar.recentDays(3)))

        // 人为写坏文件
        let fileURL = directory.appendingPathComponent("daily_metrics.json")
        try Data("not-json-at-all".utf8).write(to: fileURL)

        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-30), to: TestCalendar.day(0))
        XCTAssertTrue(result.isEmpty)

        // 必须留下备份，而不是静默清空
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(contents.contains { $0.hasPrefix("daily_metrics.corrupt-") })
    }

    // MARK: - Schema 演进

    func test_olderPayloadWithoutNewFields_stillDecodes() throws {
        // 模拟"旧版本写的文件"：只有少数字段，其余缺失
        let legacyJSON = """
        [
          {
            "day": "2025-10-16T00:00:00Z",
            "dataSource": "appleHealth",
            "hrv": { "value": 47, "unit": "ms", "source": "measured", "sampleCount": 2 }
          }
        ]
        """
        let fileURL = directory.appendingPathComponent("daily_metrics.json")
        try Data(legacyJSON.utf8).write(to: fileURL)

        let result = try storage.fetchDailyMetrics(from: TestCalendar.day(-1), to: TestCalendar.day(1))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].hrv?.value, 47)
        XCTAssertNil(result[0].sleepHours)             // 旧文件没有的字段取 nil，而不是整体失败
        XCTAssertTrue(result[0].workoutIntervals.isEmpty)
    }
}
