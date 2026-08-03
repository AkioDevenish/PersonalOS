import SwiftUI

/// The meal engine, in the app.
///
/// Same server route the web dashboard used: it reads your recent metabolic
/// signals and asks Gemma for three suggestions for the moment you pick.
struct NutritionView: View {
    @State private var history: [InsightsClient.Recommendation] = []
    @State private var latest = ""
    @State private var status = ""
    @State private var isBusy = false
    @State private var context = "next meal"

    private let contexts = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Nutrition", color: Theme.amber, size: 11)
                    .padding(.top, 12)

                Text("What to eat next.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                Text("Read from your recent glucose, sleep and activity — not a generic meal plan.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)

                HStack(spacing: 8) {
                    ForEach(contexts, id: \.self) { c in
                        Button { context = c } label: {
                            Text(c.uppercased())
                                .font(Theme.sans(9.5, medium: context == c))
                                .tracking(1.4)
                                .foregroundStyle(context == c ? Theme.warm : Theme.mid)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(context == c ? Theme.ink : .clear)
                                .overlay(Capsule().stroke(context == c ? .clear : Theme.hairline, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 22)

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
                }
                .disabled(isBusy)
                .padding(.top, 16)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                if !latest.isEmpty {
                    Plate {
                        Text(latest)
                            .font(Theme.serifBody(17))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(6)
                    }
                    .padding(.top, 18)
                }

                if !history.isEmpty {
                    SectionRule(text: "Recently suggested").padding(.top, 32)
                    ForEach(history) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            if let c = r.meal_context, !c.isEmpty {
                                Kicker(text: c, size: 9)
                            }
                            ForEach(r.meals, id: \.self) { m in
                                Text("· \(m)")
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
                        Rule()
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await loadHistory() }
    }

    private func loadHistory() async {
        history = (try? await InsightsClient().mealHistory()) ?? []
    }

    private func generate() async {
        isBusy = true
        status = ""
        defer { isBusy = false }
        do {
            latest = try await InsightsClient().generateMeals(context: context)
            await loadHistory()
        } catch {
            status = error.localizedDescription
        }
    }
}

/// Expert reports — the personas the analyze route already knows how to be.
struct ExpertsView: View {
    @State private var expert = "general"
    @State private var period = "daily"
    @State private var reports: [InsightsClient.Report] = []
    @State private var status = ""
    @State private var isBusy = false

    /// Mirrors EXPERTS in api/well-being/analyze — each has its own persona
    /// and its own allowed findings, so the reports genuinely differ.
    private let experts: [(key: String, label: String)] = [
        ("general", "Health architect"),
        ("endocrinologist", "Endocrinologist"),
        ("nutritionist", "Nutritionist"),
        ("strength_coach", "Strength coach"),
        ("data_scientist", "Data scientist"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Consult", color: Theme.amber, size: 11)
                    .padding(.top, 12)

                Text("Read by a specialist.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                Text("The same telemetry, examined through a different lens. Patterns only — never a diagnosis.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)

                VStack(spacing: 0) {
                    Rule()
                    ForEach(experts, id: \.key) { e in
                        Button { expert = e.key; Task { await load() } } label: {
                            HStack {
                                Text(e.label)
                                    .font(Theme.serif(19))
                                    .foregroundStyle(expert == e.key ? Theme.amber : Theme.ink)
                                Spacer()
                                if expert == e.key {
                                    Text("❧").font(Theme.serif(13)).foregroundStyle(Theme.amber)
                                }
                            }
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rule()
                    }
                }
                .padding(.top, 22)

                HStack(spacing: 8) {
                    ForEach(["hourly", "daily", "weekly"], id: \.self) { p in
                        Button { period = p; Task { await load() } } label: {
                            Text(p.uppercased())
                                .font(Theme.sans(9.5, medium: period == p))
                                .tracking(1.4)
                                .foregroundStyle(period == p ? Theme.warm : Theme.mid)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(period == p ? Theme.ink : .clear)
                                .overlay(Capsule().stroke(period == p ? .clear : Theme.hairline, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)

                Button {
                    Task { await generate() }
                } label: {
                    Text(isBusy ? "Consulting…" : "Ask for a new reading")
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                }
                .disabled(isBusy)
                .padding(.top, 16)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                ForEach(reports) { r in
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            if let c = r.created_at { Kicker(text: c.prefix(16).description, size: 9) }
                            Text(r.report_text ?? "")
                                .font(Theme.serifBody(16.5))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(6)
                        }
                    }
                    .padding(.top, 16)
                }

                if reports.isEmpty && !isBusy && status.isEmpty {
                    Text("No readings yet for this specialist.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 20)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
    }

    private func load() async {
        do {
            reports = try await InsightsClient().reports(period: period, expert: expert)
            status = ""
        } catch {
            status = error.localizedDescription
        }
    }

    private func generate() async {
        isBusy = true
        status = "Gemma is reading your telemetry — this takes a minute."
        defer { isBusy = false }
        do {
            try await InsightsClient().generateReport(period: period, expert: expert)
            await load()
        } catch {
            status = error.localizedDescription
        }
    }
}
