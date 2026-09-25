import XCTest
@testable import StressWatch

// MARK: - URLProtocol stub

private final class BackendURLStub: URLProtocol {
    static var nextResponse: (status: Int, body: Data) = (200, Data("{}".utf8))
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map { _ in nil }.flatMap { $0 }
        // httpBody may be stream; capture via property when available
        if Self.lastBody == nil, let stream = request.httpBodyStream {
            var data = Data()
            stream.open()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer {
                buffer.deallocate()
                stream.close()
            }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            Self.lastBody = data
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.nextResponse.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.nextResponse.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class AnalysisBackendClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BackendURLStub.nextResponse = (200, Data("{}".utf8))
        BackendURLStub.lastRequest = nil
        BackendURLStub.lastBody = nil
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BackendURLStub.self]
        return URLSession(configuration: config)
    }

    private func makeStructured() -> StructuredAnalysisResult {
        StructuredAnalysisResult(
            generatedAt: Date(),
            dataSource: .appleHealth,
            baselineWindowDays: 14,
            stressScore: 64,
            stressLevel: .medium,
            recoveryScore: 71,
            recoveryLevel: .good,
            metrics: [],
            sleepQuality: nil,
            activityLevel: .moderate,
            trends: [],
            associations: [],
            confidence: .directional,
            completeness: DataCompleteness(
                availableMetrics: [.hrv, .restingHeartRate],
                missingMetrics: [.sleepHours, .steps],
                coreCompleteness: 0.5,
                overallCompleteness: 0.92,
                historyDays: 14
            ),
            warnings: []
        )
    }

    func test_make_prependsHTTPSAndStripsSlash() throws {
        let client = try AnalysisBackendClient.make(from: "example.com:8090/")
        XCTAssertEqual(client.baseURL.absoluteString, "https://example.com:8090")
    }

    func test_make_keepsHTTP() throws {
        let client = try AnalysisBackendClient.make(from: "http://127.0.0.1:8090")
        XCTAssertEqual(client.baseURL.absoluteString, "http://127.0.0.1:8090")
    }

    func test_make_empty_throws() {
        XCTAssertThrowsError(try AnalysisBackendClient.make(from: "  "))
    }

    func test_analyzeStructured_sendsBearerAndParsesInsight() async throws {
        let body = Data("""
        {
          "insight": {
            "summary": "HRV 低于基线。",
            "findings": [{"title": "HRV 偏低", "detail": "42 vs 51", "metric": "hrv"}],
            "suggestions": ["提前入睡"],
            "tone": "平稳"
          },
          "model": "qwen3.8-27b",
          "validated": true
        }
        """.utf8)
        BackendURLStub.nextResponse = (200, body)

        let client = AnalysisBackendClient(
            baseURL: URL(string: "http://127.0.0.1:8090")!,
            session: makeSession()
        )
        let insight = try await client.analyze(
            structured: makeStructured(),
            windowDays: 7,
            apiToken: "stresswatch-dev"
        )

        XCTAssertEqual(insight.summary, "HRV 低于基线。")
        XCTAssertEqual(insight.findings.count, 1)
        XCTAssertEqual(insight.suggestions, ["提前入睡"])
        XCTAssertFalse(insight.usedFallback)

        XCTAssertEqual(BackendURLStub.lastRequest?.url?.path, "/v1/analyze")
        XCTAssertEqual(
            BackendURLStub.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer stresswatch-dev"
        )

        let sent = BackendURLStub.lastBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(sent?["kind"] as? String, "structured")
        XCTAssertEqual(sent?["windowDays"] as? Int, 7)
        XCTAssertNotNil(sent?["data"])
    }

    func test_analyze_401_throws() async {
        BackendURLStub.nextResponse = (401, Data(#"{"detail":"missing bearer token"}"#.utf8))
        let client = AnalysisBackendClient(
            baseURL: URL(string: "http://127.0.0.1:8090")!,
            session: makeSession()
        )
        do {
            _ = try await client.analyze(
                structured: makeStructured(),
                windowDays: 7,
                apiToken: "wrong"
            )
            XCTFail("expected throw")
        } catch let error as AnalysisBackendError {
            guard case .httpError(401) = error else {
                return XCTFail("unexpected \(error)")
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func test_privacyGuard_allowsBackendWithoutKey() {
        XCTAssertTrue(AnalysisPrivacyGuard.canSendHealthDataToLLM(
            enabled: true,
            hasKey: false,
            hasBackend: true,
            dataSource: .appleHealth
        ))
    }

    func test_privacyGuard_deniesWithoutAnyCredential() {
        XCTAssertFalse(AnalysisPrivacyGuard.canSendHealthDataToLLM(
            enabled: true,
            hasKey: false,
            hasBackend: false,
            dataSource: .appleHealth
        ))
    }
}
