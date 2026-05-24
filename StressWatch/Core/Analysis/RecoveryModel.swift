import Foundation

protocol RecoveryComputing {
    func compute(current: [HealthMetric], baseline: Baseline) -> RecoveryScore
}

class RecoveryModel: RecoveryComputing {
    func compute(current: [HealthMetric], baseline: Baseline) -> RecoveryScore {
        let currentHRV = current.latestValue(for: .hrv) ?? baseline.avgHRV
        let currentRestingHR = current.latestValue(for: .restingHeartRate) ?? baseline.avgRestingHR
        let currentSleep = current.latestValue(for: .sleep) ?? baseline.avgSleepHours

        let hrvScore = clamp((currentHRV / safeDenominator(baseline.avgHRV)) * 40, 0, 40)
        let restingHRScore = clamp((baseline.avgRestingHR / safeDenominator(currentRestingHR)) * 30, 0, 30)
        let sleepScore = clamp((currentSleep / safeDenominator(baseline.avgSleepHours)) * 30, 0, 30)
        let value = Int(round(hrvScore + restingHRScore + sleepScore))

        return RecoveryScore(
            id: UUID(),
            value: min(max(value, 0), 100),
            level: level(for: value),
            date: current.map(\.date).max() ?? Date()
        )
    }

    private func level(for value: Int) -> RecoveryLevel {
        if value <= 33 {
            return .poor
        } else if value <= 66 {
            return .fair
        } else {
            return .good
        }
    }
}
