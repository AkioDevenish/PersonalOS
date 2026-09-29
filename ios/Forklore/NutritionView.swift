import SwiftUI

/// The meal engine, in the app.
struct NutritionView: View {
    @EnvironmentObject var health: HealthKitManager
    @Environment(Store.self) private var store
    @ObservedObject private var readings = Readings.shared
    @State private var latest = ""
    @State private var status = ""
    @State private var isBusy = false
    /// Breakfast, not "next meal".
    @State private var context = "breakfast"

    private let contexts = ["breakfast", "lunch", "dinner", "snack"]

    /// Persisted: where you cook is a standing fact, not a per-meal choice.
    @AppStorage(Cuisine.key) private var country = Cuisine.deviceDefault
    @State private var choosingCountry = false

    /// Dishes for the chosen country, handed to the meal prompt.
    @State private var book = CuisineClient.Book.empty
    @State private var locked = false

    /// Today's snapshot, held only so the screen can show what it's reading.
    @State private var today: HealthSnapshot?

    /// The metabolic and activity signals the suggestion is built from — the same metric ids the
    /// prompt uses, so this can't drift from what the model was actually handed.
    private var signals: [(label: String, value: String, symbol: String)] {
        guard let today else { return [] }
        return ["glucose", "carbs", "sleep", "active_energy", "steps"]
            .compactMap { Metrics.by(id: $0) }
            .compactMap { spec in
                guard let shown = spec.display(today) else { return nil }
                let unit = spec.unit.isEmpty ? "" : " \(spec.unit)"
                return (spec.label, shown + unit, spec.symbol)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Nutrition", color: Theme.accent, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("What to eat next.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 8)
                    .flowIn(1)

                Text(country.isEmpty
                     ? "Based on your recent glucose, sleep and activity."
                     : "Based on your recent glucose, sleep and activity, with food from \(Cuisine.name(for: country)).")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                // The claim above is that this reads your data.
                if !signals.isEmpty {
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            Kicker(text: "Today's numbers", size: 9)
                            ForEach(signals, id: \.label) { s in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: s.symbol)
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 14, alignment: .leading)
                                    Text(s.label)
                                        .font(Theme.sans(11))
                                        .foregroundStyle(Theme.secondaryText)
                                    Spacer()
                                    Text(s.value)
                                        .font(Theme.serif(17))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    .flowIn(3)
                }

                Button {
                    choosingCountry = true
                } label: {
                    HStack(spacing: 12) {
                        Kicker(text: "Cooking in", size: 9)
                        Spacer()
                        Text(Cuisine.name(for: country))
                            .font(Theme.serif(19))
                            .foregroundStyle(country.isEmpty ? Theme.tertiaryText : Theme.text)
                            .contentTransition(.opacity)
                        Text("›").font(Theme.serif(18)).foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressRow)
                .padding(.top, 14)
                .flowIn(4)

                PillPicker(
                    values: contexts,
                    selection: $context,
                    size: 9.5,
                    tracking: 1.4,
                    padding: 12
                ) { $0 }
                    .padding(.top, 8)
                    .flowIn(5)

                Button {
                    Task { await generate() }
                } label: {
                    Text(isBusy ? "Thinking…" : "Suggest \(context)")
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.surface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.text)
                        .clipShape(Capsule())
                        // The label changes under you while it works; the words should cross-fade
                        // rather than jump.
                        .contentTransition(.opacity)
                        .animation(Theme.Motion.flow, value: isBusy)
                }
                .buttonStyle(.press)
                .disabled(isBusy)
                .padding(.top, 16)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                if isBusy {
                    Composing(lines: 5)
                        .padding(.top, 22)
                        .transition(.opacity)
                }

                if !latest.isEmpty && !isBusy {
                    Plate {
                        TypedText(runs: MealReading.runs(for: MealReading.parse(latest)))
                    }
                    .padding(.top, 18)
                }

                let suggested = readings.of(.meal)
                if !suggested.isEmpty {
                    SectionRule(text: "Recently suggested").padding(.top, 32)
                    ForEach(suggested) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            Kicker(text: r.at.formatted(date: .abbreviated, time: .shortened), size: 9)
                            Text(MealReading.clean(r.text))
                                .font(Theme.serifBody(16))
                                .foregroundStyle(Theme.text)
                                .lineSpacing(5)
                        }
                        .padding(.vertical, 14)
                    }
                }

                Spacer(minLength: 40)
            }
            // A suggestion arriving pushes the history down the page; it should slide rather than
            // jump.
            .animation(Theme.Motion.flow, value: latest)
            .animation(Theme.Motion.flow, value: isBusy)
            .animation(Theme.Motion.flow, value: status)
            .animation(Theme.Motion.flow, value: signals.count)
            .padding(.horizontal, 24)
        }
        .compactsTabBar()
        .appBackground()
        .task { await loadSignals() }
        .task { await loadBook() }
        .onChange(of: country) { _, _ in
            book = .empty
            Task { await loadBook() }
        }
        .sheet(isPresented: $choosingCountry) {
            CountryPicker(code: $country)
        }
        .subscriptionNeeded($locked, toDo: "write you a suggestion")
    }

    private func loadBook() async {
        guard !country.isEmpty else { book = .empty; return }
        let client = CuisineClient()
        try? await client.prepare(country: country)
        book = (try? await client.book(country: country)) ?? .empty
        // Generation takes a few seconds; check back until it lands.
        var tries = 0
        while book.generating, tries < 20, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            book = (try? await client.book(country: country)) ?? book
            tries += 1
        }
    }

    private func loadSignals() async {
        try? await health.requestAuthorization()
        today = try? await health.fetchTodaySnapshot()
    }

    private func generate() async {
        // The reading is written on this phone and costs nothing to serve, so this is a price on
        // the feature rather than on a bill we pay.
        guard !Paywall.enabled || store.entitlement.isSubscribed else { locked = true; return }
        isBusy = true
        status = ""
        defer { isBusy = false }
        do {
            // Written on this iPhone, from HealthKit, and never leaving it.
            let snaps = try await health.fetchHistoricalSnapshots(days: 7)
            latest = try await OnDeviceInsights.generate(
                instructions: InsightPrompts.mealInstructions,
                prompt: InsightPrompts.meals(
                    snapshots: snaps,
                    context: context,
                    country: Cuisine.name(for: country),
                    dishes: book.canon
                ),
                temperature: 0.8
            )
            readings.add(Reading(kind: .meal, text: latest))
        } catch {
            status = error.localizedDescription
        }
    }
}
