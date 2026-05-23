import SwiftUI

struct DashboardView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: DashboardViewModel
    @State private var cardsVisible = false

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

                    if viewModel.isLoading {
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
                    .staggeredCard(isVisible: cardsVisible, delay: 0.42)
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
                }
                .accessibilityLabel("刷新")
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await loadInitialData()
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
                        .foregroundStyle(.primary)

                    Text("Apple Watch wellness trends")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                DataSourceBadge(source: viewModel.dataSourceLabel)

                Text("Local-first")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text("Search wellness trends")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            }
        }
        .staggeredCard(isVisible: cardsVisible, delay: 0)
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.snapshot.metrics) { metric in
                    metricCard(metric)
                }
            }
            .staggeredCard(isVisible: cardsVisible, delay: 0.08)

            GlassCardView(cornerRadius: 30, padding: 18) {
                DashboardTrendChartView(
                    title: "7-day Stress Trend",
                    subtitle: "压力分数仅用于个人健康趋势参考",
                    values: viewModel.snapshot.stressTrend,
                    color: Color(red: 0.78, green: 0.52, blue: 0.14),
                    yRange: 0...100
                )
            }
            .staggeredCard(isVisible: cardsVisible, delay: 0.18)

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
            .staggeredCard(isVisible: cardsVisible, delay: 0.34)
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
                .buttonStyle(.plain)
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
                    color: Color(red: 0.05, green: 0.58, blue: 0.68),
                    yRange: 0...(max((viewModel.snapshot.hrvTrend.max() ?? 80), 80))
                )
            }

            GlassCardView(cornerRadius: 28, padding: 18) {
                DashboardTrendChartView(
                    title: "Heart Rate Detail",
                    subtitle: "最近心率读取和日间趋势参考",
                    values: viewModel.snapshot.heartRateTrend,
                    color: Color(red: 0.12, green: 0.56, blue: 0.50),
                    yRange: 40...(max((viewModel.snapshot.heartRateTrend.max() ?? 120), 120))
                )
            }
        }
        .staggeredCard(isVisible: cardsVisible, delay: 0.26)
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
                    activityStat(title: "Active Energy", value: viewModel.snapshot.activityEnergyToday)
                    activityStat(title: "Exercise", value: viewModel.snapshot.activityExerciseToday)
                }
            }
        }
        .staggeredCard(isVisible: cardsVisible, delay: 0.30)
    }

    private var sleepStages: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep stages")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            if viewModel.snapshot.sleepStages.isEmpty {
                Text("暂无分阶段数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.snapshot.sleepStages) { stage in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 10, height: 10)

                        Text(stage.title)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(formatHours(stage.hours))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private func activityStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(red: 0.14, green: 0.63, blue: 0.54).opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func activityBars(values: [Double]) -> some View {
        let maxValue = max(values.max() ?? 1, 1)

        return HStack(alignment: .bottom, spacing: 8) {
            if values.isEmpty {
                Text("暂无活动趋势数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ForEach(values.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.14, green: 0.63, blue: 0.54),
                                    Color(red: 0.62, green: 0.91, blue: 0.80)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(12, CGFloat(values[index] / maxValue) * 72))
                        .frame(maxWidth: .infinity)
                        .opacity(index == values.count - 1 ? 1 : 0.72)
                }
            }
        }
        .frame(height: 82)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(red: 0.14, green: 0.63, blue: 0.54).opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var loadingCard: some View {
        GlassCardView {
            ProgressView("正在加载趋势参考数据")
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .staggeredCard(isVisible: cardsVisible, delay: 0.05)
    }

    private var disclaimer: some View {
        Text("本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func emptyState(_ message: String) -> some View {
        GlassCardView {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .staggeredCard(isVisible: cardsVisible, delay: 0.05)
    }

    private var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 1.00, blue: 0.96),
                    Color(red: 0.78, green: 0.96, blue: 0.90),
                    Color(red: 0.91, green: 0.99, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.62, green: 0.91, blue: 0.80).opacity(0.42))
                .frame(width: 260, height: 260)
                .blur(radius: 58)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color(red: 0.55, green: 0.90, blue: 0.94).opacity(0.30))
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

    private func loadInitialData() async {
        withAnimation(.easeOut(duration: 0.35)) {
            cardsVisible = true
        }
        await viewModel.refresh()
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

    private func formatHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int(round((hours - Double(wholeHours)) * 60))
        return "\(wholeHours)h \(minutes)m"
    }
}

// MARK: - Animation Helpers

private extension View {
    func staggeredCard(isVisible: Bool, delay: Double) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
    }
}
