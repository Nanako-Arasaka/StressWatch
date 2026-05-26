import SwiftUI
import Charts

struct MetricChart: View {
    let metrics: [HealthMetric]

    @State private var selectedMetric: HealthMetric?
    @State private var visibleDomain: TimeInterval?
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
                    .foregroundStyle(AppColors.teal.gradient)
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("时间", metric.date),
                        y: .value("数值", metric.value)
                    )
                    .foregroundStyle(isSelected(metric) ? AppColors.primaryText(for: colorScheme) : AppColors.cyan)
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
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleDomain ?? defaultVisibleDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
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
                        }
                    }
                    .rotationEffect(.degrees(-35), anchor: .topLeading)
                    .offset(x: -10, y: 8)
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
                }
            }
            .simultaneousGesture(zoomGesture)
            .onAppear {
                onAppearCount += 1
                print("[MetricChart] onAppear count=\(onAppearCount) raw=\(metrics.count) displayed=\(displayMetrics.count)")
                resetVisibleDomainIfNeeded()
            }
            .onChange(of: metricsSignature) { _, _ in
                selectedMetric = nil
                visibleDomain = defaultVisibleDomain
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Chart Data

    private var sortedMetrics: [HealthMetric] {
        metrics.sorted { $0.date < $1.date }
    }

    private var displayMetrics: [HealthMetric] {
        downsample(sortedMetrics, maxCount: 120)
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
            .onEnded { value in
                guard !reduceMotion else {
                    return
                }

                let baseDomain = visibleDomain ?? defaultVisibleDomain
                visibleDomain = clampedVisibleDomain(baseDomain / max(Double(value), 0.2))
            }
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
        guard visibleDomain == nil else {
            return
        }

        visibleDomain = defaultVisibleDomain
    }
}
