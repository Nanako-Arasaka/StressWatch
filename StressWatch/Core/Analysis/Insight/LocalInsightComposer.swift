import Foundation

/// 本地洞察结果（LLM 失败 / 关闭时的兜底）。
struct LocalInsight {
    let summary: String
    let keyChanges: [String]
    let possibleFactors: [String]
    let trendsSummary: [String]
    let confidenceNote: String
    let disclaimer: String
}

/// 本地洞察生成器：纯端上、无 LLM、无编造。
///
/// 对应 Soma `buildExplanation` + Thump `RecoveryContext` 思路：
/// LLM 关闭 / 失败 / 无 Key 时，UI 仍有完整可读分析。
/// 措辞严格遵守 `AssociationWording` 约束，不含因果动词。
enum LocalInsightComposer {

    static func compose(_ result: StructuredAnalysisResult) -> LocalInsight {
        // Summary
        let summary = buildSummary(result)

        // Key Changes
        let keyChanges = buildKeyChanges(result)

        // Possible Factors（来自 correlation associations）
        let possibleFactors = buildPossibleFactors(result)

        // Trends Summary
        let trendsSummary = buildTrendsSummary(result)

        // Confidence Note
        let confidenceNote = buildConfidenceNote(result)

        return LocalInsight(
            summary: summary,
            keyChanges: keyChanges,
            possibleFactors: possibleFactors,
            trendsSummary: trendsSummary,
            confidenceNote: confidenceNote,
            disclaimer: "本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。"
        )
    }

    // MARK: - Summary

    private static func buildSummary(_ result: StructuredAnalysisResult) -> String {
        var parts: [String] = []

        if let stress = result.stressScore {
            let level = result.stressLevel?.displayName ?? ""
            parts.append("今日压力参考分为 \(stress)（\(level)）")
        }
        if let recovery = result.recoveryScore {
            let level = result.recoveryLevel?.displayName ?? ""
            parts.append("恢复分为 \(recovery)（\(level)）")
        }

        if parts.isEmpty {
            return "当前数据不足，建议继续积累 Apple Health 数据后再观察趋势。"
        }

        // 补充最突出的变化
        if let hrv = result.hrvDeviation, let dev = hrv.deviationPercent {
            if dev < -15 {
                parts.append("HRV 明显低于个人近期水平")
            } else if dev > 15 {
                parts.append("HRV 高于个人近期水平")
            }
        }

        return parts.joined(separator: "，") + "。"
    }

    // MARK: - Key Changes

    private static func buildKeyChanges(_ result: StructuredAnalysisResult) -> [String] {
        var changes: [String] = []

        for metric in result.metrics {
            guard let value = metric.value else { continue }
            let name = metric.metric.displayName

            if let dev = metric.deviationPercent {
                let direction = dev > 0 ? "↑" : "↓"
                let unit = metric.unit
                let valueStr = value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
                changes.append("\(name)：\(valueStr) \(unit) \(direction) \(String(format: "%.1f", abs(dev)))% vs baseline")
            } else {
                let valueStr = value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
                changes.append("\(name)：\(valueStr) \(metric.unit)")
            }
        }

        return changes.isEmpty ? ["暂无足够数据对比个人基线"] : changes
    }

    // MARK: - Possible Factors（只说关联，不说因果）

    private static func buildPossibleFactors(_ result: StructuredAnalysisResult) -> [String] {
        let significant = result.associations.filter {
            $0.strength == .noticeable || $0.strength == .clear || $0.strength == .strong
        }

        if significant.isEmpty {
            return ["目前数据中还没有观察到清晰的指标关联，再多记录几天会更清楚。"]
        }

        return significant.prefix(3).map { $0.description }
    }

    // MARK: - Trends Summary

    private static func buildTrendsSummary(_ result: StructuredAnalysisResult) -> [String] {
        // 只取 7 天窗口的结论
        let weekTrends = result.trends.filter { $0.window == .days7 }

        return weekTrends.map { trend in
            let name = trend.metric.displayName
            let dir = trend.direction.displayName

            if trend.direction == .insufficientData {
                return "\(name)：数据不足，还需 \(trend.daysRemaining) 天。"
            }

            let dev = trend.deviationPercent.map { String(format: "%.1f%%", $0) } ?? ""
            if dev.isEmpty {
                return "\(name)：近 7 天趋势\(dir)。"
            }
            return "\(name)：近 7 天趋势\(dir)（偏离基线 \(dev)）。"
        }
    }

    // MARK: - Confidence Note

    private static func buildConfidenceNote(_ result: StructuredAnalysisResult) -> String {
        var note = "本次分析可信度：\(result.confidence.displayName)。"

        if let missing = result.completeness.missingSummary {
            note += " \(missing)。"
        }

        let core = result.completeness.coreCompleteness
        if core < 1 {
            note += " 核心指标可用率 \(String(format: "%.0f%%", core * 100))。"
        }

        return note
    }
}
