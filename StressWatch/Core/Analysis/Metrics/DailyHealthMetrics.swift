import Foundation

// MARK: - 溯源

/// 一个聚合值的来源性质。
///
/// 这一层存在的理由：LLM 解读层必须能区分"实测值"与"估算/占位值"，
/// 否则会在数据缺失时做出过宣称（参考 Whoordan 的 `WhoordanMetricSource`）。
enum MetricProvenance: String, Codable, Equatable {
    /// 由 HealthKit 真实样本聚合而来。
    case measured
    /// 由其它指标推算而来（原则上禁止；保留通道以便未来显式标记）。
    case estimated
    /// 演示数据（MockHealthKitService 产出），不得上送 LLM。
    case demo
}

// MARK: - 单指标当日聚合值

/// 某个指标在某一天的聚合结果。
///
/// 关键约定：`nil` 表示**缺失**，绝不表示 0。
/// 旧代码里 `latestValue(...) ?? baseline.xxx` 的写法会把缺失伪装成"状态正常"，
/// 从这里开始必须显式处理 nil。
struct MetricSample: Codable, Equatable {
    let value: Double
    let unit: String
    let source: MetricProvenance
    /// 参与聚合的有效原始样本数。0 表示该指标缺失（此时外层应为 nil）。
    let sampleCount: Int

    var isMeasured: Bool { source == .measured }
}

// MARK: - 运动区间

/// 一次运动的时间区间，用于把体力活动从"压力"里剔除。
/// 依据：Soma `StressCalculator.filterSedentary` —— 日间心率偏高很可能只是运动导致，
/// 不应计入压力信号。
struct WorkoutInterval: Codable, Equatable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}

// MARK: - 每日聚合健康指标

/// 一天的聚合健康指标。
///
/// 这一层是本次数据分析升级的地基：Baseline / Trend / Correlation 都需要**按天对齐、
/// 缺失可辨、来源可溯**的序列。旧代码直接把 `[HealthMetric]` 原始样本交给计算层，
/// 导致 HR（一天几百条）与 Sleep（一天 1 条）被同一个 average 函数处理，
/// 采样频率反而成了隐式权重。
struct DailyHealthMetrics: Codable, Equatable, Identifiable {
    /// 用 `day` 作为身份标识，天然保证一天只有一条。
    var id: Date { day }

    /// 当日 00:00（由聚合器注入的 calendar 决定）。
    let day: Date
    let dataSource: AppDataSource

    // MARK: 心血管
    let hrv: MetricSample?
    let restingHeartRate: MetricSample?
    let heartRateMedian: MetricSample?
    let heartRateMin: MetricSample?

    // MARK: 睡眠
    let sleepHours: MetricSample?
    let sleepREMHours: MetricSample?
    let sleepCoreHours: MetricSample?
    let sleepDeepHours: MetricSample?
    let sleepAwakeHours: MetricSample?
    /// 入睡时刻。T1.4（HealthKitService 输出睡眠会话）接入前恒为 nil。
    let bedtime: Date?
    /// 起床时刻。T1.4 接入前恒为 nil。
    let wakeTime: Date?

    // MARK: 活动
    let steps: MetricSample?
    let activeEnergyKcal: MetricSample?
    let exerciseMinutes: MetricSample?
    let standHours: MetricSample?
    /// 当日运动区间。T1.4 接入前恒为空数组。
    let workoutIntervals: [WorkoutInterval]

    init(
        day: Date,
        dataSource: AppDataSource,
        hrv: MetricSample? = nil,
        restingHeartRate: MetricSample? = nil,
        heartRateMedian: MetricSample? = nil,
        heartRateMin: MetricSample? = nil,
        sleepHours: MetricSample? = nil,
        sleepREMHours: MetricSample? = nil,
        sleepCoreHours: MetricSample? = nil,
        sleepDeepHours: MetricSample? = nil,
        sleepAwakeHours: MetricSample? = nil,
        bedtime: Date? = nil,
        wakeTime: Date? = nil,
        steps: MetricSample? = nil,
        activeEnergyKcal: MetricSample? = nil,
        exerciseMinutes: MetricSample? = nil,
        standHours: MetricSample? = nil,
        workoutIntervals: [WorkoutInterval] = []
    ) {
        self.day = day
        self.dataSource = dataSource
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.heartRateMedian = heartRateMedian
        self.heartRateMin = heartRateMin
        self.sleepHours = sleepHours
        self.sleepREMHours = sleepREMHours
        self.sleepCoreHours = sleepCoreHours
        self.sleepDeepHours = sleepDeepHours
        self.sleepAwakeHours = sleepAwakeHours
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.workoutIntervals = workoutIntervals
    }
}

// MARK: - Decodable

/// 手写 Decodable：所有可选字段走 `decodeIfPresent`。
///
/// 这样后续给 `DailyHealthMetrics` 增加字段时，旧版本持久化文件仍能读出
/// （新增字段取 nil），不会因为整体 decode 失败而清空历史。
/// 依据：Whoordan `LocalStore` 用 `decodeIfPresent(...) ?? 默认值` 做 schema 演进。
extension DailyHealthMetrics {
    private enum CodingKeys: String, CodingKey {
        case day, dataSource
        case hrv, restingHeartRate, heartRateMedian, heartRateMin
        case sleepHours, sleepREMHours, sleepCoreHours, sleepDeepHours, sleepAwakeHours
        case bedtime, wakeTime
        case steps, activeEnergyKcal, exerciseMinutes, standHours
        case workoutIntervals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Date.self, forKey: .day)
        dataSource = try container.decodeIfPresent(AppDataSource.self, forKey: .dataSource) ?? .appleHealth

        hrv = try container.decodeIfPresent(MetricSample.self, forKey: .hrv)
        restingHeartRate = try container.decodeIfPresent(MetricSample.self, forKey: .restingHeartRate)
        heartRateMedian = try container.decodeIfPresent(MetricSample.self, forKey: .heartRateMedian)
        heartRateMin = try container.decodeIfPresent(MetricSample.self, forKey: .heartRateMin)

        sleepHours = try container.decodeIfPresent(MetricSample.self, forKey: .sleepHours)
        sleepREMHours = try container.decodeIfPresent(MetricSample.self, forKey: .sleepREMHours)
        sleepCoreHours = try container.decodeIfPresent(MetricSample.self, forKey: .sleepCoreHours)
        sleepDeepHours = try container.decodeIfPresent(MetricSample.self, forKey: .sleepDeepHours)
        sleepAwakeHours = try container.decodeIfPresent(MetricSample.self, forKey: .sleepAwakeHours)
        bedtime = try container.decodeIfPresent(Date.self, forKey: .bedtime)
        wakeTime = try container.decodeIfPresent(Date.self, forKey: .wakeTime)

        steps = try container.decodeIfPresent(MetricSample.self, forKey: .steps)
        activeEnergyKcal = try container.decodeIfPresent(MetricSample.self, forKey: .activeEnergyKcal)
        exerciseMinutes = try container.decodeIfPresent(MetricSample.self, forKey: .exerciseMinutes)
        standHours = try container.decodeIfPresent(MetricSample.self, forKey: .standHours)
        workoutIntervals = try container.decodeIfPresent([WorkoutInterval].self, forKey: .workoutIntervals) ?? []
    }
}

extension DailyHealthMetrics {
    /// 当天是否至少有一个实测指标。用于过滤"完全空白"的占位日。
    var hasAnyMetric: Bool {
        hrv != nil || restingHeartRate != nil || heartRateMedian != nil
            || sleepHours != nil || steps != nil || activeEnergyKcal != nil
            || exerciseMinutes != nil || standHours != nil
    }

    /// 睡眠窗口（入睡 → 起床）。任一端缺失则为 nil。
    var sleepWindow: ClosedRange<Date>? {
        guard let bedtime, let wakeTime, wakeTime > bedtime else { return nil }
        return bedtime...wakeTime
    }
}
