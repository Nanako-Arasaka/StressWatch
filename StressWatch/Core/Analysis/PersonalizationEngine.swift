import Foundation

/// 打卡自评与模型结论的调和结果。
struct CheckInReconciliation {
    let latestLabel: DailyWellnessLabel?
    let note: String?
    let agreesWithModel: Bool?
}

/// 个性化分析的最终产物：基础分析结果 + 个性化目标 + 个性化建议 + 打卡调和。
struct PersonalizedAnalysis {
    let base: WellnessAnalysis
    let goals: PersonalizedGoals
    let recommendations: [PersonalizedRecommendation]
    let checkInReconciliation: CheckInReconciliation?
    let generatedAt: Date

    var state: WellnessState { base.state }
    var confidence: Double { base.confidence }
}

protocol PersonalizationEngineing {
    func personalize(analysis: WellnessAnalysis, context: PersonalizationContext) -> PersonalizedAnalysis
}

/// PersonalizationEngine 是“基于用户数据的个性化优化”的编排层。
/// 它在 WellnessAnalyzing 产出基础分析之后运行，不修改原有协议，
/// 因此 Dashboard / Analysis / Trend 各 ViewModel 可按需接入，互不影响。
struct PersonalizationEngine: PersonalizationEngineing {
    private let goalOptimizer: any GoalOptimizing
    private let adviceGenerator: any PersonalizedAdviceGenerating

    init(
        goalOptimizer: any GoalOptimizing = GoalOptimizer(),
        adviceGenerator: any PersonalizedAdviceGenerating = PersonalizedAdviceGenerator()
    ) {
        self.goalOptimizer = goalOptimizer
        self.adviceGenerator = adviceGenerator
    }

    func personalize(analysis: WellnessAnalysis, context: PersonalizationContext) -> PersonalizedAnalysis {
        let goals = goalOptimizer.optimizeGoals(context: context, analysis: analysis)
        let recommendations = adviceGenerator.advice(for: analysis, context: context, goals: goals)
        let reconciliation = reconcile(analysis: analysis, context: context)

        return PersonalizedAnalysis(
            base: analysis,
            goals: goals,
            recommendations: recommendations,
            checkInReconciliation: reconciliation,
            generatedAt: Date()
        )
    }

    private func reconcile(analysis: WellnessAnalysis, context: PersonalizationContext) -> CheckInReconciliation? {
        guard let latest = context.latestCheckIn else {
            return nil
        }

        let userPolarity = latest.label.polarity
        let modelPolarity = analysis.state.polarity
        let agrees: Bool
        if userPolarity == 0 || modelPolarity == 0 {
            agrees = true
        } else {
            agrees = (userPolarity > 0) == (modelPolarity > 0)
        }

        let note: String? = agrees ? nil :
            "你今天记录的是“\(latest.label.displayName)”，但模型判断为“\(analysis.state.displayName)”，可结合主观感受一起参考。"

        return CheckInReconciliation(latestLabel: latest.label, note: note, agreesWithModel: agrees)
    }
}
