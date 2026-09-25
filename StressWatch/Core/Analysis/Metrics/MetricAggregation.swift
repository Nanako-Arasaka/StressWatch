import Foundation

/// 原始 `HealthMetric` 样本 → 单指标当日聚合值的纯函数集合。
///
/// 三条设计依据：
/// 1. **生理合法区间集中在一处**（参考 Whoordan 的 `isPlausible`），便于测试与调整，
///    避免区间判断散落在各个 engine 里。
/// 2. **样本数 0 时返回 nil，绝不返回 0**。缺失与"真的是 0"必须可区分。
/// 3. **HRV / HR 用中位数而非均值**，抗离群点（戴表不严、设备切换都会产生极端值）。
///
/// 只 import Foundation —— 与 Soma `Calculators/` 的纪律一致，
/// 这是本模块能被完整单测、且不依赖 HealthKit 授权的前提。
enum MetricAggregation {

    // MARK: - 生理合法区间

    /// SDNN 合理区间（ms）。低于 1ms 或高于 300ms 基本可判定为伪值。
    static let hrvRangeMs: ClosedRange<Double> = 1...300
    static let heartRateRangeBpm: ClosedRange<Double> = 25...240
    static let restingHRRangeBpm: ClosedRange<Double> = 25...180
    /// 睡眠时长（h）。下界取 0.01 而非 0：0 小时睡眠等价于"没有睡眠记录"。
    static let sleepHoursRange: ClosedRange<Double> = 0.01...24
    static let stepsRange: ClosedRange<Double> = 0...200_000
    static let energyRangeKcal: ClosedRange<Double> = 0...10_000
    static let exerciseRangeMin: ClosedRange<Double> = 0...1_440
    static let standRangeHours: ClosedRange<Double> = 0...24

    // MARK: - 归约方式

    enum MetricReducer {
        case median
        case minimum
        case maximum
    }

    // MARK: - 统计基元

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// 过滤掉非有限值与生理区间外的值。
    static func plausibleValues(_ values: [Double], in range: ClosedRange<Double>) -> [Double] {
        values.filter { $0.isFinite && range.contains($0) }
    }

    // MARK: - 聚合入口

    /// 高频采样指标（HR / HRV）按天归约。
    ///
    /// - Parameters:
    ///   - samples: 同一天、同一 `MetricType` 的原始样本。
    ///   - window: 可选时间窗（如睡眠窗口）。传入时优先使用窗内样本；
    ///             **窗内无有效样本则回退到全天**（Soma `sleepingHRV ?? todayHRV` 的思路），
    ///             避免因为作息不在预期窗口内就整日无值。
    ///   - reducer: 归约方式，默认中位数。
    /// - Returns: 无有效样本时返回 nil。
    static func sampled(
        _ samples: [HealthMetric],
        unit: String,
        range: ClosedRange<Double>,
        provenance: MetricProvenance,
        window: ClosedRange<Date>? = nil,
        reducer: MetricReducer = .median
    ) -> MetricSample? {
        guard !samples.isEmpty else { return nil }

        var used = samples
        var narrowed = false
        if let window {
            let inWindow = samples.filter { window.contains($0.date) }
            if !inWindow.isEmpty {
                used = inWindow
                narrowed = true
            }
        }

        var values = plausibleValues(used.map(\.value), in: range)
        if values.isEmpty && narrowed {
            // 窗内样本全部越界 → 回退到全天（Soma `sleepingHRV ?? todayHRV` 的语义：
            // 回退发生在"拿不到有效值"时，而不只是"窗口内没有样本"时）。
            used = samples
            values = plausibleValues(used.map(\.value), in: range)
        }
        guard !values.isEmpty else { return nil }

        let reduced: Double?
        switch reducer {
        case .median: reduced = median(values)
        case .minimum: reduced = values.min()
        case .maximum: reduced = values.max()
        }
        guard let value = reduced else { return nil }

        return MetricSample(value: value, unit: unit, source: provenance, sampleCount: values.count)
    }

    /// 日累计 / 单值指标：取当日最新一条。
    ///
    /// 适用：静息心率、睡眠时长与各分期、步数、活动能量、运动分钟、站立小时。
    /// `HealthKitService` 对这些指标已按天聚合（一天一条，落在 `endOfDay`），
    /// 因此取最新值即为当日值；`MockHealthKitService` 的步数是累计快照序列，
    /// 取最新值同样得到当日总量。
    static func latest(
        _ samples: [HealthMetric],
        unit: String,
        range: ClosedRange<Double>,
        provenance: MetricProvenance
    ) -> MetricSample? {
        guard let last = samples.max(by: { $0.date < $1.date }) else { return nil }
        guard last.value.isFinite, range.contains(last.value) else { return nil }
        return MetricSample(value: last.value, unit: unit, source: provenance, sampleCount: 1)
    }
}
