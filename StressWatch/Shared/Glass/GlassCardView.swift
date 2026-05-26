import SwiftUI

struct GlassCardView<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 26,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape
                    .fill(AppColors.cardBackground(for: colorScheme))
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(AppColors.glassStroke(for: colorScheme), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.035 : 0.10),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .shadow(color: AppColors.shadow(for: colorScheme), radius: 10, x: 0, y: 6)
    }
}
