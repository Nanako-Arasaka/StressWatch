import Foundation
import SwiftUI

struct RecoveryScore: Identifiable, Codable {
    let id: UUID
    let value: Int
    let level: RecoveryLevel
    let date: Date
}

enum RecoveryLevel: String, Codable {
    case poor
    case fair
    case good

    var displayName: String {
        switch self {
        case .poor:
            return "恢复趋势较弱"
        case .fair:
            return "恢复趋势一般"
        case .good:
            return "恢复趋势良好"
        }
    }

    var displayColor: Color {
        switch self {
        case .poor:
            return AppColors.stressWarm
        case .fair:
            return AppColors.chartSecondary.opacity(0.82)
        case .good:
            return AppColors.recoveryBlue
        }
    }
}
