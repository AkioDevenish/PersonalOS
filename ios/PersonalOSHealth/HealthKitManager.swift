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

    // MARK: Read, never written
    //
    // Everything below arrives from whatever app the person already uses:
    // Libre or Dexcom for glucose, a food app for the macros, Omron for blood
    // pressure, the Health app itself for medications and cycle. This app is a
    // reader of that bus. It does not write to HealthKit, and in particular it
    // never writes a macro it guessed, because a guessed number stored beside
    // measured ones stops being distinguishable from a measurement.
    var dietaryProteinG: Double? = nil
    var dietaryEnergyKcal: Double? = nil
    /// The pair, from one reading rather than two separate averages: a systolic
    /// from the morning beside a diastolic from the evening is not a blood
    /// pressure, it is two numbers.
    var bloodPressureSystolic: Double? = nil
    var bloodPressureDiastolic: Double? = nil
    var bloodPressureAt: Date? = nil
    /// Names of the medications the person keeps in Health, not archived.
    var medications: [String] = []
    /// How many doses were logged as taken today. Absent is not zero.
    var medicationDosesTaken: Double? = nil
    /// HKCategoryValueMenstrualFlow: 1 unspecified, 2 light, 3 medium, 4 heavy.
    var menstrualFlow: Double? = nil
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
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) { types.insert(protein) }
        if let energyIn = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(energyIn) }
        if let systolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) { types.insert(systolic) }
        if let diastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) { types.insert(diastolic) }
        if let bp = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) { types.insert(bp) }
        if let flow = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) { types.insert(flow) }
        // Medications arrived in iOS 26 as their own object types rather than
        // as samples with an identifier, so they are asked for by type.
        types.insert(HKObjectType.userAnnotatedMedicationType())
        types.insert(HKObjectType.medicationDoseEventType())
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
        
        async let protein = cumulative(.dietaryProtein, unit: .gram(), predicate: predicate)
        async let energyIn = cumulative(.dietaryEnergyConsumed, unit: .kilocalorie(), predicate: predicate)
        async let pressure = latestBloodPressure(predicate: predicate)
        async let flow = latestCategoryValue(.menstrualFlow, predicate: predicate)
        async let meds = medicationNames()
        async let dosesTaken = medicationDosesTaken(predicate: predicate)
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
            stateOfMindValence: somValence,
            dietaryProteinG: await protein,
            dietaryEnergyKcal: await energyIn,
            bloodPressureSystolic: await pressure?.systolic,
            bloodPressureDiastolic: await pressure?.diastolic,
            bloodPressureAt: await pressure?.at,
            medications: await meds,
            medicationDosesTaken: await dosesTaken,
            menstrualFlow: await flow
        )
    }

    /// The last blood pressure of the day, as a pair from one reading.
    ///
    /// Read as a correlation rather than as two quantity queries. Averaging
    /// systolic and diastolic separately across a day would produce a pair that
    /// nobody's arm ever recorded, and a morning systolic beside an evening
    /// diastolic is not a blood pressure.
    private func latestBloodPressure(
        predicate: NSPredicate
    ) async -> (systolic: Double, diastolic: Double, at: Date)? {
        guard let type = HKCorrelationType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        else { return nil }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let correlation = samples?.first as? HKCorrelation,
                      let systolic = correlation.objects(for: systolicType).first as? HKQuantitySample,
                      let diastolic = correlation.objects(for: diastolicType).first as? HKQuantitySample
                else { return continuation.resume(returning: nil) }

                let mmHg = HKUnit.millimeterOfMercury()
                continuation.resume(returning: (
                    systolic.quantity.doubleValue(for: mmHg),
                    diastolic.quantity.doubleValue(for: mmHg),
                    correlation.endDate
                ))
            }
            store.execute(query)
        }
    }

    /// The heaviest flow recorded on the day. A day with light in the morning
    /// and heavy by evening is a heavy day.
    private func latestCategoryValue(
        _ identifier: HKCategoryTypeIdentifier,
        predicate: NSPredicate
    ) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let values = (samples as? [HKCategorySample])?.map { Double($0.value) } ?? []
                continuation.resume(returning: values.max())
            }
            store.execute(query)
        }
    }

    /// The medications a person keeps in Health, by the name they call them.
    ///
    /// Their nickname wins over the clinical display text, because someone who
    /// has renamed it to "the blue one" has told you what to call it.
    private func medicationNames() async -> [String] {
        // This query enumerates rather than returning a batch: the handler runs
        // once per medication and once more with `done`. So the names are
        // gathered as they arrive and handed back at the end, exactly once.
        await withCheckedContinuation { continuation in
            var names: [String] = []
            var finished = false
            let query = HKUserAnnotatedMedicationQuery(
                predicate: nil,
                limit: HKObjectQueryNoLimit
            ) { _, medication, done, _ in
                if let medication, !medication.isArchived {
                    let name = medication.nickname ?? medication.medication.displayText
                    if !name.isEmpty { names.append(name) }
                }
                guard done, !finished else { return }
                finished = true
                continuation.resume(returning: names.sorted())
            }
            store.execute(query)
        }
    }

    /// Doses logged as actually taken. Skipped, snoozed and untouched
    /// reminders are not doses, and counting them would report a day of
    /// medication that did not happen.
    private func medicationDosesTaken(predicate: NSPredicate) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.medicationDoseEventType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let events = samples as? [HKMedicationDoseEvent], !events.isEmpty else {
                    return continuation.resume(returning: nil)
                }
                let taken = events.filter { $0.logStatus == .taken }.count
                continuation.resume(returning: Double(taken))
            }
            store.execute(query)
        }
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
