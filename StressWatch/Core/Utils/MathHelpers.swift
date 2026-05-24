import Foundation

func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}

func safeDenominator(_ value: Double) -> Double {
    max(value, 0.0001)
}
