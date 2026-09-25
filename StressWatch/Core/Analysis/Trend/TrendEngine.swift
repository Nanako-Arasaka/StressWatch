import Foundation

// MARK: - TrendDirection

/// 趋势五态（用户要求，Thump 只有三态）。
enum TrendDirection: String, Codable {
    case improving
    case stable
    case declining
    case volatile
    case insufficientData

    var displayName: String {
        switch self {
        case .improving: return "改善"
        case .stable: return "平稳"
        case .declining: return "下降"
        case .volatile: return "波动"
        case .insufficientData: return "数据不足"
        }
    }
}

/// 趋势窗口。
enum TrendWindow: String, Codable, CaseIterable {
    case days7
    case days14
    case days30

    var days: Int {
        switch self {
        case .days7: return 7
        case .days14: return 14
        case .days30: return 30
        }
    }

    var displayName: String {
        switch self {
        case .days7: return "近 7 天"
        case .days14: return "近 14 天"
        case .days30: return "近 30 天"
        }
    }
}

// MARK: - MetricTrend

/// 单指标在一个窗口内的趋势结论。
struct MetricTrend: Codable, Equatable {
    let metric: BaselineMetric
    let window: TrendWindow
    let direction: TrendDirection
    let currentValue: Double?
    let baselineValue: Double?
    let deviationPercent: Double?
    let slopePerDay: Double?
    let robustZ: Double?
    /// 变异系数 CV = residualStd / mean。
    let volatility: Double?
    let sampleCount: Int
    let minimumRequired: Int

    /// 是否可展示（数据充足）。
    var isDisplayable: Bool {
        direction != .insufficientData
    }

    /// 还需几天才有足够数据。
    var daysRemaining: Int {
        max(minimumRequired - sampleCount, 0)
    }
}

// MARK: - TrendEngine

/// 趋势引擎：对 `[DailyHealthMetrics]` 中某个指标做五态判定。
///
/// 判定顺序（综合 Thump + Soma）：
/// 1. sampleCount < minimumRequired → .insufficientData（**不再造数据**）
/// 2. baselineStd < 死区(0.5) → .stable（防除零/防噪声放大）
/// 3. |robustZ| > 2.0 → 用 z 符号定 improving/declining
/// 4. OLS 斜率（只对坏方向敏感，Thump 法）
/// 5. 前后段均值差（Soma 法，±3 死区）
/// 6. volatility CV > 0.25 → .volatile（覆盖上面任何结论）
/// 7. 否则 → .stable
///
/// 只 `import Foundation`，纯函数。
struct TrendEngine {

    /// 判定为趋势所需的最少样本天数。
    static let minimumSamples = 7
    /// 噪声死区：基线标准差低于此值视为无变异。
    static let noiseDeadzoneStd: Double = 0.5
    /// robustZ 显著阈值。
    static let significantZ: Double = 2.0
    /// OLS 斜率阈值（每天变化量）。指标语义不同方向不同。
    static let slopeThresholdPerDay: Double = 0.3
    /// 前后段均值差死区。
    static let halfDeltaDeadzone: Double = 3.0
    /// 高波动阈值（CV）。
    static let volatileCV: Double = 0.25

    // MARK: - Public

    func trend(
        metric: BaselineMetric,
        history: [DailyHealthMetrics],
        window: TrendWindow,
        baseline: PersonalBaseline?,
        now: Date,
        calendar: Calendar = .current
    ) -> MetricTrend {
        let values = extractValues(metric: metric, history: history, window: window, now: now, calendar: calendar)
        let sampleCount = values.count

        guard sampleCount >= Self.minimumSamples else {
            return MetricTrend(
                metric: metric, window: window, direction: .insufficientData,
                currentValue: values.last, baselineValue: baseline?.value,
                deviationPercent: baseline?.value != nil
                    ? (values.last).flatMap { v in baseline!.deviationPercent(of: v) }
                    : nil,
                slopePerDay: nil, robustZ: nil, volatility: nil,
                sampleCount: sampleCount, minimumRequired: Self.minimumSamples
            )
        }

        // 当前值 = 最后一个样本
        let current = values.last
        let baselineValue = baseline?.value
        let deviation = current.flatMap { v in baseline?.deviationPercent(of: v) }

        // 波动性
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let std = sqrt(variance)
        let cv = mean != 0 ? abs(std / mean) : 0

        // 2. 噪声死区
        if std < Self.noiseDeadzoneStd {
            return MetricTrend(
                metric: metric, window: window, direction: .stable,
                currentValue: current, baselineValue: baselineValue,
                deviationPercent: deviation, slopePerDay: 0,
                robustZ: 0, volatility: cv,
                sampleCount: sampleCount, minimumRequired: Self.minimumSamples
            )
        }

        // 3. Robust Z（用历史自身做参考）
        let z = RobustStatistics.robustZ(values.last ?? 0, in: values)

        // 4. OLS 斜率
        let slope = olsSlope(values)

        // 5. 前后段均值
        let mid = values.count / 2
        let firstHalf = Array(values.prefix(mid))
        let secondHalf = Array(values.suffix(values.count - mid))
        let firstMean = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondMean = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let halfDelta = secondMean - firstMean

        // 判定方向
        // 指标语义：HRV/睡眠/步数 越高越好；RHR 越低越好
        let isHigherBetter = metric != .restingHeartRate

        var direction: TrendDirection

        if let z, abs(z) > Self.significantZ {
            // z 显著：用 z 符号 + 指标语义
            if isHigherBetter {
                direction = z > 0 ? .improving : .declining
            } else {
                direction = z > 0 ? .declining : .improving
            }
        } else if abs(slope) > Self.slopeThresholdPerDay {
            // OLS 斜率显著
            if isHigherBetter {
                direction = slope > 0 ? .improving : .declining
            } else {
                direction = slope > 0 ? .declining : .improving
            }
        } else if abs(halfDelta) > Self.halfDeltaDeadzone {
            // 前后段均值差
            if isHigherBetter {
                direction = halfDelta > 0 ? .improving : .declining
            } else {
                direction = halfDelta > 0 ? .declining : .improving
            }
        } else {
            direction = .stable
        }

        // 6. 高波动覆盖
        if cv > Self.volatileCV {
            direction = .volatile
        }

        return MetricTrend(
            metric: metric, window: window, direction: direction,
            currentValue: current, baselineValue: baselineValue,
            deviationPercent: deviation, slopePerDay: slope,
            robustZ: z, volatility: cv,
            sampleCount: sampleCount, minimumRequired: Self.minimumSamples
        )
    }

    // MARK: - Private

    /// 提取窗口内的指标值序列（升序，只取非 nil）。
    private func extractValues(
        metric: BaselineMetric,
        history: [DailyHealthMetrics],
        window: TrendWindow,
        now: Date,
        calendar: Calendar
    ) -> [Double] {
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(window.days - 1), to: startOfToday) ?? startOfToday

        return history
            .filter { $0.day >= start && $0.day <= startOfToday }
            .sorted { $0.day < $1.day }
            .compactMap { day -> Double? in
                switch metric {
                case .hrv: return day.hrv?.value
                case .restingHeartRate: return day.restingHeartRate?.value
                case .sleepHours: return day.sleepHours?.value
                case .sleepREMHours: return day.sleepREMHours?.value
                case .sleepDeepHours: return day.sleepDeepHours?.value
                case .steps: return day.steps?.value
                case .activeEnergyKcal: return day.activeEnergyKcal?.value
                case .exerciseMinutes: return day.exerciseMinutes?.value
                case .standHours: return day.standHours?.value
                }
            }
    }

    /// OLS 线性回归斜率（每天变化量）。
    private func olsSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        let xMean = (n - 1) / 2 // 0,1,2,...,n-1 的均值
        let yMean = values.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for (i, y) in values.enumerated() {
            let xDiff = Double(i) - xMean
            numerator += xDiff * (y - yMean)
            denominator += xDiff * xDiff
        }
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}
