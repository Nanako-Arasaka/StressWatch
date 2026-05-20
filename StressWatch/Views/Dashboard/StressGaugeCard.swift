import SwiftUI

struct StressGaugeCard: View {
    let stressScore: StressScore?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                GlassSectionHeader(
                    title: "压力趋势参考",
                    subtitle: "基于 HR、HRV、活动和睡眠的个人趋势视图",
                    systemImage: "waveform.path.ecg"
                )

                Spacer(minLength: 12)
            }

            AnimatedScoreRing(
                value: stressScore?.value ?? 0,
                levelName: stressScore?.level.displayName ?? "暂无",
                color: stressScore?.level.displayColor ?? .gray,
                title: "压力趋势"
            )
            .frame(maxWidth: .infinity)

            if let components = stressScore?.components {
                VStack(spacing: 8) {
                    factorRow("HR 偏差", value: components.hrDeviationFactor)
                    factorRow("HRV 波动", value: components.inverseHRVFactor)
                    factorRow("活动负荷", value: components.activityLoadFactor)
                    factorRow("睡眠负债", value: components.sleepDebtFactor)
                }
            }
        }
    }

    private func factorRow(_ title: String, value: Double) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressView(value: value, total: 25)
                .frame(width: 120)
                .tint(stressScore?.level.displayColor ?? .gray)
            Text("\(Int(round(value)))")
                .font(.caption.monospacedDigit())
                .frame(width: 24, alignment: .trailing)
        }
    }
}
