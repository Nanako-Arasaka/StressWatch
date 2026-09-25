import Foundation

/// 睡眠质量评分引擎。
///
/// 分量与权重（DESIGN_PHASE3 §4.4）：
/// - **duration 30%** —— 时长 / 个人需求
/// - **stages 30%** —— Deep 40% + REM 40% + Core 20%（目标比例：Deep 20%、REM 22%）
/// - **consistency 20%** —— 就寝时刻的圆周标准差（Whoordan 法），≥ 3 晚才参与
/// - **sleepHRV 20%** —— 睡眠期 HRV 相对个人基线
///
/// 缺失处理：某分量缺失 → 退出并把权重按比例分给剩余（Soma `totalWeight` 模式），
/// **不压到 0、不伪造**。全缺失返回 nil。
///
/// 只 `import Foundation`。
struct SleepQualityEngine {

    /// 个人睡眠需求（小时）。无基线时的参考值。
    static let defaultSleepNeedHours: Double = 7.5
    /// Deep 睡眠目标占比。
    static let deepTargetRatio: Double = 0.20
    /// REM 睡眠目标占比。
    static let remTargetRatio: Double = 0.22
    /// 睡眠一致性最少晚数。
    static let minNightsForConsistency = 3
    /// 一致性满分对应的圆周标准差（小时）—— 越小要求越严。
    static let consistencyFullScoreStdHours: Double = 0.5
    /// 一致性 0 分对应的圆周标准差（小时）。
    static let consistencyZeroScoreStdHours: Double = 3.0

    // MARK: - Public

    /// 0-100 睡眠质量分。数据不足时返回 nil。
    func score(
        today: DailyHealthMetrics,
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet
    ) -> Double? {
        struct Weighted {
            let score: Double
            let weight: Double
        }

        var components: [Weighted] = []

        // 1. Duration（30%）
        if let hours = today.sleepHours?.value {
            let need = baselines.sleepHours.sampleDays >= 3
                ? baselines.sleepHours.value
                : Self.defaultSleepNeedHours
            let durationScore = min(100, max(0, hours / need * 100))
            components.append(Weighted(score: durationScore, weight: 0.30))
        }

        // 2. Stages（30%）
        if let stageScore = stageScore(today: today) {
            components.append(Weighted(score: stageScore, weight: 0.30))
        }

        // 3. Consistency（20%）—— 需 ≥ 3 晚
        if let consistencyScore = consistencyScore(history: history) {
            components.append(Weighted(score: consistencyScore, weight: 0.20))
        }

        // 4. Sleep HRV（20%）
        if let hrv = today.hrv?.value,
           baselines.hrv.isReliable,
           let z = baselines.hrv.zScore(of: hrv) {
            // z = 0 → 50；z = +2 → 100；z = -2 → 0
            let hrvScore = min(100, max(0, 50 + z * 25))
            components.append(Weighted(score: hrvScore, weight: 0.20))
        }

        guard !components.isEmpty else { return nil }

        // 权重重归一化
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedSum = components.reduce(0) { $0 + $1.score * $1.weight }
        return min(100, max(0, weightedSum / totalWeight))
    }

    /// 分量明细，供 UI 解释"为什么是这个分"。
    func components(
        today: DailyHealthMetrics,
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet
    ) -> [ScoreContribution] {
        var result: [ScoreContribution] = []

        if let hours = today.sleepHours?.value {
            let need = baselines.sleepHours.sampleDays >= 3
                ? baselines.sleepHours.value
                : Self.defaultSleepNeedHours
            let durationScore = min(100, max(0, hours / need * 100))
            let direction: ContributionDirection = durationScore >= 70 ? .favorable
                : durationScore >= 50 ? .normal : .unfavorable
            result.append(ScoreContribution(
                signal: .sleep, rawScore: durationScore, weight: 0.30,
                direction: direction,
                detail: String(format: "睡眠 %.1f 小时", hours)
            ))
        }

        if let stageScore = stageScore(today: today) {
            result.append(ScoreContribution(
                signal: .sleepStages, rawScore: stageScore, weight: 0.30,
                direction: stageScore >= 60 ? .favorable : .normal,
                detail: "睡眠分期结构"
            ))
        }

        if let consistencyScore = consistencyScore(history: history) {
            result.append(ScoreContribution(
                signal: .sleepConsistency, rawScore: consistencyScore, weight: 0.20,
                direction: consistencyScore >= 60 ? .favorable : .unfavorable,
                detail: "近 \(min(history.count, 30)) 晚就寝规律"
            ))
        }

        return result
    }

    // MARK: - Stages

    /// 分期结构分：Deep 40% + REM 40% + Core 20%。
    /// 任一分期缺失则该项退出（返回 nil）。
    func stageScore(today: DailyHealthMetrics) -> Double? {
        guard let total = today.sleepHours?.value, total > 0,
              let deep = today.sleepDeepHours?.value,
              let rem = today.sleepREMHours?.value,
              let core = today.sleepCoreHours?.value else {
            return nil
        }

        let deepRatio = deep / total
        let remRatio = rem / total
        let coreRatio = core / total

        // 目标比例：Deep 20%、REM 22%；偏离则按比例扣分（上限 100）
        let deepScore = min(100, deepRatio / Self.deepTargetRatio * 100)
        let remScore = min(100, remRatio / Self.remTargetRatio * 100)
        // Core 没有硬目标，占比 30-60% 都算合理
        let coreScore: Double
        if coreRatio >= 0.30 && coreRatio <= 0.60 {
            coreScore = 100
        } else if coreRatio < 0.30 {
            coreScore = coreRatio / 0.30 * 100
        } else {
            coreScore = max(0, 100 - (coreRatio - 0.60) * 200)
        }

        return 0.4 * deepScore + 0.4 * remScore + 0.2 * coreScore
    }

    // MARK: - Consistency

    /// 就寝时刻的圆周标准差（Whoordan 法）→ 0-100 分。
    /// 少于 3 晚返回 nil（不参与计算）。
    func consistencyScore(history: [DailyHealthMetrics]) -> Double? {
        let bedtimes = history.compactMap(\.bedtime)
        guard bedtimes.count >= Self.minNightsForConsistency else { return nil }

        let hours = bedtimes.map { bedtime -> Double in
            // 转成 0-24 的小时数
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.hour, .minute], from: bedtime)
            return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
        }

        guard let stdHours = circularStdDevHours(hours) else { return nil }

        // std 越小越好：0.5h → 100，3h → 0
        if stdHours <= Self.consistencyFullScoreStdHours {
            return 100
        }
        if stdHours >= Self.consistencyZeroScoreStdHours {
            return 0
        }
        let range = Self.consistencyZeroScoreStdHours - Self.consistencyFullScoreStdHours
        return (Self.consistencyZeroScoreStdHours - stdHours) / range * 100
    }

    /// 圆周标准差（小时）。用 sin/cos 均值的合成向量长度。
    /// 依据：Whoordan `SleepConsistencyCalculator`。
    func circularStdDevHours(_ hours: [Double]) -> Double? {
        guard hours.count >= 2 else { return nil }
        let angles = hours.map { ($0.truncatingRemainder(dividingBy: 24) + 24)
            .truncatingRemainder(dividingBy: 24) / 24 * 2 * .pi }
        let sinMean = angles.map { sin($0) }.reduce(0, +) / Double(angles.count)
        let cosMean = angles.map { cos($0) }.reduce(0, +) / Double(angles.count)
        let resultant = hypot(sinMean, cosMean)
        guard resultant > 0 else { return 24 } // 完全分散
        let stdRadians = sqrt(max(-2 * log(resultant), 0))
        return stdRadians * 24 / (2 * .pi)
    }
}
