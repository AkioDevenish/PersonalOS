import Foundation
import HealthKit
import Combine

struct HealthSnapshot {
    let recordedAt: Date
    let steps: Double?
    let distanceKm: Double?
    let flightsClimbed: Double?
    let walkingSpeedKmh: Double?
    let walkingSteadiness: Double?
    let avgBloodGlucoseMgdl: Double?
    let dietaryCarbohydratesG: Double?
    let insulinDeliveryIu: Double?
    let walkingAsymmetryPct: Double?
    let walkingStepLength: Double?
    let walkingDoubleSupportPct: Double?
    let stairAscentSpeed: Double?
    let activeEnergyBurned: Double?
    let basalEnergyBurned: Double?
    let headphoneAudioExposure: Double?
    let mindfulSessionMins: Double?
    let timeInDaylight: Double?
    let totalSleepHours: Double?
    let restingHeartRate: Double?
    let stateOfMindLabels: String?
    let stateOfMindValence: Double?
}

enum HealthKitError: LocalizedError {
    case unavailable
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .unavailable: return "HealthKit is not available on this device"
        case .unauthorized: return "Health access not granted. Open Settings → Health → Data Access"
        }
    }
}

@MainActor
final class HealthKitManager: ObservableObject {
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(distance) }
        if let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) { types.insert(flights) }
        if let speed = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) { types.insert(speed) }
        if let steadiness = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness) {
            types.insert(steadiness)
        }
        if let glucose = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) { types.insert(glucose) }
        if let carbs = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) { types.insert(carbs) }
        if let insulin = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) { types.insert(insulin) }
        if let asymmetry = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) { types.insert(asymmetry) }
        if let stepLength = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) { types.insert(stepLength) }
        if let doubleSupport = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) { types.insert(doubleSupport) }
        if let stairSpeed = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) { types.insert(stairSpeed) }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(basalEnergy) }
        if let audioEx = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) { types.insert(audioEx) }
        if let daylight = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) { types.insert(daylight) }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) { types.insert(mindful) }
        if #available(iOS 17.0, *) {
            let stateOfMind = HKObjectType.stateOfMindType()
            types.insert(stateOfMind)
        }
        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchTodaySnapshot() async throws -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        return try await fetchSnapshotForDay(Date())
    }

    /// Fetch snapshots for the last N days (including today). Used for backfilling 7d/30d history.
    func fetchHistoricalSnapshots(days: Int = 30) async throws -> [HealthSnapshot] {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        var snapshots: [HealthSnapshot] = []
        let calendar = Calendar.current
        for offset in 0..<days {
            guard let targetDate = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let snapshot = try await fetchSnapshotForDay(targetDate)
            snapshots.append(snapshot)
        }
        return snapshots
    }

    private func fetchSnapshotForDay(_ date: Date) async throws -> HealthSnapshot {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.unavailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        // Sleep and mindful sessions often start the previous day and end on the current day.
        // strictEndDate ensures we capture them if they finished today.
        let categoryPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictEndDate)

        async let steps = cumulative(.stepCount, unit: .count(), predicate: predicate)
        async let distanceM = cumulative(.distanceWalkingRunning, unit: .meter(), predicate: predicate)
        async let flights = cumulative(.flightsClimbed, unit: .count(), predicate: predicate)
        async let speed = average(.walkingSpeed, unit: HKUnit.meter().unitDivided(by: .second()), predicate: predicate)
        async let steadiness = average(.appleWalkingSteadiness, unit: .percent(), predicate: predicate)
        async let glucose = average(.bloodGlucose, unit: HKUnit(from: "mg/dL"), predicate: predicate)
        async let carbs = cumulative(.dietaryCarbohydrates, unit: .gram(), predicate: predicate)
        async let insulin = cumulative(.insulinDelivery, unit: .internationalUnit(), predicate: predicate)
        
        async let asymmetry = average(.walkingAsymmetryPercentage, unit: .percent(), predicate: predicate)
        async let stepLength = average(.walkingStepLength, unit: .meter(), predicate: predicate)
        async let doubleSupport = average(.walkingDoubleSupportPercentage, unit: .percent(), predicate: predicate)
        async let stairSpeed = average(.stairAscentSpeed, unit: HKUnit.meter().unitDivided(by: .second()), predicate: predicate)
        async let activeEnergy = cumulative(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        async let basalEnergy = cumulative(.basalEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        async let audioEx = average(.headphoneAudioExposure, unit: .decibelAWeightedSoundPressureLevel(), predicate: predicate)
        async let daylight = cumulative(.timeInDaylight, unit: .minute(), predicate: predicate)
        async let restingHR = average(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate)
        
        async let sleepSeconds = categoryDurationSum(.sleepAnalysis, predicate: categoryPredicate)
        async let mindfulSeconds = categoryDurationSum(.mindfulSession, predicate: categoryPredicate)
        
        var somLabels: String? = nil
        var somValence: Double? = nil
        if #available(iOS 17.0, *) {
            let som = await fetchStateOfMind(predicate: categoryPredicate)
            somLabels = som.0
            somValence = som.1
        }

        let distanceKm = await distanceM.map { $0 / 1000.0 }
        let speedKmh = await speed.map { $0 * 3.6 }
        let totalSleepHours = await sleepSeconds.map { $0 / 3600.0 }
        let mindfulMins = await mindfulSeconds.map { $0 / 60.0 }

        return HealthSnapshot(
            recordedAt: date,
            steps: await steps,
            distanceKm: distanceKm,
            flightsClimbed: await flights,
            walkingSpeedKmh: speedKmh,
            walkingSteadiness: await steadiness,
            avgBloodGlucoseMgdl: await glucose,
            dietaryCarbohydratesG: await carbs,
            insulinDeliveryIu: await insulin,
            walkingAsymmetryPct: await asymmetry,
            walkingStepLength: await stepLength,
            walkingDoubleSupportPct: await doubleSupport,
            stairAscentSpeed: await stairSpeed,
            activeEnergyBurned: await activeEnergy,
            basalEnergyBurned: await basalEnergy,
            headphoneAudioExposure: await audioEx,
            mindfulSessionMins: mindfulMins,
            timeInDaylight: await daylight,
            totalSleepHours: totalSleepHours,
            restingHeartRate: await restingHR,
            stateOfMindLabels: somLabels,
            stateOfMindValence: somValence
        )
    }

    private func cumulative(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await statisticsSum(type: type, unit: unit, predicate: predicate)
    }

    private func average(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func statisticsSum(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func categoryDurationSum(
        _ identifier: HKCategoryTypeIdentifier,
        predicate: NSPredicate
    ) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let totalSeconds = samples?.compactMap { $0.endDate.timeIntervalSince($0.startDate) }.reduce(0, +)
                continuation.resume(returning: totalSeconds)
            }
            store.execute(query)
        }
    }

    @available(iOS 17.0, *)
    private func fetchStateOfMind(predicate: NSPredicate) async -> (String?, Double?) {
        let type = HKObjectType.stateOfMindType()
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKStateOfMind else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                // Map rawValues to strings because Apple doesn't expose string representations natively
                let labelStrings: [String] = sample.labels.compactMap { label in
                    switch label.rawValue {
                    case 1: return "Amazed"
                    case 2: return "Amused"
                    case 3: return "Angry"
                    case 4: return "Anxious"
                    case 5: return "Awed"
                    case 6: return "Brave"
                    case 7: return "Calm"
                    case 8: return "Content"
                    case 9: return "Disappointed"
                    case 10: return "Discouraged"
                    case 11: return "Disgusted"
                    case 12: return "Embarrassed"
                    case 13: return "Excited"
                    case 14: return "Frustrated"
                    case 15: return "Grateful"
                    case 16: return "Guilty"
                    case 17: return "Happy"
                    case 18: return "Hopeful"
                    case 19: return "Hurt"
                    case 20: return "Jealous"
                    case 21: return "Joyful"
                    case 22: return "Lonely"
                    case 23: return "Passionate"
                    case 24: return "Peaceful"
                    case 25: return "Proud"
                    case 26: return "Relieved"
                    case 27: return "Sad"
                    case 28: return "Scared"
                    case 29: return "Stressed"
                    case 30: return "Surprised"
                    default: return nil
                    }
                }
                let labelsStr = labelStrings.joined(separator: ", ")
                continuation.resume(returning: (labelsStr, sample.valence))
            }
            store.execute(query)
        }
    }
}
