import SwiftUI
import WidgetKit

struct StressWatchWidget: Widget {
    private let kind = "StressWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetTimelineProvider()) { entry in
            StressWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("StressWatch")
        .description("查看今日个人健康趋势参考。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StressWatchWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
