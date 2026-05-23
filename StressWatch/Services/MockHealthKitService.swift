import Foundation

class MockHealthKitService: HealthKitDataProvider {
    private let daysOfData: Int
    private let calendar: Calendar

    init(daysOfData: Int = 7, calendar: Calendar = .current) {
        self.daysOfData = daysOfData
        self.calendar = calendar
    }

    func requestAuthorization() async throws {}

    func authorizationStatus() -> HealthKitAuthStatus {
        .authorized
    }

    func fetchMetrics(types: [MetricType], from: Date, to: Date) async throws -> [HealthMetric] {
        fixedMetrics.filter { metric in
            types.contains(metric.type) && metric.date >= from && metric.date <= to
        }
    }

    private var fixedMetrics: [HealthMetric] {
        let today = calendar.startOfDay(for: Date())
        let pattern: [(hr: Double, hrv: Double, restingHR: Double, steps: Double, sleep: Double, energy: Double, exercise: Double, stand: Double)] = [
            (72, 42, 59, 7600, 7.1, 420, 28, 10),
            (78, 36, 63, 9400, 6.4, 520, 34, 11),
            (69, 48, 58, 6900, 7.6, 380, 22, 12),
            (81, 33, 65, 11200, 5.9, 640, 46, 13),
            (74, 40, 61, 8200, 6.8, 470, 31, 9),
            (68, 51, 57, 7200, 7.8, 410, 26, 12),
            (76, 38, 62, 9800, 6.2, 560, 39, 13)
        ]

        let selectedValues = (0..<daysOfData).map { index in
            let base = pattern[index % pattern.count]
            let weekOffset = Double(index / pattern.count)
            return (
                hr: base.hr + weekOffset,
                hrv: max(20, base.hrv - weekOffset),
                restingHR: base.restingHR + (weekOffset * 0.5),
                steps: base.steps + (weekOffset * 180),
                sleep: max(4.5, base.sleep - (weekOffset * 0.05)),
                energy: base.energy + (weekOffset * 20),
                exercise: base.exercise + (weekOffset * 2),
                stand: min(16, base.stand + weekOffset)
            )
        }

        return selectedValues
            .enumerated()
            .flatMap { index, values -> [HealthMetric] in
                let daysBack = selectedValues.count - 1 - index
                let date = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
                return dailyMetrics(for: values, on: date, dayIndex: index)
            }
    }

    private func dailyMetrics(
        for values: (hr: Double, hrv: Double, restingHR: Double, steps: Double, sleep: Double, energy: Double, exercise: Double, stand: Double),
        on date: Date,
        dayIndex: Int
    ) -> [HealthMetric] {
        let rem = max(0.8, values.sleep * 0.21)
        let deep = max(0.55, values.sleep * 0.14)
        let core = max(2.8, values.sleep - rem - deep)
        let awake = 0.18 + Double(dayIndex % 3) * 0.05

        var metrics: [HealthMetric] = [
            metric(.restingHeartRate, values.restingHR, "bpm", date, hour: 6),
            metric(.sleep, values.sleep, "hours", date, hour: 6),
            metric(.sleepREM, rem, "hours", date, hour: 6),
            metric(.sleepCore, core, "hours", date, hour: 6),
            metric(.sleepDeep, deep, "hours", date, hour: 6),
            metric(.sleepAwake, awake, "hours", date, hour: 6),
            metric(.activeEnergyBurned, values.energy, "kcal", date, hour: 21),
            metric(.appleExerciseTime, values.exercise, "min", date, hour: 21),
            metric(.appleStandTime, values.stand, "h", date, hour: 21)
        ]

        let hrOffsets = [-4.0, -2.0, 1.0, 6.0, 11.0, 8.0, 4.0, 9.0, 3.0, -1.0]
        let hrHours = [7, 8, 9, 10, 12, 14, 16, 18, 20, 22]
        metrics += zip(hrHours, hrOffsets).map { hour, offset in
            metric(.heartRate, values.hr + offset + Double(dayIndex % 3), "bpm", date, hour: hour)
        }

        let hrvOffsets = [2.0, -1.0, -4.0]
        let hrvHours = [7, 13, 21]
        metrics += zip(hrvHours, hrvOffsets).map { hour, offset in
            metric(.hrv, max(15, values.hrv + offset - Double(dayIndex % 2)), "ms", date, hour: hour)
        }

        let stepMultipliers = [0.12, 0.28, 0.56, 0.78, 1.0]
        let stepHours = [9, 12, 15, 18, 21]
        metrics += zip(stepHours, stepMultipliers).map { hour, multiplier in
            metric(.steps, values.steps * multiplier, "steps", date, hour: hour)
        }

        return metrics
    }

    private func metric(
        _ type: MetricType,
        _ value: Double,
        _ unit: String,
        _ date: Date,
        hour: Int
    ) -> HealthMetric {
        let timestamp = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return HealthMetric(id: UUID(), type: type, value: value, unit: unit, date: timestamp)
    }
}
