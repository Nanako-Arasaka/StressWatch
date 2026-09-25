import Foundation

/// 一天的完整睡眠会话（区间信息）。
///
/// 存在的理由：`HealthMetric` 只能承载"某时刻的某个数值"，装不下「几点睡、几点醒」。
/// 而两件事必须依赖它：
/// 1. **HRV 的睡眠期取样** —— Soma 用 `sleepingHRV ?? todayHRV`，因为夜间 HRV 才是
///    副交感神经状态的可靠读数；白天 HRV 会被活动污染。
/// 2. **睡眠规律性** —— Soma 用就寝时刻的 stddev、Whoordan 用圆周标准差，
///    两者都需要 bedtime / wakeTime，而不只是时长。
///
/// 归属日与 `HealthKitService.fetchDailySleepAnalysis` 保持一致：**按醒来日（endDate）归属**。
struct SleepSession: Codable, Equatable, Identifiable {
    var id: Date { day }

    /// 归属日（醒来日的 00:00）。
    let day: Date
    let bedtime: Date
    let wakeTime: Date
    /// 实际睡着时长（小时）。设备只写了 InBed 时为 nil。
    let asleepHours: Double?
    /// 在床时长（小时）。未记录时为 nil。
    let inBedHours: Double?

    var window: ClosedRange<Date> { bedtime...wakeTime }

    init(
        day: Date,
        bedtime: Date,
        wakeTime: Date,
        asleepHours: Double? = nil,
        inBedHours: Double? = nil
    ) {
        self.day = day
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.asleepHours = asleepHours
        self.inBedHours = inBedHours
    }
}
