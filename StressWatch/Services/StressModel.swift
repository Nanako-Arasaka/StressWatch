import Foundation

protocol StressComputing {
    func compute(current: [HealthMetric], baseline: Baseline) -> StressScore
}

class StressModel: StressComputing {
    func compute(current: [HealthMetric], baseline: Baseline) -> StressScore {
        let currentHR = current.latestValue(for: .heartRate) ?? baseline.avgHR
        let currentHRV = current.latestValue(for: .hrv) ?? baseline.avgHRV
        let currentSteps = current.latestValue(for: .steps) ?? baseline.avgDailySteps
        let currentSleep = current.latestValue(for: .sleep) ?? baseline.avgSleepHours

        let hrFactor = clamp(((currentHR - baseline.avgHR) / safeDenominator(baseline.avgHR)) * 100, 0, 25)
        let hrvFactor = clamp(((baseline.avgHRV - currentHRV) / safeDenominator(baseline.avgHRV)) * 100, 0, 25)
        let activityFactor = clamp((abs(currentSteps - baseline.avgDailySteps) / safeDenominator(baseline.avgDailySteps)) * 50, 0, 25)
        let sleepFactor = clamp(((baseline.avgSleepHours - currentSleep) / safeDenominator(baseline.avgSleepHours)) * 100, 0, 25)
        let value = Int(round(hrFactor + hrvFactor + activityFactor + sleepFactor))

        return StressScore(
            id: UUID(),
            value: min(max(value, 0), 100),
            level: level(for: value),
            date: current.map(\.date).max() ?? Date(),
            components: StressComponents(
                hrDeviationFactor: hrFactor,
                inverseHRVFactor: hrvFactor,
                activityLoadFactor: activityFactor,
                sleepDebtFactor: sleepFactor
            )
        )
    }

    private func level(for value: Int) -> StressLevel {
        if value <= 33 {
            return .low
        } else if value <= 66 {
            return .medium
        } else {
            return .high
        }
    }
}
