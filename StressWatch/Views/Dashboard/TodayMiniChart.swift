import SwiftUI
import Charts

struct TodayMiniChart: View {
    let metrics: [HealthMetric]

    var body: some View {
        if metrics.isEmpty {
            Text("暂无今日数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(metrics) { metric in
                LineMark(
                    x: .value("时间", metric.date),
                    y: .value("数值", metric.value),
                    series: .value("指标", metric.type.rawValue)
                )
                .foregroundStyle(by: .value("指标", displayName(for: metric.type)))
                .symbol(by: .value("指标", displayName(for: metric.type)))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .chartLegend(position: .bottom)
        }
    }

    private func displayName(for type: MetricType) -> String {
        switch type {
        case .heartRate:
            return "HR"
        case .hrv:
            return "HRV"
        case .restingHeartRate:
            return "静息 HR"
        case .steps:
            return "步数"
        case .sleep:
            return "睡眠"
        case .activeEnergyBurned:
            return "活动能量"
        case .appleExerciseTime:
            return "锻炼时间"
        case .appleStandTime:
            return "站立时间"
        case .sleepREM:
            return "REM"
        case .sleepCore:
            return "Core"
        case .sleepDeep:
            return "Deep"
        case .sleepAwake:
            return "Awake"
        }
    }
}
