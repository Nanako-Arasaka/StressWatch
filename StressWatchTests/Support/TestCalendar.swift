import Foundation

/// 确定性时间与日历。
///
/// 依据：Whoordan 的测试固定 `Calendar(identifier:)` 与 `TimeZone(secondsFromGMT:)`，
/// 并用固定 `Date` 替代 `Date()`。任何按天聚合 / 基线 / 趋势的测试都必须使用这里的值，
/// 否则在 DST 切换或非 UTC 时区下会 flaky。
enum TestCalendar {
    /// 固定为 UTC 的公历，避免依赖运行环境时区。
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// 固定基准时刻：2025-10-16 00:00:00 UTC（周四）。
    /// 测试里绝不使用 `Date()`。
    static let referenceNow: Date = Date(timeIntervalSince1970: 1_760_572_800)

    /// 相对基准日的第 `offset` 天的**起始时刻**（00:00:00 UTC）。
    /// `day(0)` = 2025-10-16，`day(-1)` = 2025-10-15，`day(1)` = 2025-10-17。
    static func day(_ offset: Int) -> Date {
        utc.date(byAdding: .day, value: offset, to: utc.startOfDay(for: referenceNow))!
    }

    /// 某天内的第 `hour` 小时（可带分钟）。
    static func time(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
        let start = day(dayOffset)
        return utc.date(bySettingHour: hour, minute: minute, second: 0, of: start)!
    }

    /// 生成长度为 `count` 的连续日期序列，最后一天为 `day(0)`（即"今天"）。
    /// 用于构造"最近 N 天"的历史窗口。
    static func recentDays(_ count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (0..<count).map { day(-(count - 1 - $0)) }
    }

    // MARK: - 确定性伪随机

    /// DJB2 哈希种子。
    /// **绝不使用 `String.hashValue`** —— 后者每次进程运行都会被重新随机化，
    /// 会让"确定性"测试数据在重启后改变（Thump 踩过的坑）。
    static func seed(_ text: String) -> Int {
        var hash: UInt64 = 5381
        for scalar in text.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return Int(hash & 0xFFFF)
    }

    /// 基于种子的确定性 [0, 1) 伪随机数（线性同余）。
    /// 同一 (seed, index) 在任何进程、任何平台都返回相同结果。
    static func random(seed: Int, index: Int) -> Double {
        var state = UInt64(truncatingIfNeeded: seed) &+ UInt64(index) &* 6_364_136_223_846_793_005
        state ^= state >> 21
        state ^= state << 37
        state ^= state >> 4
        state = state &* 2_682_821_773_607_332_977
        state ^= state >> 32
        return Double(state % 100_000) / 100_000
    }
}
