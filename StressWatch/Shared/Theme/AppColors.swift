import SwiftUI

// AppColors 是 StressWatch 的统一视觉语言入口。
// 新品牌方向：湖蓝、柔和浅湖蓝、淡粉，整体偏 Calm / Recovery / Soft Glass。
enum AppColors {
    static let primaryBlue = Color(red: 0.153, green: 0.651, blue: 0.800) // #27A6CC
    static let softBlue = Color(red: 0.502, green: 0.749, blue: 0.831) // #80BFD4
    static let softPink = Color(red: 0.988, green: 0.773, blue: 0.773) // #FCC5C5
    static let darkBackground = Color(red: 0.055, green: 0.090, blue: 0.125)

    static let recoveryBlue = Color(red: 0.153, green: 0.510, blue: 0.620)
    static let stressWarm = Color(red: 0.875, green: 0.345, blue: 0.310)
    static let chartPrimary = primaryBlue
    static let chartSecondary = stressWarm

    // 兼容旧调用名，全部映射到新的品牌语义色，避免视觉系统继续分裂。
    static let teal = primaryBlue
    static let mint = softBlue
    static let cyan = primaryBlue
    static let stressAmber = stressWarm
    static let recoveryGreen = recoveryBlue
    static let sleepBlue = softBlue
    static let stepsGreen = primaryBlue.opacity(0.82)
    static let deepSleep = Color(red: 0.105, green: 0.210, blue: 0.310)

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.96) : Color(red: 0.067, green: 0.122, blue: 0.165)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.76) : Color(red: 0.067, green: 0.122, blue: 0.165).opacity(0.76)
    }

    static func glassFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.075) : Color.white.opacity(0.76)
    }

    static func glassBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.70)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.28)
    }

    static func glassStroke(for scheme: ColorScheme) -> Color {
        glassBorder(for: scheme)
    }

    static func chartGrid(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color(red: 0.067, green: 0.122, blue: 0.165).opacity(0.13)
    }

    static func chartPointHalo(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground.opacity(0.92) : Color.white.opacity(0.88)
    }

    static func shadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.20) : Color(red: 0.067, green: 0.122, blue: 0.165).opacity(0.10)
    }

    static func floatingBarFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.082) : Color.white.opacity(0.86)
    }

    static func floatingBarHighlight(for scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryBlue.opacity(0.22) : primaryBlue.opacity(0.24)
    }

    static func badgeFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.18)
    }

    static func subtleTealFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryBlue.opacity(0.16) : primaryBlue.opacity(0.13)
    }

    static func subtleActivityFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? softBlue.opacity(0.13) : softBlue.opacity(0.16)
    }

    static func heroGlow(for scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [primaryBlue.opacity(0.20), softPink.opacity(0.10)]
        }

        return [primaryBlue.opacity(0.20), softPink.opacity(0.30)]
    }

    static func stressCardTint(for scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [
                softPink.opacity(0.16),
                primaryBlue.opacity(0.10)
            ]
        }

        return [
            softPink.opacity(0.34),
            softBlue.opacity(0.18)
        ]
    }

    static func stressShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? softPink.opacity(0.07) : softPink.opacity(0.14)
    }

    static func backgroundGradient(for scheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        if scheme == .dark {
            colors = [
                darkBackground,
                Color(red: 0.075, green: 0.125, blue: 0.170),
                Color(red: 0.120, green: 0.105, blue: 0.145)
            ]
        } else {
            colors = [
                Color(red: 0.965, green: 0.990, blue: 1.000),
                Color(red: 0.902, green: 0.965, blue: 0.985),
                Color(red: 1.000, green: 0.942, blue: 0.948)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func backgroundGlowPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryBlue.opacity(0.16) : primaryBlue.opacity(0.24)
    }

    static func backgroundGlowSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? softPink.opacity(0.10) : softPink.opacity(0.30)
    }
}
