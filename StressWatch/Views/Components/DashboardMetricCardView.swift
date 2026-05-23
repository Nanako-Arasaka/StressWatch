import SwiftUI

// DashboardMetricCardView 负责展示单个健康指标卡片。
// 数据已经由 ViewModel 整理好，卡片本身不做 HealthKit 读取。
struct DashboardMetricCardView: View {
    let metric: DashboardMetric

    private var isStressCard: Bool {
        metric.id == "stress"
    }

    var body: some View {
        GlassCardView(cornerRadius: 28, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(metric.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(metric.value)
                                .font(.system(size: metric.value.count > 5 ? 26 : 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                                .minimumScaleFactor(0.72)

                            if !metric.unit.isEmpty {
                                Text(metric.unit)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.secondary)
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(metric.color)

                    Text(metric.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(metric.source.tint)
                        .frame(width: 6, height: 6)

                    Text(metric.source.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
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
                                Color(red: 1.00, green: 0.83, blue: 0.35).opacity(0.20),
                                Color(red: 1.00, green: 0.93, blue: 0.68).opacity(0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.80, green: 0.54, blue: 0.12).opacity(0.13), radius: 18, x: 0, y: 10)
            }
        }
    }
}
