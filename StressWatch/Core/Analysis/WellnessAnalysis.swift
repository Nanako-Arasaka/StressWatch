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
    let predictedLabel: String
    let confidence: Double
    let primaryFactors: [String]
    let features: WellnessFeatures
    let generatedAt: Date
    let source: WellnessAnalysisSource
    let mlInsight: MLWellnessInsight

    func withSource(_ source: WellnessAnalysisSource) -> WellnessAnalysis {
        let insight = MLWellnessInsightFactory.makeInsight(
            label: predictedLabel,
            state: state,
            confidence: confidence,
            features: features,
            source: source,
            generatedAt: generatedAt
        )

        return WellnessAnalysis(
            state: state,
            predictedLabel: predictedLabel,
            confidence: confidence,
            primaryFactors: insight.keyFactors,
            features: features,
            generatedAt: generatedAt,
            source: source,
            mlInsight: insight
        )
    }
}

struct MLWellnessInsight {
    let predictedState: String
    let confidence: Double
    let stressAssessment: String
    let sleepAssessment: String
    let recoveryAssessment: String
    let hrvAssessment: String
    let keyFactors: [String]
    let recommendations: [String]
    let modelSource: String
    let generatedAt: Date

    var summary: String {
        "\(stressAssessment)，\(sleepAssessment)，\(recoveryAssessment)。"
    }
}

enum MLWellnessInsightFactory {
    static func makeInsight(
        label: String,
        state: WellnessState,
        confidence: Double,
        features: WellnessFeatures,
        source: WellnessAnalysisSource,
        generatedAt: Date = Date()
    ) -> MLWellnessInsight {
        let mappedLabel = normalizedLabel(label: label, state: state)
        let template = template(for: mappedLabel)
        let factors = keyFactors(for: features)

        return MLWellnessInsight(
            predictedState: displayState(for: mappedLabel, fallback: state.displayName),
            confidence: confidence,
            stressAssessment: template.stressAssessment,
            sleepAssessment: template.sleepAssessment,
            recoveryAssessment: template.recoveryAssessment,
            hrvAssessment: hrvAssessment(for: features),
            keyFactors: factors.isEmpty ? template.defaultFactors : Array(factors.prefix(5)),
            recommendations: Array(template.recommendations.prefix(3)),
            modelSource: source.displayName,
            generatedAt: generatedAt
        )
    }

    private static func normalizedLabel(label: String, state: WellnessState) -> String {
        if !label.isEmpty {
            return label
        }

        switch state {
        case .balanced:
            return "normal"
        case .needRecovery:
            return "mild_stress"
        case .highStrain:
            return "attention_stress"
        case .lowActivity:
            return "low_activity"
        case .sleepDebt:
            return "sleep_debt"
        case .dataInsufficient:
            return "data_insufficient"
        }
    }

    private static func displayState(for label: String, fallback: String) -> String {
        switch label {
        case "recovery_good":
            return "恢复趋势较好"
        case "normal":
            return "状态基本稳定"
        case "mild_stress":
            return "轻微压力趋势"
        case "attention_stress":
            return "需要关注的压力趋势"
        case "high_stress":
            return "较高压力趋势"
        case "sleep_debt":
            return "睡眠不足趋势"
        case "low_activity":
            return "活动量偏低趋势"
        case "data_insufficient":
            return "数据暂不充分"
        default:
            return fallback
        }
    }

    private static func template(for label: String) -> (
        stressAssessment: String,
        sleepAssessment: String,
        recoveryAssessment: String,
        defaultFactors: [String],
        recommendations: [String]
    ) {
        switch label {
        case "recovery_good":
            return (
                "压力状况较低",
                "睡眠质量相对稳定",
                "恢复状态较好",
                ["近期整体趋势相对稳定"],
                [
                    "保持当前作息和活动节奏。",
                    "继续观察 HRV 和睡眠趋势，关注连续变化。",
                    "维持轻量活动和稳定恢复安排。"
                ]
            )
        case "normal":
            return (
                "压力状况在正常范围",
                "睡眠质量基本稳定",
                "恢复状态正常",
                ["近期指标整体处于可参考范围"],
                [
                    "继续观察 HRV 和睡眠趋势。",
                    "保持规律作息，避免只根据单日波动判断。",
                    "结合主观感受记录每天状态。"
                ]
            )
        case "mild_stress":
            return (
                "压力状况轻微升高",
                "睡眠质量可能受影响",
                "恢复状态略弱",
                ["近期压力或恢复趋势出现轻微变化"],
                [
                    "建议关注休息和睡眠规律。",
                    "减少连续高强度活动，把恢复放在优先位置。",
                    "连续观察 3 到 7 天趋势变化。"
                ]
            )
        case "attention_stress":
            return (
                "压力状况需要关注",
                "睡眠质量可能存在波动",
                "恢复状态偏弱",
                ["近期压力趋势可能高于平时"],
                [
                    "建议减少高强度活动，优先恢复。",
                    "关注睡眠时长、HRV 和静息心率的连续变化。",
                    "把当天主观疲劳感一起作为参考。"
                ]
            )
        case "high_stress":
            return (
                "压力状况较高",
                "睡眠质量可能较差",
                "恢复状态较弱",
                ["近期压力趋势可能较高"],
                [
                    "建议关注休息，避免连续高负荷。",
                    "优先安排轻量活动和更稳定的睡眠节奏。",
                    "如果趋势持续偏高，建议结合专业人士意见判断。"
                ]
            )
        case "sleep_debt":
            return (
                "压力状况可能受睡眠不足影响",
                "睡眠质量偏低",
                "恢复状态受影响",
                ["近期睡眠趋势可能不足"],
                [
                    "优先改善睡眠时长和规律。",
                    "减少睡前干扰，观察连续睡眠趋势。",
                    "第二天活动强度可适当保守。"
                ]
            )
        case "low_activity":
            return (
                "压力状况不一定高",
                "睡眠质量需结合 HRV 观察",
                "恢复状态可能存在活动刺激不足",
                ["近期活动量可能偏低"],
                [
                    "建议增加轻量活动，如散步。",
                    "先关注步数和站立时间的稳定提升。",
                    "活动目标循序渐进，不需要一次性提高强度。"
                ]
            )
        default:
            return (
                "压力状况暂不充分",
                "睡眠质量需要更多数据参考",
                "恢复状态需要继续观察",
                ["当前可用数据较少"],
                [
                    "建议连续积累 Apple Health 数据。",
                    "结果仅用于个人健康趋势参考。",
                    "优先查看数据来源和置信度。"
                ]
            )
        }
    }

    private static func keyFactors(for features: WellnessFeatures) -> [String] {
        var factors: [String] = []

        if let hrvDeviationPercent = estimatedHRVDeviationPercent(features), hrvDeviationPercent < -20 {
            factors.append("近期 HRV 明显低于个人基线")
        }

        if let sleepRatio = estimatedSleepRatio(features), sleepRatio < 0.85 {
            factors.append("近期睡眠低于个人平均水平")
        }

        if let restingHRDeviation = estimatedRestingHRDeviation(features), restingHRDeviation > 5 {
            factors.append("静息心率高于个人基线")
        }

        if let steps = features.stepsAverage, steps < 4_000 {
            factors.append("近期活动量偏低")
        }

        if let deepSleep = features.deepSleepAverage, deepSleep < 0.75 {
            factors.append("深睡时间偏少")
        }

        if factors.isEmpty {
            factors.append("近期 HRV、睡眠、恢复和活动趋势整体可继续观察")
        }

        return factors
    }

    private static func hrvAssessment(for features: WellnessFeatures) -> String {
        guard let percent = estimatedHRVDeviationPercent(features) else {
            return "HRV 相对个人基线需要更多数据参考"
        }

        if percent < -20 {
            return "HRV 明显低于个人基线"
        } else if percent < -8 {
            return "HRV 略低于个人基线"
        } else if percent > 12 {
            return "HRV 高于个人基线"
        } else {
            return "HRV 接近个人基线"
        }
    }

    private static func estimatedHRVDeviationPercent(_ features: WellnessFeatures) -> Double? {
        guard let avgHRV = features.avgHRV,
              let trend = features.hrvTrend,
              avgHRV > 0 else {
            return nil
        }

        return (trend / avgHRV) * 100
    }

    private static func estimatedSleepRatio(_ features: WellnessFeatures) -> Double? {
        guard let sleepAverage = features.sleepAverage else {
            return nil
        }

        return sleepAverage / 7.5
    }

    private static func estimatedRestingHRDeviation(_ features: WellnessFeatures) -> Double? {
        guard let restingHR = features.avgRestingHR else {
            return nil
        }

        return restingHR - 70
    }
}
