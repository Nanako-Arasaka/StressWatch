import Foundation
@testable import StressWatch

/// 构造 `HealthMetric` 原始样本的确定性工具。
///
/// 所有日期都来自 `TestCalendar`，绝不使用 `Date()`。
enum HealthMetricFixture {
    static func metric(
        _ type: MetricType,
        _ value: Double,
        unit: String? = nil,
        at date: Date,
        sourceName: String? = nil
    ) -> HealthMetric {
        HealthMetric(
            id: UUID(),
            type: type,
            value: value,
            unit: unit ?? Self.defaultUnit(for: type),
            date: date,
            sourceName: sourceName
        )
    }

    /// 在第 `dayOffset` 天的若干小时上生成同类型样本。
    static func series(
        _ type: MetricType,
        values: [Double],
        dayOffset: Int,
        hours: [Int]
    ) -> [HealthMetric] {
        zip(hours, values).map { hour, value in
            metric(type, value, at: TestCalendar.time(dayOffset: dayOffset, hour: hour))
        }
    }

    static func defaultUnit(for type: MetricType) -> String {
        switch type {
        case .heartRate, .restingHeartRate: return "bpm"
        case .hrv: return "ms"
        case .sleep, .sleepREM, .sleepCore, .sleepDeep, .sleepAwake: return "hours"
        case .steps: return "steps"
        case .activeEnergyBurned: return "kcal"
        case .appleExerciseTime: return "min"
        case .appleStandTime: return "h"
        }
    }
}
