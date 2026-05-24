import SwiftUI

struct DashboardSleepStagesSection: View {
    let stages: [SleepStageSummary]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                GlassSectionHeader(
                    title: "Sleep stages",
                    subtitle: "REM / Core / Deep / Awake 阶段仅作睡眠趋势参考",
                    systemImage: "bed.double"
                )

                if stages.isEmpty {
                    Text("暂无分阶段数据")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                        ForEach(stages) { stage in
                            stageRow(stage)
                        }
                    }
                }
            }
        }
    }

    private func stageRow(_ stage: SleepStageSummary) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stage.color)
                .frame(width: 9, height: 9)

            Text(stage.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Spacer(minLength: 6)

            Text(formatHours(stage.hours))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(stage.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
