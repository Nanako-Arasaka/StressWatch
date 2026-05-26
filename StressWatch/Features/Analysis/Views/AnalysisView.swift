import SwiftUI

struct AnalysisView: View {
    @StateObject private var viewModel: AnalysisViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentVisible = false

    init(
        metrics: [HealthMetric],
        stressScore: StressScore?,
        recoveryScore: RecoveryScore?,
        stressTrend: [Double]
    ) {
        _viewModel = StateObject(
            wrappedValue: AnalysisViewModel(
                metrics: metrics,
                stressScore: stressScore,
                recoveryScore: recoveryScore,
                stressTrend: stressTrend
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassSectionHeader(
                    title: "Insight / Analysis",
                    subtitle: "基于最近 7 天健康特征的状态趋势参考",
                    systemImage: "sparkles"
                )
                .appStaggeredCard(isVisible: contentVisible, delay: 0, reduceMotion: reduceMotion)

                statusCard
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.06, reduceMotion: reduceMotion)

                factorsCard
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.12, reduceMotion: reduceMotion)

                adviceCard
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.18, reduceMotion: reduceMotion)

                featuresCard
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.24, reduceMotion: reduceMotion)

                disclaimerCard
                    .appStaggeredCard(isVisible: contentVisible, delay: 0.30, reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 118)
        }
        .background(pageBackground)
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.refresh()
            withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
                contentVisible = true
            }
        }
    }

    private var statusCard: some View {
        GlassCardView(cornerRadius: 34, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.analysis.state.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(stateColor)

                        Text(viewModel.analysis.state.displayName)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))
                            .minimumScaleFactor(0.78)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("可信度")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText(for: colorScheme))

                        Text(viewModel.confidenceText)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(stateColor)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(stateColor.opacity(colorScheme == .dark ? 0.16 : 0.12), in: Capsule())
                }

                Text(viewModel.analysis.state.shortSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var factorsCard: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: "主要影响因素",
                    subtitle: "模型使用可解释规则筛选近期变化较明显的特征。",
                    systemImage: "slider.horizontal.3"
                )

                ForEach(viewModel.analysis.primaryFactors, id: \.self) { factor in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 7, height: 7)

                        Text(factor)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppColors.subtleTealFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var adviceCard: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: "趋势建议",
                    subtitle: "以下内容仅作为生活方式参考。",
                    systemImage: "leaf"
                )

                ForEach(Array(viewModel.advice.prefix(3).enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))
                            .frame(width: 24, height: 24)
                            .background(stateColor.opacity(colorScheme == .dark ? 0.18 : 0.14), in: Circle())

                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primaryText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var featuresCard: some View {
        GlassCardView(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: "Feature Vector",
                    subtitle: "机器学习课程展示用的近期特征摘要。",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.featureRows) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                                .lineLimit(1)

                            Text(row.value)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppColors.primaryText(for: colorScheme))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var disclaimerCard: some View {
        GlassCardView(cornerRadius: 22, padding: 14) {
            Text("本功能仅用于个人健康趋势参考和课程展示，不用于紧急用途，也不能替代专业人士判断。")
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stateColor: Color {
        switch viewModel.analysis.state {
        case .balanced:
            return AppColors.recoveryGreen
        case .needRecovery:
            return AppColors.cyan
        case .highStrain:
            return AppColors.stressAmber
        case .lowActivity:
            return AppColors.teal
        case .sleepDebt:
            return AppColors.sleepBlue
        case .dataInsufficient:
            return AppColors.secondaryText(for: colorScheme)
        }
    }

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
}
