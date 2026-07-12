import SwiftUI
import Charts

struct MetricChart: View {
    let metricType: MetricType
    let metrics: [HealthMetric]
    let resetToken: Int

    @State private var selectedMetric: HealthMetric?
    @State private var visibleStartDate: Date?
    @State private var visibleEndDate: Date?
    @State private var panStartRange: ClosedRange<Date>?
    @State private var lastMagnification: CGFloat = 1
    @State private var onAppearCount = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if metrics.isEmpty {
            Text("暂无数据")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(displayMetrics) { metric in
                    LineMark(
                        x: .value("时间", metric.date),
                        y: .value("数值", metric.value)
                    )
                    .foregroundStyle(AppColors.primaryBlue.gradient)
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("时间", metric.date),
                        y: .value("数值", metric.value)
                    )
                    .foregroundStyle(isSelected(metric) ? AppColors.primaryText(for: colorScheme) : AppColors.chartPrimary)
                    .symbolSize(isSelected(metric) ? 72 : 28)
                    .annotation(position: .top, spacing: 8) {
                        if isSelected(metric) {
                            metricTooltip(for: metric)
                        }
                    }
                }

                if let selectedMetric {
                    RuleMark(x: .value("选中时间", selectedMetric.date))
                        .foregroundStyle(AppColors.glassStroke(for: colorScheme))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXScale(domain: visibleDateRange ?? fullDateRange)
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(AppColors.chartGrid(for: colorScheme))

                    AxisTick()
                        .foregroundStyle(AppColors.chartGrid(for: colorScheme))

                    AxisValueLabel(anchor: .top) {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .rotationEffect(.degrees(-48), anchor: .topLeading)
                                .offset(x: -14, y: 10)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(AppColors.chartGrid(for: colorScheme))

                    AxisTick()
                        .foregroundStyle(AppColors.chartGrid(for: colorScheme))

                    AxisValueLabel()
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(AppColors.subtleActivityFill(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    selectNearestMetric(
                                        at: value.location,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    panVisibleRange(
                                        translationX: value.translation.width,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                }
                                .onEnded { _ in
                                    panStartRange = nil
                                }
                        )
                }
            }
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        resetZoom()
                    }
            )
            .onAppear {
                onAppearCount += 1
                print("[MetricChart] onAppear count=\(onAppearCount) raw=\(metrics.count) displayed=\(displayMetrics.count)")
                resetVisibleDomainIfNeeded()
            }
            .onChange(of: metricsSignature) { _ in
                selectedMetric = nil
                setVisibleDomain(defaultVisibleDomain, centeredAt: sortedMetrics.last?.date)
            }
            .onChange(of: resetToken) { _ in
                resetZoom()
            }
        }
    }

    // MARK: - Chart Data

    private var sortedMetrics: [HealthMetric] {
        metrics.sorted { $0.date < $1.date }
    }

    private var displayMetrics: [HealthMetric] {
        downsample(sortedMetrics, maxCount: 120)
    }

    private var yAxisDomain: ClosedRange<Double> {
        if metricType == .hrv {
            return 0...100
        }

        let values = displayMetrics.map(\.value)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let padding = max((maximum - minimum) * 0.12, 1)
        return (minimum - padding)...(maximum + padding)
    }

    private var metricsSignature: String {
        let first = sortedMetrics.first?.date.timeIntervalSince1970 ?? 0
        let last = sortedMetrics.last?.date.timeIntervalSince1970 ?? 0
        return "\(sortedMetrics.count)-\(first)-\(last)"
    }

    private var totalDomain: TimeInterval {
        guard let first = sortedMetrics.first?.date,
              let last = sortedMetrics.last?.date else {
            return 60 * 60
        }

        return max(last.timeIntervalSince(first), 60 * 60)
    }

    private var fullDateRange: ClosedRange<Date> {
        guard let first = sortedMetrics.first?.date,
              let last = sortedMetrics.last?.date else {
            let now = Date()
            return now...now.addingTimeInterval(60 * 60)
        }

        guard last > first else {
            return first...first.addingTimeInterval(60 * 60)
        }

        return first...last
    }

    private var visibleDateRange: ClosedRange<Date>? {
        guard let visibleStartDate, let visibleEndDate else {
            return nil
        }

        return visibleStartDate...visibleEndDate
    }

    private var minVisibleDomain: TimeInterval {
        min(max(totalDomain / 28, 60 * 60 * 2), totalDomain)
    }

    private var defaultVisibleDomain: TimeInterval {
        guard sortedMetrics.count > 16 else {
            return totalDomain
        }

        return clampedVisibleDomain(max(totalDomain / 3, 60 * 60 * 12))
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !reduceMotion else {
                    return
                }

                let range = visibleDateRange ?? fullDateRange
                let center = selectedMetric?.date ?? midpoint(of: range)
                let visibleDuration = range.upperBound.timeIntervalSince(range.lowerBound)
                let incrementalScale = max(Double(value / max(lastMagnification, 0.01)), 0.05)
                let nextDomain = clampedVisibleDomain(visibleDuration / incrementalScale)
                setVisibleDomain(nextDomain, centeredAt: center)
                lastMagnification = value
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }

    private func panVisibleRange(translationX: CGFloat, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        guard plotFrame.width > 1 else {
            return
        }

        let startRange = panStartRange ?? (visibleDateRange ?? fullDateRange)
        if panStartRange == nil {
            panStartRange = startRange
        }

        let duration = startRange.upperBound.timeIntervalSince(startRange.lowerBound)
        let secondsDelta = -Double(translationX / plotFrame.width) * duration
        setVisibleRange(
            start: startRange.lowerBound.addingTimeInterval(secondsDelta),
            end: startRange.upperBound.addingTimeInterval(secondsDelta)
        )
    }

    private func selectNearestMetric(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        let xPosition = location.x - plotFrame.origin.x

        guard xPosition >= 0,
              xPosition <= plotFrame.width,
              let date: Date = proxy.value(atX: xPosition) else {
            return
        }

        selectedMetric = displayMetrics.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    // MARK: - Formatting

    private func metricTooltip(for metric: HealthMetric) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metric.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption2.weight(.semibold))

            Text("\(formattedValue(metric.value))\(metric.unit.isEmpty ? "" : " \(metric.unit)")")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(AppColors.primaryText(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppColors.glassStroke(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: AppColors.shadow(for: colorScheme), radius: 12, x: 0, y: 6)
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private func formattedValue(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return value.formatted(.number.precision(.fractionLength(0)))
        }

        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    // MARK: - Helpers

    private func isSelected(_ metric: HealthMetric) -> Bool {
        selectedMetric?.id == metric.id
    }

    private func clampedVisibleDomain(_ domain: TimeInterval) -> TimeInterval {
        clamp(domain, minVisibleDomain, totalDomain)
    }

    private func setVisibleDomain(_ domain: TimeInterval, centeredAt centerDate: Date?) {
        let domain = clampedVisibleDomain(domain)
        let center = centerDate ?? sortedMetrics.last?.date ?? Date()
        setVisibleRange(
            start: center.addingTimeInterval(-domain / 2),
            end: center.addingTimeInterval(domain / 2)
        )
    }

    private func setVisibleRange(start: Date, end: Date) {
        guard let first = sortedMetrics.first?.date,
              let last = sortedMetrics.last?.date else {
            return
        }

        guard last > first else {
            visibleStartDate = first
            visibleEndDate = first.addingTimeInterval(60 * 60)
            return
        }

        let domain = clampedVisibleDomain(end.timeIntervalSince(start))
        var lower = start
        var upper = start.addingTimeInterval(domain)

        if lower < first {
            lower = first
            upper = first.addingTimeInterval(domain)
        }

        if upper > last {
            upper = last
            lower = last.addingTimeInterval(-domain)
        }

        visibleStartDate = max(lower, first)
        visibleEndDate = min(upper, last)
    }

    private func midpoint(of range: ClosedRange<Date>) -> Date {
        range.lowerBound.addingTimeInterval(range.upperBound.timeIntervalSince(range.lowerBound) / 2)
    }

    private func downsample(_ metrics: [HealthMetric], maxCount: Int) -> [HealthMetric] {
        guard metrics.count > maxCount, maxCount > 2 else {
            return metrics
        }

        let stride = max(1, Int(ceil(Double(metrics.count) / Double(maxCount))))
        var sampled = metrics.enumerated().compactMap { index, metric in
            index % stride == 0 ? metric : nil
        }

        if let last = metrics.last, sampled.last?.id != last.id {
            sampled.append(last)
        }

        return sampled
    }

    private func resetVisibleDomainIfNeeded() {
        guard visibleDateRange == nil else {
            return
        }

        setVisibleDomain(defaultVisibleDomain, centeredAt: sortedMetrics.last?.date)
    }

    private func resetZoom() {
        selectedMetric = nil
        panStartRange = nil
        setVisibleDomain(defaultVisibleDomain, centeredAt: sortedMetrics.last?.date)
    }
}
