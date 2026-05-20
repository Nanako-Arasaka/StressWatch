import Foundation
import HealthKit

class HealthKitService: HealthKitDataProvider {
    private let healthStore: HKHealthStore
    private var isAuthorized: Bool

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
        self.isAuthorized = false
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        guard let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            throw HealthKitServiceError.unavailable
        }

        let readTypes: Set<HKObjectType> = [
            heartRate,
            hrv,
            restingHeartRate,
            steps,
            sleep
        ]

        try await requestAuthorization(readTypes: readTypes)
        isAuthorized = true
    }

    func authorizationStatus() -> HealthKitAuthStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }
        return isAuthorized ? .authorized : .notDetermined
    }

    func fetchMetrics(types: [MetricType], from: Date, to: Date) async throws -> [HealthMetric] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        if !isAuthorized {
            try await requestAuthorization()
        }

        var metrics: [HealthMetric] = []

        for type in types {
            switch type {
            case .heartRate:
                metrics += try await fetchQuantityMetrics(
                    type: .heartRate,
                    quantityIdentifier: .heartRate,
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    unitLabel: "bpm",
                    from: from,
                    to: to
                )
            case .hrv:
                metrics += try await fetchQuantityMetrics(
                    type: .hrv,
                    quantityIdentifier: .heartRateVariabilitySDNN,
                    unit: .secondUnit(with: .milli),
                    unitLabel: "ms",
                    from: from,
                    to: to
                )
            case .restingHeartRate:
                metrics += try await fetchQuantityMetrics(
                    type: .restingHeartRate,
                    quantityIdentifier: .restingHeartRate,
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    unitLabel: "bpm",
                    from: from,
                    to: to
                )
            case .steps:
                metrics += try await fetchQuantityMetrics(
                    type: .steps,
                    quantityIdentifier: .stepCount,
                    unit: .count(),
                    unitLabel: "steps",
                    from: from,
                    to: to
                )
            case .sleep:
                metrics += try await fetchSleepMetrics(from: from, to: to)
            }
        }

        return metrics.sorted { $0.date < $1.date }
    }

    private func fetchQuantityMetrics(
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

    private func fetchSleepMetrics(from: Date, to: Date) async throws -> [HealthMetric] {
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

        return samples.compactMap { sample in
            guard sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            else {
                return nil
            }

            let hours = max(0, sample.endDate.timeIntervalSince(sample.startDate) / 3600)
            return HealthMetric(
                id: sample.uuid,
                type: .sleep,
                value: hours,
                unit: "hours",
                date: sample.endDate
            )
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
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume(returning: ())
                } else {
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
