import SwiftUI

// DashboardMetricCardView 负责展示单个健康指标卡片。
// 数据已经由 ViewModel 整理好，卡片本身不做 HealthKit 读取。
struct DashboardMetricCardView: View {
    let metric: DashboardMetric
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isStressCard: Bool {
        metric.id == "stress"
    }

    var body: some View {
        GlassCardView(cornerRadius: 28, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(metric.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(metric.value)
                                .font(.system(size: metric.value.count > 5 ? 28 : 38, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                                .monospacedDigit()
                                .minimumScaleFactor(0.72)
                                .appNumericChange(value: metric.value, reduceMotion: reduceMotion)

                            if !metric.unit.isEmpty {
                                Text(metric.unit)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: metric.systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(metric.color)
                        .frame(width: 34, height: 34)
                        .background(metric.color.opacity(0.15), in: Circle())
                }

                DashboardSparklineView(values: metric.trendValues, color: metric.color)

                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(metric.color)

                    Text(metric.subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(metric.source.tint)
                        .frame(width: 6, height: 6)

                    Text(metric.source.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }
                .padding(.top, 2)
            }
        }
        .background {
            if isStressCard {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.stressCardTint(for: colorScheme)[0],
                                AppColors.stressCardTint(for: colorScheme)[1]
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppColors.stressShadow(for: colorScheme), radius: 18, x: 0, y: 10)
            }
        }
    }
}
