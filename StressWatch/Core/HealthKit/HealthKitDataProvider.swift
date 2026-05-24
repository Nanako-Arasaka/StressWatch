import Foundation

protocol HealthKitDataProvider {
    func requestAuthorization() async throws
    func authorizationStatus() -> HealthKitAuthStatus
    func fetchMetrics(types: [MetricType], from: Date, to: Date) async throws -> [HealthMetric]
}

enum HealthKitAuthStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable
}
