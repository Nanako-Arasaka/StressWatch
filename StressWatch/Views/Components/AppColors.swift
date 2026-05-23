import SwiftUI

// AppColors 是 StressWatch 的轻量语义色入口。
// 视图通过 colorScheme 选择浅色 / 深色版本，避免颜色散落在各个组件里。
enum AppColors {
    static let teal = Color(red: 0.14, green: 0.63, blue: 0.54)
    static let mint = Color(red: 0.62, green: 0.91, blue: 0.80)
    static let cyan = Color(red: 0.18, green: 0.72, blue: 0.78)
    static let stressAmber = Color(red: 0.78, green: 0.52, blue: 0.14)
    static let recoveryGreen = Color(red: 0.22, green: 0.68, blue: 0.56)
    static let sleepBlue = Color(red: 0.16, green: 0.62, blue: 0.72)
    static let stepsGreen = Color(red: 0.42, green: 0.70, blue: 0.32)
    static let deepSleep = Color(red: 0.10, green: 0.28, blue: 0.25)

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.94) : Color.primary
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.66) : Color.secondary
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.06)
    }

    static func glassStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.26)
    }

    static func chartGrid(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.secondary.opacity(0.10)
    }

    static func chartPointHalo(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.07, green: 0.15, blue: 0.14).opacity(0.90) : Color(.systemBackground).opacity(0.85)
    }

    static func shadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.08)
    }

    static func badgeFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.10)
    }

    static func subtleTealFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? teal.opacity(0.14) : teal.opacity(0.08)
    }

    static func subtleActivityFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? teal.opacity(0.12) : teal.opacity(0.06)
    }

    static func stressCardTint(for scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [
                stressAmber.opacity(0.24),
                Color(red: 0.38, green: 0.24, blue: 0.08).opacity(0.16)
            ]
        }

        return [
            Color(red: 1.00, green: 0.83, blue: 0.35).opacity(0.20),
            Color(red: 1.00, green: 0.93, blue: 0.68).opacity(0.11)
        ]
    }

    static func stressShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? stressAmber.opacity(0.10) : Color(red: 0.80, green: 0.54, blue: 0.12).opacity(0.13)
    }

    static func backgroundGradient(for scheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        if scheme == .dark {
            colors = [
                Color(red: 0.04, green: 0.12, blue: 0.11),
                Color(red: 0.03, green: 0.20, blue: 0.18),
                Color(red: 0.05, green: 0.12, blue: 0.16)
            ]
        } else {
            colors = [
                Color(red: 0.91, green: 1.00, blue: 0.96),
                Color(red: 0.78, green: 0.96, blue: 0.90),
                Color(red: 0.91, green: 0.99, blue: 0.98)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func backgroundGlowPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? mint.opacity(0.16) : mint.opacity(0.42)
    }

    static func backgroundGlowSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cyan.opacity(0.12) : Color(red: 0.55, green: 0.90, blue: 0.94).opacity(0.30)
    }
}
