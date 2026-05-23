import SwiftUI

struct DashboardView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: DashboardViewModel
    @State private var cardsVisible = false
    @State private var activityBarsVisible = false
    @State private var refreshIconRotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.adaptive(minimum: 155), spacing: 14)
    ]

    // MARK: - Init

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

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
                .padding(.bottom, 28)
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
                await loadInitialData()
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                animateRefreshIcon(isLoading: isLoading)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("StressWatch")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))

                    Text("Apple Watch wellness trends")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                DataSourceBadge(source: viewModel.dataSourceLabel)

                Text("Local-first")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }

        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0, reduceMotion: reduceMotion)
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.snapshot.metrics) { metric in
                    metricCard(metric)
                }
            }
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.08, reduceMotion: reduceMotion)

            GlassCardView(cornerRadius: 30, padding: 18) {
                DashboardTrendChartView(
                    title: "7-day Stress Trend",
                    subtitle: "压力分数仅用于个人健康趋势参考",
                    values: viewModel.snapshot.stressTrend,
                    color: AppColors.stressAmber,
                    yRange: 0...100
                )
            }
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.18, reduceMotion: reduceMotion)

            detailGrid

            activityContext

            GlassCardView(cornerRadius: 28, padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    GlassSectionHeader(
                        title: "Today's insight",
                        subtitle: viewModel.snapshot.insight,
                        systemImage: "sparkles"
                    )
                }
            }
            .appStaggeredCard(isVisible: cardsVisible, delay: 0.34, reduceMotion: reduceMotion)
        }
    }

    private func metricCard(_ metric: DashboardMetric) -> some View {
        Group {
            if let metricType = destinationMetricType(for: metric.id) {
                NavigationLink {
                    MetricDetailView(
                        metricType: metricType,
                        metrics: viewModel.recentMetrics.filter { $0.type == metricType }
                    )
                } label: {
                    metricCardContent(metric)
                }
                .buttonStyle(PressScaleButtonStyle())
            } else {
                metricCardContent(metric)
            }
        }
    }

    private func metricCardContent(_ metric: DashboardMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardMetricCardView(metric: metric)

            if metric.id == "sleep" {
                GlassCardView(cornerRadius: 22, padding: 14) {
                    sleepStages
                }
            }
        }
    }

    private var detailGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
            GlassCardView(cornerRadius: 28, padding: 18) {
                DashboardTrendChartView(
                    title: "HRV / Baseline",
                    subtitle: "近期 HRV 波动趋势参考",
                    values: viewModel.snapshot.hrvTrend,
                    color: AppColors.cyan,
                    yRange: 0...(max((viewModel.snapshot.hrvTrend.max() ?? 80), 80))
                )
            }

            GlassCardView(cornerRadius: 28, padding: 18) {
                DashboardTrendChartView(
                    title: "Heart Rate Detail",
                    subtitle: "最近心率读取和日间趋势参考",
                    values: viewModel.snapshot.heartRateTrend,
                    color: AppColors.teal,
                    yRange: 40...(max((viewModel.snapshot.heartRateTrend.max() ?? 120), 120))
                )
            }
        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0.26, reduceMotion: reduceMotion)
    }

    private var activityContext: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    GlassSectionHeader(
                        title: "Activity Context",
                        subtitle: "最近 7 天活动能量趋势参考",
                        systemImage: "flame"
                    )

                    Spacer()

                    sourceBadge(viewModel.snapshot.activitySource)
                }

                activityBars(values: viewModel.snapshot.activityEnergyTrend)

                HStack(spacing: 12) {
                    activityStat(
                        title: "Move",
                        value: viewModel.snapshot.activityEnergyToday,
                        goal: viewModel.snapshot.activityEnergyGoal
                    )
                    activityStat(
                        title: "Exercise",
                        value: viewModel.snapshot.activityExerciseToday,
                        goal: viewModel.snapshot.activityExerciseGoal
                    )
                    activityStat(
                        title: "Stand",
                        value: viewModel.snapshot.activityStandToday,
                        goal: viewModel.snapshot.activityStandGoal
                    )
                }
            }
        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0.30, reduceMotion: reduceMotion)
    }

    private var sleepStages: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep stages")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))

            if viewModel.snapshot.sleepStages.isEmpty {
                Text("暂无分阶段数据")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
            } else {
                ForEach(viewModel.snapshot.sleepStages) { stage in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 10, height: 10)

                        Text(stage.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))

                        Spacer()

                        Text(formatHours(stage.hours))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(stage.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(.top, 6)
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
                                colors: [
                                    AppColors.teal,
                                    AppColors.mint
                                ],
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
        .onAppear {
            startActivityBarAnimation()
        }
        .onChange(of: values) { _ in
            startActivityBarAnimation()
        }
    }

    private var loadingCard: some View {
        GlassCardView {
            ProgressView("正在加载趋势参考数据")
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .appStaggeredCard(isVisible: cardsVisible, delay: 0.05, reduceMotion: reduceMotion)
    }

    private var disclaimer: some View {
        Text("本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。")
            .font(.footnote)
            .foregroundStyle(AppColors.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
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
    }

    // MARK: - Actions

    private func refreshData() {
        Task {
            await viewModel.refresh()
        }
    }

    @MainActor
    private func loadInitialData() async {
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            cardsVisible = true
        }
        await viewModel.refresh()
        await restartEntranceAnimation()
    }

    private func animateRefreshIcon(isLoading: Bool) {
        guard isLoading, !reduceMotion else {
            return
        }

        refreshIconRotation += 360
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

    @MainActor
    private func restartEntranceAnimation() async {
        if reduceMotion {
            cardsVisible = true
            return
        }

        cardsVisible = false
        try? await Task.sleep(nanoseconds: 30_000_000)
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            cardsVisible = true
        }
    }

    private func destinationMetricType(for id: String) -> MetricType? {
        switch id {
        case "hrv":
            return .hrv
        case "heartRate":
            return .heartRate
        case "sleep":
            return .sleep
        case "steps":
            return .steps
        case "activity":
            return .activeEnergyBurned
        default:
            return nil
        }
    }

}
