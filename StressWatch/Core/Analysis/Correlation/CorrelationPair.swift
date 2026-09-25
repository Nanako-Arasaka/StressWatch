import Foundation

// MARK: - 预期方向

/// 两指标间的预期关联方向（基于常识，用于 `isBeneficial` 判定）。
enum ExpectedDirection: String, Codable {
    case positive   // 同向变化
    case negative   // 反向变化

    var sign: Double { self == .positive ? 1 : -1 }
}

// MARK: - AssociationWording

/// 关联措辞枚举 —— **类型上禁止因果**。
///
/// 依据：Thump 的教训（文案声称次日因果但算法是同日配对）。
/// `ObservedAssociation.description` 只能由本枚举 + 数值拼装，
/// 结构上无法写出 "导致" / "因为" / "证明"。
enum AssociationWording: String, Codable {
    case observed = "数据中可观察到"
    case tendsToCooccur = "倾向于同时出现"
    case tracksWith = "与…同步变化"
    case notYetClear = "目前还没有观察到清晰关联"

    /// 生成完整描述句（禁止因果动词）。
    func describe(
        xName: String, yName: String,
        direction: String, strength: String,
        lagDays: Int, pairedDays: Int
    ) -> String {
        switch self {
        case .notYetClear:
            return "\(xName)与\(yName)：目前还没有观察到清晰关联（已配对 \(pairedDays) 天）。"
        case .observed, .tendsToCooccur, .tracksWith:
            let lagNote = lagDays > 0 ? "（滞后 \(lagDays) 天）" : ""
            return "\(xName) 与 \(yName)\(lagNote)：\(rawValue)\(strength)\(direction)。"
        }
    }
}

// MARK: - AssociationStrength

/// 关联强度分档。
enum AssociationStrength: String, Codable {
    case none
    case weak
    case noticeable
    case clear
    case strong

    /// 从 |r| 映射。
    static func from(absR: Double) -> AssociationStrength {
        switch absR {
        case ..<0.2: return .none
        case ..<0.4: return .weak
        case ..<0.6: return .noticeable
        case ..<0.8: return .clear
        default: return .strong
        }
    }

    var displayName: String {
        switch self {
        case .none: return "无明显关联"
        case .weak: return "微弱关联"
        case .noticeable: return "中等关联"
        case .clear: return "较清晰关联"
        case .strong: return "强关联"
        }
    }
}

// MARK: - CorrelationPair

/// 一对待分析的指标关系（声明式表驱动）。
struct CorrelationPair: Identifiable, Codable {
    let id: String
    let x: BaselineMetric
    let y: BaselineMetric
    /// 0 = 同日；1 = x(t) 与 y(t+1)（次日）。
    let lagDays: Int
    let expectedDirection: ExpectedDirection
    /// 最少配对天数门槛（默认 10，比 Thump 的 7 保守）。
    let minimumPairs: Int
    let displayTitle: String

    init(
        id: String? = nil,
        x: BaselineMetric,
        y: BaselineMetric,
        lagDays: Int = 0,
        expectedDirection: ExpectedDirection,
        minimumPairs: Int = 10,
        displayTitle: String? = nil
    ) {
        self.id = id ?? "\(x.rawValue)_\(y.rawValue)_lag\(lagDays)"
        self.x = x
        self.y = y
        self.lagDays = lagDays
        self.expectedDirection = expectedDirection
        self.minimumPairs = minimumPairs
        self.displayTitle = displayTitle ?? "\(x.displayName) ↔ \(y.displayName)"
    }
}

// MARK: - ObservedAssociation

/// 观察到的关联结果。
///
/// **结构性约束**：不提供任何 `causal` / `because` / `causes` 字段。
/// `description` 只能由 `AssociationWording` + 数值拼装。
struct ObservedAssociation: Identifiable, Codable {
    let pairId: String
    /// Pearson r。样本不足或分母为 0 时为 nil。
    let coefficient: Double?
    let strength: AssociationStrength
    /// r 的方向与 expectedDirection 一致 → true（颜色按是否有益，不按符号）。
    let isBeneficial: Bool
    let pairedDays: Int
    let lagDays: Int
    /// 人类可读描述（由 AssociationWording 生成）。
    let description: String
    /// Spearman 交叉验证：与 Pearson 方向一致 → true。
    let spearmanAgrees: Bool

    var id: String { pairId }
    var displayTitle: String { pairId }
}

// MARK: - 默认分析对

extension CorrelationPair {
    /// 用户要求的 6 对初始配置。
    static let defaultPairs: [CorrelationPair] = [
        CorrelationPair(
            x: .sleepHours, y: .hrv,
            lagDays: 1, expectedDirection: .positive,
            displayTitle: "睡眠 ↔ HRV"
        ),
        CorrelationPair(
            x: .sleepHours, y: .steps,
            lagDays: 0, expectedDirection: .positive,
            displayTitle: "睡眠 ↔ 活动"
        ),
        CorrelationPair(
            x: .activeEnergyKcal, y: .hrv,
            lagDays: 1, expectedDirection: .positive,
            displayTitle: "活动能量 ↔ HRV"
        ),
        CorrelationPair(
            x: .exerciseMinutes, y: .hrv,
            lagDays: 1, expectedDirection: .positive,
            displayTitle: "运动 ↔ HRV"
        ),
        CorrelationPair(
            x: .restingHeartRate, y: .sleepHours,
            lagDays: 0, expectedDirection: .negative,
            displayTitle: "静息心率 ↔ 睡眠"
        ),
        CorrelationPair(
            x: .sleepHours, y: .restingHeartRate,
            lagDays: 1, expectedDirection: .negative,
            displayTitle: "睡眠 ↔ 次日静息心率"
        )
    ]
}
