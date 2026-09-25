import Foundation

protocol HealthKitDataProvider {
    func requestAuthorization() async throws
    func authorizationStatus() -> HealthKitAuthStatus
    func fetchMetrics(types: [MetricType], from: Date, to: Date) async throws -> [HealthMetric]

    // MARK: - 区间型数据（T1.4 新增）

    /// 按天返回睡眠会话（入睡 / 起床时刻 + 时长）。
    /// `HealthMetric` 装不下区间信息，因此单独一路。
    func fetchSleepSessions(from: Date, to: Date) async throws -> [SleepSession]
    /// 返回区间内的运动时段，用于把体力活动从压力信号里剔除。
    func fetchWorkoutIntervals(from: Date, to: Date) async throws -> [WorkoutInterval]
}

extension HealthKitDataProvider {
    /// 默认空实现：让不支持区间数据的数据源（如 `MockHealthKitService`）
    /// 无需改动即可满足协议，调用方按"无数据"自然降级。
    func fetchSleepSessions(from: Date, to: Date) async throws -> [SleepSession] { [] }
    func fetchWorkoutIntervals(from: Date, to: Date) async throws -> [WorkoutInterval] { [] }
}

enum HealthKitAuthStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable
}
