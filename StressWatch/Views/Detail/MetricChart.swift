import SwiftUI
import Charts

struct MetricChart: View {
    let metrics: [HealthMetric]

    var body: some View {
        if metrics.isEmpty {
            Text("暂无数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(metrics) { metric in
                LineMark(
                    x: .value("时间", metric.date),
                    y: .value("数值", metric.value)
                )
                .foregroundStyle(.blue.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("时间", metric.date),
                    y: .value("数值", metric.value)
                )
                .foregroundStyle(.blue)
            }
        }
    }
}
