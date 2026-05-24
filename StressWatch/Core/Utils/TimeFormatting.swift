import Foundation

// 统一格式化小时数，避免 DashboardView 和 ViewModel 各自维护一份实现。
func formatHours(_ hours: Double) -> String {
    let wholeHours = Int(hours)
    let minutes = Int(round((hours - Double(wholeHours)) * 60))
    return "\(wholeHours)h \(minutes)m"
}
