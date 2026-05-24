import Foundation

protocol HealthFeatureExtracting {
    func extract(
        metrics: [HealthMetric],
        stressScore: StressScore?,
        recoveryScore: RecoveryScore?,
        stressTrend: [Double],
        now: Date
    ) -> WellnessFeatures
}

// FeatureExtractor 将最近 7 天健康数据转换为可解释的机器学习特征。
// 当前阶段只做本地统计，后续可把 WellnessFeatures 直接交给 Core ML 模型。
struct FeatureExtractor: HealthFeatureExtracting {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func extract(
        metrics: [HealthMetric],
        stressScore: StressScore?,
        recoveryScore: RecoveryScore?,
        stressTrend: [Double],
        now: Date = Date()
    ) -> WellnessFeatures {
        let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let recentMetrics = metrics.filter { $0.date >= startDate && $0.date <= now }

        let hrvValues = values(for: .hrv, in: recentMetrics)
        let heartRateValues = values(for: .heartRate, in: recentMetrics)
        let restingHRValues = values(for: .restingHeartRate, in: recentMetrics)
        let sleepValues = values(for: .sleep, in: recentMetrics)
        let stepsValues = values(for: .steps, in: recentMetrics)
        let activeEnergyValues = values(for: .activeEnergyBurned, in: recentMetrics)
        let exerciseValues = values(for: .appleExerciseTime, in: recentMetrics)
        let standValues = values(for: .appleStandTime, in: recentMetrics)
        let stressValues: [Double]
        if stressTrend.isEmpty {
            stressValues = stressScore.map { [Double($0.value)] } ?? []
        } else {
            stressValues = stressTrend
        }

        let activeEnergyAverage = average(activeEnergyValues)
        let exerciseAverage = average(exerciseValues)
        let standAverage = average(standValues)
        let activityLevel = makeActivityLevel(
            activeEnergyAverage: activeEnergyAverage,
            exerciseMinutesAverage: exerciseAverage,
            standHoursAverage: standAverage
        )

        let featureValues: [Double?] = [
            average(hrvValues),
            trend(hrvValues),
            average(heartRateValues),
            average(restingHRValues),
            average(sleepValues),
            sleepConsistency(sleepValues),
            average(stepsValues),
            activeEnergyAverage,
            exerciseAverage,
            standAverage,
            activityLevel,
            recoveryScore.map { Double($0.value) },
            average(stressValues)
        ]
        let availableCount = featureValues.compactMap { $0 }.count
        let confidence = clamp(Double(availableCount) / Double(featureValues.count), 0, 1)

        return WellnessFeatures(
            avgHRV: average(hrvValues),
            hrvTrend: trend(hrvValues),
            avgHeartRate: average(heartRateValues),
            avgRestingHR: average(restingHRValues),
            sleepAverage: average(sleepValues),
            sleepConsistency: sleepConsistency(sleepValues),
            remSleepAverage: average(values(for: .sleepREM, in: recentMetrics)),
            coreSleepAverage: average(values(for: .sleepCore, in: recentMetrics)),
            deepSleepAverage: average(values(for: .sleepDeep, in: recentMetrics)),
            awakeAverage: average(values(for: .sleepAwake, in: recentMetrics)),
            stepsAverage: average(stepsValues),
            activeEnergyAverage: activeEnergyAverage,
            exerciseMinutesAverage: exerciseAverage,
            standHoursAverage: standAverage,
            activityLevel: activityLevel,
            recoveryAverage: recoveryScore.map { Double($0.value) },
            stressAverage: average(stressValues),
            availableFeatureCount: availableCount,
            dataConfidence: confidence
        )
    }

    private func values(for type: MetricType, in metrics: [HealthMetric]) -> [Double] {
        metrics
            .filter { $0.type == type }
            .sorted { $0.date < $1.date }
            .map(\.value)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private func trend(_ values: [Double]) -> Double? {
        guard let first = values.first, let last = values.last, values.count >= 2 else {
            return nil
        }

        return last - first
    }

    private func sleepConsistency(_ values: [Double]) -> Double? {
        guard values.count >= 2, let averageValue = average(values) else {
            return nil
        }

        let variance = values
            .map { pow($0 - averageValue, 2) }
            .reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        return clamp(1 - standardDeviation / 2, 0, 1)
    }

    private func makeActivityLevel(
        activeEnergyAverage: Double?,
        exerciseMinutesAverage: Double?,
        standHoursAverage: Double?
    ) -> Double? {
        let components = [
            activeEnergyAverage.map { clamp($0 / 500, 0, 1) },
            exerciseMinutesAverage.map { clamp($0 / 30, 0, 1) },
            standHoursAverage.map { clamp($0 / 12, 0, 1) }
        ].compactMap { $0 }

        guard !components.isEmpty else {
            return nil
        }

        return components.reduce(0, +) / Double(components.count)
    }
}
