import Foundation

// MARK: - 信号与方向

/// 参与分数计算的信号维度。
enum SignalKind: String, Codable, CaseIterable {
    case hrv
    case restingHeartRate
    case sleep
    case activityLoad
    case sleepConsistency
    case sleepStages

    var displayName: String {
        switch self {
        case .hrv: return "HRV"
        case .restingHeartRate: return "静息心率"
        case .sleep: return "睡眠"
        case .activityLoad: return "活动负荷"
        case .sleepConsistency: return "睡眠规律"
        case .sleepStages: return "睡眠分期"
        }
    }
}

/// 单个信号相对个人基线的方向。
enum ContributionDirection: String, Codable {
    case favorable
    case normal
    case unfavorable

    /// UI 符号：↑ / → / ↓
    var symbol: String {
        switch self {
        case .favorable: return "↑"
        case .normal: return "→"
        case .unfavorable: return "↓"
        }
    }

    var displayName: String {
        switch self {
        case .favorable: return "有利"
        case .normal: return "正常"
        case .unfavorable: return "不利"
        }
    }
}

// MARK: - ScoreContribution

/// 单个信号对总分的贡献。可解释性的一等公民。
///
/// **不变式（必须写测试断言）**：`Σ contributions.points == finalScore`。
/// 这样解释层永远不可能与实际分数漂移（修 Thump `StressSignalBreakdown` 存加权前分数的坑）。
struct ScoreContribution: Codable, Equatable {
    let signal: SignalKind
    /// 该信号自己的 0-100 分（归一化后）。
    let rawScore: Double
    /// 实际生效权重（已对缺失信号重归一化，所有非缺失信号权重之和 = 1）。
    let weight: Double
    /// `rawScore * weight` —— 对总分的实际贡献。
    let points: Double
    let direction: ContributionDirection
    /// 人类可读，如 "HRV 42 ms，低于个人基线 17.6%"。
    let detail: String

    init(
        signal: SignalKind,
        rawScore: Double,
        weight: Double,
        direction: ContributionDirection,
        detail: String
    ) {
        self.signal = signal
        self.rawScore = rawScore
        self.weight = weight
        self.points = rawScore * weight
        self.direction = direction
        self.detail = detail
    }
}

// MARK: - AnalysisConfidence

/// 分析置信度。六值简化版（参考 Whoordan `ConfidenceLevel`）。
///
/// `.directional` 对 wellness app 特别合适：
/// "HRV 低"是确定的，但"低多少意味着什么"不确定。
enum AnalysisConfidence: String, Codable, Comparable {
    case insufficient
    case low
    case directional
    case medium
    case high

    private var rank: Int {
        switch self {
        case .insufficient: return 0
        case .low: return 1
        case .directional: return 2
        case .medium: return 3
        case .high: return 4
        }
    }

    static func < (lhs: AnalysisConfidence, rhs: AnalysisConfidence) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: String {
        switch self {
        case .insufficient: return "数据不足"
        case .low: return "可信度较低"
        case .directional: return "方向可信"
        case .medium: return "可信度中等"
        case .high: return "可信度较高"
        }
    }

    /// 从扣分制的 0...1 分数映射到枚举。
    /// 依据：Thump confidence 扣分制 —— `≥0.70 → high` / `≥0.40 → medium` / `否则 low`。
    static func from(score: Double) -> AnalysisConfidence {
        switch score {
        case ..<0.15: return .insufficient
        case ..<0.40: return .low
        case ..<0.55: return .directional
        case ..<0.70: return .medium
        default: return .high
        }
    }
}

// MARK: - DataCompleteness

/// 数据完整度：哪些指标可用、哪些缺失、核心与整体可用率。
///
/// 对应 LLM 必须知道的：
/// "今天的分析主要基于 HRV、睡眠和静息心率，活动数据不足，因此活动因素未纳入判断。"
struct DataCompleteness: Codable, Equatable {
    let availableMetrics: [BaselineMetric]
    let missingMetrics: [BaselineMetric]
    /// 核心四项（HRV / RHR / Sleep / Steps）的加权可用性 0...1。
    let coreCompleteness: Double
    /// 全部指标的可用率 0...1。
    let overallCompleteness: Double
    /// 历史中至少有一天数据的天数。
    let historyDays: Int

    /// 全缺失。
    static let empty = DataCompleteness(
        availableMetrics: [],
        missingMetrics: BaselineMetric.allCases,
        coreCompleteness: 0,
        overallCompleteness: 0,
        historyDays: 0
    )

    /// 从"当天各指标是否为 nil"构建。
    init(
        availableMetrics: [BaselineMetric],
        missingMetrics: [BaselineMetric],
        coreCompleteness: Double,
        overallCompleteness: Double,
        historyDays: Int
    ) {
        self.availableMetrics = availableMetrics
        self.missingMetrics = missingMetrics
        self.coreCompleteness = coreCompleteness
        self.overallCompleteness = overallCompleteness
        self.historyDays = historyDays
    }

    /// 便捷构建：传入当天 `DailyHealthMetrics`，自动判可用 / 缺失。
    init(today: DailyHealthMetrics?, historyDays: Int) {
        var available: [BaselineMetric] = []
        var missing: [BaselineMetric] = []

        for metric in BaselineMetric.allCases {
            let sample: MetricSample?
            switch metric {
            case .hrv: sample = today?.hrv
            case .restingHeartRate: sample = today?.restingHeartRate
            case .sleepHours: sample = today?.sleepHours
            case .sleepREMHours: sample = today?.sleepREMHours
            case .sleepDeepHours: sample = today?.sleepDeepHours
            case .steps: sample = today?.steps
            case .activeEnergyKcal: sample = today?.activeEnergyKcal
            case .exerciseMinutes: sample = today?.exerciseMinutes
            case .standHours: sample = today?.standHours
            }
            if sample != nil {
                available.append(metric)
            } else {
                missing.append(metric)
            }
        }

        let core = BaselineMetric.coreMetrics
        let coreAvailable = core.filter { available.contains($0) }.count
        let total = BaselineMetric.allCases.count

        self.init(
            availableMetrics: available,
            missingMetrics: missing,
            coreCompleteness: core.isEmpty ? 0 : Double(coreAvailable) / Double(core.count),
            overallCompleteness: total == 0 ? 0 : Double(available.count) / Double(total),
            historyDays: historyDays
        )
    }

    /// 人类可读的缺失说明。
    var missingSummary: String? {
        guard !missingMetrics.isEmpty else { return nil }
        let names = missingMetrics.map(\.displayName).joined(separator: "、")
        return "\(names)数据不足，未纳入本次判断"
    }
}
