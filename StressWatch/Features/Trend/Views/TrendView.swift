import SwiftUI

struct TrendView: View {
    @ObservedObject var viewModel: TrendViewModel
    @State private var contentVisible = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: TrendViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .appStaggeredCard(isVisible: contentVisible, delay: 0, reduceMotion: reduceMotion)

                    rangePicker
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.04, reduceMotion: reduceMotion)

                    stressTrendCard
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.08, reduceMotion: reduceMotion)

                    distributionCard
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.12, reduceMotion: reduceMotion)

                    heatmapCard
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.16, reduceMotion: reduceMotion)

                    recoveryTrendCard
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.20, reduceMotion: reduceMotion)

                    sleepConsistencyCard
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.24, reduceMotion: reduceMotion)

                    weeklyInsightTimeline
                        .appStaggeredCard(isVisible: contentVisible, delay: 0.28, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .background(pageBackground)
            .navigationTitle("趋势")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.loadHistory(days: viewModel.selectedRange.days)
            }
            .task {
                await loadHistory()
            }
        }
    }

    private var header: some View {
        GlassSectionHeader(
            title: "趋势",
            subtitle: "数据分析 Dashboard · 仅用于个人健康趋势参考",
            systemImage: "chart.xyaxis.line"
        )
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(TrendRange.allCases) { range in
                Button {
                    Task {
                        await viewModel.selectRange(range)
                    }
                } label: {
                    Text(range.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(viewModel.selectedRange == range ? AppColors.primaryText(for: colorScheme) : AppColors.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedRange == range ? AppColors.floatingBarHighlight(for: colorScheme) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(AppColors.glassStroke(for: colorScheme), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
    }

    private var stressTrendCard: some View {
        GlassCardView(cornerRadius: 26, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    title: "Monthly Stress Trend",
                    subtitle: "综合压力趋势，支持周 / 月 / 年视图",
                    systemImage: "chart.bar"
                )

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    StressBarTrendView(
                        bars: viewModel.analysis.trendBars,
                        selectedBar: viewModel.selectedTrendBar,
                        onSelect: { viewModel.selectedTrendBar = $0 }
                    )
                    .frame(height: 196)

                    if let selected = viewModel.selectedTrendBar {
                        selectedTrendSummary(selected)
                    }
                }
            }
        }
    }

    private func selectedTrendSummary(_ bar: StressTrendBar) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(bar.date, format: .dateTime.month().day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))

                Text(bar.status)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(bar.level.color)
            }

            Spacer()

            Text("\(bar.value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
        }
        .padding(14)
        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var distributionCard: some View {
        GlassCardView(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                GlassSectionHeader(
                    title: "Stress Distribution",
                    subtitle: "压力水平分布，不使用传统饼图",
                    systemImage: "chart.pie"
                )

                SegmentedDistributionBar(buckets: viewModel.analysis.distribution)
                    .frame(height: 42)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.analysis.distribution) { bucket in
                        distributionMetric(bucket)
                    }
                }
            }
        }
    }

    private func distributionMetric(_ bucket: StressDistributionBucket) -> some View {
        let band = StressBand(rawValue: bucket.id) ?? .normal
        let deltaText = bucket.delta == 0 ? "与上期持平" : "\(bucket.delta > 0 ? "较上期 +" : "较上期 ")\(bucket.delta) 次"

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(band.color)
                    .frame(width: 8, height: 8)

                Text(bucket.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText(for: colorScheme))
            }

            Text("\(bucket.count) 次")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryText(for: colorScheme))

            Text("\(Int(round(bucket.percentage * 100)))% · \(deltaText)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
        }
        .padding(12)
        .background(band.color.opacity(colorScheme == .dark ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heatmapCard: some View {
        GlassCardView(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                GlassSectionHeader(
                    title: "Stress Heatmap",
                    subtitle: "按 24 小时估计压力时段，仅作为趋势参考",
                    systemImage: "clock"
                )

                StressHeatmapView(rows: viewModel.analysis.heatmapRows)

                HStack {
                    heatmapStat(title: "建议关注", value: highStressWindow)
                    heatmapStat(title: "数据置信度", value: "\(Int(round(viewModel.analysis.confidence * 100)))%")
                }
            }
        }
    }

    private var highStressWindow: String {
        let highCells = viewModel.analysis.heatmapRows.flatMap(\.cells).filter { $0.level == .attention || $0.level == .overload }
        guard !highCells.isEmpty else { return "暂无" }
        let grouped = Dictionary(grouping: highCells) { ($0.hour / 3) * 3 }
        let hour = grouped.max { $0.value.count < $1.value.count }?.key ?? 12
        return "\(hour)-\(min(hour + 3, 24)) 时"
    }

    private func heatmapStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.subtleTealFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recoveryTrendCard: some View {
        GlassCardView(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                GlassSectionHeader(
                    title: "Recovery Trend",
                    subtitle: "联合观察 HRV、静息心率与 rolling baseline",
                    systemImage: "heart.circle"
                )

                VStack(spacing: 14) {
                    TrendLinePanel(
                        title: "估计 HRV",
                        values: viewModel.analysis.recoveryTrend.hrvPoints,
                        baseline: viewModel.analysis.recoveryTrend.rollingBaseline,
                        color: AppColors.chartPrimary
                    )
                    .frame(height: 130)

                    TrendLinePanel(
                        title: "估计静息心率",
                        values: viewModel.analysis.recoveryTrend.restingHRPoints,
                        baseline: [],
                        color: AppColors.recoveryBlue
                    )
                    .frame(height: 130)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 12)], spacing: 12) {
                    recoveryStat(title: "工作日平均 HRV", value: "\(Int(round(viewModel.analysis.recoveryTrend.weekdayAverageHRV))) ms")
                    recoveryStat(title: "周末平均 HRV", value: "\(Int(round(viewModel.analysis.recoveryTrend.weekendAverageHRV))) ms")
                    recoveryStat(title: "工作日静息心率", value: "\(Int(round(viewModel.analysis.recoveryTrend.weekdayAverageRestingHR))) bpm")
                    recoveryStat(title: "周末静息心率", value: "\(Int(round(viewModel.analysis.recoveryTrend.weekendAverageRestingHR))) bpm")
                }
            }
        }
    }

    private func recoveryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var sleepConsistencyCard: some View {
        let sleep = viewModel.analysis.sleepConsistency

        return GlassCardView(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                GlassSectionHeader(
                    title: "Sleep Consistency",
                    subtitle: "入睡 / 醒来波动与睡眠阶段占比",
                    systemImage: "moon.zzz"
                )

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(sleep.weeklyScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.primaryText(for: colorScheme))

                    Text("weekly sleep score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }

                SleepStageRatioBar(summary: sleep)
                    .frame(height: 32)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                    recoveryStat(title: "入睡波动", value: "±\(sleep.bedtimeVarianceMinutes) min")
                    recoveryStat(title: "醒来波动", value: "±\(sleep.wakeVarianceMinutes) min")
                    recoveryStat(title: "REM", value: "\(sleep.remPercent)%")
                    recoveryStat(title: "Deep", value: "\(sleep.deepPercent)%")
                }
            }
        }
    }

    private var weeklyInsightTimeline: some View {
        GlassCardView(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    title: "Weekly Insight Timeline",
                    subtitle: "自动生成的趋势观察，不构成医疗建议",
                    systemImage: "list.bullet.clipboard"
                )

                ForEach(viewModel.analysis.insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.primaryBlue)
                            .frame(width: 30, height: 30)
                            .background(AppColors.subtleTealFill(for: colorScheme), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColors.primaryText(for: colorScheme))

                            Text(insight.detail)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
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
        .allowsHitTesting(false)
    }

    private func loadHistory() async {
        withAnimation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: 0)) {
            contentVisible = true
        }
        await viewModel.loadHistory(days: viewModel.selectedRange.days)
    }
}

private struct StressBarTrendView: View {
    let bars: [StressTrendBar]
    let selectedBar: StressTrendBar?
    let onSelect: (StressTrendBar) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let maxValue = max(bars.map(\.value).max() ?? 100, 100)
        let barWidth: CGFloat = bars.count > 60 ? 9 : (bars.count > 20 ? 12 : 22)
        let spacing: CGFloat = bars.count > 60 ? 6 : 8
        let labelWidth: CGFloat = bars.count > 20 ? 36 : 42
        let contentWidth = max(320, CGFloat(bars.count) * (labelWidth + spacing) + 24)

        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .bottomLeading) {
                VStack {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppColors.chartGrid(for: colorScheme))
                            .frame(height: 0.8)
                        Spacer()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 34)

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(bars) { bar in
                        Button {
                            onSelect(bar)
                        } label: {
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(bar.level.color.gradient)
                                    .frame(width: barWidth, height: max(18, CGFloat(bar.value) / CGFloat(maxValue) * 156))
                                    .overlay {
                                        if selectedBar?.id == bar.id {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(AppColors.primaryText(for: colorScheme).opacity(0.35), lineWidth: 1)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    .opacity(selectedBar?.id == bar.id ? 1 : 0.86)

                                Text(label(for: bar.date))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                                    .frame(width: labelWidth)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(width: contentWidth, alignment: .bottomLeading)
            .frame(maxHeight: .infinity, alignment: .bottomLeading)
        }
        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func label(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private struct SegmentedDistributionBar: View {
    let buckets: [StressDistributionBucket]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let segments = normalizedSegments
            let gap: CGFloat = 5

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.subtleActivityFill(for: colorScheme))

                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(segment.color)
                        .frame(
                            width: max(0, proxy.size.width * segment.percentage - gap),
                            height: 30
                        )
                        .offset(x: segmentOffset(index: index, segments: segments, width: proxy.size.width))
                }
            }
        }
    }

    private var normalizedSegments: [DistributionSegment] {
        let total = buckets.reduce(0) { $0 + $1.percentage }
        let source = total > 0 ? buckets : StressBand.allCases.map {
            StressDistributionBucket(id: $0.rawValue, title: $0.title, count: 0, percentage: 0.25, previousCount: 0)
        }

        return source.map { bucket in
            let band = StressBand(rawValue: bucket.id) ?? .normal
            return DistributionSegment(
                id: bucket.id,
                percentage: max(0, bucket.percentage / max(total, 1)),
                color: band.color
            )
        }
    }

    private func segmentOffset(index: Int, segments: [DistributionSegment], width: CGFloat) -> CGFloat {
        guard index > 0 else { return 0 }
        return segments.prefix(index).reduce(0) { $0 + width * $1.percentage }
    }
}

private struct DistributionSegment {
    let id: String
    let percentage: Double
    let color: Color
}

private struct StressHeatmapView: View {
    let rows: [StressHeatmapRow]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                    Text("\(hour)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    Spacer()
                }
            }
            .padding(.leading, 42)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rows) { row in
                        HStack(spacing: 6) {
                            Text(row.date, format: .dateTime.month().day())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                                .frame(width: 36, alignment: .leading)

                            ForEach(row.cells) { cell in
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(cell.level.color.opacity(0.88))
                                    .frame(width: 13, height: 7)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(12)
        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TrendLinePanel: View {
    let title: String
    let values: [Double]
    let baseline: [Double]
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))

            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Rectangle()
                            .fill(AppColors.chartGrid(for: colorScheme))
                            .frame(height: 0.7)
                            .offset(y: proxy.size.height * CGFloat(index) / 2)
                    }

                    if baseline.count > 1 {
                        linePath(values: baseline, in: proxy.size)
                            .stroke(AppColors.secondaryText(for: colorScheme).opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    }

                    linePath(values: values, in: proxy.size)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .padding(12)
        .background(AppColors.subtleActivityFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func linePath(values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let step = size.width / CGFloat(values.count - 1)

        for index in values.indices {
            let x = CGFloat(index) * step
            let y = size.height - CGFloat((values[index] - minValue) / range) * (size.height - 12) - 6
            if index == values.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

private struct SleepStageRatioBar: View {
    let summary: SleepConsistencySummary

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                stage(width: proxy.size.width, percent: summary.remPercent, color: AppColors.chartPrimary)
                stage(width: proxy.size.width, percent: summary.corePercent, color: AppColors.primaryBlue)
                stage(width: proxy.size.width, percent: summary.deepPercent, color: AppColors.deepSleep)
                stage(width: proxy.size.width, percent: summary.awakePercent, color: AppColors.chartSecondary)
            }
        }
    }

    private func stage(width: CGFloat, percent: Int, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color.opacity(0.88))
            .frame(width: max(8, width * CGFloat(percent) / 100))
    }
}

private extension StressBand {
    var color: Color {
        switch self {
        case .recovered:
            return AppColors.primaryBlue
        case .normal:
            return AppColors.softBlue
        case .attention:
            return Color(red: 0.96, green: 0.62, blue: 0.48)
        case .overload:
            return AppColors.stressWarm
        }
    }
}
