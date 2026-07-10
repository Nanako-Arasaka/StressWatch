import SwiftUI

struct MetricDetailView: View {
    // MARK: - Properties

    let metricType: MetricType
    let metrics: [HealthMetric]

    @State private var contentVisible = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch metricType {
        case .heartRate:
            return "HR"
        case .hrv:
            return "HRV"
        case .restingHeartRate:
            return "静息 HR"
        case .steps:
            return "步数"
        case .sleep:
            return "睡眠"
        case .activeEnergyBurned:
            return "活动能量"
        case .appleExerciseTime:
            return "锻炼时间"
        case .appleStandTime:
            return "站立时间"
        case .sleepREM:
            return "REM"
        case .sleepCore:
            return "Core 睡眠"
        case .sleepDeep:
            return "Deep 睡眠"
        case .sleepAwake:
            return "清醒"
        }
    }

    private var iconName: String {
        switch metricType {
        case .heartRate:
            return "heart"
        case .hrv:
            return "waveform"
        case .restingHeartRate:
            return "heart.circle"
        case .steps:
            return "figure.walk"
        case .sleep:
            return "moon"
        case .activeEnergyBurned:
            return "flame"
        case .appleExerciseTime:
            return "figure.run"
        case .appleStandTime:
            return "figure.stand"
        case .sleepREM, .sleepCore, .sleepDeep:
            return "bed.double"
        case .sleepAwake:
            return "sun.max"
        }
    }

    private var explanation: String {
        switch metricType {
        case .heartRate:
            return "心率可用于观察日内活动和恢复状态相关波动。"
        case .hrv:
            return "HRV 可作为恢复趋势的参考指标之一。"
        case .restingHeartRate:
            return "静息心率可辅助观察长期恢复和负荷变化。"
        case .steps:
            return "步数用于描述每日活动负荷变化。"
        case .sleep:
            return "睡眠时长用于观察恢复趋势参考。"
        case .activeEnergyBurned:
            return "活动能量用于描述每日活动负荷变化。"
        case .appleExerciseTime:
            return "锻炼时间用于辅助观察每日活动强度。"
        case .appleStandTime:
            return "站立时间用于辅助观察每日活动节律。"
        case .sleepREM:
            return "REM 睡眠用于展示睡眠分阶段参考。"
        case .sleepCore:
            return "Core 睡眠用于展示睡眠分阶段参考。"
        case .sleepDeep:
            return "Deep 睡眠用于展示睡眠分阶段参考。"
        case .sleepAwake:
            return "清醒时间用于辅助理解夜间睡眠连续性。"
        }
    }

    private var influenceText: String {
        switch metricType {
        case .heartRate:
            return "当心率明显高于个人基线时，压力趋势参考可能上升。"
        case .hrv:
            return "当 HRV 低于个人基线时，恢复趋势参考可能下降。"
        case .restingHeartRate:
            return "静息心率偏高可能让恢复趋势参考更保守。"
        case .steps:
            return "活动量偏离个人基线时，会影响活动负荷因子。"
        case .sleep:
            return "睡眠时长偏低会影响睡眠负债因子和恢复趋势参考。"
        case .activeEnergyBurned:
            return "活动能量偏离个人基线时，可辅助理解活动负荷变化。"
        case .appleExerciseTime:
            return "锻炼时间变化可作为活动负荷趋势参考。"
        case .appleStandTime:
            return "站立时间变化可作为活动节律趋势参考。"
        case .sleepREM, .sleepCore, .sleepDeep:
            return "睡眠阶段变化可辅助观察恢复趋势参考。"
        case .sleepAwake:
            return "夜间清醒时间偏多时，可作为睡眠连续性参考。"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassSectionHeader(
                    title: title,
                    subtitle: "Recent 7-day trend reference",
                    systemImage: iconName
                )
                .staggeredDetail(isVisible: contentVisible, delay: 0, reduceMotion: reduceMotion)

                GlassCardView {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassSectionHeader(
                            title: "最近 7 天图表",
                            subtitle: "用于观察该指标的近期波动。",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )

                        MetricChart(metrics: metrics)
                            .frame(height: 300)
                            .opacity(contentVisible ? 1 : 0)
                            .animation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0.16), value: contentVisible)
                    }
                }
                .staggeredDetail(isVisible: contentVisible, delay: 0.08, reduceMotion: reduceMotion)

                GlassCardView {
                    VStack(alignment: .leading, spacing: 12) {
                        GlassSectionHeader(
                            title: "指标解释",
                            subtitle: explanation,
                            systemImage: "info.circle"
                        )

                        Text(influenceText)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .staggeredDetail(isVisible: contentVisible, delay: 0.16, reduceMotion: reduceMotion)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(pageBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            showContent()
        }
    }

    // MARK: - Styling

    private var pageBackground: some View {
        ZStack {
            AppColors.backgroundGradient(for: colorScheme)

            Circle()
                .fill(AppColors.backgroundGlowPrimary(for: colorScheme))
                .frame(width: 260, height: 260)
                .blur(radius: 34)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppColors.backgroundGlowSecondary(for: colorScheme))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 140, y: -80)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func showContent() {
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            contentVisible = true
        }
    }
}

// MARK: - Animation Helpers

private extension View {
    func staggeredDetail(isVisible: Bool, delay: Double, reduceMotion: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : AppMotion.cardEntranceOffset)
            .animation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: delay), value: isVisible)
    }
}
