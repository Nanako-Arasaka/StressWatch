import SwiftUI

struct DashboardDetailGridSection: View {
    let metrics: [DashboardMetric]
    let recentMetrics: [HealthMetric]
    let hrvTrend: [Double]
    let heartRateTrend: [Double]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
            ForEach(metrics) { metric in
                DashboardMetricNavigationCard(metric: metric, recentMetrics: recentMetrics)
            }

            GlassCardView(cornerRadius: 28, padding: 18) {
                DashboardTrendChartView(
                    title: "HRV / Baseline",
                    subtitle: "近期 HRV 波动趋势参考",
                    values: hrvTrend,
                    color: AppColors.chartPrimary,
                    yRange: 0...(max((hrvTrend.max() ?? 80), 80))
                )
            }

            GlassCardView(cornerRadius: 28, padding: 18) {
                DashboardTrendChartView(
                    title: "Heart Rate Detail",
                    subtitle: "最近心率读取和日间趋势参考",
                    values: heartRateTrend,
                    color: AppColors.primaryBlue,
                    yRange: 40...(max((heartRateTrend.max() ?? 120), 120))
                )
            }
        }
    }
}
