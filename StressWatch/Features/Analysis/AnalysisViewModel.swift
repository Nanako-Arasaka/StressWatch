import Foundation

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published private(set) var analysis: WellnessAnalysis
    @Published private(set) var advice: [String]
    @Published private(set) var todayCheckIn: DailyWellnessCheckIn?
    @Published private(set) var checkInErrorMessage: String?

    private let metrics: [HealthMetric]
    private let stressScore: StressScore?
    private let recoveryScore: RecoveryScore?
    private let stressTrend: [Double]
    private let storage: any LocalStorageProtocol
    private let featureExtractor: any HealthFeatureExtracting
    private let analyzer: any WellnessAnalyzing
    private let adviceGenerator: any AdviceGenerating

    init(
        metrics: [HealthMetric],
        stressScore: StressScore?,
        recoveryScore: RecoveryScore?,
        stressTrend: [Double],
        storage: any LocalStorageProtocol,
        featureExtractor: any HealthFeatureExtracting = FeatureExtractor(),
        analyzer: any WellnessAnalyzing = CoreMLWellnessAnalyzer(),
        adviceGenerator: any AdviceGenerating = AdviceGenerator()
    ) {
        self.metrics = metrics
        self.stressScore = stressScore
        self.recoveryScore = recoveryScore
        self.stressTrend = stressTrend
        self.storage = storage
        self.featureExtractor = featureExtractor
        self.analyzer = analyzer
        self.adviceGenerator = adviceGenerator

        let initialFeatures = featureExtractor.extract(
            metrics: metrics,
            stressScore: stressScore,
            recoveryScore: recoveryScore,
            stressTrend: stressTrend,
            now: Date()
        )
        let initialAnalysis = analyzer.analyze(features: initialFeatures)
        self.analysis = initialAnalysis
        self.advice = adviceGenerator.advice(for: initialAnalysis)
        self.todayCheckIn = try? storage.fetchTodayCheckIn()
        self.checkInErrorMessage = nil
    }

    var confidenceText: String {
        "\(Int(round(analysis.confidence * 100)))%"
    }

    var analysisSourceText: String {
        analysis.source.displayName
    }

    var factorSourceSubtitle: String {
        switch analysis.source {
        case .coreMLPersonalModel:
            return "模型使用本地 Core ML 输出和近期趋势特征生成参考。"
        case .ruleBased, .coreMLUnavailableRuleFallback:
            return "模型使用可解释规则筛选近期变化较明显的特征。"
        }
    }

    var featureRows: [AnalysisFeatureRow] {
        let features = analysis.features
        return [
            AnalysisFeatureRow(title: "Avg HRV", value: format(features.avgHRV, suffix: " ms")),
            AnalysisFeatureRow(title: "HRV Trend", value: formatSigned(features.hrvTrend, suffix: " ms")),
            AnalysisFeatureRow(title: "Avg HR", value: format(features.avgHeartRate, suffix: " bpm")),
            AnalysisFeatureRow(title: "Resting HR", value: format(features.avgRestingHR, suffix: " bpm")),
            AnalysisFeatureRow(title: "Sleep Avg", value: features.sleepAverage.map(formatHours) ?? "暂无"),
            AnalysisFeatureRow(title: "Sleep Consistency", value: formatPercent(features.sleepConsistency)),
            AnalysisFeatureRow(title: "REM Avg", value: features.remSleepAverage.map(formatHours) ?? "暂无"),
            AnalysisFeatureRow(title: "Core Avg", value: features.coreSleepAverage.map(formatHours) ?? "暂无"),
            AnalysisFeatureRow(title: "Deep Avg", value: features.deepSleepAverage.map(formatHours) ?? "暂无"),
            AnalysisFeatureRow(title: "Awake Avg", value: features.awakeAverage.map(formatHours) ?? "暂无"),
            AnalysisFeatureRow(title: "Steps Avg", value: formatInteger(features.stepsAverage)),
            AnalysisFeatureRow(title: "Activity Level", value: formatPercent(features.activityLevel)),
            AnalysisFeatureRow(title: "Recovery Avg", value: formatInteger(features.recoveryAverage)),
            AnalysisFeatureRow(title: "Stress Avg", value: formatInteger(features.stressAverage))
        ]
    }

    func refresh() {
        let features = featureExtractor.extract(
            metrics: metrics,
            stressScore: stressScore,
            recoveryScore: recoveryScore,
            stressTrend: stressTrend,
            now: Date()
        )
        let newAnalysis = analyzer.analyze(features: features)
        analysis = newAnalysis
        advice = adviceGenerator.advice(for: newAnalysis)
        todayCheckIn = try? storage.fetchTodayCheckIn()
    }

    func saveTodayCheckIn(label: DailyWellnessLabel) {
        let checkIn = DailyWellnessCheckIn(
            date: Date(),
            label: label,
            note: nil,
            createdAt: Date()
        )

        do {
            try storage.saveDailyCheckIn(checkIn)
            todayCheckIn = checkIn
            checkInErrorMessage = nil
        } catch {
            checkInErrorMessage = "无法保存今日记录"
        }
    }

    var todayCheckInStatusText: String {
        if let todayCheckIn {
            return "今日已记录：\(todayCheckIn.label.displayName)"
        }

        return "今日尚未记录"
    }

    private func format(_ value: Double?, suffix: String) -> String {
        guard let value else {
            return "暂无"
        }

        return "\(Int(round(value)))\(suffix)"
    }

    private func formatSigned(_ value: Double?, suffix: String) -> String {
        guard let value else {
            return "暂无"
        }

        let rounded = Int(round(value))
        return "\(rounded >= 0 ? "+" : "")\(rounded)\(suffix)"
    }

    private func formatInteger(_ value: Double?) -> String {
        guard let value else {
            return "暂无"
        }

        return "\(Int(round(value)))"
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else {
            return "暂无"
        }

        return "\(Int(round(value * 100)))%"
    }
}

struct AnalysisFeatureRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}
