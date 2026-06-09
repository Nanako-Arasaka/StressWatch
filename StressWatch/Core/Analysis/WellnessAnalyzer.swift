import Foundation

protocol WellnessAnalyzing {
    func analyze(features: WellnessFeatures) -> WellnessAnalysis
}

// WellnessAnalyzer 是当前 MVP 的轻量规则模型。
// 未来替换为 Core ML 时，只需要实现同一个 WellnessAnalyzing 协议。
struct WellnessAnalyzer: WellnessAnalyzing {
    func analyze(features: WellnessFeatures) -> WellnessAnalysis {
        if features.availableFeatureCount < 4 || features.dataConfidence < 0.35 {
            return makeAnalysis(
                state: .dataInsufficient,
                features: features,
                factors: ["可用指标较少", "建议积累更多连续数据", "当前结果仅作低置信度参考"]
            )
        }

        if (features.stressAverage ?? 0) >= 70 ||
            ((features.avgRestingHR ?? 0) >= 78 && (features.hrvTrend ?? 0) <= -5) {
            return makeAnalysis(
                state: .highStrain,
                features: features,
                factors: compactFactors([
                    features.stressAverage.map { "压力趋势平均约 \(Int(round($0)))" },
                    features.avgRestingHR.map { "静息心率平均约 \(Int(round($0))) bpm" },
                    features.hrvTrend.map { "HRV 近期变化约 \(signedInt($0)) ms" }
                ])
            )
        }

        if (features.recoveryAverage ?? 100) < 45 ||
            ((features.avgHRV ?? 100) < 35 && (features.sleepAverage ?? 8) < 7) {
            return makeAnalysis(
                state: .needRecovery,
                features: features,
                factors: compactFactors([
                    features.recoveryAverage.map { "恢复分数平均约 \(Int(round($0)))" },
                    features.avgHRV.map { "HRV 平均约 \(Int(round($0))) ms" },
                    features.sleepAverage.map { "睡眠平均约 \(formatHours($0))" }
                ])
            )
        }

        if (features.sleepAverage ?? 8) < 6.5 || (features.sleepConsistency ?? 1) < 0.45 {
            return makeAnalysis(
                state: .sleepDebt,
                features: features,
                factors: compactFactors([
                    features.sleepAverage.map { "睡眠平均约 \(formatHours($0))" },
                    features.sleepConsistency.map { "睡眠稳定度约 \(Int(round($0 * 100)))%" },
                    features.awakeAverage.map { "清醒阶段平均约 \(formatHours($0))" }
                ])
            )
        }

        if (features.stepsAverage ?? 8_000) < 4_000 && (features.activityLevel ?? 1) < 0.45 {
            return makeAnalysis(
                state: .lowActivity,
                features: features,
                factors: compactFactors([
                    features.stepsAverage.map { "步数平均约 \(Int(round($0)))" },
                    features.activeEnergyAverage.map { "活动能量平均约 \(Int(round($0))) kcal" },
                    features.exerciseMinutesAverage.map { "运动时间平均约 \(Int(round($0))) min" }
                ])
            )
        }

        return makeAnalysis(
            state: .balanced,
            features: features,
            factors: compactFactors([
                features.stressAverage.map { "压力趋势平均约 \(Int(round($0)))" },
                features.recoveryAverage.map { "恢复分数约 \(Int(round($0)))" },
                features.activityLevel.map { "活动完成度约 \(Int(round($0 * 100)))%" }
            ])
        )
    }

    private func makeAnalysis(
        state: WellnessState,
        features: WellnessFeatures,
        factors: [String]
    ) -> WellnessAnalysis {
        let label = label(for: state)
        let generatedAt = Date()
        let insight = MLWellnessInsightFactory.makeInsight(
            label: label,
            state: state,
            confidence: features.dataConfidence,
            features: features,
            source: .ruleBased,
            generatedAt: generatedAt
        )

        WellnessAnalysis(
            state: state,
            predictedLabel: label,
            confidence: features.dataConfidence,
            primaryFactors: insight.keyFactors,
            features: features,
            generatedAt: generatedAt,
            source: .ruleBased,
            mlInsight: insight
        )
    }

    private func label(for state: WellnessState) -> String {
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

    private func compactFactors(_ factors: [String?]) -> [String] {
        let values = factors.compactMap { $0 }
        return values.isEmpty ? ["当前可解释因素较少"] : values
    }

    private func signedInt(_ value: Double) -> String {
        let rounded = Int(round(value))
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }
}
