import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel

    @State private var cardsVisible = false
    @State private var refreshIconRotation: Double = 0
    @State private var showStartupLogo = true
    @State private var hasLoadedInitialData = false
    @State private var onAppearCount = 0
    @Binding private var shouldOpenAnalysis: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: DashboardViewModel, shouldOpenAnalysis: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._shouldOpenAnalysis = shouldOpenAnalysis
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if viewModel.isLoading && viewModel.snapshot.metrics.isEmpty {
                        loadingCard
                    } else if viewModel.needsMoreData {
                        emptyState("需要更多趋势参考数据")
                    } else if let errorMessage = viewModel.errorMessage {
                        emptyState(errorMessage)
                    } else {
                        dashboardContent
                    }

                    GlassCardView(cornerRadius: 22, padding: 14) {
                        disclaimer
                    }
                    .appStaggeredCard(isVisible: cardsVisible, delay: 0.42, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .background(pageBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(refreshIconRotation))
                        .animation(AppMotion.chartDrawing(reduceMotion: reduceMotion), value: refreshIconRotation)
                }
                .accessibilityLabel("刷新")
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                Task {
                    await dismissStartupLogo()
                }
                await loadInitialData()
            }
            .onAppear {
                onAppearCount += 1
                print("[DashboardView] onAppear count=\(onAppearCount)")
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                animateRefreshIcon(isLoading: isLoading)
            }
            .overlay {
                startupLogoOverlay
            }
            .navigationDestination(isPresented: $shouldOpenAnalysis) {
                AnalysisView(
                    metrics: viewModel.recentMetrics,
                    stressScore: viewModel.stressScore,
                    recoveryScore: viewModel.recoveryScore,
                    stressTrend: viewModel.snapshot.stressTrend,
                    storage: viewModel.localStorage
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("StressWatch")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))

                    Text("Apple Watch wellness trends")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }

                Spacer()
            }
        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0, reduceMotion: reduceMotion)
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            DashboardHeroSection(
                metrics: primaryMetrics,
                dataSourceLabel: viewModel.dataSourceLabel
            )
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.08, reduceMotion: reduceMotion)

            LiveStressCard(snapshot: viewModel.snapshot.liveStress)
                .appStaggeredCard(isVisible: cardsVisible, delay: 0.10, reduceMotion: reduceMotion)

            DashboardAnalysisEntryCard(
                recentMetrics: viewModel.recentMetrics,
                stressScore: viewModel.stressScore,
                recoveryScore: viewModel.recoveryScore,
                stressTrend: viewModel.snapshot.stressTrend,
                storage: viewModel.localStorage
            )
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.12, reduceMotion: reduceMotion)

            DashboardKeySignalsSection(
                metrics: auxiliaryMetrics,
                recentMetrics: viewModel.recentMetrics
            )
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.16, reduceMotion: reduceMotion)

            GlassCardView(cornerRadius: 30, padding: 18) {
                DashboardTrendChartView(
                    title: "7-day Stress Trend",
                    subtitle: "压力分数仅用于个人健康趋势参考",
                    values: viewModel.snapshot.stressTrend,
                    color: AppColors.stressWarm,
                    yRange: 0...100
                )
            }
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.20, reduceMotion: reduceMotion)

            DashboardDetailGridSection(
                metrics: detailMetrics,
                recentMetrics: viewModel.recentMetrics,
                hrvTrend: viewModel.snapshot.hrvTrend,
                heartRateTrend: viewModel.snapshot.heartRateTrend
            )
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.26, reduceMotion: reduceMotion)

            DashboardSleepStagesSection(stages: viewModel.snapshot.sleepStages)
                .appStaggeredCard(isVisible: cardsVisible, delay: 0.30, reduceMotion: reduceMotion)

            DashboardActivityContextSection(snapshot: viewModel.snapshot)
                .appStaggeredCard(isVisible: cardsVisible, delay: 0.30, reduceMotion: reduceMotion)

            todayInsight
                .appStaggeredCard(isVisible: cardsVisible, delay: 0.38, reduceMotion: reduceMotion)
        }
    }

    private var primaryMetrics: [DashboardMetric] {
        metrics(withIDs: ["stress", "recovery"])
    }

    private var auxiliaryMetrics: [DashboardMetric] {
        metrics(withIDs: ["hrv", "sleep", "steps", "activity"])
    }

    private var detailMetrics: [DashboardMetric] {
        metrics(withIDs: ["heartRate"])
    }

    private var todayInsight: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: "Today's insight",
                    subtitle: viewModel.snapshot.wellnessInsight?.predictedState ?? "个人健康趋势参考",
                    systemImage: "sparkles"
                )

                if let insight = viewModel.snapshot.wellnessInsight {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                        dashboardInsightTile(title: "Pressure", value: insight.stressAssessment)
                        dashboardInsightTile(title: "Sleep", value: insight.sleepAssessment)
                        dashboardInsightTile(title: "Recovery", value: insight.recoveryAssessment)
                    }

                    Text(insight.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(viewModel.snapshot.insight)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func dashboardInsightTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.subtleTealFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loadingCard: some View {
        GlassCardView {
            ProgressView("正在加载趋势参考数据")
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0.05, reduceMotion: reduceMotion)
    }

    private var disclaimer: some View {
        Text("本应用仅用于个人健康趋势参考，不提供专业健康判断或紧急用途。如有健康问题，请咨询专业人士。")
            .font(.footnote)
            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var pageBackground: some View {
        ZStack {
            AppColors.backgroundGradient(for: colorScheme)

            Circle()
                .fill(AppColors.backgroundGlowPrimary(for: colorScheme))
                .frame(width: 220, height: 220)
                .blur(radius: 34)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppColors.backgroundGlowSecondary(for: colorScheme))
                .frame(width: 240, height: 240)
                .blur(radius: 40)
                .offset(x: 140, y: -80)
        }
        .ignoresSafeArea()
    }

    private var startupLogoOverlay: some View {
        Group {
            if showStartupLogo {
                ZStack {
                    AppColors.backgroundGradient(for: colorScheme)

                    VStack(spacing: 14) {
                        Image("StressWatchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)

                        Text("StressWatch")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))
                    }
                    .scaleEffect(reduceMotion ? 1 : 1.03)
                }
                .ignoresSafeArea()
                .transition(.opacity.combined(with: reduceMotion ? AnyTransition.identity : AnyTransition.scale(scale: 0.98)))
            }
        }
        .allowsHitTesting(false)
    }

    private func emptyState(_ message: String) -> some View {
        GlassCardView {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0.05, reduceMotion: reduceMotion)
    }

    private func metrics(withIDs ids: [String]) -> [DashboardMetric] {
        ids.compactMap { id in
            viewModel.snapshot.metrics.first { $0.id == id }
        }
    }

    private func refreshData() {
        print("[DashboardView] refresh button tapped")
        Task {
            await viewModel.refresh()
        }
    }

    @MainActor
    private func loadInitialData() async {
        guard !hasLoadedInitialData else {
            print("[DashboardView] initial load skipped")
            return
        }

        hasLoadedInitialData = true
        print("[DashboardView] initial load start")
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            cardsVisible = true
        }
        await viewModel.refresh()
        print("[DashboardView] initial load end")
    }

    private func animateRefreshIcon(isLoading: Bool) {
        guard isLoading, !reduceMotion else {
            return
        }

        refreshIconRotation += 360
    }

    @MainActor
    private func dismissStartupLogo() async {
        try? await Task.sleep(nanoseconds: 520_000_000)
        withAnimation(AppMotion.numericChange(reduceMotion: reduceMotion)) {
            showStartupLogo = false
        }
    }
}
