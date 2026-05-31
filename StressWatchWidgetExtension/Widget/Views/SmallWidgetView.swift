import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(
                    title: "StressWatch",
                    subtitle: widgetInsightLabel(for: entry.snapshot.analysisSource)
                )

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(scoreText)
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(widgetRecoveryTint(for: entry.snapshot.recoveryScore))
                        .minimumScaleFactor(0.72)

                    Text("Recovery")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetColorPalette.mutedInk)
                }

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetColorPalette.mistBlue)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    WidgetPill(text: liveStressText)
                    Spacer(minLength: 0)
                    WidgetUpdatedText(date: entry.snapshot.generatedAt)
                }
            }
            .padding(14)
        }
        .widgetURL(WidgetDeepLink.dashboard)
        .containerBackground(for: .widget) {
            WidgetBackgroundView()
        }
    }

    private var scoreText: String {
        entry.snapshot.recoveryScore.map(String.init) ?? "--"
    }

    private var liveStressText: String {
        if entry.snapshot.isPlaceholder {
            return "Stress --"
        }

        if let score = entry.snapshot.liveStressScore {
            return "Stress \(score)"
        }

        return entry.snapshot.liveStressStatus
    }

    private var statusText: String {
        entry.snapshot.isPlaceholder ? entry.snapshot.insightText : entry.snapshot.recoveryStatus
    }
}
