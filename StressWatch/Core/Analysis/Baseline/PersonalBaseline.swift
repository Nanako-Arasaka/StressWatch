import Foundation

// MARK: - 指标与方法

/// 可建立个人基线的指标维度。
enum BaselineMetric: String, Codable, CaseIterable {
    case hrv
    case restingHeartRate
    case sleepHours
    case sleepREMHours
    case sleepDeepHours
    case steps
    case activeEnergyKcal
    case exerciseMinutes
    case standHours

    var displayName: String {
        switch self {
        case .hrv: return "HRV"
        case .restingHeartRate: return "静息心率"
        case .sleepHours: return "睡眠时长"
        case .sleepREMHours: return "REM 睡眠"
        case .sleepDeepHours: return "深睡"
        case .steps: return "步数"
        case .activeEnergyKcal: return "活动能量"
        case .exerciseMinutes: return "运动时间"
        case .standHours: return "站立时间"
        }
    }

    /// 核心四项：完整度计算与 UI 优先展示以它们为准。
    static var coreMetrics: [BaselineMetric] {
        [.hrv, .restingHeartRate, .sleepHours, .steps]
    }
}

/// 基线中心值的计算方法。
enum BaselineMethod: String, Codable {
    /// 中位数 + MAD。RHR / Sleep / 活动类。
    case median
    /// log 域 EWMA + 样本 SD。HRV 专用（对数正态 + 近因加权）。
    case logEWMA
    /// 75 分位。HRV 锚点，抗"长期压力把基线拖低"（Thump）。
    case p75
}

// MARK: - PersonalBaseline

/// 单指标的个人基线：中心值 + 离散度 + 样本量 + 校准进度。
///
/// 与旧 `Baseline` 的区别：
/// - 旧结构只有均值，没有变异度、没有样本量门槛、缺失写 0。
/// - 这里 `dispersion == nil` 或 `sampleDays < requiredDays` 时 `isReliable == false`，
///   `zScore(of:)` 返回 nil —— **调用方必须处理 nil，不许默认 0 或回退"正常"**。
struct PersonalBaseline: Codable, Equatable {
    let metric: BaselineMetric
    /// 参与计算的窗口天数（7 / 14 / 30）。
    let windowDays: Int
    /// 中心值（中位数 / log-EWMA 还原值 / P75）。
    let value: Double
    /// 离散度（MAD×1.4826 / log 域 sdLn）。无变异时为 nil。
    let dispersion: Double?
    /// 实际参与的有效天数（非 nil 样本的天数）。
    let sampleDays: Int
    /// 该指标要求的最少天数。
    let requiredDays: Int
    let computedAt: Date
    let method: BaselineMethod
    /// HRV 专用锚点：P75（"好日子"水平），用于 UI 比值展示。其余指标为 nil。
    let anchorP75: Double?

    init(
        metric: BaselineMetric,
        windowDays: Int,
        value: Double,
        dispersion: Double?,
        sampleDays: Int,
        requiredDays: Int,
        computedAt: Date,
        method: BaselineMethod,
        anchorP75: Double? = nil
    ) {
        self.metric = metric
        self.windowDays = windowDays
        self.value = value
        self.dispersion = dispersion
        self.sampleDays = sampleDays
        self.requiredDays = requiredDays
        self.computedAt = computedAt
        self.method = method
        self.anchorP75 = anchorP75
    }

    /// 可靠基线：样本天数达标 **且** 存在正的变异度。
    /// 变异度为 0 / nil 时无法判断"这次偏离是否异常"，一律视为不可靠。
    var isReliable: Bool {
        sampleDays >= requiredDays && (dispersion ?? 0) > 0
    }

    /// 校准进度 0...1。UI 可显示"还需 N 天完成校准"。
    var calibrationProgress: Double {
        guard requiredDays > 0 else { return 1 }
        return min(1, Double(sampleDays) / Double(requiredDays))
    }

    var daysRemaining: Int {
        max(requiredDays - sampleDays, 0)
    }

    /// 稳健 z 值。基线不可靠时返回 nil —— **绝不返回 0 冒充"无偏离"**。
    ///
    /// - `method == .logEWMA` 时用 log 域 z（对 HRV 的对数正态分布更正确）。
    /// - 其余方法用 `(value - center) / dispersion`。
    func zScore(of value: Double) -> Double? {
        guard isReliable, value.isFinite, let dispersion, dispersion > 0 else {
            return nil
        }
        switch method {
        case .logEWMA:
            guard value > 0 else { return nil }
            return (log(value) - log(self.value)) / dispersion
        case .median, .p75:
            return (value - self.value) / dispersion
        }
    }

    /// 相对偏离百分比：`(value - baseline) / baseline * 100`。
    /// 基线值 ≤ 0 或样本不足时返回 nil。
    func deviationPercent(of value: Double) -> Double? {
        guard sampleDays > 0, value.isFinite, value > 0 || self.value > 0 else { return nil }
        let base = self.value
        guard abs(base) > 1e-9 else { return nil }
        return (value - base) / base * 100
    }
}

// MARK: - PersonalBaselineSet

/// 一组指标的个人基线。缺某个指标时对应字段为"不可靠的空壳"或由引擎填入。
struct PersonalBaselineSet: Codable, Equatable {
    let hrv: PersonalBaseline
    let restingHeartRate: PersonalBaseline
    let sleepHours: PersonalBaseline
    let steps: PersonalBaseline
    let activeEnergyKcal: PersonalBaseline
    let exerciseMinutes: PersonalBaseline
    let standHours: PersonalBaseline

    /// 核心指标的短板天数（Whoordan `coreDayCount`）：取最小而非平均。
    var coreDayCount: Int {
        min(hrv.sampleDays, restingHeartRate.sampleDays, sleepHours.sampleDays)
    }

    /// 是否至少核心指标都达到可靠门槛。
    var isReliable: Bool {
        hrv.isReliable && restingHeartRate.isReliable && sleepHours.isReliable
    }

    /// 生成旧 `Baseline` 结构，供 `PersonalizationContext` / `LocalStorage` 继续使用，
    /// 不破坏现有调用方。字段从各指标中心值映射；缺样本的指标写 0（旧结构的约定）。
    func legacyBaseline() -> Baseline {
        Baseline(
            avgHR: restingHeartRate.value, // 旧 avgHR 用的是 heartRate 样本均值，这里退而用 RHR 中心
            avgHRV: hrv.value,
            avgRestingHR: restingHeartRate.value,
            avgDailySteps: steps.value,
            avgSleepHours: sleepHours.value,
            calculatedAt: max(
                hrv.computedAt,
                restingHeartRate.computedAt,
                sleepHours.computedAt
            ),
            dataWindowDays: coreDayCount
        )
    }
}
