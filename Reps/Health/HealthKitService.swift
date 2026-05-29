import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        let bodyMass = HKQuantityType(.bodyMass)
        let height = HKQuantityType(.height)
        let readTypes: Set<HKObjectType> = [
            bodyMass,
            height,
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.heartRate),
            HKWorkoutType.workoutType()
        ]
        let shareTypes: Set<HKSampleType> = [bodyMass, height, HKWorkoutType.workoutType()]

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func fetchLatestBodyMetrics() async throws -> (weightKg: Double?, heightCm: Double?) {
        guard isAvailable else { throw HealthKitError.unavailable }

        let weight = try await latestQuantity(for: HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo))
        let height = try await latestQuantity(for: HKQuantityType(.height), unit: .meterUnit(with: .centi))

        return (weight, height)
    }

    func fetchDailyMetrics(days: Int = 30) async throws -> [DailyHealthMetric] {
        guard isAvailable else { throw HealthKitError.unavailable }

        let steps = try await dailyCumulativeValues(for: HKQuantityType(.stepCount), unit: .count(), days: days)
        let activeEnergy = try await dailyCumulativeValues(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), days: days)
        let dietaryEnergy = try await dailyCumulativeValues(for: HKQuantityType(.dietaryEnergyConsumed), unit: .kilocalorie(), days: days)
        let water = try await dailyCumulativeValues(for: HKQuantityType(.dietaryWater), unit: .liter(), days: days)

        let calendar = Calendar.current
        let dates = Set(steps.keys).union(activeEnergy.keys).union(dietaryEnergy.keys).union(water.keys)

        return dates.sorted().map { date in
            DailyHealthMetric(
                date: date,
                steps: steps[calendar.startOfDay(for: date)] ?? 0,
                activeEnergyKcal: activeEnergy[calendar.startOfDay(for: date)] ?? 0,
                dietaryEnergyKcal: dietaryEnergy[calendar.startOfDay(for: date)] ?? 0,
                waterLiters: water[calendar.startOfDay(for: date)] ?? 0
            )
        }
    }

    func saveBodyMetrics(weightKg: Double, heightCm: Double, date: Date = .now) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        let weightSample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg),
            start: date,
            end: date
        )

        let heightSample = HKQuantitySample(
            type: HKQuantityType(.height),
            quantity: HKQuantity(unit: .meterUnit(with: .centi), doubleValue: heightCm),
            start: date,
            end: date
        )

        try await healthStore.save([weightSample, heightSample])
    }

    func fetchRecentCardioLogs(days: Int = 90) async throws -> [CardioLog] {
        guard isAvailable else { throw HealthKitError.unavailable }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: HKObjectQueryNoLimit
        )

        let workouts = try await descriptor.result(for: healthStore)
        var logs: [CardioLog] = []

        for workout in workouts where workout.isCardioLike {
            let heartRate = try? await heartRateSummary(for: workout)
            logs.append(CardioLog(
                activityType: CardioLog.ActivityType(workoutActivityType: workout.workoutActivityType),
                date: workout.startDate,
                durationMinutes: max(Int(workout.duration / 60), 1),
                distanceKm: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)),
                averageSpeedKmh: nil,
                averagePaceSecondsPerKm: nil,
                averageHeartRate: heartRate?.average,
                maxHeartRate: heartRate?.max,
                estimatedCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                rpe: nil,
                notes: String(localized: "Importado desde Apple Health")
            ))
        }

        return logs
    }

    func saveWorkout(_ session: WorkoutSession) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        let start = session.startedAt ?? session.date
        let end = session.endedAt ?? Calendar.current.date(byAdding: .minute, value: session.durationMinutes, to: start) ?? start
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = session.location == .home ? .indoor : .unknown

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.addMetadata([
            HKMetadataKeyWorkoutBrandName: "Reps",
            HKMetadataKeyCoachedWorkout: false
        ])
        try await builder.beginCollection(at: start)

        if let calories = session.estimatedCalories {
            let sample = HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                start: start,
                end: end
            )
            try await addSamples([sample], to: builder)
        }

        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    private func latestQuantity(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        let samples = try await descriptor.result(for: healthStore)
        return samples.first?.quantity.doubleValue(for: unit)
    }

    private func dailyCumulativeValues(for type: HKQuantityType, unit: HKUnit, days: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: samplePredicate,
            options: .cumulativeSum,
            anchorDate: endDate,
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: healthStore)
        var values: [Date: Double] = [:]

        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            values[calendar.startOfDay(for: statistics.startDate)] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }

        return values
    }

    private func heartRateSummary(for workout: HKWorkout) async throws -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let samplePredicate = HKSamplePredicate.quantitySample(type: heartRateType, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: [.discreteAverage, .discreteMax]
        )

        let statistics = try await descriptor.result(for: healthStore)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return (
            statistics?.averageQuantity()?.doubleValue(for: unit),
            statistics?.maximumQuantity()?.doubleValue(for: unit)
        )
    }

    private func addSamples(_ samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum HealthKitError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health no está disponible en este dispositivo."
        }
    }
}

private extension HKWorkout {
    var isCardioLike: Bool {
        switch workoutActivityType {
        case .running, .walking, .cycling, .elliptical, .rowing, .highIntensityIntervalTraining:
            true
        default:
            false
        }
    }
}

private extension CardioLog.ActivityType {
    init(workoutActivityType: HKWorkoutActivityType) {
        switch workoutActivityType {
        case .running:
            self = .outdoorRun
        case .walking:
            self = .walking
        case .cycling:
            self = .stationaryBike
        case .elliptical:
            self = .elliptical
        case .rowing:
            self = .rowing
        case .highIntensityIntervalTraining:
            self = .hiit
        default:
            self = .other
        }
    }
}
