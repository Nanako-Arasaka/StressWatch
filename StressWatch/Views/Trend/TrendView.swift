import SwiftUI

struct TrendView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: TrendViewModel
    @State private var contentVisible = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .appStaggeredCard(isVisible: contentVisible, delay: 0, reduceMotion: reduceMotion)

                    GlassCardView(cornerRadius: 30, padding: 18) {
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
                                    .animation(AppMotion.chartDrawing(reduceMotion: reduceMotion).delay(0.18), value: contentVisible)
                            }
                        }
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.08, reduceMotion: reduceMotion)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        LiquidMetricCard(
                            title: "恢复趋势",
                            value: "暂无历史",
                            subtitle: "当前未保存恢复历史",
                            color: AppColors.recoveryGreen,
                            systemImage: "heart.circle"
                        )

                        LiquidMetricCard(
                            title: "HRV 趋势",
                            value: "详情页查看",
                            subtitle: "从 Dashboard 进入 HRV",
                            color: AppColors.cyan,
                            systemImage: "waveform"
                        )
                    }
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.16, reduceMotion: reduceMotion)

                    scoreList
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.24, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
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
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: "每日摘要",
                    subtitle: "只用于个人健康趋势参考。",
                    systemImage: "list.bullet.rectangle"
                )

                if viewModel.stressHistory.isEmpty {
                    Text("暂无趋势数据")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
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
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var pageBackground: some View {
        ZStack {
            AppColors.backgroundGradient(for: colorScheme)

            Circle()
                .fill(AppColors.backgroundGlowPrimary(for: colorScheme))
                .frame(width: 260, height: 260)
                .blur(radius: 58)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppColors.backgroundGlowSecondary(for: colorScheme))
                .frame(width: 300, height: 300)
                .blur(radius: 72)
                .offset(x: 140, y: -80)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func loadHistory() async {
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            contentVisible = true
        }
        await viewModel.loadHistory(days: 7)
    }
}
