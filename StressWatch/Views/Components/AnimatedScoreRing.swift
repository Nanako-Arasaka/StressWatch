import SwiftUI

struct AnimatedScoreRing: View {
    let value: Int
    let levelName: String
    let color: Color
    let title: String

    @State private var progress: Double = 0

    private var normalizedValue: Double {
        min(max(Double(value), 0), 100)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.14), lineWidth: 16)

            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(levelName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .onAppear {
            animateProgress()
        }
        .onChange(of: value) { _ in
            animateProgress()
        }
    }

    private func animateProgress() {
        progress = 0
        withAnimation(.easeOut(duration: 0.35)) {
            progress = normalizedValue
        }
    }
}
