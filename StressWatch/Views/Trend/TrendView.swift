import SwiftUI

struct TrendView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: TrendViewModel
    @State private var contentVisible = false

    // MARK: - Init

    init(viewModel: TrendViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassSectionHeader(
                        title: "趋势",
                        subtitle: "Recent wellness trend references",
                        systemImage: "chart.xyaxis.line"
                    )
                    .staggeredTrend(isVisible: contentVisible, delay: 0)

                    GlassCardView {
                        VStack(alignment: .leading, spacing: 12) {
                            GlassSectionHeader(
                                title: "7 天压力趋势",
                                subtitle: "每日趋势参考，数据来自本地缓存。",
                                systemImage: "waveform.path.ecg"
                            )

                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            } else {
                                TrendChart(scores: viewModel.stressHistory)
                                    .frame(height: 220)
                                    .opacity(contentVisible ? 1 : 0)
                                    .animation(.easeOut(duration: 0.35).delay(0.18), value: contentVisible)
                            }
                        }
                    }
                    .staggeredTrend(isVisible: contentVisible, delay: 0.08)

                    VStack(spacing: 12) {
                        LiquidMetricCard(
                            title: "恢复趋势",
                            value: "暂无历史",
                            subtitle: "当前未保存恢复历史",
                            color: .green,
                            systemImage: "heart.circle"
                        )

                        LiquidMetricCard(
                            title: "HRV 趋势",
                            value: "详情页查看",
                            subtitle: "从 Dashboard 进入 HRV",
                            color: .blue,
                            systemImage: "waveform"
                        )
                    }
                    .staggeredTrend(isVisible: contentVisible, delay: 0.16)

                    scoreList
                        .staggeredTrend(isVisible: contentVisible, delay: 0.24)
                }
                .padding()
            }
            .background(pageBackground)
            .navigationTitle("趋势")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.loadHistory(days: 7)
            }
            .task {
                await loadHistory()
            }
        }
    }

    // MARK: - Sections

    private var scoreList: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: "每日摘要",
                    subtitle: "只用于个人健康趋势参考。",
                    systemImage: "list.bullet.rectangle"
                )

                if viewModel.stressHistory.isEmpty {
                    Text("暂无趋势数据")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(viewModel.stressHistory) { score in
                        HStack {
                            Text(score.date, format: .dateTime.month().day())
                            Spacer()
                            Text("\(score.value)")
                                .monospacedDigit()
                                .fontWeight(.semibold)
                            Text(score.level.displayName)
                                .foregroundStyle(score.level.displayColor)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground),
                Color.orange.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func loadHistory() async {
        withAnimation(.easeOut(duration: 0.35)) {
            contentVisible = true
        }
        await viewModel.loadHistory(days: 7)
    }
}

// MARK: - Animation Helpers

private extension View {
    func staggeredTrend(isVisible: Bool, delay: Double) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
    }
}
