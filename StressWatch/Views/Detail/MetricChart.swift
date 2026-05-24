import SwiftUI
import Charts

struct MetricChart: View {
    let metrics: [HealthMetric]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if metrics.isEmpty {
            Text("暂无数据")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(metrics) { metric in
                LineMark(
                    x: .value("时间", metric.date),
                    y: .value("数值", metric.value)
                )
                .foregroundStyle(AppColors.teal.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("时间", metric.date),
                    y: .value("数值", metric.value)
                )
                .foregroundStyle(AppColors.cyan)
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(AppColors.subtleActivityFill(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
