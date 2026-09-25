import Foundation

// MARK: - MetricDeviation

/// 单指标的偏离 + 趋势（用户要求的 JSON 形状）。
struct MetricDeviation: Codable, Identifiable {
    let metric: BaselineMetric
    let value: Double?
    let unit: String
    let baseline: Double?
    let deviationPercent: Double?
    let trend: TrendDirection
    let provenance: MetricProvenance

    var id: String { metric.rawValue }
}

// MARK: - SleepQualityAnalysis

/// 睡眠质量分析结论。
struct SleepQualityAnalysis: Codable {
    let durationHours: Double?
    let baselineHours: Double?
    let deviationPercent: Double?
    let qualityLabel: String
    let remPercent: Double?
    let deepPercent: Double?
}

// MARK: - ActivityLevel

/// 活动水平分级。
enum ActivityLevel: String, Codable {
    case sedentary
    case low
    case moderate
    case high
    case veryHigh

    var displayName: String {
        switch self {
        case .sedentary: return "久坐"
        case .low: return "偏低"
        case .moderate: return "适中"
        case .high: return "较高"
        case .veryHigh: return "很高"
        }
    }
}

// MARK: - StructuredAnalysisResult

/// 一次完整分析的结构化结果 —— LLM 的唯一输入。
///
/// **关键**：LLM 只负责解读，不负责计算。所有数值在这里已经算完。
/// 对应用户需求的 JSON 形状：
/// ```
/// {
///   "stressScore": 64,
///   "recoveryScore": 71,
///   "hrv": { "value": 42, "baseline": 51, "deviationPercent": -17.6, "trend": "declining" },
///   "confidence": 0.86,
///   "dataCompleteness": 0.92
/// }
/// ```
struct StructuredAnalysisResult: Codable {
    let generatedAt: Date
    let dataSource: AppDataSource
    let baselineWindowDays: Int

    // 分数
    let stressScore: Int?
    let stressLevel: StressLevel?
    let recoveryScore: Int?
    let recoveryLevel: RecoveryLevel?

    // 各指标偏离
    let metrics: [MetricDeviation]
    let sleepQuality: SleepQualityAnalysis?
    let activityLevel: ActivityLevel

    // 趋势
    let trends: [MetricTrend]

    // 相关性
    let associations: [ObservedAssociation]

    // 数据质量
    let confidence: AnalysisConfidence
    let completeness: DataCompleteness
    let warnings: [String]

    // MARK: - 便捷访问

    func deviation(for metric: BaselineMetric) -> MetricDeviation? {
        metrics.first { $0.metric == metric }
    }

    var hrvDeviation: MetricDeviation? { deviation(for: .hrv) }
    var rhrDeviation: MetricDeviation? { deviation(for: .restingHeartRate) }
    var sleepDeviation: MetricDeviation? { deviation(for: .sleepHours) }

    /// 生成 LLM 可读的紧凑摘要（WorkoutTracker `buildStatsContext` 思路）。
    var compactSummary: String {
        var lines: [String] = []

        if let s = stressScore {
            lines.append("Stress: \(s)")
        }
        if let r = recoveryScore {
            lines.append("Recovery: \(r)")
        }

        if let hrv = hrvDeviation, let v = hrv.value {
            let baseline = hrv.baseline.map { String(format: "%.0f", $0) } ?? "—"
            let dev = hrv.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("HRV: \(String(format: "%.0f", v)) ms (baseline \(baseline), \(dev), trend \(hrv.trend.rawValue))")
        }

        if let rhr = rhrDeviation, let v = rhr.value {
            let baseline = rhr.baseline.map { String(format: "%.0f", $0) } ?? "—"
            let dev = rhr.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("RHR: \(String(format: "%.0f", v)) bpm (baseline \(baseline), \(dev))")
        }

        if let sleep = sleepDeviation, let v = sleep.value {
            let baseline = sleep.baseline.map { String(format: "%.1f", $0) } ?? "—"
            let dev = sleep.deviationPercent.map { String(format: "%.1f%%", $0) } ?? "—"
            lines.append("Sleep: \(String(format: "%.1f", v)) h (baseline \(baseline), \(dev))")
        }

        lines.append("Activity: \(activityLevel.displayName)")
        lines.append("Confidence: \(confidence.displayName)")
        lines.append("Data completeness: \(String(format: "%.0f%%", completeness.overallCompleteness * 100))")

        if let missing = completeness.missingSummary {
            lines.append("Missing: \(missing)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - AnalysisInsightBuilder
