import Foundation

struct HealthMetric: Identifiable, Codable {
    let id: UUID
    let type: MetricType
    let value: Double
    let unit: String
    let date: Date
    /// HealthKit 写入来源（如「小米运动健康」「Apple Watch」），未知则为 nil。
    let sourceName: String?

    init(
        id: UUID,
        type: MetricType,
        value: Double,
        unit: String,
        date: Date,
        sourceName: String? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.date = date
        self.sourceName = sourceName
    }
}

enum MetricType: String, Codable, CaseIterable {
    case heartRate
    case hrv
    case restingHeartRate
    case steps
    case sleep
    case activeEnergyBurned
    case appleExerciseTime
    case appleStandTime
    case sleepREM
    case sleepCore
    case sleepDeep
    case sleepAwake
}

// MARK: - 第三方健康源识别（路径 A：小米运动健康 → Apple 健康）

/// 小米 / 手环类写入源。名称会随系统语言与 App 版本变化，这里做宽松匹配。
enum HealthSourceClassifier {
    private static let xiaomiKeywords = [
        "小米运动健康",
        "小米运动",
        "mi fitness",
        "mifitness",
        "xiaomi wear",
        "xiaomi fitness",
        "zepp life",
        "zepp",
        "amazfit",
        "huami",
        "mi fit",
        "miband",
        "mi band"
    ]

    static func isXiaomiFamily(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return xiaomiKeywords.contains { lowered.contains($0) }
    }

    /// 从一批指标里汇总写入源展示名（去重、保持稳定顺序）。
    static func uniqueSourceNames(in metrics: [HealthMetric]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for metric in metrics {
            guard let name = metric.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            ordered.append(name)
        }
        return ordered
    }

    /// 数据源徽章文案：Apple Health，并标注是否含小米等第三方写入。
    static func dashboardSourceLabel(
        metrics: [HealthMetric],
        baseLabel: String
    ) -> String {
        let names = uniqueSourceNames(in: metrics)
        let xiaomiNames = names.filter { isXiaomiFamily($0) }
        guard !xiaomiNames.isEmpty else {
            return baseLabel
        }
        // 只展示一个代表名，避免徽章过长
        let representative = xiaomiNames.contains("小米运动健康") ? "小米运动健康" : xiaomiNames[0]
        return "\(baseLabel) · \(representative)"
    }

    /// 设置页「已检测到的写入源」摘要。
    static func detectedSourcesDescription(in metrics: [HealthMetric]) -> String? {
        let names = uniqueSourceNames(in: metrics)
        guard !names.isEmpty else { return nil }
        return names.joined(separator: "、")
    }
}

extension Array where Element == HealthMetric {
    func latestValue(for type: MetricType) -> Double? {
        filter { $0.type == type }
            .max { $0.date < $1.date }?
            .value
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
