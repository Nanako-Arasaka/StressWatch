import Foundation
@testable import StressWatch

/// 构造 `DailyHealthMetrics` 的确定性工具。
///
/// 用于给 Baseline / Trend / Correlation / Scoring 的测试提供"看起来像真人、
/// 但完全可复现"的多日序列。
enum DailyHealthMetricsFixture {

    /// 一天的指标蓝图。默认是一组"健康成年人"的合理值，测试按需覆盖。
    struct Blueprint {
        var hrv: Double? = 50
        var restingHR: Double? = 60
        var heartRateMedian: Double? = 72
        var sleepHours: Double? = 7.5
        var sleepREM: Double? = 1.6
        var sleepCore: Double? = 4.2
        var sleepDeep: Double? = 1.2
        var steps: Double? = 8_000
        var activeEnergy: Double? = 450
        var exerciseMinutes: Double? = 30
        var standHours: Double? = 11
    }

    static func sample(_ value: Double?, unit: String, source: MetricProvenance) -> MetricSample? {
        guard let value else { return nil }
        return MetricSample(value: value, unit: unit, source: source, sampleCount: 1)
    }

    static func day(
        _ date: Date,
        dataSource: AppDataSource = .appleHealth,
        _ blueprint: Blueprint = Blueprint()
    ) -> DailyHealthMetrics {
        let source: MetricProvenance = dataSource == .demo ? .demo : .measured
        return DailyHealthMetrics(
            day: date,
            dataSource: dataSource,
            hrv: sample(blueprint.hrv, unit: "ms", source: source),
            restingHeartRate: sample(blueprint.restingHR, unit: "bpm", source: source),
            heartRateMedian: sample(blueprint.heartRateMedian, unit: "bpm", source: source),
            sleepHours: sample(blueprint.sleepHours, unit: "hours", source: source),
            sleepREMHours: sample(blueprint.sleepREM, unit: "hours", source: source),
            sleepCoreHours: sample(blueprint.sleepCore, unit: "hours", source: source),
            sleepDeepHours: sample(blueprint.sleepDeep, unit: "hours", source: source),
            steps: sample(blueprint.steps, unit: "steps", source: source),
            activeEnergyKcal: sample(blueprint.activeEnergy, unit: "kcal", source: source),
            exerciseMinutes: sample(blueprint.exerciseMinutes, unit: "min", source: source),
            standHours: sample(blueprint.standHours, unit: "h", source: source)
        )
    }

    /// 一系列连续日期（来自 `TestCalendar`）上的同一蓝图。
    static func series(
        days: [Date],
        dataSource: AppDataSource = .appleHealth,
        _ blueprint: Blueprint = Blueprint()
    ) -> [DailyHealthMetrics] {
        days.map { day($0, dataSource: dataSource, blueprint) }
    }

    /// 按索引变化的蓝图，用于构造趋势 / 相关性场景。
    static func series(
        days: [Date],
        dataSource: AppDataSource = .appleHealth,
        _ build: (Int, inout Blueprint) -> Void
    ) -> [DailyHealthMetrics] {
        days.enumerated().map { index, date in
            var blueprint = Blueprint()
            build(index, &blueprint)
            return day(date, dataSource: dataSource, blueprint)
        }
    }
}
