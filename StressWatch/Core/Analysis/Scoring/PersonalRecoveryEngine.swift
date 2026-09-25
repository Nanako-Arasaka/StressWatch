import Foundation

/// 个人化恢复分析引擎（替换旧 `RecoveryModel`，旧的保留不删）。
///
/// **关键修正**：旧 `RecoveryModel` 用 `current/baseline * 40`，"等于基线" = 满分 100。
/// 这里改为 `50 + z * 25`：**等于基线 = 50 分（中性），高于基线才能拿高分**。
///
/// 分量与权重：
/// - HRV 40%（log 域 z-score）
/// - Resting HR 20%（双向）
/// - Sleep 25%（SleepQualityEngine）
/// - Activity Load 15%（ACR 惩罚）
///
/// **不变式**：`Σ contributions.points == score`（±0.5）。
/// 全缺失 → `score == nil`。只 `import Foundation`。
struct PersonalRecoveryEngine {

    private let sleepEngine = SleepQualityEngine()
    private let loadEngine = ActivityLoadEngine()

    // MARK: - 输出

    struct RecoveryAnalysis: Codable {
        let score: Int?
        let level: RecoveryLevel?
        let contributions: [ScoreContribution]
        let confidence: AnalysisConfidence
        let warnings: [String]
        let isProvisional: Bool
    }

    // MARK: - Public

    func compute(
        today: DailyHealthMetrics?,
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet
    ) -> RecoveryAnalysis {
        var warnings: [String] = []
        var confidenceScore: Double = 1.0

        let isProvisional = !baselines.hrv.isReliable
        if isProvisional {
            warnings.append("基线形成中，恢复分数将随数据积累而 refine")
            confidenceScore -= 0.25
        }

        struct Component {
            let signal: SignalKind
            let rawScore: Double
            let weight: Double
            let direction: ContributionDirection
            let detail: String
        }

        var components: [Component] = []

        // 1. HRV 分量（权重 0.40）—— 50 + z * 25
        if let hrvValue = today?.hrv?.value {
            let hrvScore: Double
            let detail: String

            if baselines.hrv.isReliable, let z = baselines.hrv.zScore(of: hrvValue) {
                hrvScore = min(100, max(0, 50 + z * 25))
                let dev = baselines.hrv.deviationPercent(of: hrvValue) ?? 0
                detail = String(format: "HRV %.0f ms，偏离个人基线 %.1f%%", hrvValue, dev)
            } else {
                // 人群参考 40ms
                let ratio = hrvValue / 40
                hrvScore = min(100, max(0, 50 + (ratio - 1) * 50))
                detail = String(format: "HRV %.0f ms（基线形成中）", hrvValue)
            }

            let direction: ContributionDirection = hrvScore >= 65 ? .favorable
                : hrvScore <= 35 ? .unfavorable : .normal
            components.append(Component(
                signal: .hrv, rawScore: hrvScore, weight: 0.40,
                direction: direction, detail: detail
            ))
        } else {
            warnings.append("HRV 数据缺失，未纳入恢复评估")
            confidenceScore -= 0.15
        }

        // 2. Resting HR 分量（权重 0.20）—— 双向
        if let rhrValue = today?.restingHeartRate?.value {
            let rhrScore: Double
            let detail: String

            if baselines.restingHeartRate.sampleDays >= 5 {
                // RHR 低 = 恢复好
                let dev = baselines.restingHeartRate.value - rhrValue
                rhrScore = min(100, max(0, 50 + dev * 4))
                detail = String(format: "静息心率 %.0f bpm，基线 %.0f bpm", rhrValue, baselines.restingHeartRate.value)
            } else {
                let dev = 60 - rhrValue
                rhrScore = min(100, max(0, 50 + dev * 4))
                detail = String(format: "静息心率 %.0f bpm（基线形成中）", rhrValue)
            }

            let direction: ContributionDirection = rhrScore >= 65 ? .favorable
                : rhrScore <= 35 ? .unfavorable : .normal
            components.append(Component(
                signal: .restingHeartRate, rawScore: rhrScore, weight: 0.20,
                direction: direction, detail: detail
            ))
        } else {
            warnings.append("静息心率数据缺失，未纳入恢复评估")
            confidenceScore -= 0.15
        }

        // 3. Sleep 分量（权重 0.25）—— 用 SleepQualityEngine
        if let today = today, let sleepScore = sleepEngine.score(today: today, history: history, baselines: baselines) {
            let direction: ContributionDirection = sleepScore >= 65 ? .favorable
                : sleepScore <= 35 ? .unfavorable : .normal
            let hours = today.sleepHours?.value ?? 0
            components.append(Component(
                signal: .sleep, rawScore: sleepScore, weight: 0.25,
                direction: direction,
                detail: String(format: "睡眠质量 %.0f/100（%.1f 小时）", sleepScore, hours)
            ))
        } else {
            warnings.append("睡眠数据不足，未纳入恢复评估")
            confidenceScore -= 0.10
        }

        // 4. Activity Load 分量（权重 0.15）—— ACR 惩罚
        if let today = today,
           let acr = loadEngine.acr(history: history, baselines: baselines, now: Date()) {
            // ACR = 1 → loadScore = 50；ACR > 1.3 → 下降；ACR < 1 → 上升
            let loadScore = min(100, max(0, 100 - (acr - 0.5) * 60))
            let direction: ContributionDirection = acr > 1.3 ? .unfavorable
                : acr < 0.8 ? .favorable : .normal
            components.append(Component(
                signal: .activityLoad, rawScore: loadScore, weight: 0.15,
                direction: direction,
                detail: String(format: "活动负荷比 ACR %.2f", acr)
            ))
        }

        guard !components.isEmpty else {
            return RecoveryAnalysis(
                score: nil, level: nil, contributions: [],
                confidence: .insufficient, warnings: warnings, isProvisional: isProvisional
            )
        }

        // 权重重归一化
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let normalized = components.map {
            (signal: $0.signal, rawScore: $0.rawScore, weight: $0.weight / totalWeight,
             direction: $0.direction, detail: $0.detail)
        }

        let weightedScore = normalized.reduce(0.0) { $0 + $1.rawScore * $1.weight }

        if !baselines.hrv.isReliable && !isProvisional {
            confidenceScore -= 0.10
            warnings.append("HRV 基线变异度不足")
        }

        confidenceScore = max(0, min(1, confidenceScore))
        let confidence = isProvisional ? .low : AnalysisConfidence.from(score: confidenceScore)

        let finalScore = Int(round(min(100, max(0, weightedScore))))
        let level: RecoveryLevel = finalScore <= 33 ? .poor : (finalScore <= 66 ? .fair : .good)

        let contributions = normalized.map {
            ScoreContribution(
                signal: $0.signal, rawScore: $0.rawScore, weight: $0.weight,
                direction: $0.direction, detail: $0.detail
            )
        }

        return RecoveryAnalysis(
            score: finalScore, level: level, contributions: contributions,
            confidence: confidence, warnings: warnings, isProvisional: isProvisional
        )
    }
}
