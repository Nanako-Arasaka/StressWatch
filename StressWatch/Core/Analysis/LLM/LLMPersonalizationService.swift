import Foundation

enum LLMServiceError: LocalizedError {
    case disabled
    case missingAPIKey
    case invalidResponse
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .disabled: return "AI 分析未启用，请在设置中开启并填写 MiniMax API Key。"
        case .missingAPIKey: return "未找到 MiniMax API Key，请在设置中填写。"
        case .invalidResponse: return "模型返回了无法解析的结果，请重试。"
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - AnalysisPayload（端上已算好的聚合快照，LLM 只解读不重算）

/// 一次健康数据分析任务的结构化输入。
/// 全部数值来自 FeatureExtractor / WellnessAnalysis / PersonalizationContext /
/// GoalOptimizer / PersonalizedAdviceGenerator，LLM 不负责重新计算。
struct AnalysisPayload: Codable {
    struct BaselineBlock: Codable {
        let avgHRV: Double
        let avgRestingHR: Double
        let avgDailySteps: Double
        let avgSleepHours: Double
        let dataWindowDays: Int
    }

    struct FeatureBlock: Codable {
        let avgHRV: Double?
        let hrvTrend: Double?
        let avgHeartRate: Double?
        let avgRestingHR: Double?
        let sleepAverageHours: Double?
        let sleepConsistency: Double?
        let remSleepAverageHours: Double?
        let coreSleepAverageHours: Double?
        let deepSleepAverageHours: Double?
        let stepsAverage: Double?
        let activeEnergyAverage: Double?
        let exerciseMinutesAverage: Double?
        let standHoursAverage: Double?
        let recoveryAverage: Double?
        let stressAverage: Double?
        let dataConfidence: Double
    }

    struct TrendBlock: Codable {
        let hrv7dDelta: Double?
        let restingHR7dDelta: Double?
        let sleep7dDeltaHours: Double?
        let steps7dDelta: Double?
    }

    struct GoalBlock: Codable {
        let sleepTargetHours: Double
        let stepsTarget: Int
        let exerciseTargetMin: Int
        let standTargetHours: Int
        let rationale: [String]
    }

    struct RecommendationBlock: Codable {
        let title: String
        let detail: String
    }

    let currentState: String
    let predictedLabel: String
    let confidencePercent: Int
    let analysisSource: String
    let mlSummary: String
    let keyFactors: [String]
    let baseline: BaselineBlock?
    let features: FeatureBlock
    let trends7d: TrendBlock
    let recentCheckInLabelsLast14d: [String]
    let checkInNote: String?
    let personalizedGoals: GoalBlock
    let topRecommendations: [RecommendationBlock]
}

// MARK: - PersonalizationInsight（一次 LLM 调用的结构化产出）

/// 大模型返回的结构化解析结果；展示在 AnalysisView 个性化分析卡片。
struct PersonalizationInsight: Codable, Equatable {
    struct Finding: Codable, Equatable, Identifiable {
        let title: String
        let detail: String
        let metric: String?

        var id: String { "\(title)|\(metric ?? "")" }
    }

    let summary: String
    let findings: [Finding]
    let suggestions: [String]
    let tone: String
    let generatedAt: Date
    let windowDays: Int
    /// true = JSON 解析失败，已退化为纯文本 summary
    let usedFallback: Bool

    init(
        summary: String,
        findings: [Finding] = [],
        suggestions: [String] = [],
        tone: String = "平稳",
        generatedAt: Date = Date(),
        windowDays: Int = 7,
        usedFallback: Bool = false
    ) {
        self.summary = summary
        self.findings = findings
        self.suggestions = suggestions
        self.tone = tone
        self.generatedAt = generatedAt
        self.windowDays = windowDays
        self.usedFallback = usedFallback
    }
}

/// 兼容旧命名（AnalysisViewModel / 单测若仍用 LLMInsight）。
typealias LLMInsight = PersonalizationInsight

// MARK: - Service

protocol LLMPersonalizationAnalyzing {
    func generateInsight(
        context: PersonalizationContext,
        analysis: PersonalizedAnalysis,
        model: String,
        apiKey: String
    ) async throws -> PersonalizationInsight

    /// T6.3：优先消费 StructuredAnalysisResult（带 deviation/trend/provenance/completeness）。
    func generateInsight(
        structured: StructuredAnalysisResult,
        model: String,
        apiKey: String
    ) async throws -> PersonalizationInsight
}

/// 一次健康数据分析任务：
/// 1) 把端上已算好的结果打成 AnalysisPayload（数据最小化）
/// 2) 单次 LLM 调用
/// 3) 严格 Codable 解析为 PersonalizationInsight；失败则 fallback
struct LLMPersonalizationService: LLMPersonalizationAnalyzing {
    var client: MiniMaxClientProtocol = MiniMaxClient()

    /// 分析窗口：特征近 7 天、打卡近 14 天；展示用 windowDays 取特征窗。
    static let featureWindowDays = 7

    func generateInsight(
        context: PersonalizationContext,
        analysis: PersonalizedAnalysis,
        model: String,
        apiKey: String
    ) async throws -> PersonalizationInsight {
        let payload = Self.buildPayload(context: context, analysis: analysis)
        let messages = Self.buildMessages(payload: payload)
        let text = try await client.complete(messages: messages, model: model, apiKey: apiKey)
        return Self.parseInsight(from: text, windowDays: Self.featureWindowDays)
    }

    /// T6.3：用 StructuredAnalysisResult 生成洞察（首选路径）。
    func generateInsight(
        structured: StructuredAnalysisResult,
        model: String,
        apiKey: String
    ) async throws -> PersonalizationInsight {
        let messages = Self.buildStructuredMessages(result: structured)
        let text = try await client.complete(messages: messages, model: model, apiKey: apiKey)
        return Self.parseInsight(from: text, windowDays: 7)
    }

    // MARK: - Structured messages（T6.3 强化 prompt）

    static func buildStructuredMessages(result: StructuredAnalysisResult) -> [MiniMaxMessage] {
        let system = """
        你是一位温和、专业的个人健康教练。你将收到一份已经由 App 计算完成的结构化分析结果。
        规则：
        1. 只做生活方式层面的解读，不做医疗诊断；异常情况建议咨询专业人士。
        2. 严禁重新计算、推断或改写任何数值；引用时直接使用载荷里的数字与结论。
        3. 回答使用简体中文。
        4. 相关性与因果：数据中的 "association" 只表示"同时观察到"，不得使用「导致」「因为」「说明」「证明」「引起」等因果动词。必须使用「可能」「与…相关」「数据显示」「可以观察到」「倾向于」。
        5. 数据边界：provenance = "estimated" 的值是估算值，不得描述为「你的实测…」；provenance = "demo" 的值是演示数据，必须在文案中说明。
        6. 缺失处理：dataCompleteness 中标记为 missing 的指标，必须说明"该因素未纳入本次判断"，不得推断。
        7. 不编造：只允许引用载荷中出现的数值。任何载荷中不存在的数值、日期、趋势都不得生成。
        8. 必须且只能返回一个 JSON 对象（不要 markdown 代码块），结构为：
        {
          "summary": "2-4 句总结，结合个人基线与关键趋势",
          "findings": [
            {"title": "短标题", "detail": "1-2 句依据，可引用载荷数值", "metric": "hrv|sleep|rhr|steps|stress|recovery|other"}
          ],
          "suggestions": ["可执行建议1", "建议2", "建议3"],
          "tone": "鼓励|警示|平稳"
        }
        约束：findings 最多 4 条，suggestions 最多 3 条；findings 必须能对应到载荷中的已有结论或数值。
        """

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = (try? encoder.encode(result)) ?? Data("{}".utf8)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let user = "StructuredAnalysisResult（端上已算好，请据此生成个性化分析）：\n\(jsonString)"

        return [
            MiniMaxMessage(role: "system", content: system),
            MiniMaxMessage(role: "user", content: user)
        ]
    }

    // MARK: - AnalysisPayload（只搬运已有计算结果）

    static func buildPayload(
        context: PersonalizationContext,
        analysis: PersonalizedAnalysis
    ) -> AnalysisPayload {
        let base = analysis.base
        let features = base.features
        let ml = base.mlInsight

        let baselineBlock: AnalysisPayload.BaselineBlock? = context.baseline.map {
            AnalysisPayload.BaselineBlock(
                avgHRV: round1($0.avgHRV),
                avgRestingHR: round1($0.avgRestingHR),
                avgDailySteps: round1($0.avgDailySteps),
                avgSleepHours: round2($0.avgSleepHours),
                dataWindowDays: $0.dataWindowDays
            )
        }

        let featureBlock = AnalysisPayload.FeatureBlock(
            avgHRV: features.avgHRV.map(round1),
            hrvTrend: features.hrvTrend.map(round1),
            avgHeartRate: features.avgHeartRate.map(round1),
            avgRestingHR: features.avgRestingHR.map(round1),
            sleepAverageHours: features.sleepAverage.map(round2),
            sleepConsistency: features.sleepConsistency.map(round2),
            remSleepAverageHours: features.remSleepAverage.map(round2),
            coreSleepAverageHours: features.coreSleepAverage.map(round2),
            deepSleepAverageHours: features.deepSleepAverage.map(round2),
            stepsAverage: features.stepsAverage.map { round1($0) },
            activeEnergyAverage: features.activeEnergyAverage.map(round1),
            exerciseMinutesAverage: features.exerciseMinutesAverage.map(round1),
            standHoursAverage: features.standHoursAverage.map(round1),
            recoveryAverage: features.recoveryAverage.map(round1),
            stressAverage: features.stressAverage.map(round1),
            dataConfidence: round2(features.dataConfidence)
        )

        let trendBlock = AnalysisPayload.TrendBlock(
            hrv7dDelta: context.hrvTrend.map(round1),
            restingHR7dDelta: context.restingHRTrend.map(round1),
            sleep7dDeltaHours: context.sleepTrend.map(round2),
            steps7dDelta: context.stepsTrend.map(round1)
        )

        let checkInLabels = context.recentCheckIns.suffix(14).map(\.label.displayName)

        let goalBlock = AnalysisPayload.GoalBlock(
            sleepTargetHours: round2(analysis.goals.sleepTargetHours),
            stepsTarget: analysis.goals.stepsTarget,
            exerciseTargetMin: analysis.goals.exerciseTargetMin,
            standTargetHours: analysis.goals.standTargetHours,
            rationale: Array(analysis.goals.rationale.prefix(4))
        )

        let topRecs = analysis.recommendations.prefix(4).map {
            AnalysisPayload.RecommendationBlock(title: $0.title, detail: $0.detail)
        }

        return AnalysisPayload(
            currentState: analysis.state.displayName,
            predictedLabel: base.predictedLabel,
            confidencePercent: Int(round(analysis.confidence * 100)),
            analysisSource: base.source.displayName,
            mlSummary: ml.summary,
            keyFactors: Array((base.primaryFactors.isEmpty ? ml.keyFactors : base.primaryFactors).prefix(5)),
            baseline: baselineBlock,
            features: featureBlock,
            trends7d: trendBlock,
            recentCheckInLabelsLast14d: checkInLabels,
            checkInNote: analysis.checkInReconciliation?.note,
            personalizedGoals: goalBlock,
            topRecommendations: topRecs
        )
    }

    // MARK: - Prompt（单次调用，禁止重算）

    private static func buildMessages(payload: AnalysisPayload) -> [MiniMaxMessage] {
        let system = """
        你是一位温和、专业的个人健康教练。你将收到一份已经由 App 计算完成的聚合分析载荷（AnalysisPayload）。
        规则：
        1. 只做生活方式层面的解读，不做医疗诊断；异常情况建议咨询专业人士。
        2. 严禁重新计算、推断或改写任何数值；引用时直接使用载荷里的数字与结论。
        3. 回答使用简体中文。
        4. 必须且只能返回一个 JSON 对象（不要 markdown 代码块），结构为：
        {
          "summary": "2-4 句总结，结合个人基线与关键趋势",
          "findings": [
            {"title": "短标题", "detail": "1-2 句依据，可引用载荷数值", "metric": "hrv|sleep|rhr|steps|stress|recovery|other"}
          ],
          "suggestions": ["可执行建议1", "建议2", "建议3"],
          "tone": "鼓励|警示|平稳"
        }
        约束：findings 最多 4 条，suggestions 最多 3 条；findings 必须能对应到载荷中的已有结论或数值。
        """

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = (try? encoder.encode(payload)) ?? Data("{}".utf8)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let user = "AnalysisPayload（端上已算好，请据此生成个性化分析）：\n\(jsonString)"

        return [
            MiniMaxMessage(role: "system", content: system),
            MiniMaxMessage(role: "user", content: user)
        ]
    }

    // MARK: - 解析（严格 Codable + fallback）

    private struct InsightDTO: Decodable {
        struct FindingDTO: Decodable {
            let title: String
            let detail: String
            let metric: String?
        }

        let summary: String
        let findings: [FindingDTO]?
        let suggestions: [String]?
        let tone: String?
    }

    static func parseInsight(from text: String, windowDays: Int = featureWindowDays) -> PersonalizationInsight {
        let cleaned = extractJSONObject(from: text)

        if let data = cleaned.data(using: .utf8),
           let dto = try? JSONDecoder().decode(InsightDTO.self, from: data),
           !dto.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let findings = (dto.findings ?? []).prefix(4).map {
                PersonalizationInsight.Finding(
                    title: $0.title,
                    detail: $0.detail,
                    metric: $0.metric
                )
            }
            let suggestions = Array((dto.suggestions ?? []).prefix(3).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty })
            let tone = normalizeTone(dto.tone)

            return PersonalizationInsight(
                summary: dto.summary.trimmingCharacters(in: .whitespacesAndNewlines),
                findings: Array(findings),
                suggestions: suggestions,
                tone: tone,
                generatedAt: Date(),
                windowDays: windowDays,
                usedFallback: false
            )
        }

        // fallback：整段当作 summary，保证 UI 始终可展示
        let rawSummary = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return PersonalizationInsight(
            summary: rawSummary.isEmpty ? "模型未返回可用内容，请重试。" : rawSummary,
            findings: [],
            suggestions: [],
            tone: "平稳",
            generatedAt: Date(),
            windowDays: windowDays,
            usedFallback: true
        )
    }

    private static func extractJSONObject(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}"),
           start < end {
            cleaned = String(cleaned[start...end])
        }
        return cleaned
    }

    private static func normalizeTone(_ tone: String?) -> String {
        guard let tone = tone?.trimmingCharacters(in: .whitespacesAndNewlines), !tone.isEmpty else {
            return "平稳"
        }
        if tone.contains("鼓") { return "鼓励" }
        if tone.contains("警") { return "警示" }
        return "平稳"
    }

    private static func round1(_ v: Double) -> Double { round(v * 10) / 10 }
    private static func round2(_ v: Double) -> Double { round(v * 100) / 100 }
}
