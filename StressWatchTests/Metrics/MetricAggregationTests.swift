import XCTest
@testable import StressWatch
final class MetricAggregationTests: XCTestCase {

    // MARK: - median

    func test_median_empty_returnsNil() {
        XCTAssertNil(MetricAggregation.median([]))
    }

    func test_median_singleValue() {
        XCTAssertEqual(MetricAggregation.median([42]), 42)
    }

    func test_median_oddCount() {
        XCTAssertEqual(MetricAggregation.median([30, 50, 40]), 40)
    }

    func test_median_evenCount_averagesMiddleTwo() {
        XCTAssertEqual(MetricAggregation.median([10, 40]), 25)
    }

    func test_median_isOrderIndependent() {
        XCTAssertEqual(MetricAggregation.median([50, 10, 30]), MetricAggregation.median([10, 30, 50]))
    }

    // MARK: - plausibleValues

    func test_plausibleValues_dropsOutOfRangeSamples() {
        let result = MetricAggregation.plausibleValues([40, 500, 20], in: MetricAggregation.hrvRangeMs)
        XCTAssertEqual(result, [40, 20])
    }

    func test_plausibleValues_dropsNonFinite() {
        let result = MetricAggregation.plausibleValues([.nan, .infinity, 45], in: MetricAggregation.hrvRangeMs)
        XCTAssertEqual(result, [45])
    }

    func test_plausibleValues_keepsBoundaries() {
        let result = MetricAggregation.plausibleValues([1, 300], in: MetricAggregation.hrvRangeMs)
        XCTAssertEqual(result, [1, 300])
    }

    // MARK: - sampled

    func test_sampled_noSamples_returnsNil() {
        XCTAssertNil(MetricAggregation.sampled([], unit: "ms", range: 1...300, provenance: .measured))
    }

    func test_sampled_allValuesImplausible_returnsNil() {
        let samples = HealthMetricFixture.series(.hrv, values: [400, 0.2], dayOffset: 0, hours: [7, 8])
        XCTAssertNil(MetricAggregation.sampled(samples, unit: "ms", range: MetricAggregation.hrvRangeMs, provenance: .measured))
    }

    func test_sampled_usesMedianAndCountsOnlyPlausibleValues() {
        let samples = HealthMetricFixture.series(.hrv, values: [40, 500, 60], dayOffset: 0, hours: [7, 8, 9])
        let result = MetricAggregation.sampled(samples, unit: "ms", range: MetricAggregation.hrvRangeMs, provenance: .measured)
        XCTAssertEqual(result?.value, 50)          // median(40, 60)
        XCTAssertEqual(result?.sampleCount, 2)     // 500 被剔除
        XCTAssertEqual(result?.unit, "ms")
        XCTAssertEqual(result?.source, .measured)
    }

    func test_sampled_windowPrefersInWindowSamples() {
        // 白天 3 条 + 凌晨 2 条；窗口只覆盖凌晨
        let day = HealthMetricFixture.series(.hrv, values: [80, 90, 100], dayOffset: 0, hours: [9, 14, 20])
        let night = HealthMetricFixture.series(.hrv, values: [50, 60], dayOffset: 0, hours: [2, 4])
        let window = TestCalendar.time(dayOffset: 0, hour: 1)...TestCalendar.time(dayOffset: 0, hour: 6)

        let result = MetricAggregation.sampled(
            day + night, unit: "ms", range: MetricAggregation.hrvRangeMs,
            provenance: .measured, window: window
        )
        XCTAssertEqual(result?.value, 55)          // median(50, 60)，白天的高值未被计入
        XCTAssertEqual(result?.sampleCount, 2)
    }

    func test_sampled_windowWithNoValidSample_fallsBackToWholeDay() {
        // 窗口内只有一条越界值 → 回退到全天（Soma sleepingHRV ?? todayHRV）
        let inWindow = [HealthMetricFixture.metric(.hrv, 999, at: TestCalendar.time(dayOffset: 0, hour: 3))]
        let outside = [HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: 0, hour: 15))]
        let window = TestCalendar.time(dayOffset: 0, hour: 1)...TestCalendar.time(dayOffset: 0, hour: 6)

        let result = MetricAggregation.sampled(
            inWindow + outside, unit: "ms", range: MetricAggregation.hrvRangeMs,
            provenance: .measured, window: window
        )
        XCTAssertEqual(result?.value, 44)
    }

    func test_sampled_emptyWindow_fallsBackToWholeDay() {
        let samples = [HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: 0, hour: 15))]
        let window = TestCalendar.time(dayOffset: 0, hour: 1)...TestCalendar.time(dayOffset: 0, hour: 6)
        let result = MetricAggregation.sampled(
            samples, unit: "ms", range: MetricAggregation.hrvRangeMs,
            provenance: .measured, window: window
        )
        XCTAssertEqual(result?.value, 44)
    }

    func test_sampled_reducerMinimum() {
        let samples = HealthMetricFixture.series(.heartRate, values: [70, 58, 96], dayOffset: 0, hours: [8, 12, 18])
        let result = MetricAggregation.sampled(
            samples, unit: "bpm", range: MetricAggregation.heartRateRangeBpm,
            provenance: .measured, reducer: .minimum
        )
        XCTAssertEqual(result?.value, 58)
    }

    func test_sampled_reducerMaximum() {
        let samples = HealthMetricFixture.series(.heartRate, values: [70, 58, 96], dayOffset: 0, hours: [8, 12, 18])
        let result = MetricAggregation.sampled(
            samples, unit: "bpm", range: MetricAggregation.heartRateRangeBpm,
            provenance: .measured, reducer: .maximum
        )
        XCTAssertEqual(result?.value, 96)
    }

    // MARK: - latest

    func test_latest_noSamples_returnsNil() {
        XCTAssertNil(MetricAggregation.latest([], unit: "bpm", range: 25...180, provenance: .measured))
    }

    func test_latest_picksMostRecentSample() {
        let older = HealthMetricFixture.metric(.restingHeartRate, 70, at: TestCalendar.time(dayOffset: 0, hour: 6))
        let newer = HealthMetricFixture.metric(.restingHeartRate, 63, at: TestCalendar.time(dayOffset: 0, hour: 9))
        let result = MetricAggregation.latest(
            [newer, older], unit: "bpm", range: MetricAggregation.restingHRRangeBpm, provenance: .measured
        )
        XCTAssertEqual(result?.value, 63)
    }

    func test_latest_outOfRange_returnsNil() {
        let sample = HealthMetricFixture.metric(.restingHeartRate, 400, at: TestCalendar.time(dayOffset: 0, hour: 6))
        XCTAssertNil(MetricAggregation.latest(
            [sample], unit: "bpm", range: MetricAggregation.restingHRRangeBpm, provenance: .measured
        ))
    }

    func test_latest_zeroSleepTreatedAsMissing() {
        // 睡眠下界为 0.01h：0 小时等价于"没有睡眠记录"，不能当作有效值
        let sample = HealthMetricFixture.metric(.sleep, 0, at: TestCalendar.time(dayOffset: 0, hour: 6))
        XCTAssertNil(MetricAggregation.latest(
            [sample], unit: "hours", range: MetricAggregation.sleepHoursRange, provenance: .measured
        ))
    }

    // MARK: - provenance

    func test_provenanceIsPropagated() {
        let samples = [HealthMetricFixture.metric(.hrv, 44, at: TestCalendar.time(dayOffset: 0, hour: 3))]
        let result = MetricAggregation.sampled(
            samples, unit: "ms", range: MetricAggregation.hrvRangeMs, provenance: .demo
        )
        XCTAssertEqual(result?.source, .demo)
        XCTAssertFalse(result?.isMeasured ?? true)
    }
}
