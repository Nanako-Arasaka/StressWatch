import Foundation

// MARK: - Errors

enum AnalysisBackendError: LocalizedError {
    case missingBaseURL
    case invalidURL
    case httpError(Int)
    case invalidResponse
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL: return "未配置分析服务器地址，请在设置中填写。"
        case .invalidURL: return "分析服务器地址无效。"
        case .httpError(let code): return "分析服务器请求失败（HTTP \(code)）"
        case .invalidResponse: return "分析服务器返回了无法解析的结果"
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - Protocol

/// 自建分析代理客户端（OpenAI 风格 `/v1/analyze`）。
/// 只发送端上已算好的聚合载荷，不上传原始 HealthKit 采样。
protocol AnalysisBackendClientProtocol: Sendable {
    func analyze(
        structured: StructuredAnalysisResult,
        windowDays: Int,
        apiToken: String?
    ) async throws -> PersonalizationInsight

    func analyze(
        payload: AnalysisPayload,
        windowDays: Int,
        apiToken: String?
    ) async throws -> PersonalizationInsight
}

// MARK: - DTO

/// 与 server `AnalyzeResponse.insight` 对齐的解码结构。
private struct BackendInsightDTO: Decodable {
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

private struct AnalyzeResponseDTO: Decodable {
    let insight: BackendInsightDTO?
    let model: String?
    let validated: Bool?
}

private struct AnalyzeRequestDTO: Encodable {
    let kind: String
    let windowDays: Int
    let data: AnyEncodable
}

/// 类型擦除，便于把任意 Encodable 塞进 `data`。
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        encodeFunc = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

// MARK: - Client

struct AnalysisBackendClient: AnalysisBackendClientProtocol {
    var baseURL: URL
    var session: URLSession = .shared

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// 从用户配置的字符串创建；自动补全 scheme / 去掉尾斜杠。
    static func make(from string: String) throws -> AnalysisBackendClient {
        var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard !trimmed.isEmpty else { throw AnalysisBackendError.missingBaseURL }

        if !trimmed.lowercased().hasPrefix("http://"), !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed) else { throw AnalysisBackendError.invalidURL }
        return AnalysisBackendClient(baseURL: url)
    }

    func analyze(
        structured: StructuredAnalysisResult,
        windowDays: Int,
        apiToken: String?
    ) async throws -> PersonalizationInsight {
        try await post(
            kind: "structured",
            windowDays: windowDays,
            data: structured,
            apiToken: apiToken
        )
    }

    func analyze(
        payload: AnalysisPayload,
        windowDays: Int,
        apiToken: String?
    ) async throws -> PersonalizationInsight {
        try await post(
            kind: "payload",
            windowDays: windowDays,
            data: payload,
            apiToken: apiToken
        )
    }

    // MARK: - Private

    private func post<T: Encodable>(
        kind: String,
        windowDays: Int,
        data: T,
        apiToken: String?
    ) async throws -> PersonalizationInsight {
        let endpoint = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("analyze")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = apiToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = AnalyzeRequestDTO(
            kind: kind,
            windowDays: windowDays,
            data: AnyEncodable(data)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode == 401 {
                throw AnalysisBackendError.httpError(401)
            }
            throw AnalysisBackendError.httpError(http.statusCode)
        }

        guard
            let decoded = try? JSONDecoder().decode(AnalyzeResponseDTO.self, from: data),
            let insight = decoded.insight
        else {
            throw AnalysisBackendError.invalidResponse
        }

        let findings = (insight.findings ?? []).prefix(4).map {
            PersonalizationInsight.Finding(title: $0.title, detail: $0.detail, metric: $0.metric)
        }
        let suggestions = Array((insight.suggestions ?? []).prefix(3)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })

        return PersonalizationInsight(
            summary: insight.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            findings: Array(findings),
            suggestions: suggestions,
            tone: Self.normalizeTone(insight.tone),
            generatedAt: Date(),
            windowDays: windowDays,
            usedFallback: false
        )
    }

    private static func normalizeTone(_ tone: String?) -> String {
        guard let tone = tone?.trimmingCharacters(in: .whitespacesAndNewlines), !tone.isEmpty else {
            return "平稳"
        }
        if tone.contains("鼓") { return "鼓励" }
        if tone.contains("警") { return "警示" }
        return "平稳"
    }
}
