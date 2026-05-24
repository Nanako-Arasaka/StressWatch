import SwiftUI

struct DashboardKeySignalsSection: View {
    let metrics: [DashboardMetric]
    let recentMetrics: [HealthMetric]

    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.adaptive(minimum: 156), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key signals")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(metrics) { metric in
                    DashboardMetricNavigationCard(metric: metric, recentMetrics: recentMetrics)
                }
            }
        }
    }
}
