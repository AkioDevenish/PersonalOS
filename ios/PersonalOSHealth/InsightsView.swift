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

    /// What people say they eat here.
    @State private var book = CuisineClient.Book.empty
    @State private var newDish = ""
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
                            Kicker(text: "Reading right now", size: 9)
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

                if !country.isEmpty {
                    SectionRule(text: "What people eat here").padding(.top, 34)

                    Text(book.all.isEmpty
                         ? "Nothing named yet. Add a dish you eat."
                         : "Dishes eaten in \(Cuisine.name(for: country)). Hold one to say it isn't.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineSpacing(3)
                        .padding(.top, 10)

                    VStack(spacing: 0) {
                        ForEach(book.all) { d in
                            Button {
                                Task { await vote(d.dish) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(d.dish)
                                        .font(Theme.serif(18))
                                        .foregroundStyle(d.mine ? Theme.accent : Theme.text)
                                    Spacer()
                                    Text(voteLine(d))
                                        .font(Theme.sans(9.5))
                                        .tracking(1.2)
                                        .foregroundStyle(Theme.tertiaryText)
                                    if d.mine { SelectionMark(size: 12) }
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressRow)
                            .contextMenu {
                                // Only offered for dishes nobody has vouched for.
                                if d.canBeRejected(threshold: book.threshold) {
                                    Button("Not eaten here", systemImage: "xmark.circle", role: .destructive) {
                                        Task { await reject(d.dish) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 6)

                    HStack(spacing: 12) {
                        TextField("Name a dish", text: $newDish)
                            .font(Theme.serif(18))
                            .foregroundStyle(Theme.text)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { Task { await add() } }

                        Button {
                            Task { await add() }
                        } label: {
                            Kicker(text: "Add", color: Theme.accent, size: 10)
                        }
                        .buttonStyle(.press)
                        .disabled(newDish.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 14)
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
        .background(Theme.background)
        .task { await loadSignals() }
        .task { await loadBook() }
        .onChange(of: country) { _, _ in
            book = .empty
            Task { await loadBook() }
        }
        .animation(Theme.Motion.flow, value: book.all)
        .sheet(isPresented: $choosingCountry) {
            CountryPicker(code: $country)
        }
        .subscriptionNeeded($locked, toDo: "write you a suggestion")
    }

    private func voteLine(_ d: CuisineClient.Dish) -> String {
        guard d.votes > 0 else { return "" }
        return d.votes == 1 ? "named by 1" : "named by \(d.votes)"
    }

    private func reject(_ dish: String) async {
        Haptics.tap()
        try? await CuisineClient().reject(country: country, dish: dish)
        book = (try? await CuisineClient().book(country: country)) ?? book
    }

    private func loadBook() async {
        guard !country.isEmpty else { book = .empty; return }
        book = (try? await CuisineClient().book(country: country)) ?? .empty
    }

    private func vote(_ dish: String) async {
        Haptics.select()
        try? await CuisineClient().suggest(country: country, dish: dish)
        book = (try? await CuisineClient().book(country: country)) ?? book
    }

    private func add() async {
        let dish = newDish.trimmingCharacters(in: .whitespaces)
        guard !dish.isEmpty else { return }
        newDish = ""
        await vote(dish)
    }

    private func loadSignals() async {
        try? await health.requestAuthorization()
        today = try? await health.fetchTodaySnapshot()
    }

    private func generate() async {
        // The reading is written on this phone and costs nothing to serve, so this is a price on
        // the feature rather than on a bill we pay.
        guard store.entitlement.isSubscribed else { locked = true; return }
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

/// Expert reports — the personas the analyze route already knows how to be.
struct ExpertsView: View {
    @EnvironmentObject var health: HealthKitManager
    @Environment(Store.self) private var store
    @EnvironmentObject private var notifier: Notifier
    @State private var expert = InsightPrompts.experts[0].key
    /// Hourly, not daily.
    @State private var period = "hourly"
    @ObservedObject private var readings = Readings.shared
    @State private var status = ""
    @State private var isBusy = false
    /// On-device reports aren't stored on a server, so they live here for the session.
    @State private var localReport = ""
    @State private var locked = false

    /// One list, in InsightPrompts, shared by the screen and by the on-device prompts.
    private var experts: [InsightPrompts.Expert] { InsightPrompts.experts }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Consult", color: Theme.accent, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("Read by a specialist.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 8)
                    .flowIn(1)

                Text("Patterns only, never a diagnosis.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                VStack(spacing: 0) {
                    ForEach(experts, id: \.key) { e in
                        Button {
                            guard expert != e.key else { return }
                            Haptics.select()
                            withAnimation(Theme.Motion.bouncy) { expert = e.key }
                        } label: {
                            HStack {
                                Text(e.label)
                                    .font(Theme.serif(19))
                                    .foregroundStyle(expert == e.key ? Theme.accent : Theme.text)
                                Spacer()
                                if expert == e.key {
                                    SelectionMark()
                                }
                            }
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressRow)
                    }
                }
                .padding(.top, 22)
                .flowIn(3)

                PillPicker(
                    values: ["hourly", "daily", "weekly", "monthly"],
                    selection: $period,
                    size: 9,
                    tracking: 1.2,
                    padding: 12
                ) { $0 }
                    .padding(.top, 20)

                // The button used to say only "Ask for a new reading", which left you guessing
                // which specialist and which window you were about to spend a minute on.
                Button {
                    Task { await generate() }
                } label: {
                    Text(isBusy
                         ? "Consulting…"
                         : "Ask the \(expertLabel.lowercased()) for \(indefiniteArticle(for: period)) \(period) reading")
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.surface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.text)
                        .clipShape(Capsule())
                        // The label restates the two choices above it, so it rewrites itself on
                        // every tap up there — a cross-fade rather than a snap.
                        .contentTransition(.opacity)
                        .animation(Theme.Motion.flow, value: isBusy)
                }
                .buttonStyle(.press)
                .disabled(isBusy)
                .padding(.top, 16)

                Text(requestSummary)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(3)
                    .padding(.top, 10)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                if isBusy {
                    Composing(lines: 6)
                        .padding(.top, 22)
                        .transition(.opacity)
                }

                if !localReport.isEmpty && !isBusy {
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            Kicker(text: "Written on this iPhone", size: 9)
                            TypedText(runs: [
                                TypedRun(
                                    text: MealReading.clean(localReport),
                                    font: Theme.serifBody(16.5),
                                    color: Theme.text
                                )
                            ], duration: 3.2)
                        }
                    }
                    .padding(.top, 16)
                }

                let kept = readings.reports(expert: expert, period: period)
                ForEach(isBusy ? [] : kept) { r in
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            Kicker(text: r.at.formatted(date: .abbreviated, time: .shortened), size: 9)
                            Text(MealReading.clean(r.text))
                                .font(Theme.serifBody(16.5))
                                .foregroundStyle(Theme.text)
                                .lineSpacing(6)
                        }
                    }
                    .padding(.top, 16)
                }

                if kept.isEmpty && localReport.isEmpty && !isBusy && status.isEmpty {
                    Text("No readings yet for this specialist.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.top, 20)
                }

                Spacer(minLength: 40)
            }
            // The writing state and the finished reading swap in place, so the page settles rather
            // than jumping when a report lands.
            .animation(Theme.Motion.flow, value: isBusy)
            .animation(Theme.Motion.flow, value: status)
            .animation(Theme.Motion.flow, value: localReport)
            .padding(.horizontal, 24)
        }
        .compactsTabBar()
        .background(Theme.background)
        .subscriptionNeeded($locked, toDo: "write you a reading")
    }

    private var expertLabel: String {
        experts.first { $0.key == expert }?.label ?? "specialist"
    }

    /// How far back this period reaches, in words.
    private var requestWindow: String {
        switch period {
        case "hourly": return "the last thirty hours"
        case "weekly": return "the last two weeks"
        case "monthly": return "the last two months"
        default: return "the last week"
        }
    }

    /// Spells out the whole request: who, over what window, on which engine.
    private var requestSummary: String {
        let window = requestWindow
        return "\(window) of your data, read on this iPhone."
    }

    /// How many days of history each period should hand the model.
    private var daysForPeriod: Int {
        switch period {
        case "hourly": return 2
        case "weekly": return 14
        case "monthly": return 60
        default: return 7
        }
    }

    private func generate() async {
        isBusy = true
        defer { isBusy = false }

        // Asked here, at the one moment it is about to be useful, rather than at launch.
        guard store.entitlement.isSubscribed else { locked = true; return }

        let mayNotify = await notifier.permitted()

        status = "Reading your telemetry on this iPhone…"
        do {
            let snaps = try await health.fetchHistoricalSnapshots(days: daysForPeriod)
            // Refuse before asking rather than let the model fill the gap.
            guard InsightPrompts.canReport(snapshots: snaps, expert: expert) else {
                throw OnDeviceInsights.OnDeviceError.notEnoughData
            }
            localReport = try await OnDeviceInsights.generate(
                instructions: InsightPrompts.instructions(for: expert),
                prompt: InsightPrompts.report(
                    snapshots: snaps,
                    expert: expert,
                    rangeLabel: "the last \(daysForPeriod) days"
                )
            )
            status = ""
            readings.add(Reading(kind: .report, expert: expert, period: period, text: localReport))
            announce(localReport, if: mayNotify)
        } catch {
            status = error.localizedDescription
        }
    }

    /// Says the reading is ready.
    private func announce(_ report: String, if permitted: Bool) {
        guard permitted, !report.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        notifier.readingReady(
            specialist: expertLabel,
            window: requestWindow,
            opening: Notifier.opening(of: report)
        )
    }
}
