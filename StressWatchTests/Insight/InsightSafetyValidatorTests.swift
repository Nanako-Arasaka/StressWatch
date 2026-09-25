import XCTest
@testable import StressWatch

final class InsightSafetyValidatorTests: XCTestCase {

    private var now: Date { TestCalendar.referenceNow }

    // MARK: - 医疗术语

    func test_medicalTerm_flagged() {
        let insight = makeInsight(summary: "你被诊断为高血压倾向")
        let result = makeResult()
        let validation = InsightSafetyValidator.validate(insight, against: result)
        XCTAssertFalse(validation.isSafe)
        XCTAssertTrue(validation.violations.contains { $0.contains("医疗") })
    }

    // MARK: - 因果动词

    func test_causalVerb_flagged() {
        let insight = makeInsight(summary: "睡眠不足导致了你的压力升高")
        let result = makeResult()
        let validation = InsightSafetyValidator.validate(insight, against: result)
        XCTAssertFalse(validation.isSafe)
        XCTAssertTrue(validation.violations.contains { $0.contains("因果") })
    }

    // MARK: - 数值回溯

    func test_fabricatedNumber_flagged() {
        // 声称 HRV 是 99ms，但结果里是 42
        let insight = makeInsight(summary: "你的 HRV 是 99ms，低于基线")
        let result = makeResult()
        let validation = InsightSafetyValidator.validate(insight, against: result)
        XCTAssertTrue(validation.hasSuspectNumbers)
        XCTAssertTrue(validation.suspectNumbers.contains("99"))
    }

    func test_validNumber_passes() {
        // 引用结果中的真实数字
        let insight = makeInsight(summary: "你的 HRV 是 42ms，基线是 51ms")
        let result = makeResult()
        let validation = InsightSafetyValidator.validate(insight, against: result)
        XCTAssertTrue(validation.suspectNumbers.isEmpty)
    }

    // MARK: - 安全文本

    func test_safeText_passes() {
        let insight = makeInsight(
            summary: "数据显示你的 HRV 可能低于个人近期水平，可以观察到睡眠也偏短。",
            suggestions: ["建议保持规律作息", "可以关注休息节奏"]
        )
        let result = makeResult()
        let validation = InsightSafetyValidator.validate(insight, against: result)
        XCTAssertTrue(validation.isSafe)
        XCTAssertTrue(validation.suspectNumbers.isEmpty)
    }

    // MARK: - AI 腔

    func test_aiSlop_flagged() {
        let insight = makeInsight(summary: "You are crushing it! 太棒了！")
        let result = makeResult()
        let validation = InsightSafetyValidator.validate(insight, against: result)
        XCTAssertFalse(validation.isSafe)
    }

    // MARK: - Helpers

    private func makeInsight(
        summary: String,
        suggestions: [String] = []
    ) -> PersonalizationInsight {
        PersonalizationInsight(
            summary: summary,
            findings: [],
            suggestions: suggestions,
            tone: "平稳",
            generatedAt: now,
            windowDays: 7
        )
    }

    private func makeResult() -> StructuredAnalysisResult {
        StructuredAnalysisResult(
            generatedAt: now,
            dataSource: .appleHealth,
            baselineWindowDays: 14,
            stressScore: 64,
            stressLevel: .medium,
            recoveryScore: 71,
            recoveryLevel: .good,
            metrics: [
                MetricDeviation(metric: .hrv, value: 42, unit: "ms", baseline: 51, deviationPercent: -17.6, trend: .declining, provenance: .measured),
                MetricDeviation(metric: .restingHeartRate, value: 68, unit: "bpm", baseline: 63, deviationPercent: 7.9, trend: .stable, provenance: .measured),
                MetricDeviation(metric: .sleepHours, value: 6.4, unit: "hours", baseline: 7.3, deviationPercent: -12.3, trend: .stable, provenance: .measured),
                MetricDeviation(metric: .steps, value: 8000, unit: "steps", baseline: 8000, deviationPercent: 0, trend: .stable, provenance: .measured)
            ],
            sleepQuality: SleepQualityAnalysis(
                durationHours: 6.4, baselineHours: 7.3,
                deviationPercent: -12.3, qualityLabel: "belowBaseline",
                remPercent: 22, deepPercent: 18
            ),
            activityLevel: .moderate,
            trends: [],
            associations: [],
            confidence: .high,
            completeness: DataCompleteness(
                availableMetrics: [.hrv, .restingHeartRate, .sleepHours, .steps],
                missingMetrics: [.activeEnergyKcal, .exerciseMinutes, .standHours, .sleepREMHours, .sleepDeepHours],
                coreCompleteness: 1.0,
                overallCompleteness: 0.55,
                historyDays: 14
            ),
            warnings: []
        )
    }
}

final class AnalysisPrivacyGuardTests: XCTestCase {

    func test_allConditionsMet_canSend() {
        XCTAssertTrue(AnalysisPrivacyGuard.canSendHealthDataToLLM(
            enabled: true, hasKey: true, dataSource: .appleHealth
        ))
    }

    func test_disabled_cannotSend() {
        XCTAssertFalse(AnalysisPrivacyGuard.canSendHealthDataToLLM(
            enabled: false, hasKey: true, dataSource: .appleHealth
        ))
    }

    func test_noKey_cannotSend() {
        XCTAssertFalse(AnalysisPrivacyGuard.canSendHealthDataToLLM(
            enabled: true, hasKey: false, dataSource: .appleHealth
        ))
    }

    func test_demoDataSource_cannotSend() {
        // T6.5：demo 数据禁止上云
        XCTAssertFalse(AnalysisPrivacyGuard.canSendHealthDataToLLM(
            enabled: true, hasKey: true, dataSource: .demo
        ))
    }

    func test_denyReason_demoDataSource() {
        let reason = AnalysisPrivacyGuard.denyReason(
            enabled: true, hasKey: true, dataSource: .demo
        )
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("演示"))
    }

    func test_denyReason_nilWhenAllowed() {
        let reason = AnalysisPrivacyGuard.denyReason(
            enabled: true, hasKey: true, dataSource: .appleHealth
        )
        XCTAssertNil(reason)
    }
}
