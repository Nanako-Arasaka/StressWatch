import Foundation

/// 可选的 MiniMax 模型。M3 质量最高；M2.7-highspeed 更快更省。
enum MiniMaxModel: String, CaseIterable, Codable {
    case m3 = "MiniMax-M3"
    case m2_7_highspeed = "MiniMax-M2.7-highspeed"

    static var `default`: MiniMaxModel { .m3 }

    var displayName: String {
        switch self {
        case .m3: return "MiniMax-M3（更强，推荐）"
        case .m2_7_highspeed: return "MiniMax-M2.7-highspeed（更快更省）"
        }
    }
}

struct MiniMaxMessage: Codable {
    let role: String
    let content: String
}

struct MiniMaxChatRequest: Codable {
    let model: String
    let messages: [MiniMaxMessage]
    let stream: Bool
    let temperature: Double
    let max_completion_tokens: Int
}

struct MiniMaxChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
        let finish_reason: String?
    }
    let choices: [Choice]
    let base_resp: BaseResp?
    struct BaseResp: Decodable {
        let status_code: Int?
        let status_msg: String?
    }
}

enum MiniMaxClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "MiniMax 接口地址无效"
        case .invalidResponse: return "MiniMax 返回了无法解析的结果"
        case .httpError(let code): return "MiniMax 请求失败（HTTP \(code)）"
        case .apiError(let code, let msg): return "MiniMax 接口错误（\(code)）：\(msg)"
        }
    }
}

protocol MiniMaxClientProtocol {
    func complete(messages: [MiniMaxMessage], model: String, apiKey: String) async throws -> String
}

/// 基于 URLSession 的 MiniMax OpenAI 兼容客户端。
/// 仅负责网络与响应解析，不关心业务语义。
struct MiniMaxClient: MiniMaxClientProtocol {
    var baseURL: URL = URL(string: "https://api.minimax.io/v1/chat/completions")!

    func complete(messages: [MiniMaxMessage], model: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body = MiniMaxChatRequest(
            model: model,
            messages: messages,
            stream: false,
            temperature: 0.4,
            max_completion_tokens: 1024
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let parsed = try? JSONDecoder().decode(MiniMaxChatResponse.self, from: data),
               let base = parsed.base_resp, let code = base.status_code, code != 0 {
                throw MiniMaxClientError.apiError(code, base.status_msg ?? "未知错误")
            }
            throw MiniMaxClientError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(MiniMaxChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw MiniMaxClientError.invalidResponse
        }
        return content
    }
}
