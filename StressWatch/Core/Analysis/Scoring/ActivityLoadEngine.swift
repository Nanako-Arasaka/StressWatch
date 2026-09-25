import Foundation

/// 轻量活动负荷引擎：把 steps / energy / exercise 归一成 0-100 日负荷，
/// 再算 ATL（急性 7 天 EWMA）/ CTL（慢性 28 天 EWMA）/ ACR（急慢比）。
///
/// **不是训练功能** —— 纯统计骨架（ATL/CTL/ACR），无 workout 概念、无训练建议。
/// 依据：WorkoutTracker 的 ATL/CTL 统计骨架（Soma/Whoordan 无此模块）；
/// ACR > 1.3 视为近期负荷异常升高（Soma `StrainCalculator` 的阈值）。
///
/// 冷启动：前 7 天用固定参考值 `500`（Soma `StrainCalculator` 容量模式），
/// 之后切到滚动个人均值。纯函数，只 `import Foundation`。
struct ActivityLoadEngine {

    /// 冷启动期（天）：不足时用固定参考负荷。
    static let coldStartDays = 7
    /// 冷启动固定参考值（归一化分母）。
    static let coldStartReference: Double = 500
    /// ACR 异常升高的阈值。
    static let acrElevatedThreshold: Double = 1.3

    // MARK: - 日负荷

    /// 把一天的活动量归一成 0-100 的负荷分。
    ///
    /// 权重：steps 0.5 / activeEnergy 0.3 / exercise 0.2（Soma MovementScore 模式：
    /// 缺失信号退出并把权重按比例分给剩余；全缺失返回 nil）。
    func dailyLoad(
        _ day: DailyHealthMetrics,
        baselines: PersonalBaselineSet
    ) -> Double? {
        struct Weighted {
            let value: Double
            let weight: Double
            let label: String
        }

        var components: [Weighted] = []

        if let steps = day.steps?.value, baselines.steps.sampleDays > 0, baselines.steps.value > 0 {
            let ratio = min(3, steps / baselines.steps.value) // 上限 3 倍基线
            components.append(Weighted(value: ratio * 33.33, weight: 0.5, label: "steps"))
        }
        if let energy = day.activeEnergyKcal?.value,
           baselines.activeEnergyKcal.sampleDays > 0,
           baselines.activeEnergyKcal.value > 0 {
            let ratio = min(3, energy / baselines.activeEnergyKcal.value)
            components.append(Weighted(value: ratio * 33.33, weight: 0.3, label: "energy"))
        }
        if let exercise = day.exerciseMinutes?.value,
           baselines.exerciseMinutes.sampleDays > 0,
           baselines.exerciseMinutes.value > 0 {
            let ratio = min(3, exercise / baselines.exerciseMinutes.value)
            components.append(Weighted(value: ratio * 33.33, weight: 0.2, label: "exercise"))
        }

        guard !components.isEmpty else { return nil }

        // 权重重归一化（Soma MovementScore `totalWeight` 模式）
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedSum = components.reduce(0) { $0 + $1.value * $1.weight }
        return min(100, max(0, weightedSum / totalWeight))
    }

    // MARK: - ATL / CTL / ACR

    /// 急性负荷：近 7 天日负荷的 EWMA。
    /// 不足 7 天时用已有天数的算术均值（冷启动）。
    func acuteLoad(history: [DailyHealthMetrics], baselines: PersonalBaselineSet, now: Date) -> Double? {
        rollingLoad(history: history, baselines: baselines, now: now, windowDays: 7)
    }

    /// 慢性负荷：近 28 天日负荷的 EWMA。
    /// 不足 7 天时用 `coldStartReference` 归一后的固定值（Soma 容量模式）。
    func chronicLoad(history: [DailyHealthMetrics], baselines: PersonalBaselineSet, now: Date) -> Double? {
        let loads = dailyLoads(history: history, baselines: baselines, now: now, windowDays: 28)
        if loads.count < Self.coldStartDays {
            // 冷启动：用固定参考值直接归一成中等负荷
            return 50
        }
        return ewma(loads, alpha: 2.0 / (28.0 + 1.0))
    }

    /// 急慢比 ACR = ATL / CTL。任一缺失返回 nil。
    /// ACR > 1.3 → 近期负荷异常升高。
    func acr(history: [DailyHealthMetrics], baselines: PersonalBaselineSet, now: Date) -> Double? {
        guard let atl = acuteLoad(history: history, baselines: baselines, now: now),
              let ctl = chronicLoad(history: history, baselines: baselines, now: now),
              ctl > 0 else {
            return nil
        }
        return atl / ctl
    }

    /// ACR 是否异常升高。
    func isElevated(history: [DailyHealthMetrics], baselines: PersonalBaselineSet, now: Date) -> Bool {
        guard let ratio = acr(history: history, baselines: baselines, now: now) else { return false }
        return ratio > Self.acrElevatedThreshold
    }

    // MARK: - Private

    private func rollingLoad(
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet,
        now: Date,
        windowDays: Int
    ) -> Double? {
        let loads = dailyLoads(history: history, baselines: baselines, now: now, windowDays: windowDays)
        guard !loads.isEmpty else { return nil }
        if loads.count < Self.coldStartDays {
            // 不足 7 天：用算术均值即可
            return loads.reduce(0, +) / Double(loads.count)
        }
        return ewma(loads, alpha: 2.0 / (Double(windowDays) + 1.0))
    }

    private func dailyLoads(
        history: [DailyHealthMetrics],
        baselines: PersonalBaselineSet,
        now: Date,
        windowDays: Int
    ) -> [Double] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: startOfToday) ?? startOfToday
        return history
            .filter { $0.day >= start && $0.day <= startOfToday }
            .sorted { $0.day < $1.day }
            .compactMap { dailyLoad($0, baselines: baselines) }
    }

    /// EWMA，α 越大越看重近期。
    private func ewma(_ values: [Double], alpha: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        var result = values[0]
        for i in 1..<values.count {
            result = alpha * values[i] + (1 - alpha) * result
        }
        return result
    }
}
