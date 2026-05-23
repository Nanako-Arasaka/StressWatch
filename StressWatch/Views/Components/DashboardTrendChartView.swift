import SwiftUI

// DashboardTrendChartView 是 Dashboard 大卡片中的 7 天趋势图。
// 它保持轻量，线条和点位风格接近网页原型。
struct DashboardTrendChartView: View {
    let title: String
    let subtitle: String
    let values: [Double]
    let color: Color
    let yRange: ClosedRange<Double>

    @State private var drawProgress: CGFloat = AppMotion.chartInitialProgress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassSectionHeader(
                title: title,
                subtitle: subtitle,
                systemImage: "chart.line.uptrend.xyaxis"
            )

            GeometryReader { proxy in
                ZStack {
                    gridLines

                    if values.count < 2 {
                        Text("暂无足够趋势数据")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        trendPath(in: proxy.size)
                            .trim(from: 0, to: reduceMotion ? 1 : drawProgress)
                            .stroke(
                                color.gradient,
                                style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                            )

                        ForEach(points(in: proxy.size).indices, id: \.self) { index in
                            let point = points(in: proxy.size)[index]
                            Circle()
                                .fill(AppColors.chartPointHalo(for: colorScheme))
                                .frame(width: 11, height: 11)
                                .position(point)
                                .opacity(reduceMotion ? 1 : drawProgress)

                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                                .position(point)
                                .opacity(reduceMotion ? 1 : drawProgress)
                        }
                    }
                }
            }
            .frame(height: 210)
        }
        .onAppear {
            startDrawingAnimation()
        }
        .onChange(of: values) { _ in
            startDrawingAnimation()
        }
    }

    private var gridLines: some View {
        VStack {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(AppColors.chartGrid(for: colorScheme))
                    .frame(height: 1)
                Spacer()
            }
        }
    }

    private func trendPath(in size: CGSize) -> Path {
        let points = points(in: size)
        var path = Path()

        guard let first = points.first else {
            return path
        }

        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }

        return path
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let lower = yRange.lowerBound
        let upper = yRange.upperBound
        let range = max(upper - lower, 1)
        let horizontalStep = size.width / CGFloat(max(values.count - 1, 1))

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * horizontalStep
            let normalized = (min(max(value, lower), upper) - lower) / range
            let y = size.height - CGFloat(normalized) * (size.height - 18) - 9
            return CGPoint(x: x, y: y)
        }
    }

    private func startDrawingAnimation() {
        if reduceMotion {
            drawProgress = 1
            return
        }

        drawProgress = AppMotion.chartInitialProgress
        withAnimation(AppMotion.chartDrawing(reduceMotion: reduceMotion)) {
            drawProgress = 1
        }
    }
}
