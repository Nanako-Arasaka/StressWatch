import Foundation

// LiveStressEstimator 是无状态纯函数，方便后续测试或替换算法。
enum LiveStressEstimator {
    static func estimate(
        recentHRV: Double?,
        baselineHRV: Double?,
        recentRestingHR: Double?,
        baselineRestingHR: Double?,
        sleepHours: Double?,
        baselineSleepHours: Double?,
        source: AppDataSource,
        now: Date = Date()
    ) -> LiveStressSnapshot {
        let confidence = dataConfidence(
            recentHRV: recentHRV,
            baselineHRV: baselineHRV,
            recentRestingHR: recentRestingHR,
            baselineRestingHR: baselineRestingHR,
            sleepHours: sleepHours,
            baselineSleepHours: baselineSleepHours
        )

        guard
            let recentHRV,
            let baselineHRV,
            baselineHRV > 0
        else {
            return LiveStressSnapshot(
                score: nil,
                status: .dataInsufficient,
                recentHRV: recentHRV,
                baselineHRV: baselineHRV,
                hrvDeviationPercent: nil,
                recentRestingHR: recentRestingHR,
                baselineRestingHR: baselineRestingHR,
                sleepHours: sleepHours,
                baselineSleepHours: baselineSleepHours,
                dataConfidence: confidence,
                lastUpdated: now,
                explanation: "近期 HRV 或相对基线不足，建议等待更多 Apple Health 数据后再查看趋势参考。",
                source: source
            )
        }

        let hrvDeviation = (recentHRV - baselineHRV) / safeDenominator(baselineHRV)
        var score = initialScore(forHRVDeviation: hrvDeviation)

        if
            let recentRestingHR,
            let baselineRestingHR,
            baselineRestingHR > 0
        {
            let restingDelta = recentRestingHR - baselineRestingHR
            if restingDelta > 10 {
                score += 15
            } else if restingDelta > 5 {
                score += 8
            }
        }

        if
            let sleepHours,
            let baselineSleepHours,
            baselineSleepHours > 0
        {
            let sleepRatio = sleepHours / safeDenominator(baselineSleepHours)
            if sleepRatio < 0.70 {
                score += 15
            } else if sleepRatio < 0.85 {
                score += 8
            }
        }

        let finalScore = clamp(score, 0, 100)
        let status = status(for: finalScore)

        return LiveStressSnapshot(
            score: finalScore,
            status: status,
            recentHRV: recentHRV,
            baselineHRV: baselineHRV,
            hrvDeviationPercent: hrvDeviation * 100,
            recentRestingHR: recentRestingHR,
            baselineRestingHR: baselineRestingHR,
            sleepHours: sleepHours,
            baselineSleepHours: baselineSleepHours,
            dataConfidence: confidence,
            lastUpdated: now,
            explanation: explanation(status: status, hrvDeviation: hrvDeviation),
            source: source
        )
    }

    private static func initialScore(forHRVDeviation hrvDeviation: Double) -> Double {
        if hrvDeviation >= 0.10 {
            return 20
        } else if hrvDeviation >= -0.10 {
            return 40
        } else if hrvDeviation >= -0.20 {
            return 60
        } else if hrvDeviation >= -0.30 {
            return 78
        } else {
            return 90
        }
    }

    private static func status(for score: Double) -> LiveStressStatus {
        if score <= 25 {
            return .recoveryGood
        } else if score <= 50 {
            return .normal
        } else if score <= 70 {
            return .mildStress
        } else if score <= 85 {
            return .attentionStress
        } else {
            return .highStress
        }
    }

    private static func dataConfidence(
        recentHRV: Double?,
        baselineHRV: Double?,
        recentRestingHR: Double?,
        baselineRestingHR: Double?,
        sleepHours: Double?,
        baselineSleepHours: Double?
    ) -> Double {
        var confidence = 0.0
        if recentHRV != nil, baselineHRV != nil {
            confidence += 60
        }
        if recentRestingHR != nil, baselineRestingHR != nil {
            confidence += 20
        }
        if sleepHours != nil, baselineSleepHours != nil {
            confidence += 20
        }
        return min(confidence, 100)
    }

    private static func explanation(status: LiveStressStatus, hrvDeviation: Double) -> String {
        let deviationText = hrvDeviation < 0 ? "低于" : "高于"

        switch status {
        case .recoveryGood:
            return "近期 HRV 相对基线\(deviationText)，当前恢复趋势参考较好。"
        case .normal:
            return "近期 HRV 接近个人基线，当前状态趋势参考较平稳。"
        case .mildStress:
            return "近期 HRV 相对基线偏低，可能提示恢复压力增加，建议关注休息节奏。"
        case .attentionStress:
            return "近期 HRV 明显低于个人基线，当前趋势参考提示需要关注恢复和睡眠。"
        case .highStress:
            return "近期 HRV 大幅低于个人基线，当前趋势参考较高，建议优先关注放松和睡眠。"
        case .dataInsufficient:
            return "近期 HRV 或个人基线不足，暂不生成当前压力趋势参考。"
        }
    }
}
