import Foundation

/// 稳健统计函数集：中位数 / MAD / robust Z / log 域 EWMA / 分位数 / 离群点剔除。
///
/// 设计依据：
/// 1. **Soma** `BaselineCalculator.logHRVStats` —— HRV 呈对数正态分布，
///    算术均值偏向长尾；log 域 EWMA(α=0.25) 做中心、样本 SD 做个人变异度，
///    z-score = `(ln(today) - meanLn) / sdLn`。
/// 2. **Thump** `robustZ`（median + MAD）—— 抗离群点；HRV 基线锚点用 **P75**
///    防止长期压力期把基线拖低（"越病越正常"）。
/// 3. **Whoordan** 中位数基线 —— 对设备切换、戴表不严产生的极端值更稳。
///
/// 全部纯函数，只 `import Foundation`，零依赖、可完整单测。
enum RobustStatistics {

    // MARK: - 离群点剔除方法

    enum OutlierMethod {
        /// 中位数 ± 3×MAD×1.4826（近似 3σ）。
        case mad3Sigma
        /// Tukey IQR：Q1-1.5×IQR ~ Q3+1.5×IQR。
        case iqr
    }

    // MARK: - 中心与离散

    /// 中位数。空数组返回 nil。
    static func median(_ values: [Double]) -> Double? {
        let cleaned = values.filter { $0.isFinite }
        guard !cleaned.isEmpty else { return nil }
        let sorted = cleaned.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// 样本标准差（n-1）。少于 2 个样本或全等值时返回 nil。
    static func stddev(_ values: [Double]) -> Double? {
        let cleaned = values.filter { $0.isFinite }
        guard cleaned.count >= 2 else { return nil }
        let mean = cleaned.reduce(0, +) / Double(cleaned.count)
        let variance = cleaned.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(cleaned.count - 1)
        let sd = sqrt(variance)
        // 全等值时方差为 0 —— 表示"没有变异度"，用 nil 区分于"变异度极小"。
        return sd > 0 ? sd : nil
    }

    /// MAD（Median Absolute Deviation）× 1.4826，使正态分布下与 σ 同量纲。
    /// 全等值或空数组返回 nil。
    static func mad(_ values: [Double]) -> Double? {
        guard let center = median(values) else { return nil }
        let deviations = values.filter { $0.isFinite }.map { abs($0 - center) }
        guard let medianDeviation = median(deviations), medianDeviation > 0 else { return nil }
        return medianDeviation * 1.4826
    }

    // MARK: - z-score

    /// 稳健 z 值：`(value - median) / MAD`。
    /// MAD == 0（序列几乎无变异）或样本不足时返回 nil —— 调用方必须处理 nil，不许默认 0。
    static func robustZ(_ value: Double, in baseline: [Double]) -> Double? {
        guard value.isFinite, let center = median(baseline), let dispersion = mad(baseline) else {
            return nil
        }
        return (value - center) / dispersion
    }

    // MARK: - log 域（HRV 专用）

    /// log 域 EWMA 中心 + 样本 SD。
    ///
    /// - 中心用 **EWMA（α = 0.25，近因加权）** 而非算术均值：近期状态权重更高。
    /// - 离散用 **log 域样本 SD（n-1）**：衡量这个人自己的日间变异幅度。
    /// - 入参只保留正值（HRV 必须 > 0），少于 2 个有效样本返回 nil。
    ///
    /// 依据：Soma `BaselineCalculator.logHRVStats`。
    static func logDomainStats(_ values: [Double]) -> (meanLn: Double, sdLn: Double)? {
        let positives = values.filter { $0.isFinite && $0 > 0 }
        guard positives.count >= 2 else { return nil }

        let lns = positives.map { log($0) }
        // α = 2 / (N + 1) 当 N = 7 → 0.25，与 Soma 一致。
        let alpha = 2.0 / 8.0
        var ewma = lns[0]
        for i in 1..<lns.count {
            ewma = alpha * lns[i] + (1 - alpha) * ewma
        }

        let mean = lns.reduce(0, +) / Double(lns.count)
        let variance = lns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(lns.count - 1)
        let sdLn = sqrt(variance)
        // 全等值时 sdLn == 0，无法做 z，返回 nil。
        guard sdLn > 0 else { return nil }

        return (meanLn: ewma, sdLn: sdLn)
    }

    /// log 域 z-score：`(ln(today) - meanLn) / sdLn`。
    /// 任一前提不满足（today ≤ 0 / 样本不足 / 零方差）返回 nil。
    /// 依据：Soma `hrvZScore` 与 `test_hrvZScore_nilWhenNoSpread`。
    static func logZScore(_ today: Double, history: [Double]) -> Double? {
        guard today.isFinite, today > 0, let stats = logDomainStats(history) else { return nil }
        return (log(today) - stats.meanLn) / stats.sdLn
    }

    // MARK: - 分位数

    /// 线性插值分位数（0...1）。空数组返回 nil。
    /// 用于 Thump 式 HRV 基线锚点（P75，锚定"好日子"）。
    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        let cleaned = values.filter { $0.isFinite }.sorted()
        guard !cleaned.isEmpty else { return nil }
        let clamped = min(1, max(0, p))
        if cleaned.count == 1 { return cleaned[0] }

        let position = clamped * Double(cleaned.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, cleaned.count - 1)
        let fraction = position - Double(lower)
        return cleaned[lower] + (cleaned[upper] - cleaned[lower]) * fraction
    }

    /// P75 —— Thump 的 HRV 基线锚点。
    static func p75(_ values: [Double]) -> Double? {
        percentile(values, 0.75)
    }

    // MARK: - 离群点剔除

    /// 剔除离群点后返回剩余值（保持原顺序）。
    /// 少于 3 个样本时不剔除（无法可靠估计分布）。
    static func dropOutliers(_ values: [Double], method: OutlierMethod) -> [Double] {
        let cleaned = values.filter { $0.isFinite }
        guard cleaned.count >= 3 else { return cleaned }

        switch method {
        case .mad3Sigma:
            guard let center = median(cleaned), let dispersion = mad(cleaned) else {
                return cleaned
            }
            let bound = 3 * dispersion
            return cleaned.filter { abs($0 - center) <= bound }

        case .iqr:
            guard let q1 = percentile(cleaned, 0.25),
                  let q3 = percentile(cleaned, 0.75) else {
                return cleaned
            }
            let iqr = q3 - q1
            guard iqr > 0 else { return cleaned }
            let lower = q1 - 1.5 * iqr
            let upper = q3 + 1.5 * iqr
            return cleaned.filter { $0 >= lower && $0 <= upper }
        }
    }
}
