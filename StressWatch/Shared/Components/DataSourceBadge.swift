import SwiftUI

struct DataSourceBadge: View {
    let source: String

    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAppleHealth: Bool {
        source == "Apple Health"
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isAppleHealth ? AppColors.primaryBlue : AppColors.softBlue)
                .frame(width: 8, height: 8)

            Text(source)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.primaryText(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(AppColors.glassStroke(for: colorScheme), lineWidth: 1)
        }
        .opacity(isVisible ? 1 : 0.65)
        .scaleEffect(isVisible || reduceMotion ? 1 : AppMotion.badgeInitialScale)
        .animation(AppMotion.numericChange(reduceMotion: reduceMotion), value: source)
        .onAppear {
            withAnimation(AppMotion.numericChange(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
        .onChange(of: source) { _ in
            isVisible = false
            withAnimation(AppMotion.numericChange(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }
}
