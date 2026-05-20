import Foundation
import SwiftUI

struct StressScore: Identifiable, Codable {
    let id: UUID
    let value: Int
    let level: StressLevel
    let date: Date
    let components: StressComponents
}

enum StressLevel: String, Codable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        }
    }

    var displayColor: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

struct StressComponents: Codable {
    let hrDeviationFactor: Double
    let inverseHRVFactor: Double
    let activityLoadFactor: Double
    let sleepDebtFactor: Double
}
