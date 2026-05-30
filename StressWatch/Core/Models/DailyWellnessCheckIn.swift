import Foundation

struct DailyWellnessCheckIn: Identifiable, Codable {
    var id: String {
        Self.dayKey(for: date)
    }

    let date: Date
    let label: DailyWellnessLabel
    let note: String?
    let createdAt: Date

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

enum DailyWellnessLabel: String, CaseIterable, Codable, Identifiable {
    case feelingGood = "feeling_good"
    case normal = "normal"
    case tired = "tired"
    case highStress = "high_stress"
    case poorRecovery = "poor_recovery"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .feelingGood:
            return "状态很好"
        case .normal:
            return "正常"
        case .tired:
            return "有点累"
        case .highStress:
            return "压力较大"
        case .poorRecovery:
            return "恢复较差"
        }
    }
}
