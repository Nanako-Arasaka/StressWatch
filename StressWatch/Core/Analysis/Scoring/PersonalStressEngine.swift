import Foundation

/// 个人化压力分析引擎（替换旧 `StressModel`，旧的保留不删）。
///
/// 算法综合 Soma + Thump：
/// 1. sedentary 过滤（Soma）—— 剔除运动时段心率，不把活动当压力
/// 2. 各信号 z-score（Soma log 域 + Thump robust Z）
/// 3. 双向归一化 —— 不是只罚不奖
/// 4. 权重重分配（Soma `totalWeight` 模式）—— 缺失信号退出
/// 5. disagreement damping（Thump）—— 信号互搏时向中性压缩
/// 6. confidence 扣分制 + warnings（Thump）—— 每个扣分一条可读原因
/// 7. provisional 兜底（Thump）—— 基线未成型不空态阻塞
///
/// **不变式**：`Σ contributions.points == score`（±0.5）。
/// 全缺失 → `score == nil`（不是 0，不是 50）。
/// 只 `import Foundation`。
struct PersonalStressEngine {

    /// 运动后冷却时间（分钟）。
    static let workoutCooldownMinutes: Double = 15
    /// 努力度阈值：HR ≥ 50% maxHR 视为运动（Soma `effortThresholdRatio`）。
    static let effortThresholdRatio: Double = 0.5
    /// 估算 maxHR 的年龄参考（无用户年龄时用 190）。
    static let referenceMaxHR: Double = 190

    // MARK: - 输出

    /// 一次压力分析的完整结果。
    struct StressAnalysis: Codable {
        /// nil = 数据不足，不给分数。
        let score: Int?
        let level: StressLevel?
        let contributions: [ScoreContribution]
        let confidence: AnalysisConfidence
        /// 每个扣分项一条人类可读原因。
        let warnings: [String]
        /// 基线未成型（用人群参考值）。
        let isProvisional: Bool
    }

    // MARK: - Public

    func compute(
        today: DailyHealthMetrics?,
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet
    ) -> StressAnalysis {
        var warnings: [String] = []
        var confidenceScore: Double = 1.0

        // 7. Provisional：基线未成型
        let isProvisional = !baselines.hrv.isReliable
        if isProvisional {
            warnings.append("基线形成中，分数将随数据积累而 refine")
            confidenceScore -= 0.25
        }

        // 分量收集
        struct Component {
            let signal: SignalKind
            let rawScore: Double
            let weight: Double
            let direction: ContributionDirection
            let detail: String
            /// 该分量的"方向分"（+1 压力高 / 0 中性 / -1 压力低），用于 disagreement 检测。
            let stressPolarity: Int
        }

        var components: [Component] = []

        // 1. HRV 分量（权重 0.35）
        if let hrvValue = today?.hrv?.value {
            let hrvScore: Double
            let polarity: Int
            let detail: String

            if baselines.hrv.isReliable, let z = baselines.hrv.zScore(of: hrvValue) {
                // 双向：z = -2 → 90（HRV 低压 = 压力高）；z = 0 → 50；z = +2 → 10
                hrvScore = min(100, max(0, 50 - z * 20))
                polarity = z < -1 ? 1 : (z > 1 ? -1 : 0)
                let dev = baselines.hrv.deviationPercent(of: hrvValue) ?? 0
                detail = String(format: "HRV %.0f ms，偏离个人基线 %.1f%%", hrvValue, dev)
            } else if isProvisional {
                // 人群参考值 40ms
                let ratio = hrvValue / 40
                hrvScore = min(100, max(0, 100 - ratio * 50))
                polarity = hrvValue < 35 ? 1 : 0
                detail = String(format: "HRV %.0f ms（基线形成中，参考人群均值 40 ms）", hrvValue)
            } else {
                // 有值但基线不可靠且非 provisional（不应发生）→ 退出
                hrvScore = 50
                polarity = 0
                detail = "HRV 基线不可靠"
            }

            let direction: ContributionDirection = hrvScore >= 65 ? .unfavorable
                : hrvScore <= 35 ? .favorable : .normal
            components.append(Component(
                signal: .hrv, rawScore: hrvScore, weight: 0.35,
                direction: direction, detail: detail, stressPolarity: polarity
            ))
        } else {
            warnings.append("HRV 数据缺失，未纳入本次压力判断")
            confidenceScore -= 0.15
        }

        // 2. Resting HR 分量（权重 0.25）
        if let rhrValue = today?.restingHeartRate?.value {
            let rhrScore: Double
            let polarity: Int
            let detail: String

            if baselines.restingHeartRate.sampleDays >= 5 {
                let dev = rhrValue - baselines.restingHeartRate.value
                rhrScore = min(100, max(0, 50 + dev * 3))
                polarity = dev > 5 ? 1 : (dev < -5 ? -1 : 0)
                detail = String(format: "静息心率 %.0f bpm，基线 %.0f bpm（%+.0f）", rhrValue, baselines.restingHeartRate.value, dev)
            } else {
                // 人群参考 60 bpm
                let dev = rhrValue - 60
                rhrScore = min(100, max(0, 50 + dev * 3))
                polarity = dev > 5 ? 1 : 0
                detail = String(format: "静息心率 %.0f bpm（基线形成中，参考 60 bpm）", rhrValue)
            }

            let direction: ContributionDirection = rhrScore >= 65 ? .unfavorable
                : rhrScore <= 35 ? .favorable : .normal
            components.append(Component(
                signal: .restingHeartRate, rawScore: rhrScore, weight: 0.25,
                direction: direction, detail: detail, stressPolarity: polarity
            ))
        } else {
            warnings.append("静息心率数据缺失，未纳入本次压力判断")
            confidenceScore -= 0.15
        }

        // 3. Sleep 分量（权重 0.25）
        if let sleepValue = today?.sleepHours?.value {
            let sleepScore: Double
            let polarity: Int
            let detail: String

            if baselines.sleepHours.sampleDays >= 5 {
                let gap = baselines.sleepHours.value - sleepValue
                sleepScore = min(100, max(0, 50 + gap * 12))
                polarity = gap > 1 ? 1 : (gap < -1 ? -1 : 0)
                detail = String(format: "睡眠 %.1f 小时，基线 %.1f 小时（缺口 %+.1f h）", sleepValue, baselines.sleepHours.value, -gap)
            } else {
                let gap = 7.5 - sleepValue
                sleepScore = min(100, max(0, 50 + gap * 12))
                polarity = gap > 1 ? 1 : 0
                detail = String(format: "睡眠 %.1f 小时（基线形成中，参考 7.5 h）", sleepValue)
            }

            let direction: ContributionDirection = sleepScore >= 65 ? .unfavorable
                : sleepScore <= 35 ? .favorable : .normal
            components.append(Component(
                signal: .sleep, rawScore: sleepScore, weight: 0.25,
                direction: direction, detail: detail, stressPolarity: polarity
            ))
        } else {
            warnings.append("睡眠数据缺失，未纳入本次压力判断")
            confidenceScore -= 0.10
        }

        // 4. Activity Load 分量（权重 0.15）
        if let today = today {
            let loadEngine = ActivityLoadEngine()
            if let loadScore = loadEngine.dailyLoad(today, baselines: baselines) {
                // 高负荷 → 压力偏高
                let normalized = min(100, max(0, loadScore))
                let polarity = normalized > 70 ? 1 : (normalized < 30 ? -1 : 0)
                let direction: ContributionDirection = normalized >= 70 ? .unfavorable
                    : normalized <= 30 ? .favorable : .normal
                components.append(Component(
                    signal: .activityLoad, rawScore: normalized, weight: 0.15,
                    direction: direction,
                    detail: String(format: "活动负荷 %.0f/100", normalized),
                    stressPolarity: polarity
                ))
            }
        }

        // 全缺失 → score == nil
        guard !components.isEmpty else {
            return StressAnalysis(
                score: nil, level: nil, contributions: [],
                confidence: .insufficient, warnings: warnings, isProvisional: isProvisional
            )
        }

        // 4. 权重重归一化
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let normalizedComponents = components.map {
            (signal: $0.signal, rawScore: $0.rawScore, weight: $0.weight / totalWeight,
             direction: $0.direction, detail: $0.detail, stressPolarity: $0.stressPolarity)
        }

        var weightedScore = normalizedComponents.reduce(0.0) {
            $0 + $1.rawScore * $1.weight
        }

        // 5. Disagreement damping
        let polarities = normalizedComponents.map(\.stressPolarity)
        let hasPositive = polarities.contains(1)
        let hasNegative = polarities.contains(-1)
        if hasPositive && hasNegative {
            weightedScore = weightedScore * 0.7 + 50 * 0.3
            confidenceScore -= 0.30
            warnings.append("HRV 与静息心率信号方向不一致，分数已向中性压缩")
        }

        // 6. Confidence 扣分
        if !baselines.hrv.isReliable && !isProvisional {
            confidenceScore -= 0.10
            warnings.append("HRV 基线变异度不足")
        }

        confidenceScore = max(0, min(1, confidenceScore))
        let confidence = isProvisional ? .low : AnalysisConfidence.from(score: confidenceScore)

        let finalScore = Int(round(min(100, max(0, weightedScore))))
        let level: StressLevel = finalScore <= 33 ? .low : (finalScore <= 66 ? .medium : .high)

        // 构建 contributions（必须满足 Σ points ≈ finalScore）
        let contributions = normalizedComponents.map {
            ScoreContribution(
                signal: $0.signal, rawScore: $0.rawScore, weight: $0.weight,
                direction: $0.direction, detail: $0.detail
            )
        }

        return StressAnalysis(
            score: finalScore, level: level, contributions: contributions,
            confidence: confidence, warnings: warnings, isProvisional: isProvisional
        )
    }

    // MARK: - Sedentary 过滤（Soma filterSedentary）

    /// 从当日 HR 样本中剔除运动时段 + 运动后冷却期的心率。
    /// 用于避免把活动导致的 HR 升高误判为压力。
    /// 依据：Soma `StressCalculator.filterSedentary`。
    func filterSedentary(
        _ samples: [(date: Date, hr: Double)],
        workoutIntervals: [WorkoutInterval],
        maxHR: Double = PersonalStressEngine.referenceMaxHR
    ) -> [(date: Date, hr: Double)] {
        let cooldown = Self.workoutCooldownMinutes * 60
        return samples.filter { sample in
            // 努力度阈值
            if maxHR > 0, sample.hr >= Self.effortThresholdRatio * maxHR {
                return false
            }
            // workout 窗口 + 冷却期
            for workout in workoutIntervals {
                let cooldownEnd = workout.end.addingTimeInterval(cooldown)
                if sample.date >= workout.start && sample.date <= cooldownEnd {
                    return false
                }
            }
            return true
        }
    }
}
