import SwiftUI

struct MetricDetailView: View {
    // MARK: - Properties

    let metricType: MetricType
    let metrics: [HealthMetric]

    @State private var contentVisible = false

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
                .staggeredDetail(isVisible: contentVisible, delay: 0)

                GlassCardView {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassSectionHeader(
                            title: "最近 7 天图表",
                            subtitle: "用于观察该指标的近期波动。",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )

                        MetricChart(metrics: metrics)
                            .frame(height: 240)
                            .opacity(contentVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.35).delay(0.16), value: contentVisible)
                    }
                }
                .staggeredDetail(isVisible: contentVisible, delay: 0.08)

                GlassCardView {
                    VStack(alignment: .leading, spacing: 12) {
                        GlassSectionHeader(
                            title: "指标解释",
                            subtitle: explanation,
                            systemImage: "info.circle"
                        )

                        Text(influenceText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .staggeredDetail(isVisible: contentVisible, delay: 0.16)
            }
            .padding()
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
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground),
                Color.purple.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func showContent() {
        withAnimation(.easeOut(duration: 0.35)) {
            contentVisible = true
        }
    }
}

// MARK: - Animation Helpers

private extension View {
    func staggeredDetail(isVisible: Bool, delay: Double) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
    }
}
