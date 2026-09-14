import Foundation
import HealthKit
import Combine

/// Reading and writing the cycle, and nothing else.
///
/// Its own store rather than a method on `HealthKitManager`, for two reasons
/// that are both about keeping the boundary visible.
///
/// The first is permission. `HealthKitManager` asks for nineteen types the
/// moment somebody syncs, and reproductive data has no business in that
/// prompt: nobody opening a step counter should be asked to hand over their
/// period. This asks separately, when the cycle screen is first opened, for
/// the one type it needs.
///
/// The second is that this is the only object in the app that touches
/// reproductive data at all. Nothing it returns is a `HealthSnapshot`, so
/// nothing it returns can reach the Convex sync or the text a practitioner is
/// sent. Both of those compose from a snapshot and neither has a route to
/// this.
///
/// It is also the only place in the app that asks to *write* to Apple Health.
/// Everything else reads. A period logged here belongs in the system's own
/// Cycle Tracking, where it is encrypted at rest, where Apple Watch can use it
/// for a retrospective ovulation estimate this app cannot make, and where a
/// person can delete it without trusting us to honour that.
@MainActor
final class CycleStore: ObservableObject {
    private let store = HKHealthStore()

    @Published private(set) var reading = Cycle.Reading.empty
    @Published private(set) var loading = true
    @Published private(set) var denied = false

    /// The one type this feature needs. Ovulation tests, cervical mucus,
    /// sexual activity and the rest exist in HealthKit and are deliberately
    /// not asked for: every extra type is another thing to hold and another
    /// line in a permission sheet, and none of them is needed to answer where
    /// somebody is in their cycle.
    private var flowType: HKCategoryType? {
        HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
    }

    /// Roughly a year, which is enough to see a pattern and to notice one
    /// changing, and not so much that a first read is slow.
    private let window = 400

    func load() async {
        guard HKHealthStore.isHealthDataAvailable(), let flowType else {
            loading = false
            return
        }
        do {
            // Read and write together: the screen both shows the cycle and
            // records today, and asking twice would be two sheets for one
            // decision.
            try await store.requestAuthorization(toShare: [flowType], read: [flowType])
            denied = false
        } catch {
            denied = true
            loading = false
            return
        }
        reading = Cycle.read(await days())
        loading = false
    }

    /// Records today, or changes what was already recorded.
    ///
    /// Marks a cycle start when nothing was bled on in the two days before, so
    /// the boundary is written into Apple Health rather than left for
    /// everything downstream to infer from gaps.
    func log(_ flow: Cycle.Flow, on date: Date = Date()) async {
        guard let flowType else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start)?
            .addingTimeInterval(-1) else { return }

        // Replace rather than stack. Two flows for one day is not a thing a
        // body does, and it would break the run-length counting.
        await remove(on: start)

        let recent = reading.periods.first.map {
            (calendar.dateComponents([.day], from: $0.start, to: start).day ?? 99) <= $0.days + 1
        } ?? false

        let sample = HKCategorySample(
            type: flowType,
            value: flow.category.rawValue,
            start: start,
            end: end,
            metadata: [HKMetadataKeyMenstrualCycleStart: flow.isBleeding && !recent]
        )

        try? await store.save(sample)
        reading = Cycle.read(await days())
    }

    /// Takes a day back out, for a mis-tap.
    func remove(on date: Date) async {
        guard let flowType else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let existing: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: flowType, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in continuation.resume(returning: samples ?? []) }
            store.execute(query)
        }
        // Only ours. A sample written by Apple Health or another app is not
        // this app's to delete, and HealthKit refuses anyway.
        let mine = existing.filter { $0.sourceRevision.source == HKSource.default() }
        if !mine.isEmpty { try? await store.delete(mine) }
    }

    func refresh() async {
        reading = Cycle.read(await days())
    }

    private func days() async -> [Cycle.Day] {
        guard let flowType,
              let from = Calendar.current.date(byAdding: .day, value: -window, to: Date())
        else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: [])
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: flowType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let days = (samples as? [HKCategorySample] ?? []).map { sample in
                    Cycle.Day(
                        date: sample.startDate,
                        flow: Cycle.Flow(rawValue: sample.value) ?? .unspecified,
                        marksCycleStart: sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool ?? false
                    )
                }
                continuation.resume(returning: days)
            }
            store.execute(query)
        }
    }
}
