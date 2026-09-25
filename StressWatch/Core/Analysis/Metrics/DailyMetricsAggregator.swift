import Foundation

protocol DailyMetricsAggregating {
    func aggregate(
        metrics: [HealthMetric],
        dataSource: AppDataSource,
        now: Date,
        sleepSessions: [SleepSession],
        workoutIntervals: [WorkoutInterval]
    ) -> [DailyHealthMetrics]
}

extension DailyMetricsAggregating {
    /// 无区间数据时的便捷入口 —— 现有调用方不需要改动签名。
    func aggregate(
        metrics: [HealthMetric],
        dataSource: AppDataSource,
        now: Date
    ) -> [DailyHealthMetrics] {
        aggregate(
            metrics: metrics,
            dataSource: dataSource,
            now: now,
            sleepSessions: [],
            workoutIntervals: []
        )
    }
}

/// 把原始 `HealthMetric` 样本序列转换成按天对齐的 `[DailyHealthMetrics]`。
///
/// 四条关键行为：
/// 1. **按天补齐**：从最早数据日到 `max(最晚数据日, 今天)` 之间的每一天都会产出一条记录。
///    缺失的那天所有指标为 nil，但条目存在 —— 这是 Trend / Correlation 判断
///    "数据断档"与"日历连续性"的前提（Thump 用 `gap > 1.5 days` 打断连续计数）。
/// 2. **来源不再丢失**：`dataSource` 一路带到 `MetricSample.provenance`，
///    下游与 LLM 才能区分实测值与演示值。旧代码把 demo 数据混进 Apple Health 数组后，
///    这层信息就丢了。
/// 3. **HRV 优先取睡眠期样本**（Soma `sleepingHRV ?? todayHRV`）：夜间 HRV 才是
///    副交感状态的可靠读数，白天样本会被活动污染。睡眠窗口缺失时回退全天。
/// 4. **运动区间按"与当天有重叠"归属**，跨午夜的运动会同时出现在两天，
///    保证 sedentary 过滤不会漏掉睡前/凌晨的训练。
///
/// 纯函数，无 IO，只 import Foundation。
struct DailyMetricsAggregator: DailyMetricsAggregating {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func aggregate(
        metrics: [HealthMetric],
        dataSource: AppDataSource,
        now: Date,
        sleepSessions: [SleepSession],
        workoutIntervals: [WorkoutInterval]
    ) -> [DailyHealthMetrics] {
        let grouped = Dictionary(grouping: metrics) { calendar.startOfDay(for: $0.date) }
        guard let earliestDay = grouped.keys.min() else {
            return []
        }

        let latestDataDay = grouped.keys.max() ?? earliestDay
        let today = calendar.startOfDay(for: now)
        let lastDay = max(latestDataDay, today)

        let provenance: MetricProvenance = dataSource == .demo ? .demo : .measured
        let sessionsByDay = Dictionary(grouping: sleepSessions) { calendar.startOfDay(for: $0.day) }

        var days: [DailyHealthMetrics] = []
        var day = earliestDay
        while day <= lastDay {
            days.append(
                makeDay(
                    day: day,
                    samples: grouped[day] ?? [],
                    dataSource: dataSource,
                    provenance: provenance,
                    sleepSession: sessionsByDay[day]?.first,
                    workoutIntervals: Self.workoutsOverlapping(day: day, calendar: calendar, in: workoutIntervals)
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    // MARK: - Private

    /// 与当天 [00:00, 次日 00:00) 有重叠的运动区间。
    static func workoutsOverlapping(
        day: Date,
        calendar: Calendar,
        in intervals: [WorkoutInterval]
    ) -> [WorkoutInterval] {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return [] }
        return intervals.filter { $0.start < nextDay && $0.end > day }
    }

    private func makeDay(
        day: Date,
        samples: [HealthMetric],
        dataSource: AppDataSource,
        provenance: MetricProvenance,
        sleepSession: SleepSession?,
        workoutIntervals: [WorkoutInterval]
    ) -> DailyHealthMetrics {
        func of(_ type: MetricType) -> [HealthMetric] {
            samples.filter { $0.type == type }
        }

        return DailyHealthMetrics(
            day: day,
            dataSource: dataSource,
            hrv: MetricAggregation.sampled(
                of(.hrv), unit: "ms", range: MetricAggregation.hrvRangeMs,
                provenance: provenance, window: sleepSession?.window
            ),
            restingHeartRate: MetricAggregation.latest(
                of(.restingHeartRate), unit: "bpm", range: MetricAggregation.restingHRRangeBpm, provenance: provenance
            ),
            heartRateMedian: MetricAggregation.sampled(
                of(.heartRate), unit: "bpm", range: MetricAggregation.heartRateRangeBpm, provenance: provenance
            ),
            heartRateMin: MetricAggregation.sampled(
                of(.heartRate), unit: "bpm", range: MetricAggregation.heartRateRangeBpm,
                provenance: provenance, reducer: .minimum
            ),
            sleepHours: MetricAggregation.latest(
                of(.sleep), unit: "hours", range: MetricAggregation.sleepHoursRange, provenance: provenance
            ),
            sleepREMHours: MetricAggregation.latest(
                of(.sleepREM), unit: "hours", range: MetricAggregation.sleepHoursRange, provenance: provenance
            ),
            sleepCoreHours: MetricAggregation.latest(
                of(.sleepCore), unit: "hours", range: MetricAggregation.sleepHoursRange, provenance: provenance
            ),
            sleepDeepHours: MetricAggregation.latest(
                of(.sleepDeep), unit: "hours", range: MetricAggregation.sleepHoursRange, provenance: provenance
            ),
            sleepAwakeHours: MetricAggregation.latest(
                of(.sleepAwake), unit: "hours", range: MetricAggregation.sleepHoursRange, provenance: provenance
            ),
            bedtime: sleepSession?.bedtime,
            wakeTime: sleepSession?.wakeTime,
            steps: MetricAggregation.latest(
                of(.steps), unit: "steps", range: MetricAggregation.stepsRange, provenance: provenance
            ),
            activeEnergyKcal: MetricAggregation.latest(
                of(.activeEnergyBurned), unit: "kcal", range: MetricAggregation.energyRangeKcal, provenance: provenance
            ),
            exerciseMinutes: MetricAggregation.latest(
                of(.appleExerciseTime), unit: "min", range: MetricAggregation.exerciseRangeMin, provenance: provenance
            ),
            standHours: MetricAggregation.latest(
                of(.appleStandTime), unit: "h", range: MetricAggregation.standRangeHours, provenance: provenance
            ),
            workoutIntervals: workoutIntervals
        )
    }
}
