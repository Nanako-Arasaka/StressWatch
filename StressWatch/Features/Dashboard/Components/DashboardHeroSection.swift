import SwiftUI

struct DashboardHeroSection: View {
    let metrics: [DashboardMetric]
    let dataSourceLabel: String

    @State private var heroGlowBreathing = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassCardView(cornerRadius: 34, padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's balance")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))

                        Text("个人健康趋势参考")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    }

                    Spacer()

                    DataSourceBadge(source: dataSourceLabel)
                }

                heroLogo

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    ForEach(metrics) { metric in
                        heroMetricCard(metric)
                    }
                }
            }
        }
    }

    private var heroLogo: some View {
        ZStack {
            Circle()
                .fill(AppColors.mint.opacity(colorScheme == .dark ? 0.12 : 0.28))
                .frame(width: 180, height: 180)
                .blur(radius: 42)
                .scaleEffect(heroGlowBreathing ? 1.06 : 0.98)
                .opacity(heroGlowBreathing ? 0.92 : 0.72)

            Circle()
                .stroke(AppColors.glassStroke(for: colorScheme), lineWidth: 0.7)
                .frame(width: 132, height: 132)
                .opacity(0.28)

            Image("StressWatchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: AppColors.mint.opacity(colorScheme == .dark ? 0.14 : 0.20), radius: 20, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 118)
        .onAppear(perform: startHeroGlow)
    }

    private func heroMetricCard(_ metric: DashboardMetric) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    .font(.system(size: 54, weight: .bold, design: .rounded))
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
                .frame(height: 40)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 192, alignment: .leading)
        .background(
            LinearGradient(
                colors: metric.id == "stress" ? AppColors.stressCardTint(for: colorScheme) : [
                    AppColors.recoveryGreen.opacity(colorScheme == .dark ? 0.18 : 0.13),
                    AppColors.mint.opacity(colorScheme == .dark ? 0.10 : 0.16)
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

    private func startHeroGlow() {
        guard !reduceMotion else {
            heroGlowBreathing = true
            return
        }

        withAnimation(AppMotion.ambientBreathing(reduceMotion: reduceMotion)) {
            heroGlowBreathing = true
        }
    }
}
