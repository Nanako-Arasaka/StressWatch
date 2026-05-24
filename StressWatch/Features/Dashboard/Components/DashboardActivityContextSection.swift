import SwiftUI

struct DashboardActivityContextSection: View {
    let snapshot: HealthDashboardSnapshot

    @State private var activityBarsVisible = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    GlassSectionHeader(
                        title: "Activity Context",
                        subtitle: "最近 7 天活动能量趋势参考",
                        systemImage: "flame"
                    )

                    Spacer()

                    sourceBadge(snapshot.activitySource)
                }

                activityBars(values: snapshot.activityEnergyTrend)

                HStack(spacing: 12) {
                    activityStat(title: "Move", value: snapshot.activityEnergyToday, goal: snapshot.activityEnergyGoal)
                    activityStat(title: "Exercise", value: snapshot.activityExerciseToday, goal: snapshot.activityExerciseGoal)
                    activityStat(title: "Stand", value: snapshot.activityStandToday, goal: snapshot.activityStandGoal)
                }
            }
        }
    }

    private func sourceBadge(_ source: DashboardMetricSource) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(source.tint)
                .frame(width: 6, height: 6)

            Text(source.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private func activityStat(title: String, value: String, goal: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.system(size: value.count > 7 ? 17 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .appNumericChange(value: value, reduceMotion: reduceMotion)

            Text("/ \(goal)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.subtleTealFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func activityBars(values: [Double]) -> some View {
        let maxValue = max(values.max() ?? 1, 1)

        return HStack(alignment: .bottom, spacing: 8) {
            if values.isEmpty {
                Text("暂无活动趋势数据")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ForEach(values.indices, id: \.self) { index in
                    let progress: CGFloat = activityBarsVisible || reduceMotion ? 1 : AppMotion.chartInitialProgress

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.teal, AppColors.mint],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(12, CGFloat(values[index] / maxValue) * 72) * progress)
                        .frame(maxWidth: .infinity)
                        .opacity(index == values.count - 1 ? 1 : 0.72)
                        .animation(AppMotion.barGrowth(reduceMotion: reduceMotion, delay: Double(index) * AppMotion.barStaggerDelay), value: activityBarsVisible)
                }
            }
        }
        .frame(height: 82)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear(perform: startActivityBarAnimation)
        .onChange(of: values) { _ in
            startActivityBarAnimation()
        }
    }

    private func startActivityBarAnimation() {
        if reduceMotion {
            activityBarsVisible = true
            return
        }

        activityBarsVisible = false
        withAnimation(AppMotion.barGrowth(reduceMotion: reduceMotion, delay: 0)) {
            activityBarsVisible = true
        }
    }
}
