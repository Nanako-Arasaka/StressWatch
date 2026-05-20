import Foundation

struct Baseline: Codable {
    let avgHR: Double
    let avgHRV: Double
    let avgRestingHR: Double
    let avgDailySteps: Double
    let avgSleepHours: Double
    let calculatedAt: Date
    let dataWindowDays: Int

    var isValid: Bool { dataWindowDays >= 3 }
}
