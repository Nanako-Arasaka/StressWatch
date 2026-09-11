import Foundation

/// 个性化上下文：把用户个人基线、近期趋势与打卡历史汇聚起来，
/// 供 GoalOptimizer 与建议生成器产出真正“因人而异”的内容。
///
/// 这是“基于用户数据进行个性化优化”的入口数据。它不依赖 ML 模型文件，
/// 纯端上即可工作；当 Core ML 个人模型可用时，分析结果会作为其中一环被进一步个性化。
struct PersonalizationContext {
    let baseline: Baseline?
    let hrvTrend: Double?            // 近 7 天 HRV 变化（末值 - 首值）
    let restingHRTrend: Double?     // 近 7 天静息心率变化
    let sleepTrend: Double?         // 近 7 天睡眠时长变化
    let stepsTrend: Double?         // 近 7 天步数变化
    let avgActiveEnergy: Double?    // 近期活动能量均值（可选）
    let avgExerciseMinutes: Double? // 近期运动分钟均值（可选）
    let avgStandHours: Double?      // 近期站立小时均值（可选）
    let recentCheckIns: [DailyWellnessCheckIn] // 近 14 天，按时间升序

    var latestCheckIn: DailyWellnessCheckIn? {
        recentCheckIns.last
    }

    init(
        baseline: Baseline? = nil,
        hrvTrend: Double? = nil,
        restingHRTrend: Double? = nil,
        sleepTrend: Double? = nil,
        stepsTrend: Double? = nil,
        avgActiveEnergy: Double? = nil,
        avgExerciseMinutes: Double? = nil,
        avgStandHours: Double? = nil,
        recentCheckIns: [DailyWellnessCheckIn] = []
    ) {
        self.baseline = baseline
        self.hrvTrend = hrvTrend
        self.restingHRTrend = restingHRTrend
        self.sleepTrend = sleepTrend
        self.stepsTrend = stepsTrend
        self.avgActiveEnergy = avgActiveEnergy
        self.avgExerciseMinutes = avgExerciseMinutes
        self.avgStandHours = avgStandHours
        self.recentCheckIns = recentCheckIns
    }
}

/// 可个性化调整的目标维度。
enum GoalKind: String, CaseIterable, Codable {
    case sleep
    case steps
    case activeEnergy
    case exercise
    case stand

    var displayName: String {
        switch self {
        case .sleep: return "睡眠"
        case .steps: return "步数"
        case .activeEnergy: return "活动能量"
        case .exercise: return "运动时间"
        case .stand: return "站立"
        }
    }
}

// MARK: - 自评 / 模型状态的极性（用于打卡与模型的调和）

extension DailyWellnessLabel {
    /// >0 偏正面，<0 偏负面，0 中性。
    var polarity: Int {
        switch self {
        case .feelingGood: return 1
        case .normal: return 0
        case .tired: return -1
        case .highStress: return -1
        case .poorRecovery: return -1
        }
    }
}

extension WellnessState {
    var polarity: Int {
        switch self {
        case .balanced: return 0
        case .needRecovery: return -1
        case .highStrain: return -1
        case .lowActivity: return 0
        case .sleepDebt: return -1
        case .dataInsufficient: return 0
        }
    }
}
