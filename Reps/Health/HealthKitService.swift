import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var hasWriteAuthorization: Bool {
        guard isAvailable else { return false }
        return writableTypes.contains {
            healthStore.authorizationStatus(for: $0) == .sharingAuthorized
        }
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        try await healthStore.requestAuthorization(toShare: writableTypes, read: readableTypes)
        await enableBackgroundDelivery()
    }

    private var writableTypes: Set<HKSampleType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKWorkoutType.workoutType()
        ]
    }

    private var readableTypes: Set<HKObjectType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.waistCircumference),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis),
            HKSeriesType.workoutRoute(),
            HKWorkoutType.workoutType()
        ]
    }

    func fetchLatestBodyMetrics() async throws -> (weightKg: Double?, heightCm: Double?) {
        guard isAvailable else { throw HealthKitError.unavailable }

        let weight = try await latestQuantity(for: HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo))
        let height = try await latestQuantity(for: HKQuantityType(.height), unit: .meterUnit(with: .centi))

        return (weight, height)
    }

    func fetchBodyWellnessDefaults(for date: Date = .now) async throws -> BodyWellnessDefaults {
        guard isAvailable else { throw HealthKitError.unavailable }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let bodyFat = try await latestQuantity(
            for: HKQuantityType(.bodyFatPercentage),
            unit: .percent()
        ).map { $0 * 100 }
        let waist = try await latestQuantity(
            for: HKQuantityType(.waistCircumference),
            unit: .meterUnit(with: .centi)
        )
        let sleepHours = try await sleepHours(from: startOfDay, to: endOfDay)
        let water = try await cumulativeValue(
            for: HKQuantityType(.dietaryWater),
            unit: .liter(),
            from: startOfDay,
            to: endOfDay
        )
        let dietaryEnergy = try await cumulativeValue(
            for: HKQuantityType(.dietaryEnergyConsumed),
            unit: .kilocalorie(),
            from: startOfDay,
            to: endOfDay
        )
        let activeEnergy = try await cumulativeValue(
            for: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            from: startOfDay,
            to: endOfDay
        )
        let exerciseMinutes = try await cumulativeValue(
            for: HKQuantityType(.appleExerciseTime),
            unit: .minute(),
            from: startOfDay,
            to: endOfDay
        )
        let restingHeartRate = try await averageValue(
            for: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: startOfDay,
            to: endOfDay
        )
        let heartRateVariability = try await averageValue(
            for: HKQuantityType(.heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli),
            from: startOfDay,
            to: endOfDay
        )

        return BodyWellnessDefaults(
            bodyFatPercentage: bodyFat,
            waistCm: waist,
            sleepHours: sleepHours,
            waterLiters: positive(water),
            dietaryEnergyKcal: positive(dietaryEnergy),
            sleepQuality: Self.estimatedSleepQuality(
                sleepHours: sleepHours,
                heartRateVariabilityMS: heartRateVariability
            ),
            fatigue: Self.estimatedFatigue(
                sleepHours: sleepHours,
                activeEnergyKcal: activeEnergy,
                exerciseMinutes: exerciseMinutes,
                restingHeartRate: restingHeartRate,
                heartRateVariabilityMS: heartRateVariability
            ),
            stress: Self.estimatedStress(
                sleepHours: sleepHours,
                restingHeartRate: restingHeartRate,
                heartRateVariabilityMS: heartRateVariability
            )
        )
    }

    func fetchDailyMetrics(days: Int = 30) async throws -> [DailyHealthMetric] {
        guard isAvailable else { throw HealthKitError.unavailable }

        let steps = try await dailyCumulativeValues(for: HKQuantityType(.stepCount), unit: .count(), days: days)
        let activeEnergy = try await dailyCumulativeValues(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), days: days)
        let exerciseMinutes = try await dailyCumulativeValues(for: HKQuantityType(.appleExerciseTime), unit: .minute(), days: days)
        let dietaryEnergy = try await dailyCumulativeValues(for: HKQuantityType(.dietaryEnergyConsumed), unit: .kilocalorie(), days: days)
        let water = try await dailyCumulativeValues(for: HKQuantityType(.dietaryWater), unit: .liter(), days: days)
        let restingHeartRate = try await dailyAverageValues(
            for: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: days
        )
        let heartRateVariability = try await dailyAverageValues(
            for: HKQuantityType(.heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli),
            days: days
        )

        let calendar = Calendar.current
        let dates = Set(steps.keys)
            .union(activeEnergy.keys)
            .union(exerciseMinutes.keys)
            .union(dietaryEnergy.keys)
            .union(water.keys)
            .union(restingHeartRate.keys)
            .union(heartRateVariability.keys)

        return dates.sorted().map { date in
            DailyHealthMetric(
                date: date,
                steps: steps[calendar.startOfDay(for: date)] ?? 0,
                activeEnergyKcal: activeEnergy[calendar.startOfDay(for: date)] ?? 0,
                dietaryEnergyKcal: dietaryEnergy[calendar.startOfDay(for: date)] ?? 0,
                waterLiters: water[calendar.startOfDay(for: date)] ?? 0,
                exerciseMinutes: exerciseMinutes[calendar.startOfDay(for: date)],
                restingHeartRate: restingHeartRate[calendar.startOfDay(for: date)],
                heartRateVariabilityMS: heartRateVariability[calendar.startOfDay(for: date)]
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

    func saveDailyNutrition(waterLiters: Double?, dietaryEnergyKcal: Double?, date: Date = .now) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        var samples: [HKSample] = []
        if let waterLiters, waterLiters > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryWater),
                quantity: HKQuantity(unit: .liter(), doubleValue: waterLiters),
                start: date,
                end: date
            ))
        }
        if let dietaryEnergyKcal, dietaryEnergyKcal > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryEnergyConsumed),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: dietaryEnergyKcal),
                start: date,
                end: date
            ))
        }

        guard !samples.isEmpty else { return }
        try await healthStore.save(samples)
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
            let sensors = try? await fetchWorkoutSensorSummary(start: workout.startDate, end: workout.endDate)
            logs.append(CardioLog(
                activityType: CardioLog.ActivityType(workoutActivityType: workout.workoutActivityType),
                date: workout.startDate,
                durationMinutes: max(Int(workout.duration / 60), 1),
                distanceKm: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)),
                averageSpeedKmh: nil,
                averagePaceSecondsPerKm: nil,
                averageHeartRate: heartRate?.average ?? sensors?.averageHeartRate,
                maxHeartRate: heartRate?.max ?? sensors?.maxHeartRate,
                estimatedCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                steps: sensors?.steps,
                activeEnergyKcal: sensors?.activeEnergyKcal,
                heartRateBefore: sensors?.heartRateBefore,
                heartRateAfter: sensors?.heartRateAfter,
                rpe: nil,
                notes: localizedString("imported_from_apple_health")
            ))
        }

        return logs
    }

    func fetchWorkoutSensorSummary(start: Date, end: Date) async throws -> WorkoutSensorSummary {
        guard isAvailable else { throw HealthKitError.unavailable }

        let normalizedEnd = max(end, start.addingTimeInterval(60))
        let heartRate = try await heartRateSummary(from: start, to: normalizedEnd)
        let steps = try await cumulativeValue(
            for: HKQuantityType(.stepCount),
            unit: .count(),
            from: start,
            to: normalizedEnd
        )
        let activeEnergy = try await cumulativeValue(
            for: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            from: start,
            to: normalizedEnd
        )
        let beforeWindowStart = start.addingTimeInterval(-15 * 60)
        let afterWindowEnd = normalizedEnd.addingTimeInterval(15 * 60)

        return WorkoutSensorSummary(
            steps: positive(steps),
            activeEnergyKcal: positive(activeEnergy),
            averageHeartRate: heartRate.average,
            maxHeartRate: heartRate.max,
            heartRateBefore: try await averageValue(
                for: HKQuantityType(.heartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                from: beforeWindowStart,
                to: start
            ),
            heartRateAfter: try await averageValue(
                for: HKQuantityType(.heartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                from: normalizedEnd,
                to: afterWindowEnd
            )
        )
    }

    func saveWorkout(_ session: WorkoutSession) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        let start = session.startedAt ?? session.date
        let end = session.endedAt ?? Calendar.current.date(byAdding: .minute, value: session.durationMinutes, to: start) ?? start
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = session.healthKitWorkoutActivityType
        configuration.locationType = session.location == .outdoor ? .outdoor : (session.location == .home ? .indoor : .unknown)

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

        if let distanceKm = session.distanceKm, distanceKm > 0 {
            let sample = HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
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

    private func cumulativeValue(for type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: unit)
    }

    private func averageValue(for type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .discreteAverage)
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.averageQuantity()?.doubleValue(for: unit)
    }

    private func sleepHours(from startDate: Date, to endDate: Date) async throws -> Double? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )

        let samples = try await descriptor.result(for: healthStore)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let seconds = samples.reduce(0) { total, sample in
            guard asleepValues.contains(sample.value) else { return total }
            return total + sample.endDate.timeIntervalSince(sample.startDate)
        }

        guard seconds > 0 else { return nil }
        return seconds / 3600
    }

    private static func estimatedSleepQuality(sleepHours: Double?, heartRateVariabilityMS: Double?) -> Int? {
        guard sleepHours != nil || heartRateVariabilityMS != nil else { return nil }

        var score = 3
        if let sleepHours {
            if sleepHours >= 8 { score += 2 }
            else if sleepHours >= 7 { score += 1 }
            else if sleepHours < 5.5 { score -= 2 }
            else if sleepHours < 6.5 { score -= 1 }
        }
        if let heartRateVariabilityMS {
            if heartRateVariabilityMS >= 70 { score += 1 }
            else if heartRateVariabilityMS < 35 { score -= 1 }
        }

        return clamped(score)
    }

    private static func estimatedFatigue(
        sleepHours: Double?,
        activeEnergyKcal: Double?,
        exerciseMinutes: Double?,
        restingHeartRate: Double?,
        heartRateVariabilityMS: Double?
    ) -> Int? {
        guard sleepHours != nil || activeEnergyKcal != nil || exerciseMinutes != nil || restingHeartRate != nil || heartRateVariabilityMS != nil else {
            return nil
        }

        var score = 3
        if let sleepHours, sleepHours < 6 { score += 1 }
        if let activeEnergyKcal, activeEnergyKcal > 700 { score += 1 }
        if let exerciseMinutes, exerciseMinutes > 75 { score += 1 }
        if let restingHeartRate, restingHeartRate > 75 { score += 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS < 35 { score += 1 }
        if let sleepHours, sleepHours >= 8 { score -= 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS >= 70 { score -= 1 }

        return clamped(score)
    }

    private static func estimatedStress(
        sleepHours: Double?,
        restingHeartRate: Double?,
        heartRateVariabilityMS: Double?
    ) -> Int? {
        guard sleepHours != nil || restingHeartRate != nil || heartRateVariabilityMS != nil else { return nil }

        var score = 3
        if let sleepHours, sleepHours < 6 { score += 1 }
        if let restingHeartRate, restingHeartRate > 75 { score += 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS < 35 { score += 1 }
        if let sleepHours, sleepHours >= 7.5 { score -= 1 }
        if let restingHeartRate, restingHeartRate < 58 { score -= 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS >= 70 { score -= 1 }

        return clamped(score)
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 1), 5)
    }

    private func positive(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
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

    private func dailyAverageValues(for type: HKQuantityType, unit: HKUnit, days: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: samplePredicate,
            options: .discreteAverage,
            anchorDate: endDate,
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: healthStore)
        var values: [Date: Double] = [:]

        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let average = statistics.averageQuantity()?.doubleValue(for: unit) {
                values[calendar.startOfDay(for: statistics.startDate)] = average
            }
        }

        return values
    }

    private func enableBackgroundDelivery() async {
        guard isAvailable else { return }

        for case let type as HKQuantityType in readableTypes {
            try? await healthStore.enableBackgroundDelivery(for: type, frequency: .hourly)
        }
        try? await healthStore.enableBackgroundDelivery(for: HKWorkoutType.workoutType(), frequency: .immediate)
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

    private func heartRateSummary(from startDate: Date, to endDate: Date) async throws -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
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

private extension WorkoutSession {
    var healthKitWorkoutActivityType: HKWorkoutActivityType {
        let title = workoutTitle.lowercased()
        if title.contains("camina") || title.contains("walk") {
            return .walking
        }
        if title.contains("carrera") || title.contains("run") {
            return .running
        }
        if distanceKm != nil || !routePoints.isEmpty {
            return .walking
        }
        return .traditionalStrengthTraining
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
