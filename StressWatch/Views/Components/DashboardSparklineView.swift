import SwiftUI

// DashboardSparklineView 是小卡片里的迷你趋势线。
// 它使用 Path 手绘曲线，避免默认图表样式过重。
struct DashboardSparklineView: View {
    let values: [Double]
    let color: Color

    @State private var drawProgress: CGFloat = AppMotion.chartInitialProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if values.count < 2 {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    sparklinePath(in: proxy.size)
                        .trim(from: 0, to: reduceMotion ? 1 : drawProgress)
                        .stroke(
                            color.gradient,
                            style: StrokeStyle(lineWidth: 2.15, lineCap: .round, lineJoin: .round)
                        )

                    ForEach(points(in: proxy.size).indices, id: \.self) { index in
                        let point = points(in: proxy.size)[index]
                        Circle()
                            .fill(index == values.count - 1 ? color : color.opacity(0.45))
                            .frame(width: index == values.count - 1 ? 5 : 3.5, height: index == values.count - 1 ? 5 : 3.5)
                            .position(point)
                            .opacity(reduceMotion ? 1 : drawProgress)
                    }
                }
            }
        }
        .frame(height: 42)
        .onAppear {
            startDrawingAnimation()
        }
        .onChange(of: values) { _ in
            startDrawingAnimation()
        }
    }

    private func sparklinePath(in size: CGSize) -> Path {
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
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let horizontalStep = size.width / CGFloat(max(values.count - 1, 1))

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * horizontalStep
            let normalized = (value - minValue) / range
            let y = size.height - CGFloat(normalized) * (size.height - 6) - 3
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
