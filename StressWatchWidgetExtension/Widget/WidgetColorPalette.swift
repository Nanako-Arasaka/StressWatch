import SwiftUI

enum WidgetColorPalette {
    static let deepNavy = Color(red: 0.03, green: 0.07, blue: 0.11)
    static let blueGreen = Color(red: 0.22, green: 0.82, blue: 0.72)
    static let lakeBlue = Color(red: 0.15, green: 0.65, blue: 0.80)
    static let mistBlue = Color(red: 0.50, green: 0.75, blue: 0.83)
    static let softPink = Color(red: 0.99, green: 0.77, blue: 0.77)
    static let ink = Color.white
    static let mutedInk = Color.white.opacity(0.68)

    static let background = LinearGradient(
        colors: [
            deepNavy,
            Color(red: 0.04, green: 0.16, blue: 0.22),
            Color(red: 0.10, green: 0.09, blue: 0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
