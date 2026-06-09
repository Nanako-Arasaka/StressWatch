import Foundation

protocol AdviceGenerating {
    func advice(for analysis: WellnessAnalysis) -> [String]
}

// AdviceGenerator 将状态分类转换成保守的生活方式建议。
// 文案只使用“可能、趋势、参考、建议关注”，不提供医疗用途结论。
struct AdviceGenerator: AdviceGenerating {
    func advice(for analysis: WellnessAnalysis) -> [String] {
        if !analysis.mlInsight.recommendations.isEmpty {
            return analysis.mlInsight.recommendations
        }

        switch analysis.state {
        case .balanced:
            return [
                "近期整体趋势较平衡，可以继续保持稳定作息和轻量活动。",
                "建议关注 HRV、睡眠和活动量的连续变化，而不是单日波动。",
                "如果某天分数变化较大，可以结合当天睡眠和运动强度一起参考。"
            ]
        case .needRecovery:
            return [
                "最近恢复状态可能较弱，建议优先保证睡眠和降低高强度活动。",
                "如果 HRV 低于近期基线，可以安排更轻量的活动和放松时间。",
                "建议连续观察 3 到 7 天趋势，避免只根据单日数据判断。"
            ]
        case .highStrain:
            return [
                "近期压力趋势或活动负荷可能偏高，建议关注休息和节奏调整。",
                "如果静息心率偏高且 HRV 走低，可以减少高强度训练作为参考。",
                "建议把睡眠、活动能量和主观感受一起观察。"
            ]
        case .lowActivity:
            return [
                "近期活动量可能偏低，可以尝试轻量步行或短时间活动。",
                "建议先关注步数、活动能量和站立时间的稳定提升。",
                "活动目标可以循序渐进，不需要一次性提高强度。"
            ]
        case .sleepDebt:
            return [
                "睡眠不足可能影响恢复趋势，建议优先关注入睡和起床节奏。",
                "如果夜间清醒阶段较多，可以先观察睡前习惯和环境变化。",
                "建议连续记录睡眠时长和稳定度，用趋势而不是单日作为参考。"
            ]
        case .dataInsufficient:
            return [
                "当前可用数据较少，建议连续佩戴设备并积累更多记录。",
                "部分指标缺失时，分析可信度会降低，结果仅作趋势参考。",
                "可以先查看 Dashboard 中哪些卡片来自 Apple Health 或 Demo Data。"
            ]
        }
    }
}
