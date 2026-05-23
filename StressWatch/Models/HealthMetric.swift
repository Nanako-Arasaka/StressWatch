import Foundation

struct HealthMetric: Identifiable, Codable {
    let id: UUID
    let type: MetricType
    let value: Double
    let unit: String
    let date: Date
}

enum MetricType: String, Codable, CaseIterable {
    case heartRate
    case hrv
    case restingHeartRate
    case steps
    case sleep
    case activeEnergyBurned
    case appleExerciseTime
    case sleepREM
    case sleepCore
    case sleepDeep
    case sleepAwake
}

extension Array where Element == HealthMetric {
    func latestValue(for type: MetricType) -> Double? {
        filter { $0.type == type }
            .max { $0.date < $1.date }?
            .value
    }
}
