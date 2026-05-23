import SwiftUI
import Charts

struct TrendChart: View {
    let scores: [StressScore]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if scores.isEmpty {
            Text("暂无趋势数据")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(scores) { score in
                LineMark(
                    x: .value("日期", score.date),
                    y: .value("压力趋势参考", score.value)
                )
                .foregroundStyle(AppColors.stressAmber)
                .symbol(Circle())
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("日期", score.date),
                    y: .value("压力趋势参考", score.value)
                )
                .foregroundStyle(score.level.displayColor)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(AppColors.subtleActivityFill(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
