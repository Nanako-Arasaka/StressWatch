import Foundation

// Live Stress 只表示当前压力趋势参考，不用于专业健康判断。
enum LiveStressStatus: String, Codable {
    case recoveryGood
    case normal
    case mildStress
    case attentionStress
    case highStress
    case dataInsufficient

    var displayName: String {
        switch self {
        case .recoveryGood:
            return "恢复良好"
        case .normal:
            return "状态正常"
        case .mildStress:
            return "轻微压力"
        case .attentionStress:
            return "注意压力"
        case .highStress:
            return "压力较高"
        case .dataInsufficient:
            return "数据不足"
        }
    }
}

// Dashboard 展示当前趋势参考所需的完整快照。
struct LiveStressSnapshot {
    let score: Double?
    let status: LiveStressStatus
    let recentHRV: Double?
    let baselineHRV: Double?
    let hrvDeviationPercent: Double?
    let recentRestingHR: Double?
    let baselineRestingHR: Double?
    let sleepHours: Double?
    let baselineSleepHours: Double?
    let dataConfidence: Double
    let lastUpdated: Date
    let explanation: String
    let source: AppDataSource

    static let empty = LiveStressSnapshot(
        score: nil,
        status: .dataInsufficient,
        recentHRV: nil,
        baselineHRV: nil,
        hrvDeviationPercent: nil,
        recentRestingHR: nil,
        baselineRestingHR: nil,
        sleepHours: nil,
        baselineSleepHours: nil,
        dataConfidence: 0,
        lastUpdated: Date(),
        explanation: "近期 HRV 或个人基线不足，暂不生成当前压力趋势参考。",
        source: .demo
    )
}
