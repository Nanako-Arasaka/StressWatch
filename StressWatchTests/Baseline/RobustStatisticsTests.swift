import XCTest
@testable import StressWatch

final class RobustStatisticsTests: XCTestCase {

    // MARK: - median

    func test_median_empty_returnsNil() {
        XCTAssertNil(RobustStatistics.median([]))
    }

    func test_median_singleValue() {
        XCTAssertEqual(RobustStatistics.median([42]), 42)
    }

    func test_median_oddCount() {
        XCTAssertEqual(RobustStatistics.median([3, 1, 2]), 2)
    }

    func test_median_evenCount_averagesMiddleTwo() {
        XCTAssertEqual(RobustStatistics.median([4, 1, 3, 2]), 2.5)
    }

    func test_median_isOrderIndependent() {
        XCTAssertEqual(
            RobustStatistics.median([9, 1, 5, 3]),
            RobustStatistics.median([1, 3, 5, 9])
        )
    }

    func test_median_ignoresNonFinite() {
        XCTAssertEqual(RobustStatistics.median([1, .nan, 3, .infinity, 2]), 2)
    }

    // MARK: - stddev

    func test_stddev_emptyOrSingle_returnsNil() {
        XCTAssertNil(RobustStatistics.stddev([]))
        XCTAssertNil(RobustStatistics.stddev([5]))
    }

    func test_stddev_allEqual_returnsNil() {
        XCTAssertNil(RobustStatistics.stddev([50, 50, 50, 50]))
    }

    func test_stddev_knownSequence() {
        // [2,4,4,4,5,5,7,9] sample SD = 2.138...
        let sd = RobustStatistics.stddev([2, 4, 4, 4, 5, 5, 7, 9])
        XCTAssertNotNil(sd)
        XCTAssertEqual(sd!, 2.13809, accuracy: 0.001)
    }

    // MARK: - mad

    func test_mad_empty_returnsNil() {
        XCTAssertNil(RobustStatistics.mad([]))
    }

    func test_mad_allEqual_returnsNil() {
        // 全等值 → 中位绝对偏差为 0 → nil（无法做 z）
        XCTAssertNil(RobustStatistics.mad([50, 50, 50]))
    }

    func test_mad_knownSequence() {
        // median=3, deviations=[2,1,0,1,2], medianDev=1, mad=1*1.4826
        let result = RobustStatistics.mad([1, 2, 3, 4, 5])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.4826, accuracy: 0.0001)
    }

    // MARK: - robustZ

    func test_robustZ_nilWhenNoSpread() {
        XCTAssertNil(RobustStatistics.robustZ(60, in: Array(repeating: 50.0, count: 7)))
    }

    func test_robustZ_nilWhenBaselineEmpty() {
        XCTAssertNil(RobustStatistics.robustZ(60, in: []))
    }

    func test_robustZ_atCenter_isZero() {
        let baseline: [Double] = [10, 20, 30, 40, 50]
        let z = RobustStatistics.robustZ(30, in: baseline)
        XCTAssertNotNil(z)
        XCTAssertEqual(z!, 0, accuracy: 0.01)
    }

    func test_robustZ_aboveCenter_isPositive() {
        let z = RobustStatistics.robustZ(50, in: [10, 20, 30, 40, 50] as [Double])
        XCTAssertNotNil(z)
        XCTAssertGreaterThan(z!, 0)
    }

    // MARK: - logDomainStats / logZScore

    func test_logDomainStats_emptyOrSingle_returnsNil() {
        XCTAssertNil(RobustStatistics.logDomainStats([]))
        XCTAssertNil(RobustStatistics.logDomainStats([50.0]))
    }

    func test_logDomainStats_zeroVariance_returnsNil() {
        // Soma 的 test_hrvZScore_nilWhenNoSpread 必抄
        XCTAssertNil(RobustStatistics.logDomainStats([50.0, 50, 50, 50, 50, 50, 50]))
    }

    func test_logDomainStats_rejectsNonPositive() {
        XCTAssertNil(RobustStatistics.logDomainStats([0.0, -5, 50]))
    }

    func test_logZScore_nilWhenNoSpread() {
        XCTAssertNil(RobustStatistics.logZScore(60, history: Array(repeating: 50.0, count: 7)))
    }

    func test_logZScore_nilWhenTodayNonPositive() {
        let history: [Double] = [40, 45, 50, 55, 60]
        XCTAssertNil(RobustStatistics.logZScore(0, history: history))
        XCTAssertNil(RobustStatistics.logZScore(-10, history: history))
    }

    func test_logZScore_aboveMean_isPositive() {
        let history: [Double] = [40, 45, 50, 55, 60]
        let z = RobustStatistics.logZScore(80, history: history)
        XCTAssertNotNil(z)
        XCTAssertGreaterThan(z!, 0)
    }

    func test_logZScore_belowMean_isNegative() {
        let history: [Double] = [40, 45, 50, 55, 60]
        let z = RobustStatistics.logZScore(25, history: history)
        XCTAssertNotNil(z)
        XCTAssertLessThan(z!, 0)
    }

    /// EWMA 近因性：把最新值改高后，中心应被拉高（比算术均值更敏感于近期）。
    func test_logDomainStats_ewmaIsRecencyWeighted() {
        let base = [50.0, 50, 50, 50, 50, 50, 50]
        // 最后一天 HRV 飙到 100
        let spiked = [50.0, 50, 50, 50, 50, 50, 100]

        let baseStats = RobustStatistics.logDomainStats(Array(base.dropLast()) + [51])
        let spikedStats = RobustStatistics.logDomainStats(spiked)
        XCTAssertNotNil(baseStats)
        XCTAssertNotNil(spikedStats)

        // exp(ewma) —— spiked 的中心应高于平稳序列
        let baseCenter = exp(baseStats!.meanLn)
        let spikedCenter = exp(spikedStats!.meanLn)
        XCTAssertGreaterThan(spikedCenter, baseCenter)
    }

    // MARK: - percentile / p75

    func test_percentile_empty_returnsNil() {
        XCTAssertNil(RobustStatistics.percentile([], 0.5))
    }

    func test_percentile_singleValue() {
        XCTAssertEqual(RobustStatistics.percentile([42], 0.75), 42)
    }

    func test_percentile_median() {
        XCTAssertEqual(RobustStatistics.percentile([1, 2, 3, 4, 5], 0.5), 3)
    }

    func test_p75_ofLinearSequence() {
        // [1...10]，P75 线性插值 ≈ 7.75
        let values = (1...10).map(Double.init)
        let p = RobustStatistics.p75(values)
        XCTAssertNotNil(p)
        XCTAssertEqual(p!, 7.75, accuracy: 0.01)
    }

    /// Thump 的核心回归：压力螺旋（HRV 50→25）下 P75 不被拖到很低。
    func test_p75_notDraggedDownByStressSpiral() {
        // 14 天从 50 递减到 25，模拟长期压力
        let spiral = (0..<14).map { 50.0 - Double($0) * (25.0 / 13.0) }
        let p = RobustStatistics.p75(spiral)
        XCTAssertNotNil(p)
        // P75 应仍靠近"好日子"水平（≈42+），而不是中位数≈37
        XCTAssertGreaterThan(p!, 40)
    }

    // MARK: - dropOutliers

    func test_dropOutliers_tooFewSamples_returnsAsIs() {
        let values = [1.0, 2.0]
        XCTAssertEqual(RobustStatistics.dropOutliers(values, method: .mad3Sigma), values)
    }

    func test_dropOutliers_mad3Sigma_removesSingleExtreme() {
        let values = [50.0, 51, 49, 52, 48, 200] // 200 是极端值
        let cleaned = RobustStatistics.dropOutliers(values, method: .mad3Sigma)
        XCTAssertFalse(cleaned.contains(200))
        XCTAssertEqual(cleaned.count, 5)
    }

    func test_dropOutliers_iqr_removesExtreme() {
        let values = [10.0, 11, 12, 13, 14, 15, 100]
        let cleaned = RobustStatistics.dropOutliers(values, method: .iqr)
        XCTAssertFalse(cleaned.contains(100))
    }

    func test_dropOutliers_keepsInliers() {
        let values = [48.0, 50, 52, 49, 51]
        let cleaned = RobustStatistics.dropOutliers(values, method: .mad3Sigma)
        XCTAssertEqual(cleaned.count, 5)
    }
}
