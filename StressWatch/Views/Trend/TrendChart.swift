import SwiftUI
import Charts

struct TrendChart: View {
    let scores: [StressScore]

    var body: some View {
        if scores.isEmpty {
            Text("暂无趋势数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(scores) { score in
                LineMark(
                    x: .value("日期", score.date),
                    y: .value("压力趋势参考", score.value)
                )
                .foregroundStyle(.orange)
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
        }
    }
}
