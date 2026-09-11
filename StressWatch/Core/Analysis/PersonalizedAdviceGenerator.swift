import Foundation

enum RecommendationCategory: String, CaseIterable {
    case sleep
    case activity
    case recovery
    case stress
    case hrv

    var displayName: String {
        switch self {
        case .sleep: return "睡眠"
        case .activity: return "活动"
        case .recovery: return "恢复"
        case .stress: return "压力"
        case .hrv: return "HRV"
        }
    }
}

/// 一条个性化建议：具体、可量化、可关联到某个优化目标。
struct PersonalizedRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let category: RecommendationCategory
    let priority: Int   // 1 = 最优先
    let linkedGoal: GoalKind?

    var priorityLabel: String {
        priority == 1 ? "优先" : (priority == 2 ? "建议" : "保持")
    }
}

protocol PersonalizedAdviceGenerating {
    func advice(
        for analysis: WellnessAnalysis,
        context: PersonalizationContext,
        goals: PersonalizedGoals
    ) -> [PersonalizedRecommendation]
}

/// PersonalizedAdviceGenerator 把规则模型 / Core ML 的状态结论，
/// 结合用户的个人基线和目标，转成“具体到你身上”的建议。
/// 文案保持“可能 / 趋势 / 参考”，不构成医疗结论。
struct PersonalizedAdviceGenerator: PersonalizedAdviceGenerating {
    func advice(
        for analysis: WellnessAnalysis,
        context: PersonalizationContext,
        goals: PersonalizedGoals
    ) -> [PersonalizedRecommendation] {
        var recs: [PersonalizedRecommendation] = []
        let f = analysis.features

        // 1) HRV 相对个人基线
        if let base = context.baseline?.avgHRV, base > 0, let avg = f.avgHRV {
            let pct = (avg - base) / base * 100
            if pct < -20 {
                recs.append(.init(
                    title: "HRV 明显低于你的基线",
                    detail: "近 7 天 HRV 均值约 \(Int(avg)) ms，比你的个人基线 \(Int(base)) ms 低约 \(Int(-pct))%。建议优先恢复，降低训练强度。",
                    category: .hrv, priority: 1, linkedGoal: nil))
            } else if pct < -8 {
                recs.append(.init(
                    title: "HRV 略低于你的基线",
                    detail: "HRV 约 \(Int(avg)) ms，比个人基线 \(Int(base)) ms 低约 \(Int(-pct))%，可注意观察连续变化。",
                    category: .hrv, priority: 2, linkedGoal: nil))
            }
        }

        // 2) 静息心率相对个人基线
        if let base = context.baseline?.avgRestingHR, base > 0, let rhr = f.avgRestingHR {
            let delta = rhr - base
            if delta > 5 {
                recs.append(.init(
                    title: "静息心率高于你的基线",
                    detail: "静息心率约 \(Int(rhr)) bpm，比个人基线 \(Int(base)) bpm 高约 \(Int(delta)) bpm，可能提示疲劳或负荷偏高。",
                    category: .stress, priority: delta > 10 ? 1 : 2, linkedGoal: nil))
            }
        }

        // 3) 睡眠：相对基线 + 相对个人目标
        if let sleep = f.sleepAverage {
            let baseSleep = context.baseline?.avgSleepHours
            if let base = baseSleep, base > 0, sleep < base * 0.85 {
                recs.append(.init(
                    title: "睡眠低于你的基线",
                    detail: "近 7 天睡眠约 \(formatHours(sleep))，比个人基线 \(formatHours(base)) 少约 \(formatHours(base - sleep))，建议提前入睡。",
                    category: .sleep, priority: 1, linkedGoal: .sleep))
            } else if sleep < goals.sleepTargetHours - 0.25 {
                let gap = goals.sleepTargetHours - sleep
                recs.append(.init(
                    title: "睡眠距个人目标还有差距",
                    detail: "睡眠约 \(formatHours(sleep))，距你的目标 \(formatHours(goals.sleepTargetHours)) 还差约 \(formatHours(gap))，今晚可尝试提前 30 分钟休息。",
                    category: .sleep, priority: 2, linkedGoal: .sleep))
            }
        }

        // 4) 步数：相对个人目标
        if let steps = f.stepsAverage {
            if Double(steps) < Double(goals.stepsTarget) * 0.8 {
                let gap = goals.stepsTarget - Int(steps)
                recs.append(.init(
                    title: "步数低于个人目标",
                    detail: "近期步数约 \(Int(steps)) 步，距目标 \(goals.stepsTarget) 步还差约 \(gap) 步，可由一次轻量散步补足。",
                    category: .activity, priority: 2, linkedGoal: .steps))
            }
        }

        // 5) 活动量整体偏低
        if let level = f.activityLevel, level < 0.45,
           (f.stepsAverage ?? 8_000) < 4_000 {
            recs.append(.init(
                title: "活动量整体偏低",
                detail: "活动完成度约 \(Int(level * 100))%，可从短距离步行或站立开始，循序渐进。",
                category: .activity, priority: 2, linkedGoal: .steps))
        }

        // 6) 恢复分数偏低
        if let rec = f.recoveryAverage, rec < 45 {
            recs.append(.init(
                title: "恢复分数偏低",
                detail: "恢复分数约 \(Int(rec))，建议把休息和睡眠放在优先位置，减少连续高强度活动。",
                category: .recovery, priority: 2, linkedGoal: nil))
        }

        // 7) 打卡自评与模型结论不一致时，给出交叉参考
        if let checkIn = context.latestCheckIn {
            let agrees = checkInAgreesWithModel(label: checkIn.label, state: analysis.state)
            if !agrees {
                recs.append(.init(
                    title: "主观感受与模型略有出入",
                    detail: "你今天记录的是“\(checkIn.label.displayName)”，模型判断为“\(analysis.state.displayName)”。两者都可参考，请结合当天实际感受一起看。",
                    category: .stress, priority: 1, linkedGoal: nil))
            }
        }

        // 兜底：没有触发任何偏差，给出保持型建议
        if recs.isEmpty {
            if context.baseline != nil {
                recs.append(.init(
                    title: "关键指标接近你的基线",
                    detail: "HRV、静息心率与睡眠整体接近个人基线，可继续保持稳定作息与轻量活动。",
                    category: .recovery, priority: 3, linkedGoal: nil))
            } else {
                recs.append(.init(
                    title: "继续积累个人数据",
                    detail: "当前可用数据较少，建议连续佩戴设备，个性化目标与建议会在数据充分后更精准。",
                    category: .recovery, priority: 3, linkedGoal: nil))
            }
        }

        return recs.sorted { $0.priority < $1.priority }
    }

    // MARK: - 辅助

    private func checkInAgreesWithModel(label: DailyWellnessLabel, state: WellnessState) -> Bool {
        let userPolarity = label.polarity
        let modelPolarity = state.polarity
        if userPolarity == 0 || modelPolarity == 0 { return true }
        return (userPolarity > 0) == (modelPolarity > 0)
    }

    private func formatHours(_ value: Double) -> String {
        let total = Int(round(value * 60))
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}
