import Foundation

/// LLM 输出后置校验（Thump 只在测试层做，这里提到运行时）。
///
/// 校验三类：
/// 1. banned terms（医疗 / jargon / AI 腔 / 拟人化）
/// 2. 因果动词黑名单
/// 3. 数值回溯：insight 中的数字必须能在 StructuredAnalysisResult 中找到
enum InsightSafetyValidator {

    /// 校验结果。
    struct ValidationResult {
        let isSafe: Bool
        let violations: [String]
        /// 数值可疑（找不到来源）。
        let suspectNumbers: [String]

        var hasSuspectNumbers: Bool { !suspectNumbers.isEmpty }
    }

    // MARK: - 黑名单

    static let medicalTerms = [
        "诊断", "治疗", "治愈", "处方", "临床", "病理", "疾病",
        "diagnose", "treat", "cure", "prescribe", "clinical", "pathological"
    ]

    static let jargonTerms = [
        "SDNN", "RMSSD", "coefficient", "z-score", "p-value", "regression analysis",
        "标准差", "方差", "相关系数", "回归分析"
    ]

    static let aiSlopTerms = [
        "crushing it", "on fire", "killing it", "smashing it", "rock solid",
        "太棒了", "棒极了", "无敌", "碾压"
    ]

    static let anthropomorphTerms = [
        "你的心脏在说", "你的身体在请求", "你的心脏喜欢",
        "your heart loves", "your body is asking", "your heart is telling you"
    ]

    static let causalTerms = [
        "导致", "因为", "证明", "引起", "造成", "说明你",
        "causes", "because", "proves", "leads to", "results in"
    ]

    // MARK: - Public

    static func validate(
        _ insight: PersonalizationInsight,
        against result: StructuredAnalysisResult
    ) -> ValidationResult {
        var violations: [String] = []
        var suspectNumbers: [String] = []

        // 合并所有文本
        let texts = [insight.summary]
            + insight.findings.map { "\($0.title) \($0.detail)" }
            + insight.suggestions

        for text in texts {
            // 1. Banned terms
            for term in medicalTerms where text.contains(term) {
                violations.append("医疗术语: \(term)")
            }
            for term in jargonTerms where text.contains(term) {
                violations.append("专业术语: \(term)")
            }
            for term in aiSlopTerms where text.localizedCaseInsensitiveContains(term) {
                violations.append("AI 腔: \(term)")
            }
            for term in anthropomorphTerms where text.localizedCaseInsensitiveContains(term) {
                violations.append("拟人化: \(term)")
            }

            // 2. 因果动词
            for term in causalTerms where text.contains(term) {
                violations.append("因果动词: \(term)")
            }

            // 3. 数值回溯
            let numbers = extractNumbers(from: text)
            for number in numbers where !existsInResult(number, result: result) {
                suspectNumbers.append(number)
            }
        }

        return ValidationResult(
            isSafe: violations.isEmpty,
            violations: violations,
            suspectNumbers: suspectNumbers
        )
    }

    // MARK: - 数值提取与回溯

    /// 从文本中提取数字（整数和一位小数）。
    static func extractNumbers(from text: String) -> [String] {
        var numbers: [String] = []
        let pattern = "\\d+\\.?\\d*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let number = nsText.substring(with: match.range)
            // 过滤掉极小的数字（可能是时间戳等）
            if let value = Double(number), value > 0.5 {
                numbers.append(number)
            }
        }
        return numbers
    }

    /// 数字是否能在 StructuredAnalysisResult 中找到（±0.5 容差）。
    static func existsInResult(_ number: String, result: StructuredAnalysisResult) -> Bool {
        guard let value = Double(number) else { return false }

        // 收集所有已知数值
        var known: [Double] = []

        if let s = result.stressScore { known.append(Double(s)) }
        if let r = result.recoveryScore { known.append(Double(r)) }

        for m in result.metrics {
            if let v = m.value { known.append(v) }
            if let b = m.baseline { known.append(b) }
            if let d = m.deviationPercent { known.append(abs(d)) }
        }

        if let sq = result.sleepQuality {
            if let h = sq.durationHours { known.append(h) }
            if let b = sq.baselineHours { known.append(b) }
            if let rem = sq.remPercent { known.append(rem) }
            if let deep = sq.deepPercent { known.append(deep) }
        }

        for t in result.trends {
            if let v = t.currentValue { known.append(v) }
            if let b = t.baselineValue { known.append(b) }
            if let d = t.deviationPercent { known.append(abs(d)) }
        }

        // confidence 和 completeness
        known.append(result.completeness.coreCompleteness * 100)
        known.append(result.completeness.overallCompleteness * 100)

        // ±0.5 容差
        return known.contains { abs($0 - value) <= 0.5 }
    }
}
