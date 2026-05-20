import Foundation

protocol BaselineCalculating {
    func calculate(from metrics: [HealthMetric]) -> Baseline?
}

class BaselineEngine: BaselineCalculating {
    private let minimumDaysRequired: Int
    private let calendar: Calendar

    init(minimumDaysRequired: Int = 3, calendar: Calendar = .current) {
        self.minimumDaysRequired = minimumDaysRequired
        self.calendar = calendar
    }

    func calculate(from metrics: [HealthMetric]) -> Baseline? {
        let days = Set(metrics.map { calendar.startOfDay(for: $0.date) })
        guard days.count >= minimumDaysRequired else {
            return nil
        }

        return Baseline(
            avgHR: averageValue(for: .heartRate, in: metrics),
            avgHRV: averageValue(for: .hrv, in: metrics),
            avgRestingHR: averageValue(for: .restingHeartRate, in: metrics),
            avgDailySteps: averageValue(for: .steps, in: metrics),
            avgSleepHours: averageValue(for: .sleep, in: metrics),
            calculatedAt: Date(),
            dataWindowDays: days.count
        )
    }

    private func averageValue(for type: MetricType, in metrics: [HealthMetric]) -> Double {
        let values = metrics.filter { $0.type == type }.map(\.value)
        guard !values.isEmpty else {
            return 0
        }
        return values.reduce(0, +) / Double(values.count)
    }
}
