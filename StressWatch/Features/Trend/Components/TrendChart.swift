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
                AreaMark(
                    x: .value("日期", score.date),
                    y: .value("压力趋势参考", score.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.stressAmber.opacity(colorScheme == .dark ? 0.16 : 0.14),
                            AppColors.stressAmber.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("日期", score.date),
                    y: .value("压力趋势参考", score.value)
                )
                .foregroundStyle(AppColors.stressAmber)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("日期", score.date),
                    y: .value("压力趋势参考", score.value)
                )
                .foregroundStyle(score.level.displayColor)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                        .foregroundStyle(AppColors.chartGrid(for: colorScheme))
                    AxisValueLabel()
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(AppColors.subtleActivityFill(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
