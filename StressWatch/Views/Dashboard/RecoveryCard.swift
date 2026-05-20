import SwiftUI

struct RecoveryCard: View {
    let recoveryScore: RecoveryScore?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader(
                title: "恢复趋势参考",
                subtitle: "结合 HRV、静息心率和睡眠的恢复趋势",
                systemImage: "heart.circle.fill"
            )

            AnimatedScoreRing(
                value: recoveryScore?.value ?? 0,
                levelName: recoveryScore?.level.displayName ?? "暂无数据",
                color: recoveryScore?.level.displayColor ?? .gray,
                title: "恢复趋势"
            )
            .frame(maxWidth: .infinity)
        }
    }
}
