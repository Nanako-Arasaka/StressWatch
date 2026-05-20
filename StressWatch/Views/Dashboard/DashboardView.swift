import SwiftUI

struct DashboardView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: DashboardViewModel
    @State private var cardsVisible = false

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
                        GlassCardView {
                            ProgressView("正在加载趋势参考数据")
                                .frame(maxWidth: .infinity, minHeight: 140)
                        }
                        .staggeredCard(isVisible: cardsVisible, delay: 0.05)
                    } else if viewModel.needsMoreData {
                        emptyState("需要更多数据后才能生成状态")
                    } else if let errorMessage = viewModel.errorMessage {
                        emptyState(errorMessage)
                    } else {
                        NavigationLink {
                            MetricDetailView(
                                metricType: .heartRate,
                                metrics: viewModel.recentMetrics.filter { $0.type == .heartRate }
                            )
                        } label: {
                            GlassCardView {
                                StressGaugeCard(stressScore: viewModel.stressScore)
                            }
                            .staggeredCard(isVisible: cardsVisible, delay: 0.05)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MetricDetailView(
                                metricType: .hrv,
                                metrics: viewModel.recentMetrics.filter { $0.type == .hrv }
                            )
                        } label: {
                            GlassCardView {
                                RecoveryCard(recoveryScore: viewModel.recoveryScore)
                            }
                            .staggeredCard(isVisible: cardsVisible, delay: 0.12)
                        }
                        .buttonStyle(.plain)

                        GlassCardView {
                            VStack(alignment: .leading, spacing: 14) {
                                GlassSectionHeader(
                                    title: "今日 HR / HRV",
                                    subtitle: "Apple Watch 日内波动趋势参考",
                                    systemImage: "chart.xyaxis.line"
                                )

                                TodayMiniChart(metrics: viewModel.todayHR + viewModel.todayHRV)
                                    .frame(height: 180)
                                    .opacity(cardsVisible ? 1 : 0)
                                    .animation(.easeOut(duration: 0.35).delay(0.22), value: cardsVisible)

                                HStack {
                                    NavigationLink("查看 HR 趋势参考") {
                                        MetricDetailView(
                                            metricType: .heartRate,
                                            metrics: viewModel.recentMetrics.filter { $0.type == .heartRate }
                                        )
                                    }

                                    Spacer()

                                    NavigationLink("查看 HRV 趋势参考") {
                                        MetricDetailView(
                                            metricType: .hrv,
                                            metrics: viewModel.recentMetrics.filter { $0.type == .hrv }
                                        )
                                    }
                                }
                                .font(.footnote.weight(.semibold))
                            }
                        }
                        .staggeredCard(isVisible: cardsVisible, delay: 0.19)

                        GlassCardView {
                            VStack(alignment: .leading, spacing: 8) {
                                GlassSectionHeader(
                                    title: "今日状态解释",
                                    subtitle: "分数仅用于趋势参考。请结合近期睡眠、活动和主观感受一起观察。",
                                    systemImage: "sparkles"
                                )
                            }
                        }
                        .staggeredCard(isVisible: cardsVisible, delay: 0.26)
                    }

                    GlassCardView(cornerRadius: 20, padding: 14) {
                        disclaimer
                    }
                    .staggeredCard(isVisible: cardsVisible, delay: 0.33)
                }
                .padding()
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
        VStack(alignment: .leading, spacing: 6) {
            Text("StressWatch")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)

            Text("Apple Watch wellness trends")
                .font(.headline)
                .foregroundStyle(.secondary)

            DataSourceBadge(source: viewModel.dataSourceLabel)
                .padding(.top, 6)
        }
        .staggeredCard(isVisible: cardsVisible, delay: 0)
    }

    private var disclaimer: some View {
        Text("本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急用途。如有健康问题，请咨询专业人士。")
            .font(.footnote)
            .foregroundStyle(.secondary)
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
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground),
                Color.blue.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
}

// MARK: - Animation Helpers

private extension View {
    func staggeredCard(isVisible: Bool, delay: Double) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
    }
}
