import SwiftUI

struct DashboardHeroSection: View {
    let metrics: [DashboardMetric]
    let dataSourceLabel: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日状态")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))

                        Text("个人健康趋势参考")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    }

                    Spacer()

                    DataSourceBadge(source: dataSourceLabel)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    ForEach(metrics) { metric in
                        heroMetricCard(metric)
                    }
                }
            }
        }
    }

    private func heroMetricCard(_ metric: DashboardMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: metric.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(metric.color)
                    .frame(width: 36, height: 36)
                    .background(metric.color.opacity(0.14), in: Circle())

                Spacer()

                Text(metric.status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(metric.color)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primaryText(for: colorScheme))
                    .monospacedDigit()
                    .minimumScaleFactor(0.74)
                    .appNumericChange(value: metric.value, reduceMotion: reduceMotion)

                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }
            }

            Text(metric.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            DashboardSparklineView(values: metric.trendValues, color: metric.color)
                .frame(height: 32)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
        .background(
            LinearGradient(
                colors: metric.id == "stress" ? AppColors.stressCardTint(for: colorScheme) : [
                    AppColors.recoveryBlue.opacity(colorScheme == .dark ? 0.18 : 0.13),
                    AppColors.softBlue.opacity(colorScheme == .dark ? 0.10 : 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(AppColors.glassStroke(for: colorScheme).opacity(0.70), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
    }

}
