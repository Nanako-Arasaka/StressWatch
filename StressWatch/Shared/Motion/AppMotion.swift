import SwiftUI

// AppMotion 是 StressWatch 的轻量动画入口。
// 所有 Dashboard 微交互尽量从这里读取时长、缩放和动画曲线，避免 magic number 散落在视图里。
enum AppMotion {
    static let fastDuration: Double = 0.22
    static let normalDuration: Double = 0.35
    static let slowDuration: Double = 0.48
    static let ambientDuration: Double = 2.8
    static let cardEntranceOffset: CGFloat = 18
    static let buttonPressScale: CGFloat = 0.98
    static let badgeInitialScale: CGFloat = 0.96
    static let chartInitialProgress: CGFloat = 0.001
    static let barStaggerDelay: Double = 0.035

    static func cardEntrance(reduceMotion: Bool, delay: Double) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01).delay(delay)
        }
        return .easeOut(duration: normalDuration).delay(delay)
    }

    static func chartDrawing(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .easeOut(duration: 0.62)
    }

    static func barGrowth(reduceMotion: Bool, delay: Double) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01).delay(delay)
        }
        return .easeOut(duration: normalDuration).delay(delay)
    }

    static func numericChange(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .easeInOut(duration: fastDuration)
    }

    static func spring(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .spring(response: normalDuration, dampingFraction: 0.86)
    }

    static func ambientBreathing(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        // 性能优先：环境光只做一次轻微过渡，避免静止页面持续占用 GPU。
        return .easeInOut(duration: slowDuration)
    }
}

// 可点击卡片的轻量按压反馈。NavigationLink 使用 plain button style 时也能保留跳转。
struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? AppMotion.buttonPressScale : 1)
            .animation(AppMotion.spring(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

// 页面卡片入场动画：Reduce Motion 开启时只保留最小透明度变化，不做位移。
private struct StaggeredCardModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : AppMotion.cardEntranceOffset)
            .animation(AppMotion.cardEntrance(reduceMotion: reduceMotion, delay: delay), value: isVisible)
    }
}

// 数字文本变化动画。保持在 iOS 16 可编译的基础 API 上，避免依赖 iOS 17 SDK 符号。
private struct NumericChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .transition(.opacity)
            .animation(AppMotion.numericChange(reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    func appStaggeredCard(isVisible: Bool, delay: Double, reduceMotion: Bool) -> some View {
        modifier(StaggeredCardModifier(isVisible: isVisible, delay: delay, reduceMotion: reduceMotion))
    }

    func appNumericChange<Value: Equatable>(value: Value, reduceMotion: Bool) -> some View {
        modifier(NumericChangeModifier(value: value, reduceMotion: reduceMotion))
    }
}
