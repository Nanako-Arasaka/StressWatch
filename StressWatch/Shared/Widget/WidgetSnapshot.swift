import Foundation

struct WidgetSnapshot: Codable, Equatable {
    let recoveryScore: Int?
    let recoveryStatus: String
    let liveStressScore: Int?
    let liveStressStatus: String
    let hrvText: String
    let sleepText: String
    let insightText: String
    let dataSource: String
    let analysisSource: String
    let generatedAt: Date
    let isPlaceholder: Bool
    let schemaVersion: Int
}

extension WidgetSnapshot {
    static let currentSchemaVersion = 1

    static func placeholder(
        dataSource: String = "暂无数据",
        analysisSource: String = "Rule-based",
        generatedAt: Date = Date()
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            recoveryScore: nil,
            recoveryStatus: "等待数据",
            liveStressScore: nil,
            liveStressStatus: "数据不足",
            hrvText: "暂无",
            sleepText: "暂无",
            insightText: "Open StressWatch to generate data",
            dataSource: dataSource,
            analysisSource: analysisSource,
            generatedAt: generatedAt,
            isPlaceholder: true,
            schemaVersion: currentSchemaVersion
        )
    }
}
