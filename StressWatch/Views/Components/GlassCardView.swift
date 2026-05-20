import SwiftUI

struct GlassCardView<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

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
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: cornerRadius)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return self
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape
                    .fill(.white.opacity(0.06))
            }
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}
