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

/// 大模型返回的结构化洞察。
struct LLMInsight {
    let summary: String
    let suggestions: [String]
    let tone: String          // 鼓励 / 警示 / 平稳
    let generatedAt: Date
}

protocol LLMPersonalizationAnalyzing {
    func generateInsight(
        context: PersonalizationContext,
        analysis: PersonalizedAnalysis,
        model: String,
        apiKey: String
    ) async throws -> LLMInsight
}

/// 把端上已经算好的「个性化快照」（基线 / 趋势 / 打卡 / 目标 / 建议）
/// 以聚合、去标识的形式交给 MiniMax，生成自然语言解读。
/// 严格遵守数据最小化：只发聚合摘要，不含姓名与精确日期。
struct LLMPersonalizationService: LLMPersonalizationAnalyzing {
    var client: MiniMaxClientProtocol = MiniMaxClient()

    func generateInsight(
        context: PersonalizationContext,
        analysis: PersonalizedAnalysis,
        model: String,
        apiKey: String
    ) async throws -> LLMInsight {
        let snapshot = Self.buildSnapshot(context: context, analysis: analysis)
        let messages = Self.buildMessages(snapshot: snapshot)
        let text = try await client.complete(messages: messages, model: model, apiKey: apiKey)
        return try Self.parseInsight(from: text)
    }

    // MARK: - Prompt 构造（数据最小化）

    private static func buildSnapshot(context: PersonalizationContext, analysis: PersonalizedAnalysis) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["currentState"] = analysis.state.displayName
        dict["confidence"] = Int(round(analysis.confidence * 100))

        if let base = context.baseline {
            dict["baseline"] = [
                "avgHRV": round1(base.avgHRV),
                "avgRestingHR": round1(base.avgRestingHR),
                "avgDailySteps": Int(base.avgDailySteps),
                "avgSleepHours": round2(base.avgSleepHours)
            ]
        }

        var trends: [String: Any] = [:]
        if let v = context.hrvTrend { trends["hrv7dDelta"] = round1(v) }
        if let v = context.restingHRTrend { trends["restingHR7dDelta"] = round1(v) }
        if let v = context.sleepTrend { trends["sleep7dDeltaHours"] = round2(v) }
        if let v = context.stepsTrend { trends["steps7dDelta"] = Int(v) }
        dict["recentTrends7d"] = trends

        let recentLabels = context.recentCheckIns.suffix(14).map { $0.label.displayName }
        dict["recentCheckInLabelsLast14d"] = recentLabels

        var goals: [String: Any] = [:]
        goals["sleepTargetHours"] = round2(analysis.goals.sleepTargetHours)
        goals["stepsTarget"] = analysis.goals.stepsTarget
        goals["exerciseTargetMin"] = analysis.goals.exerciseTargetMin
        goals["standTargetHours"] = analysis.goals.standTargetHours
        goals["rationale"] = analysis.goals.rationale
        dict["personalizedGoals"] = goals

        dict["topRecommendations"] = analysis.recommendations.prefix(4).map {
            ["title": $0.title, "detail": $0.detail]
        }

        if let rec = analysis.checkInReconciliation, let note = rec.note {
            dict["checkInNote"] = note
        }

        return dict
    }

    private static func buildMessages(snapshot: [String: Any]) -> [MiniMaxMessage] {
        let system = """
        你是一位温和、专业的个人健康教练，帮助用户理解自己的健康趋势数据。
        你只做生活方式层面的解读与建议，不做医疗诊断；遇到明显异常应建议用户咨询专业人士。
        回答使用简体中文。你将收到该用户最近数据的聚合摘要（已去除任何个人身份信息）。
        你必须且只能返回一个 JSON 对象，格式严格为：
        {"summary":"一段 2-4 句的中文总结，结合用户的个人基线指出关键趋势","suggestions":["具体可执行的建议1","建议2","建议3（最多3条）"],"tone":"鼓励|警示|平稳 三选一"}
        不要使用 markdown 代码块符号，直接输出纯 JSON。
        """

        let jsonData = try? JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted])
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let user = "以下是该用户近期健康数据的聚合摘要，请据此生成个性化分析：\n\(jsonString)"

        return [
            MiniMaxMessage(role: "system", content: system),
            MiniMaxMessage(role: "user", content: user)
        ]
    }

    // MARK: - 解析

    private static func parseInsight(from text: String) throws -> LLMInsight {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.contains("```") {
            if let start = cleaned.firstIndex(of: "{"),
               let end = cleaned.lastIndex(of: "}") {
                cleaned = String(cleaned[start...end])
            }
        }
        guard let data = cleaned.data(using: .utf8) else { throw LLMServiceError.invalidResponse }

        struct Payload: Decodable {
            let summary: String
            let suggestions: [String]?
            let tone: String?
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            // 退化：把整段内容当作 summary 返回，保证可用
            return LLMInsight(summary: text, suggestions: [], tone: "平稳", generatedAt: Date())
        }

        return LLMInsight(
            summary: payload.summary,
            suggestions: payload.suggestions ?? [],
            tone: payload.tone ?? "平稳",
            generatedAt: Date()
        )
    }

    private static func round1(_ v: Double) -> Double { round(v * 10) / 10 }
    private static func round2(_ v: Double) -> Double { round(v * 100) / 100 }
}
