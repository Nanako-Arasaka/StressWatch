import SwiftUI

struct WidgetBackgroundView: View {
    var body: some View {
        ZStack {
            WidgetColorPalette.background

            Circle()
                .fill(WidgetColorPalette.lakeBlue.opacity(0.28))
                .frame(width: 150, height: 150)
                .blur(radius: 24)
                .offset(x: -60, y: -62)

            Circle()
                .fill(WidgetColorPalette.softPink.opacity(0.22))
                .frame(width: 142, height: 142)
                .blur(radius: 26)
                .offset(x: 86, y: 58)
        }
    }
}

struct WidgetHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetColorPalette.ink)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetColorPalette.mutedInk)
                .lineLimit(1)
        }
    }
}

struct WidgetPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(WidgetColorPalette.ink.opacity(0.88))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                    )
            )
    }
}

struct WidgetUpdatedText: View {
    let date: Date

    var body: some View {
        Text(Self.relativeText(from: date))
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(WidgetColorPalette.mutedInk)
            .lineLimit(1)
    }

    private static func relativeText(from date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))

        if seconds < 60 {
            return "Updated now"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "Updated \(minutes)m ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "Updated \(hours)h ago"
        }

        return "Updated \(hours / 24)d ago"
    }
}

struct WidgetScorePanel: View {
    let title: String
    let value: String
    let status: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetColorPalette.mutedInk)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(status)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetColorPalette.ink.opacity(0.82))
                .lineLimit(1)
        }
    }
}

struct WidgetMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetColorPalette.mistBlue)

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetColorPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
    }
}

enum WidgetDeepLink {
    static let dashboard = URL(string: "stresswatch://dashboard")!
    static let analysis = URL(string: "stresswatch://analysis")!
}

func widgetInsightLabel(for analysisSource: String) -> String {
    analysisSource == "Core ML Personal Model" ? "AI Insight" : "Trend Reference"
}

func widgetRecoveryTint(for score: Int?) -> Color {
    guard let score else {
        return WidgetColorPalette.mutedInk
    }

    if score >= 70 {
        return WidgetColorPalette.blueGreen
    } else if score >= 45 {
        return WidgetColorPalette.lakeBlue
    } else {
        return WidgetColorPalette.softPink
    }
}
