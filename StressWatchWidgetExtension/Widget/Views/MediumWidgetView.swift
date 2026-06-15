import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        WidgetHeader(
                            title: "StressWatch",
                            subtitle: widgetInsightLabel(for: entry.snapshot.analysisSource)
                        )
                        WidgetScorePanel(
                            title: "Recovery",
                            value: entry.snapshot.recoveryScore.map(String.init) ?? "--",
                            status: entry.snapshot.recoveryStatus,
                            tint: widgetRecoveryTint(for: entry.snapshot.recoveryScore)
                        )
                        .widgetURL(WidgetDeepLink.dashboard)

                        WidgetScorePanel(
                            title: "Live Stress",
                            value: entry.snapshot.liveStressScore.map(String.init) ?? "--",
                            status: entry.snapshot.liveStressStatus,
                            tint: WidgetColorPalette.softPink
                        )
                    }
                    .frame(maxWidth: 132, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            WidgetMetricTile(title: "HRV", value: entry.snapshot.hrvText)
                            WidgetMetricTile(title: "Sleep", value: entry.snapshot.sleepText)
                        }

                        Text(entry.snapshot.insightText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(WidgetColorPalette.ink.opacity(0.9))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .widgetURL(WidgetDeepLink.analysis)

                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 6) {
                    WidgetPill(text: entry.snapshot.dataSource)
                    WidgetPill(text: widgetInsightLabel(for: entry.snapshot.analysisSource))
                    Spacer(minLength: 0)
                    WidgetUpdatedText(date: entry.snapshot.generatedAt)
                }
            }
            .padding(14)
        }
        .stressWatchWidgetBackground()
    }
}
