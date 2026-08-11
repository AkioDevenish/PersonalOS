import SwiftUI

/// The meal engine, in the app.
///
/// Same server route the web dashboard used: it reads your recent metabolic
/// signals and asks Gemma for three suggestions for the moment you pick.
struct NutritionView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var history: [InsightsClient.Recommendation] = []
    @State private var latest = ""
    @State private var status = ""
    @State private var isBusy = false
    /// Breakfast, not "next meal".
    ///
    /// The default used to be a fifth value that wasn't in the pills, so the
    /// row of choices showed nothing selected while the button quietly asked
    /// for something else — you could generate a meal you had never chosen.
    /// Every state the screen can be in is now one you can see.
    @State private var context = "breakfast"

    private let contexts = ["breakfast", "lunch", "dinner", "snack"]

    /// Persisted: where you cook is a standing fact, not a per-meal choice.
    @AppStorage(Cuisine.key) private var country = Cuisine.deviceDefault
    @State private var choosingCountry = false

    /// What people say they eat here. The reason the model stops inventing
    /// dish names: it chooses from this rather than recalling from nothing.
    @State private var book = CuisineClient.Book.empty
    @State private var newDish = ""
    @State private var seeding = false
    @State private var consulting = false

    /// Today's snapshot, held only so the screen can show what it's reading.
    @State private var today: HealthSnapshot?

    /// The metabolic and activity signals the suggestion is built from — the
    /// same metric ids the prompt uses, so this can't drift from what the
    /// model was actually handed.
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
                Kicker(text: "Nutrition", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("What to eat next.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                    .flowIn(1)

                Text(country.isEmpty
                     ? "Read from your recent glucose, sleep and activity — not a generic meal plan."
                     : "Read from your recent glucose, sleep and activity, and cooked with what you can actually buy in \(Cuisine.name(for: country)).")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                // The claim above is that this reads your data. Showing the
                // readings it is holding is the cheapest way to make that
                // checkable, and it's the difference between a suggestion you
                // trust and one that could have come from anywhere.
                if !signals.isEmpty {
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            Kicker(text: "Reading right now", size: 9)
                            ForEach(signals, id: \.label) { s in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: s.symbol)
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundStyle(Theme.amber)
                                        .frame(width: 14, alignment: .leading)
                                    Text(s.label)
                                        .font(Theme.sans(11))
                                        .foregroundStyle(Theme.mid)
                                    Spacer()
                                    Text(s.value)
                                        .font(Theme.serif(17))
                                        .foregroundStyle(Theme.ink)
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
                            .foregroundStyle(country.isEmpty ? Theme.dust : Theme.ink)
                            .contentTransition(.opacity)
                        Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
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
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                        // The label changes under you while it works; the
                        // words should cross-fade rather than jump.
                        .contentTransition(.opacity)
                        .animation(Theme.Motion.flow, value: isBusy)
                }
                .buttonStyle(.press)
                .disabled(isBusy)
                .padding(.top, 16)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
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
                         ? (seeding
                            ? "Writing a starter list for \(Cuisine.name(for: country))…"
                            : "Nothing named yet. Add the first dish and it goes into your suggestions straight away.")
                         : "Named by people who eat in \(Cuisine.name(for: country)). Once \(book.threshold) people name a dish it goes into everyone's suggestions here — yours count for you immediately.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
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
                                        .foregroundStyle(d.mine ? Theme.amber : Theme.ink)
                                    Spacer()
                                    Text(voteLine(d))
                                        .font(Theme.sans(9.5))
                                        .tracking(1.2)
                                        .foregroundStyle(Theme.dust)
                                    if d.mine { SelectionMark(size: 12) }
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressRow)
                        }
                    }
                    .padding(.top, 6)

                    HStack(spacing: 12) {
                        TextField("Name a dish", text: $newDish)
                            .font(Theme.serif(18))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { Task { await add() } }

                        Button {
                            Task { await add() }
                        } label: {
                            Kicker(text: "Add", color: Theme.amber, size: 10)
                        }
                        .buttonStyle(.press)
                        .disabled(newDish.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 14)
                }

                if !history.isEmpty {
                    SectionRule(text: "Recently suggested").padding(.top, 32)
                    ForEach(history) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            if let c = r.meal_context, !c.isEmpty {
                                Kicker(text: c, size: 9)
                            }
                            ForEach(r.meals, id: \.self) { m in
                                Text("· \(MealReading.clean(m))")
                                    .font(Theme.serifBody(16))
                                    .foregroundStyle(Theme.ink)
                            }
                            if let i = r.insight, !i.isEmpty {
                                Text(i)
                                    .font(Theme.sans(11.5))
                                    .foregroundStyle(Theme.dust)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }

                Spacer(minLength: 40)
            }
            // A suggestion arriving pushes the history down the page; it
            // should slide rather than jump.
            .animation(Theme.Motion.flow, value: latest)
            .animation(Theme.Motion.flow, value: isBusy)
            .animation(Theme.Motion.flow, value: status)
            .animation(Theme.Motion.flow, value: signals.count)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        // Pinned rather than scrolled away with the content: the whole point
        // of it is being reachable from anywhere on a long page, and a button
        // you have to scroll back up to find is a link.
        .overlay(alignment: .bottomTrailing) {
            Button {
                Haptics.tap()
                consulting = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 56, height: 56)
                        .shadow(color: Theme.ink.opacity(0.18), radius: 12, y: 4)
                    Image(systemName: "bubble.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.warm)
                }
            }
            .buttonStyle(.press)
            .accessibilityLabel("Ask a nutritionist")
            .padding(.trailing, 22)
            .padding(.bottom, 26)
        }
        .sheet(isPresented: $consulting) { ConsultView() }
        .task { await loadSignals() }
        .task { await loadHistory() }
        .task { await loadBook() }
        .onChange(of: country) { _, _ in
            book = .empty
            Task { await loadBook() }
        }
        .animation(Theme.Motion.flow, value: book.all)
        .sheet(isPresented: $choosingCountry) {
            CountryPicker(code: $country)
        }
    }

    private func loadHistory() async {
        history = (try? await InsightsClient().mealHistory()) ?? []
    }

    /// "NAMED BY 4" — and for a starter-list dish nobody has vouched for yet,
    /// say so rather than showing a zero, which reads as a rejection.
    private func voteLine(_ d: CuisineClient.Dish) -> String {
        if d.votes == 0 { return d.seeded ? "suggested" : "" }
        return d.votes == 1 ? "named by 1" : "named by \(d.votes)"
    }

    private func loadBook() async {
        guard !country.isEmpty else { book = .empty; return }
        book = (try? await CuisineClient().book(country: country)) ?? .empty
        await seedIfEmpty()
    }

    /// Writes a starter list for a country nobody has named anything for.
    ///
    /// Only from the on-device model, which is both the default engine and the
    /// one that most needs the help — a hosted model asked for Trinidadian food
    /// already knows. The starter list carries no votes, so the first real
    /// person to disagree with it outranks it by simply saying so.
    private func seedIfEmpty() async {
        guard book.all.isEmpty, !country.isEmpty, !seeding else { return }
        guard ModelChoice.isOnDevice, #available(iOS 26.0, *) else { return }
        seeding = true
        defer { seeding = false }

        let name = Cuisine.name(for: country)
        guard let written = try? await OnDeviceInsights.generate(
            instructions: InsightPrompts.starterInstructions,
            prompt: InsightPrompts.starterDishes(country: name),
            temperature: 0.4
        ) else { return }

        let dishes = written
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.replacingOccurrences(of: "^[-·*\\d.\\s]+", with: "", options: .regularExpression) }
            .filter { !$0.isEmpty && $0.count <= 60 }
        guard dishes.count >= 5 else { return }

        try? await CuisineClient().seed(country: country, dishes: dishes)
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
        isBusy = true
        status = ""
        defer { isBusy = false }
        do {
            // On-device reads HealthKit here and never leaves the phone; every
            // other engine is reached through the server, which holds the key.
            if ModelChoice.isOnDevice, #available(iOS 26.0, *) {
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
            } else {
                latest = try await InsightsClient().generateMeals(
                    context: context,
                    country: country.isEmpty ? nil : Cuisine.name(for: country),
                    dishes: book.canon
                )
                await loadHistory()
            }
        } catch {
            status = error.localizedDescription
        }
    }
}

/// Expert reports — the personas the analyze route already knows how to be.
struct ExpertsView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject private var notifier: Notifier
    @State private var expert = InsightPrompts.experts[0].key
    /// Hourly, not daily. The daily report reads the *previous* completed day,
    /// so opening this screen at nine in the morning offered you a reading of
    /// yesterday as the default — the least current thing on the list. Hourly
    /// reads the last thirty hours, which is the day you are actually in.
    @State private var period = "hourly"
    @State private var reports: [InsightsClient.Report] = []
    @State private var status = ""
    @State private var isBusy = false
    /// On-device reports aren't stored on a server, so they live here for the
    /// session. Persisting them is a separate job from generating them.
    @State private var localReport = ""

    /// One list, in InsightPrompts, shared by the screen and by the on-device
    /// prompts. It was duplicated here, which is how the retired "Health
    /// architect" survived in the picker after the server stopped writing it.
    private var experts: [InsightPrompts.Expert] { InsightPrompts.experts }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Consult", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("Read by a specialist.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                    .flowIn(1)

                Text("The same telemetry, examined through a different lens. Patterns only — never a diagnosis.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                VStack(spacing: 0) {
                    ForEach(experts, id: \.key) { e in
                        Button {
                            guard expert != e.key else { return }
                            Haptics.select()
                            withAnimation(Theme.Motion.bouncy) { expert = e.key }
                            Task { await load() }
                        } label: {
                            HStack {
                                Text(e.label)
                                    .font(Theme.serif(19))
                                    .foregroundStyle(expert == e.key ? Theme.amber : Theme.ink)
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
                    .onSelect { Task { await load() } }
                    .padding(.top, 20)

                // The button used to say only "Ask for a new reading", which
                // left you guessing which specialist and which window you were
                // about to spend a minute on. Both choices are above it; the
                // request should say what it heard.
                Button {
                    Task { await generate() }
                } label: {
                    Text(isBusy
                         ? "Consulting…"
                         : "Ask the \(expertLabel.lowercased()) for \(indefiniteArticle(for: period)) \(period) reading")
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                        // The label restates the two choices above it, so it
                        // rewrites itself on every tap up there — a cross-fade
                        // rather than a snap.
                        .contentTransition(.opacity)
                        .animation(Theme.Motion.flow, value: isBusy)
                }
                .buttonStyle(.press)
                .disabled(isBusy)
                .padding(.top, 16)

                Text(requestSummary)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(3)
                    .padding(.top, 10)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
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
                                    color: Theme.ink
                                )
                            ], duration: 3.2)
                        }
                    }
                    .padding(.top, 16)
                }

                ForEach(isBusy ? [] : reports) { r in
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            if let c = r.created_at { Kicker(text: c.prefix(16).description, size: 9) }
                            Text(MealReading.clean(r.report_text ?? ""))
                                .font(Theme.serifBody(16.5))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(6)
                        }
                    }
                    .padding(.top, 16)
                }

                if reports.isEmpty && localReport.isEmpty && !isBusy && status.isEmpty {
                    Text("No readings yet for this specialist.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 20)
                }

                Spacer(minLength: 40)
            }
            // The writing state and the finished reading swap in place, so the
            // page settles rather than jumping when a report lands.
            .animation(Theme.Motion.flow, value: isBusy)
            .animation(Theme.Motion.flow, value: status)
            .animation(Theme.Motion.flow, value: localReport)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
    }

    private func load() async {
        // Nothing to fetch when reports are written on the phone.
        guard !ModelChoice.isOnDevice else { status = ""; return }
        do {
            reports = try await InsightsClient().reports(period: period, expert: expert)
            status = ""
        } catch {
            status = error.localizedDescription
        }
    }

    private var expertLabel: String {
        experts.first { $0.key == expert }?.label ?? "specialist"
    }

    /// How far back this period reaches, in words. Pulled out of the summary
    /// so the notification can say the same thing the screen does.
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
        let engine = ModelChoice.isOnDevice
            ? "on this iPhone"
            // The model name is the useful half — "by claude-sonnet-4-6" tells
            // you what wrote it, where "by anthropic" tells you who to invoice.
            : "by \(ModelChoice.model.isEmpty ? ModelChoice.provider : ModelChoice.model)"
        return "Reads \(window) of your telemetry as \(indefiniteArticle(for: expertLabel)) \(expertLabel.lowercased()), written \(engine)."
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

        // Asked here, at the one moment it is about to be useful, rather than
        // at launch. A minute of waiting is the reason the permission exists,
        // so the prompt arrives with that minute rather than before it.
        let mayNotify = await notifier.permitted()

        if ModelChoice.isOnDevice, #available(iOS 26.0, *) {
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
                announce(localReport, if: mayNotify)
            } catch {
                status = error.localizedDescription
            }
            return
        }

        status = "Reading your telemetry — this takes a minute."
        do {
            try await InsightsClient().generateReport(period: period, expert: expert)
            await load()
            announce(reports.first?.report_text ?? "", if: mayNotify)
        } catch {
            status = error.localizedDescription
        }
    }

    /// Says the reading is ready. Only ever after one you asked for, and only
    /// with something in it — a notification announcing an empty report is a
    /// worse outcome than no notification.
    private func announce(_ report: String, if permitted: Bool) {
        guard permitted, !report.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        notifier.readingReady(
            specialist: expertLabel,
            window: requestWindow,
            opening: Notifier.opening(of: report)
        )
    }
}
