import Foundation
import HealthKit

class HealthKitService: HealthKitDataProvider {
    private let healthStore: HKHealthStore
    private let authorizationRequestedKey = "StressWatch.HealthKitAuthorizationRequested"
    private let calendar: Calendar
    private let standTimeIdentifier = HKQuantityTypeIdentifier(rawValue: "HKQuantityTypeIdentifierAppleStandTime")

    init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKitService] requestAuthorization unavailable: health data is not available")
            throw HealthKitServiceError.unavailable
        }

        let readTypes = try makeReadTypes()
        print("[HealthKitService] requestAuthorization readTypes=\(readTypes.map { $0.identifier }.sorted())")
        try await requestAuthorization(readTypes: readTypes)
        UserDefaults.standard.set(true, forKey: authorizationRequestedKey)
        print("[HealthKitService] requestAuthorization completed")
    }

    func authorizationStatus() -> HealthKitAuthStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        return UserDefaults.standard.bool(forKey: authorizationRequestedKey) ? .authorized : .notDetermined
    }

    func fetchMetrics(types: [MetricType], from: Date, to: Date) async throws -> [HealthMetric] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        if !UserDefaults.standard.bool(forKey: authorizationRequestedKey) {
            try await requestAuthorization()
        }

        var metrics: [HealthMetric] = []

        // 单项指标读取失败时只跳过该指标，避免一个缺失项拖垮整个 Dashboard。
        for type in types {
            do {
                switch type {
                case .heartRate:
                    metrics += try await fetchQuantitySamples(
                        type: .heartRate,
                        quantityIdentifier: .heartRate,
                        unit: HKUnit.count().unitDivided(by: .minute()),
                        unitLabel: "bpm",
                        from: from,
                        to: to
                    )
                case .hrv:
                    metrics += try await fetchQuantitySamples(
                        type: .hrv,
                        quantityIdentifier: .heartRateVariabilitySDNN,
                        unit: .secondUnit(with: .milli),
                        unitLabel: "ms",
                        from: from,
                        to: to
                    )
                case .restingHeartRate:
                    metrics += try await fetchQuantitySamples(
                        type: .restingHeartRate,
                        quantityIdentifier: .restingHeartRate,
                        unit: HKUnit.count().unitDivided(by: .minute()),
                        unitLabel: "bpm",
                        from: from,
                        to: to
                    )
                case .steps:
                    metrics += try await fetchDailyStepTotals(from: from, to: to)
                case .sleep:
                    metrics += try await fetchDailySleepAnalysis(from: from, to: to)
                case .activeEnergyBurned:
                    metrics += try await fetchDailyActiveEnergyTotals(from: from, to: to)
                case .appleExerciseTime:
                    metrics += try await fetchDailyExerciseTimeTotals(from: from, to: to)
                case .appleStandTime:
                    metrics += try await fetchDailyStandTimeTotals(from: from, to: to)
                case .sleepREM, .sleepCore, .sleepDeep, .sleepAwake:
                    continue
                }
            } catch {
                print("[HealthKitService] fetchMetrics skipped \(type.rawValue): \(error)")
                continue
            }
        }

        return metrics.sorted { $0.date < $1.date }
    }

    private func makeReadTypes() throws -> Set<HKObjectType> {
        guard let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        else {
            throw HealthKitServiceError.unavailable
        }

        var readTypes: Set<HKObjectType> = [
            heartRate,
            hrv,
            restingHeartRate,
            steps,
            sleep,
            activeEnergy,
            exerciseTime
        ]

        if #available(iOS 18.0, *),
           let standTime = HKObjectType.quantityType(forIdentifier: standTimeIdentifier) {
            readTypes.insert(standTime)
        }

        return readTypes
    }

    private func fetchQuantitySamples(
        type: MetricType,
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        unitLabel: String,
        from: Date,
        to: Date
    ) async throws -> [HealthMetric] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw HealthKitServiceError.unavailable
        }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples = try await executeSampleQuery(
            sampleType: quantityType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor]
        ).compactMap { $0 as? HKQuantitySample }

        return samples.map { sample in
            HealthMetric(
                id: sample.uuid,
                type: type,
                value: sample.quantity.doubleValue(for: unit),
                unit: unitLabel,
                date: sample.endDate
            )
        }
    }

    private func fetchDailyStepTotals(from: Date, to: Date) async throws -> [HealthMetric] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitServiceError.unavailable
        }

        let dailyTotals = try await executeStatisticsCollectionQuery(
            quantityType: quantityType,
            unit: .count(),
            from: from,
            to: to
        )

        return dailyTotals.map { day, value in
            HealthMetric(
                id: UUID(),
                type: .steps,
                value: value,
                unit: "steps",
                date: calendar.endOfDay(for: day)
            )
        }
    }

    private func fetchDailyActiveEnergyTotals(from: Date, to: Date) async throws -> [HealthMetric] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitServiceError.unavailable
        }

        let dailyTotals = try await executeStatisticsCollectionQuery(
            quantityType: quantityType,
            unit: .kilocalorie(),
            from: from,
            to: to
        )

        return dailyTotals.map { day, value in
            HealthMetric(
                id: UUID(),
                type: .activeEnergyBurned,
                value: value,
                unit: "kcal",
                date: calendar.endOfDay(for: day)
            )
        }
    }

    private func fetchDailyExerciseTimeTotals(from: Date, to: Date) async throws -> [HealthMetric] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitServiceError.unavailable
        }

        let dailyTotals = try await executeStatisticsCollectionQuery(
            quantityType: quantityType,
            unit: .minute(),
            from: from,
            to: to
        )

        return dailyTotals.map { day, value in
            HealthMetric(
                id: UUID(),
                type: .appleExerciseTime,
                value: value,
                unit: "min",
                date: calendar.endOfDay(for: day)
            )
        }
    }

    private func fetchDailyStandTimeTotals(from: Date, to: Date) async throws -> [HealthMetric] {
        guard #available(iOS 18.0, *) else {
            return []
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: standTimeIdentifier) else {
            throw HealthKitServiceError.unavailable
        }

        let dailyTotals = try await executeStatisticsCollectionQuery(
            quantityType: quantityType,
            unit: .hour(),
            from: from,
            to: to
        )

        return dailyTotals.map { day, value in
            HealthMetric(
                id: UUID(),
                type: .appleStandTime,
                value: value,
                unit: "h",
                date: calendar.endOfDay(for: day)
            )
        }
    }

    private func fetchDailySleepAnalysis(from: Date, to: Date) async throws -> [HealthMetric] {
        guard let categoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.unavailable
        }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples = try await executeSampleQuery(
            sampleType: categoryType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor]
        ).compactMap { $0 as? HKCategorySample }

        // 总睡眠只累计真正 asleep 阶段；awake 只作为阶段摘要展示，不计入总时长。
        var totalsByDay: [Date: Double] = [:]
        var stageHoursByTypeAndDay: [MetricType: [Date: Double]] = [
            .sleepREM: [:],
            .sleepCore: [:],
            .sleepDeep: [:],
            .sleepAwake: [:]
        ]

        samples.forEach { sample in
            let hours = max(0, sample.endDate.timeIntervalSince(sample.startDate) / 3600)
            let day = calendar.startOfDay(for: sample.endDate)

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                totalsByDay[day, default: 0] += hours
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                totalsByDay[day, default: 0] += hours
                stageHoursByTypeAndDay[.sleepREM, default: [:]][day, default: 0] += hours
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                totalsByDay[day, default: 0] += hours
                stageHoursByTypeAndDay[.sleepCore, default: [:]][day, default: 0] += hours
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                totalsByDay[day, default: 0] += hours
                stageHoursByTypeAndDay[.sleepDeep, default: [:]][day, default: 0] += hours
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stageHoursByTypeAndDay[.sleepAwake, default: [:]][day, default: 0] += hours
            default:
                break
            }
        }

        var metrics = totalsByDay.map { day, hours in
            HealthMetric(
                id: UUID(),
                type: .sleep,
                value: hours,
                unit: "hours",
                date: calendar.endOfDay(for: day)
            )
        }

        stageHoursByTypeAndDay.forEach { type, dailyHours in
            metrics += dailyHours.map { day, hours in
                HealthMetric(
                    id: UUID(),
                    type: type,
                    value: hours,
                    unit: "hours",
                    date: calendar.endOfDay(for: day)
                )
            }
        }

        return metrics
    }

    private func executeStatisticsCollectionQuery(
        quantityType: HKQuantityType,
        unit: HKUnit,
        from: Date,
        to: Date
    ) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Date: Double], Error>) in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let anchorDate = calendar.startOfDay(for: from)
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let collection else {
                    continuation.resume(returning: [:])
                    return
                }

                var values: [Date: Double] = [:]
                collection.enumerateStatistics(from: from, to: to) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    if value > 0 {
                        values[self.calendar.startOfDay(for: statistics.startDate)] = value
                    }
                }

                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    private func executeSampleQuery(
        sampleType: HKSampleType,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor]
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func requestAuthorization(readTypes: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes) { success, error in
                if let error {
                    print("[HealthKitService] HKHealthStore authorization error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    print("[HealthKitService] HKHealthStore authorization success callback")
                    continuation.resume(returning: ())
                } else {
                    print("[HealthKitService] HKHealthStore authorization failed callback")
                    continuation.resume(throwing: HealthKitServiceError.authorizationFailed)
                }
            }
        }
    }
}

enum HealthKitServiceError: Error {
    case unavailable
    case authorizationFailed
}

extension HealthKitServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "HealthKit 不可用"
        case .authorizationFailed:
            return "HealthKit 授权失败或被拒绝"
        }
    }
}
