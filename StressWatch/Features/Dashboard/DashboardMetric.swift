import Foundation
import SwiftUI

// DashboardMetric 是 Dashboard 卡片的展示模型。
// 它只描述 UI 需要显示的文字、图标、颜色和趋势点，不直接读取 HealthKit。
struct DashboardMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let status: String
    let systemImage: String
    let color: Color
    let trendValues: [Double]
    let source: DashboardMetricSource
}

// 每张卡片可以独立说明自己来自 Apple Health、Demo，或暂无可用数据。
enum DashboardMetricSource {
    case appleHealth
    case demo
    case unavailable

    var label: String {
        switch self {
        case .appleHealth:
            return "Apple Health"
        case .demo:
            return "Demo"
        case .unavailable:
            return "暂无数据"
        }
    }

    var tint: Color {
        switch self {
        case .appleHealth:
            return AppColors.primaryBlue
        case .demo:
            return AppColors.softBlue
        case .unavailable:
            return AppColors.softPink.opacity(0.72)
        }
    }
}

// HealthDashboardSnapshot 是 Dashboard 一次刷新后的完整页面状态。
// View 只消费这个快照，具体计算和 fallback 逻辑留在 DashboardViewModel。
struct HealthDashboardSnapshot {
    let metrics: [DashboardMetric]
    let stressTrend: [Double]
    let hrvTrend: [Double]
    let heartRateTrend: [Double]
    let activityEnergyTrend: [Double]
    let activityStandTrend: [Double]
    let activityEnergyToday: String
    let activityExerciseToday: String
    let activityStandToday: String
    let activityEnergyGoal: String
    let activityExerciseGoal: String
    let activityStandGoal: String
    let activitySource: DashboardMetricSource
    let sleepStages: [SleepStageSummary]
    let insight: String

    static let empty = HealthDashboardSnapshot(
        metrics: [],
        stressTrend: [],
        hrvTrend: [],
        heartRateTrend: [],
        activityEnergyTrend: [],
        activityStandTrend: [],
        activityEnergyToday: "暂无",
        activityExerciseToday: "暂无",
        activityStandToday: "暂无",
        activityEnergyGoal: "500 kcal",
        activityExerciseGoal: "30 min",
        activityStandGoal: "12 h",
        activitySource: .unavailable,
        sleepStages: [],
        insight: "正在准备趋势参考数据。"
    )
}

// 睡眠阶段摘要用于展示 REM、Core、Deep、Awake。
// 总睡眠时长仍只由真正睡眠阶段计算，Awake 不参与总睡眠。
struct SleepStageSummary: Identifiable {
    let id: String
    let title: String
    let hours: Double
    let color: Color
}
