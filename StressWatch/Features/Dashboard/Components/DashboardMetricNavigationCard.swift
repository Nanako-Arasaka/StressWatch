import SwiftUI

struct DashboardMetricNavigationCard: View {
    let metric: DashboardMetric
    let recentMetrics: [HealthMetric]

    var body: some View {
        Group {
            if let metricType = destinationMetricType(for: metric.id) {
                NavigationLink {
                    MetricDetailView(
                        metricType: metricType,
                        metrics: recentMetrics.filter { $0.type == metricType }
                    )
                } label: {
                    DashboardMetricCardView(metric: metric)
                }
                .buttonStyle(PressScaleButtonStyle())
            } else {
                DashboardMetricCardView(metric: metric)
            }
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
