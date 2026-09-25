import Foundation

/// 从 `[DailyHealthMetrics]` 计算各指标的个人基线。
///
/// 方法选择（见 DESIGN_PHASE3 §3.2）：
/// | 指标 | 方法 | requiredDays | 理由 |
/// |---|---|---|---|
/// | HRV | log 域 EWMA(α=0.25) + 样本 SD，另存 P75 锚点 | 7 | 对数正态；需个人变异度 |
/// | RHR / Sleep / 活动 | 中位数 + MAD | 5 | 抗离群，绝对波动小 |
///
/// 硬约定：
/// - **样本天数不足时仍返回结构**，但 `isReliable == false`、`zScore()` 返回 nil。
///   调用方据此显示"校准中，还需 N 天"，而不是伪造基线。
/// - **序列有洞（缺失日）只影响 `sampleDays`，不插值、不填 0。**
/// - 全部纯函数，只 `import Foundation`。
protocol PersonalBaselineComputing {
    func compute(
        metric: BaselineMetric,
        from history: [DailyHealthMetrics],
        windowDays: Int,
        now: Date
    ) -> PersonalBaseline

    func baselineSet(
        from history: [DailyHealthMetrics],
        windowDays: Int,
        now: Date
    ) -> PersonalBaselineSet
}

struct PersonalBaselineEngine: PersonalBaselineComputing {
    /// 注入日历，保证与调用方 / 测试的时区一致。
    /// 测试用 `TestCalendar.utc`，生产用 `.current`（Whoordan 同款纪律）。
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - 各指标的配置

    private struct MetricSpec {
        let method: BaselineMethod
        let requiredDays: Int
        let unit: String
        /// 是否额外计算 P75 锚点（仅 HRV）。
        let computesAnchor: Bool
    }

    private func spec(for metric: BaselineMetric) -> MetricSpec {
        switch metric {
        case .hrv:
            return MetricSpec(method: .logEWMA, requiredDays: 7, unit: "ms", computesAnchor: true)
        case .restingHeartRate:
            return MetricSpec(method: .median, requiredDays: 5, unit: "bpm", computesAnchor: false)
        case .sleepHours:
            return MetricSpec(method: .median, requiredDays: 5, unit: "hours", computesAnchor: false)
        case .sleepREMHours, .sleepDeepHours:
            return MetricSpec(method: .median, requiredDays: 5, unit: "hours", computesAnchor: false)
        case .steps:
            return MetricSpec(method: .median, requiredDays: 5, unit: "steps", computesAnchor: false)
        case .activeEnergyKcal:
            return MetricSpec(method: .median, requiredDays: 5, unit: "kcal", computesAnchor: false)
        case .exerciseMinutes:
            return MetricSpec(method: .median, requiredDays: 5, unit: "min", computesAnchor: false)
        case .standHours:
            return MetricSpec(method: .median, requiredDays: 5, unit: "h", computesAnchor: false)
        }
    }

    // MARK: - Public

    func compute(
        metric: BaselineMetric,
        from history: [DailyHealthMetrics],
        windowDays: Int,
        now: Date
    ) -> PersonalBaseline {
        let config = spec(for: metric)
        let window = windowed(history, windowDays: windowDays, now: now)
        // 只取该指标非 nil 的天 —— 缺失日不占位、不插值。
        let values = window.compactMap { day -> Double? in
            sample(for: metric, in: day)?.value
        }
        // 离群点剔除（MAD 3σ）。样本 < 3 时原样返回。
        let cleaned = RobustStatistics.dropOutliers(values, method: .mad3Sigma)

        let value: Double
        let dispersion: Double?

        switch config.method {
        case .logEWMA:
            let stats = RobustStatistics.logDomainStats(cleaned)
            // log-EWMA 的中心是 meanLn，还原成原始尺度时用 exp(ewma)。
            value = stats.map { exp($0.meanLn) } ?? 0
            dispersion = stats?.sdLn

        case .median, .p75:
            value = RobustStatistics.median(cleaned) ?? 0
            dispersion = RobustStatistics.mad(cleaned)
        }

        let anchor = config.computesAnchor ? RobustStatistics.p75(cleaned) : nil

        return PersonalBaseline(
            metric: metric,
            windowDays: windowDays,
            value: value,
            dispersion: dispersion,
            sampleDays: cleaned.count,
            requiredDays: config.requiredDays,
            computedAt: now,
            method: config.method,
            anchorP75: anchor
        )
    }

    func baselineSet(
        from history: [DailyHealthMetrics],
        windowDays: Int,
        now: Date
    ) -> PersonalBaselineSet {
        func baseline(_ metric: BaselineMetric) -> PersonalBaseline {
            compute(metric: metric, from: history, windowDays: windowDays, now: now)
        }
        return PersonalBaselineSet(
            hrv: baseline(.hrv),
            restingHeartRate: baseline(.restingHeartRate),
            sleepHours: baseline(.sleepHours),
            steps: baseline(.steps),
            activeEnergyKcal: baseline(.activeEnergyKcal),
            exerciseMinutes: baseline(.exerciseMinutes),
            standHours: baseline(.standHours)
        )
    }

    // MARK: - Private

    /// 取最近 `windowDays` 天（含今天）的历史，按日期升序。
    private func windowed(
        _ history: [DailyHealthMetrics],
        windowDays: Int,
        now: Date
    ) -> [DailyHealthMetrics] {
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: startOfToday) ?? startOfToday
        return history
            .filter { $0.day >= start && $0.day <= startOfToday }
            .sorted { $0.day < $1.day }
    }

    private func sample(for metric: BaselineMetric, in day: DailyHealthMetrics) -> MetricSample? {
        switch metric {
        case .hrv: return day.hrv
        case .restingHeartRate: return day.restingHeartRate
        case .sleepHours: return day.sleepHours
        case .sleepREMHours: return day.sleepREMHours
        case .sleepDeepHours: return day.sleepDeepHours
        case .steps: return day.steps
        case .activeEnergyKcal: return day.activeEnergyKcal
        case .exerciseMinutes: return day.exerciseMinutes
        case .standHours: return day.standHours
        }
    }
}
