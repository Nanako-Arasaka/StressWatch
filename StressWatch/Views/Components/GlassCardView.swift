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
            }
            .overlay {
                shape
                    .strokeBorder(AppColors.glassStroke(for: colorScheme), lineWidth: 1)
            }
            .shadow(color: AppColors.shadow(for: colorScheme), radius: 18, x: 0, y: 10)
    }
}
