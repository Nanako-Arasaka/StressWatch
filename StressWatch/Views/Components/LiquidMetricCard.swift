import SwiftUI

struct LiquidMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let systemImage: String

    var body: some View {
        GlassCardView(cornerRadius: 22, padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
