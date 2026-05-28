import SwiftUI

struct DashboardAnalysisEntryCard: View {
    let recentMetrics: [HealthMetric]
    let stressScore: StressScore?
    let recoveryScore: RecoveryScore?
    let stressTrend: [Double]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink {
            AnalysisView(
                metrics: recentMetrics,
                stressScore: stressScore,
                recoveryScore: recoveryScore,
                stressTrend: stressTrend
            )
        } label: {
            GlassCardView(cornerRadius: 28, padding: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.chartPrimary)
                        .frame(width: 42, height: 42)
                        .background(AppColors.chartPrimary.opacity(colorScheme == .dark ? 0.18 : 0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Insight / Analysis")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))

                        Text("基于最近 7 天健康特征生成趋势参考和生活方式建议")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
