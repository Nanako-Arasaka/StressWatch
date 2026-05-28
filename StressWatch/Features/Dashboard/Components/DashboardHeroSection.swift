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
                .fill(AppColors.heroGlow(for: colorScheme)[0])
                .frame(width: 164, height: 164)
                .blur(radius: 26)
                .scaleEffect(heroGlowBreathing ? 1.02 : 0.98)
                .opacity(heroGlowBreathing ? 0.72 : 0.58)

            Circle()
                .fill(AppColors.heroGlow(for: colorScheme)[1])
                .frame(width: 118, height: 118)
                .blur(radius: 22)
                .offset(x: 28, y: 18)
                .opacity(0.74)

            Circle()
                .stroke(AppColors.glassStroke(for: colorScheme), lineWidth: 0.7)
                .frame(width: 132, height: 132)
                .opacity(0.28)

            Image("StressWatchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: AppColors.softBlue.opacity(colorScheme == .dark ? 0.10 : 0.14), radius: 8, x: 0, y: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 118)
        .onAppear(perform: startHeroGlow)
        .onDisappear {
            heroGlowBreathing = false
        }
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

    private func startHeroGlow() {
        guard !reduceMotion else {
            heroGlowBreathing = false
            return
        }

        withAnimation(AppMotion.ambientBreathing(reduceMotion: reduceMotion)) {
            heroGlowBreathing = true
        }
    }
}
