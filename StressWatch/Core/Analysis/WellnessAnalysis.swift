import Foundation

// WellnessFeatures 是给规则模型或未来 Core ML 模型使用的输入特征。
// 它只保存统计后的数值，不保存原始 HealthKit 权限或读取逻辑。
struct WellnessFeatures {
    let avgHRV: Double?
    let hrvTrend: Double?
    let avgHeartRate: Double?
    let avgRestingHR: Double?
    let sleepAverage: Double?
    let sleepConsistency: Double?
    let remSleepAverage: Double?
    let coreSleepAverage: Double?
    let deepSleepAverage: Double?
    let awakeAverage: Double?
    let stepsAverage: Double?
    let activeEnergyAverage: Double?
    let exerciseMinutesAverage: Double?
    let standHoursAverage: Double?
    let activityLevel: Double?
    let recoveryAverage: Double?
    let stressAverage: Double?
    let availableFeatureCount: Int
    let dataConfidence: Double
}

enum WellnessAnalysisSource: String, Codable {
    case ruleBased
    case coreMLPersonalModel
    case coreMLUnavailableRuleFallback

    var displayName: String {
        switch self {
        case .ruleBased:
            return "Rule-based"
        case .coreMLPersonalModel:
            return "Core ML Personal Model"
        case .coreMLUnavailableRuleFallback:
            return "Core ML unavailable, using rule-based fallback"
        }
    }
}

// WellnessState 是机器学习课程展示用的状态分类。
// 文案必须保持为趋势参考，不能作为医疗结论。
enum WellnessState: String, Codable, CaseIterable {
    case balanced = "Balanced"
    case needRecovery = "Need Recovery"
    case highStrain = "High Strain"
    case lowActivity = "Low Activity"
    case sleepDebt = "Sleep Debt"
    case dataInsufficient = "Data Insufficient"

    var displayName: String {
        switch self {
        case .balanced:
            return "状态较平衡"
        case .needRecovery:
            return "建议恢复优先"
        case .highStrain:
            return "近期负荷偏高"
        case .lowActivity:
            return "活动量偏低"
        case .sleepDebt:
            return "睡眠可能不足"
        case .dataInsufficient:
            return "数据暂不充分"
        }
    }

    var shortSummary: String {
        switch self {
        case .balanced:
            return "近期指标整体较平衡，可继续观察趋势变化。"
        case .needRecovery:
            return "恢复相关指标可能偏弱，建议优先关注休息节奏。"
        case .highStrain:
            return "近期压力趋势或活动负荷可能偏高，建议降低强度。"
        case .lowActivity:
            return "近期活动量可能偏低，可以从轻量活动开始。"
        case .sleepDebt:
            return "睡眠时长或稳定性可能不足，建议关注作息。"
        case .dataInsufficient:
            return "当前可用数据较少，建议积累更多连续数据后再观察。"
        }
    }
}

struct WellnessAnalysis {
    let state: WellnessState
    let confidence: Double
    let primaryFactors: [String]
    let features: WellnessFeatures
    let generatedAt: Date
    let source: WellnessAnalysisSource

    func withSource(_ source: WellnessAnalysisSource) -> WellnessAnalysis {
        WellnessAnalysis(
            state: state,
            confidence: confidence,
            primaryFactors: primaryFactors,
            features: features,
            generatedAt: generatedAt,
            source: source
        )
    }
}
