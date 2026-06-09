import CoreML
import Foundation

struct CoreMLWellnessAnalyzer: WellnessAnalyzing {
    private let fallbackAnalyzer: any WellnessAnalyzing
    private let model: MLModel?
    private let classLabels: [String]

    // Keep this order aligned with ml_training/output/feature_columns.json.
    private let featureColumns = [
        "avg_hrv_sdnn",
        "min_hrv_sdnn",
        "max_hrv_sdnn",
        "avg_heart_rate",
        "resting_heart_rate",
        "sleep_hours",
        "rem_sleep_hours",
        "core_sleep_hours",
        "deep_sleep_hours",
        "awake_hours",
        "steps",
        "active_energy",
        "exercise_minutes",
        "stand_hours",
        "hrv_7d_baseline",
        "hrv_deviation_percent",
        "resting_hr_7d_baseline",
        "resting_hr_deviation",
        "sleep_7d_baseline",
        "sleep_ratio",
        "data_confidence"
    ]

    init(
        fallbackAnalyzer: any WellnessAnalyzing = WellnessAnalyzer(),
        modelURL: URL? = Bundle.main.url(forResource: "StressWatchWellnessClassifier", withExtension: "mlmodelc"),
        labelsURL: URL? = Bundle.main.url(forResource: "coreml_class_labels", withExtension: "json")
    ) {
        self.fallbackAnalyzer = fallbackAnalyzer
        self.model = modelURL.flatMap { try? MLModel(contentsOf: $0) }
        self.classLabels = Self.loadClassLabels(from: labelsURL)
    }

    func analyze(features: WellnessFeatures) -> WellnessAnalysis {
        guard let model,
              !classLabels.isEmpty,
              let provider = makeFeatureProvider(for: model, features: features),
              let prediction = try? model.prediction(from: provider),
              let label = predictedLabel(from: prediction),
              let state = state(for: label)
        else {
            return fallbackAnalyzer
                .analyze(features: features)
                .withSource(.coreMLUnavailableRuleFallback)
        }

        let confidence = predictedConfidence(from: prediction) ?? features.dataConfidence
        let generatedAt = Date()
        let insight = MLWellnessInsightFactory.makeInsight(
            label: label,
            state: state,
            confidence: confidence,
            features: features,
            source: .coreMLPersonalModel,
            generatedAt: generatedAt
        )

        return WellnessAnalysis(
            state: state,
            predictedLabel: label,
            confidence: confidence,
            primaryFactors: insight.keyFactors,
            features: features,
            generatedAt: generatedAt,
            source: .coreMLPersonalModel,
            mlInsight: insight
        )
    }

    private func makeFeatureProvider(for model: MLModel, features: WellnessFeatures) -> MLDictionaryFeatureProvider? {
        let expectedInputs = Set(model.modelDescription.inputDescriptionsByName.keys)
        let knownFeatures = Set(featureColumns)

        guard expectedInputs.isSubset(of: knownFeatures) else {
            return nil
        }

        var values: [String: MLFeatureValue] = [:]
        for column in featureColumns where expectedInputs.contains(column) {
            let value = featureValue(for: column, features: features) ?? Double.nan
            values[column] = MLFeatureValue(double: value)
        }

        return try? MLDictionaryFeatureProvider(dictionary: values)
    }

    private func featureValue(for column: String, features: WellnessFeatures) -> Double? {
        let value: Double?
        switch column {
        case "avg_hrv_sdnn":
            value = features.avgHRV
        case "min_hrv_sdnn":
            value = estimatedMinimumHRV(features)
        case "max_hrv_sdnn":
            value = estimatedMaximumHRV(features)
        case "avg_heart_rate":
            value = features.avgHeartRate
        case "resting_heart_rate":
            value = features.avgRestingHR
        case "sleep_hours":
            value = features.sleepAverage
        case "rem_sleep_hours":
            value = features.remSleepAverage
        case "core_sleep_hours":
            value = features.coreSleepAverage
        case "deep_sleep_hours":
            value = features.deepSleepAverage
        case "awake_hours":
            value = features.awakeAverage
        case "steps":
            value = features.stepsAverage
        case "active_energy":
            value = features.activeEnergyAverage
        case "exercise_minutes":
            value = features.exerciseMinutesAverage
        case "stand_hours":
            value = features.standHoursAverage
        case "hrv_7d_baseline":
            value = features.avgHRV
        case "hrv_deviation_percent":
            value = estimatedHRVDeviationPercent(features)
        case "resting_hr_7d_baseline":
            value = estimatedRestingHRBaseline(features)
        case "resting_hr_deviation":
            value = estimatedRestingHRDeviation(features)
        case "sleep_7d_baseline":
            value = estimatedSleepBaseline(features)
        case "sleep_ratio":
            value = estimatedSleepRatio(features)
        case "data_confidence":
            value = features.dataConfidence * 100
        default:
            value = nil
        }

        guard let value, value.isFinite else {
            return nil
        }

        return value
    }

    private func estimatedMinimumHRV(_ features: WellnessFeatures) -> Double? {
        guard let average = features.avgHRV else {
            return nil
        }

        let trend = features.hrvTrend ?? 0
        return max(0, average + min(0, trend))
    }

    private func estimatedMaximumHRV(_ features: WellnessFeatures) -> Double? {
        guard let average = features.avgHRV else {
            return nil
        }

        let trend = features.hrvTrend ?? 0
        return max(0, average + max(0, trend))
    }

    private func estimatedHRVDeviationPercent(_ features: WellnessFeatures) -> Double? {
        guard let average = features.avgHRV,
              let trend = features.hrvTrend,
              average > 0 else {
            return nil
        }

        return (trend / average) * 100
    }

    private func estimatedRestingHRBaseline(_ features: WellnessFeatures) -> Double? {
        features.avgRestingHR
    }

    private func estimatedRestingHRDeviation(_ features: WellnessFeatures) -> Double? {
        guard let restingHR = features.avgRestingHR else {
            return nil
        }

        return restingHR - 70
    }

    private func estimatedSleepBaseline(_ features: WellnessFeatures) -> Double? {
        if let sleepAverage = features.sleepAverage {
            return max(sleepAverage, 7.5)
        }

        return 7.5
    }

    private func estimatedSleepRatio(_ features: WellnessFeatures) -> Double? {
        guard let sleepAverage = features.sleepAverage,
              let baseline = estimatedSleepBaseline(features),
              baseline > 0 else {
            return nil
        }

        return sleepAverage / baseline
    }

    private func predictedLabel(from prediction: MLFeatureProvider) -> String? {
        if let label = prediction.featureValue(for: "classLabel")?.stringValue, !label.isEmpty {
            return label
        }

        if let index = prediction.featureValue(for: "classLabel")?.int64Value,
           let label = classLabel(at: Int(index)) {
            return label
        }

        if let doubleIndex = prediction.featureValue(for: "classLabel")?.doubleValue,
           doubleIndex.isFinite,
           let label = classLabel(at: Int(doubleIndex)) {
            return label
        }

        if let label = prediction.featureValue(for: "target_label")?.stringValue, !label.isEmpty {
            return label
        }

        return topProbability(from: prediction)?.label
    }

    private func predictedConfidence(from prediction: MLFeatureProvider) -> Double? {
        topProbability(from: prediction)?.probability
    }

    private func topProbability(from prediction: MLFeatureProvider) -> (label: String, probability: Double)? {
        guard let dictionary = prediction.featureValue(for: "classProbability")?.dictionaryValue else {
            return nil
        }

        return dictionary
            .compactMap { key, value -> (String, Double)? in
                let probability = value.doubleValue
                let label: String
                if let stringKey = key as? String {
                    label = stringKey
                } else if let index = key as? Int {
                    label = classLabel(at: index) ?? "\(index)"
                } else if let numberKey = key as? NSNumber {
                    label = classLabel(at: numberKey.intValue) ?? numberKey.stringValue
                } else {
                    label = key.description
                }
                return label.isEmpty ? nil : (label, probability)
            }
            .max { $0.probability < $1.probability }
    }

    private func classLabel(at index: Int) -> String? {
        guard classLabels.indices.contains(index) else {
            return nil
        }

        return classLabels[index]
    }

    private static func loadClassLabels(from url: URL?) -> [String] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let labels = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }

        return labels
    }

    private func state(for label: String) -> WellnessState? {
        switch label {
        case "recovery_good", "normal", "feeling_good":
            return .balanced
        case "mild_stress", "tired", "poor_recovery":
            return .needRecovery
        case "attention_stress", "high_stress":
            return .highStrain
        case "sleep_debt":
            return .sleepDebt
        case "low_activity":
            return .lowActivity
        case "data_insufficient":
            return .dataInsufficient
        default:
            return nil
        }
    }
}
