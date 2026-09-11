import Foundation

/// 个性化目标集合：根据个人基线动态设定，而非写死的全局默认值。
struct PersonalizedGoals {
    let sleepTargetHours: Double
    let stepsTarget: Int
    let activeEnergyTargetKcal: Int
    let exerciseTargetMin: Int
    let standTargetHours: Int
    let rationale: [String]
    let generatedAt: Date

    /// 当前值与目标的差距（正=未达标，负=已超出），用于 UI 展示进度。
    func gap(for kind: GoalKind, current: Double?) -> Double? {
        guard let current else { return nil }
        switch kind {
        case .sleep: return sleepTargetHours - current
        case .steps: return Double(stepsTarget) - current
        case .activeEnergy: return Double(activeEnergyTargetKcal) - current
        case .exercise: return Double(exerciseTargetMin) - current
        case .stand: return Double(standTargetHours) - current
        }
    }
}

protocol GoalOptimizing {
    func optimizeGoals(context: PersonalizationContext, analysis: WellnessAnalysis) -> PersonalizedGoals
}

/// GoalOptimizer 根据个人基线 + 当前状态，给出“跳一跳够得着”的个性化目标。
/// 原则：
/// - 睡眠 / 步数优先使用个人基线，避免用全局默认值误导。
/// - 活动能量 / 运动 / 站立在缺少个人数据时回落到 Apple 风格默认值，
///   并在恢复偏弱或高负荷时主动下调，保证目标可达。
struct GoalOptimizer: GoalOptimizing {
    func optimizeGoals(context: PersonalizationContext, analysis: WellnessAnalysis) -> PersonalizedGoals {
        var rationale: [String] = []

        // 睡眠目标：个人基线睡眠，限制在合理区间并取整到 0.25h。
        let sleepTarget: Double
        if let base = context.baseline?.avgSleepHours, base > 0 {
            let clamped = min(max(base, 6.5), 9.0)
            sleepTarget = (round(clamped * 4) / 4)
            rationale.append("睡眠目标参考你近 \(context.baseline?.dataWindowDays ?? 0) 天基线 \(formatHours(base))，设为 \(formatHours(sleepTarget))。")
        } else {
            sleepTarget = 7.5
            rationale.append("暂无个人睡眠基线，先使用 7.5h 参考目标，积累数据后会自动调整。")
        }

        // 步数目标：个人基线步数上浮约 10%，限制在合理区间。
        let stepsTarget: Int
        if let base = context.baseline?.avgDailySteps, base > 0 {
            let lifted = base * 1.1
            let clamped = min(max(lifted, 4000), 15000)
            stepsTarget = Int(round(clamped) / 100) * 100
            rationale.append("步数目标在你的基线 \(Int(base)) 步基础上上浮约 10%，设为 \(stepsTarget) 步。")
        } else {
            stepsTarget = 8000
            rationale.append("暂无个人步数基线，先使用 8000 步参考目标。")
        }

        // 活动能量 / 运动 / 站立：默认 Apple 风格，按状态微调可达性。
        let conservative = (analysis.state == .needRecovery || analysis.state == .highStrain)
        let lowActivity = (analysis.state == .lowActivity)

        let exerciseTarget: Int = conservative ? 20 : (lowActivity ? 25 : 30)
        let standTarget: Int = conservative ? 10 : 12
        let activeEnergyTarget: Int
        if let energy = context.avgActiveEnergy, energy > 0 {
            let lifted = energy * 1.1
            activeEnergyTarget = Int(round(min(max(lifted, 300), 1200)) / 50) * 50
            rationale.append("活动能量目标参考你近期均值 \(Int(energy)) kcal 上浮约 10%。")
        } else {
            activeEnergyTarget = 500
        }

        if conservative {
            rationale.append("当前恢复偏弱或负荷偏高，运动 / 站立目标已主动下调，优先保证可执行。")
        }

        return PersonalizedGoals(
            sleepTargetHours: sleepTarget,
            stepsTarget: stepsTarget,
            activeEnergyTargetKcal: activeEnergyTarget,
            exerciseTargetMin: exerciseTarget,
            standTargetHours: standTarget,
            rationale: rationale,
            generatedAt: Date()
        )
    }

    private func formatHours(_ value: Double) -> String {
        let total = Int(round(value * 60))
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}
