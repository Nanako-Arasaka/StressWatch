import SwiftUI

struct DataSourceBadge: View {
    let source: String

    @State private var isVisible = false

    private var isAppleHealth: Bool {
        source == "Apple Health"
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isAppleHealth ? .green : .blue)
                .frame(width: 8, height: 8)

            Text(source)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .opacity(isVisible ? 1 : 0.65)
        .scaleEffect(isVisible ? 1 : 0.96)
        .animation(.easeOut(duration: 0.25), value: source)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = true
            }
        }
        .onChange(of: source) { _ in
            isVisible = false
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = true
            }
        }
    }
}
