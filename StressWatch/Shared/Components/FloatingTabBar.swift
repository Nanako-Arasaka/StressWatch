import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case dashboard
    case trend
    case settings

    var title: String {
        switch self {
        case .dashboard:
            return "今日"
        case .trend:
            return "趋势"
        case .settings:
            return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.33percent"
        case .trend:
            return "chart.xyaxis.line"
        case .settings:
            return "gearshape"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    @Namespace private var tabNamespace
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(AppMotion.spring(reduceMotion: reduceMotion)) {
                        selection = tab
                    }
                } label: {
                    tabItem(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .frame(maxWidth: 360)
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .background(AppColors.floatingBarFill(for: colorScheme), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(AppColors.glassStroke(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: AppColors.shadow(for: colorScheme), radius: 26, x: 0, y: 16)
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return HStack(spacing: isSelected ? 7 : 0) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 15, weight: .bold, design: .rounded))

            if isSelected {
                Text(tab.title)
                    .font(.caption.weight(.bold))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .foregroundStyle(isSelected ? AppColors.primaryText(for: colorScheme) : AppColors.secondaryText(for: colorScheme))
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background {
            if isSelected {
                Capsule()
                    .fill(AppColors.floatingBarHighlight(for: colorScheme))
                    .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                    .shadow(color: AppColors.mint.opacity(colorScheme == .dark ? 0.18 : 0.24), radius: 18, x: 0, y: 8)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelected {
                Circle()
                    .fill(AppColors.mint)
                    .frame(width: 4, height: 4)
                    .offset(y: -4)
                    .opacity(0.8)
            }
        }
    }
}
