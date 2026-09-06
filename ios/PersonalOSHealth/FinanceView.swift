import SwiftUI

/// The money tab.
///
/// A ledger, like the rest of the app: what came in, what went out, and where
/// it went, over a window you choose. The figures are derived on the server at
/// read time, so correcting an entry corrects every total that quotes it.
struct FinanceView: View {
    @AppStorage("ledger_currency") private var currency = Money.deviceDefault

    @State private var span: LedgerSpan = .month
    @State private var ledger = FinanceClient.Ledger.empty
    @State private var loading = true
    @State private var failure: String?
    @State private var composing = false

    private let client = FinanceClient()

    /// The totals for the currency being written in. Rows in other currencies
    /// are still listed; they are simply not added to this one's figure.
    private var total: FinanceClient.Total? {
        ledger.totals.first { $0.currency == currency } ?? ledger.totals.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PillPicker(values: LedgerSpan.allCases, selection: $span) { $0.title }
                    .onSelect { Task { await load() } }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .padding(.bottom, 34)

                headline
                    .flowIn(0)

                Button {
                    Haptics.tap()
                    composing = true
                } label: {
                    Text("Record an entry")
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.press)
                .padding(.top, 30)
                .flowIn(1)

                if let failure {
                    Text(failure)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 18)
                }

                if loading && ledger.entries.isEmpty {
                    Composing(lines: 4)
                        .frame(height: 96)
                        .padding(.top, 40)
                // Only claim the ledger is empty when it actually read
                // as empty. A failed read shows nothing either, and
                // "nothing written yet" over a network error tells the
                // reader their entries are gone.
                } else if ledger.entries.isEmpty && failure == nil {
                    empty
                } else {
                    if !ledger.spendByCategory.isEmpty {
                        SectionRule(text: "Where it went")
                            .padding(.top, 44)
                            .padding(.bottom, 18)
                        categories
                    }

                    SectionRule(text: "Entries")
                        .padding(.top, 44)
                        .padding(.bottom, 6)
                    entries
                }

                Ornament()
                    .padding(.top, 46)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 26)
            .padding(.top, 10)
        }
        .background(Theme.linen)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $composing) {
            FinanceEntrySheet(currency: currency) { date, minor, category, note in
                try await client.add(
                    date: date, minor: minor, currency: currency,
                    category: category, note: note
                )
                await load()
            }
        }
    }

    // MARK: Pieces

    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: span.heading)

            Text(Money.text(total?.net ?? 0, currency, showingSign: true))
                .font(Theme.serif(46))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
                .contentTransition(.numericText())

            // Two figures rather than one signed number, because "in" and
            // "out" are the two things anyone actually wants to compare.
            HStack(spacing: 18) {
                figure("In", Money.text(total?.incoming ?? 0, currency), Theme.sage)
                figure("Out", Money.text(total?.outgoing ?? 0, currency), Theme.amber)
            }
            .padding(.top, 18)
        }
    }

    private func figure(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Kicker(text: label, color: tint, size: 9)
            Text(value)
                .font(Theme.sans(14, medium: true))
                .foregroundStyle(Theme.mid)
        }
    }

    private var categories: some View {
        // The widest category sets the scale, so the bars compare against the
        // biggest thing you spent on rather than against the total, which on a
        // long list would leave every bar a stub.
        let widest = ledger.spendByCategory.first?.minor ?? 1
        return VStack(spacing: 14) {
            ForEach(Array(ledger.spendByCategory.prefix(6).enumerated()), id: \.element.id) { i, row in
                VStack(spacing: 6) {
                    HStack {
                        Text(row.category)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(Money.text(row.minor, row.currency))
                            .font(Theme.sans(12, medium: true))
                            .foregroundStyle(Theme.mid)
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.amber.opacity(0.55))
                            .frame(width: max(2, geo.size.width * bar(row.minor, widest)))
                    }
                    .frame(height: 3)
                }
                .flowIn(i)
            }
        }
    }

    private func bar(_ value: Int, _ widest: Int) -> CGFloat {
        widest > 0 ? CGFloat(value) / CGFloat(widest) : 0
    }

    private var entries: some View {
        VStack(spacing: 0) {
            ForEach(Array(ledger.entries.enumerated()), id: \.element.id) { i, entry in
                FinanceRow(entry: entry) {
                    try await client.remove(id: entry.id)
                    await load()
                }
                .flowIn(min(i, 8))
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Nothing written yet")
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)
            Text("Record what you spend and what you earn, and the reading builds itself.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.dust)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Behaviour

    private func load() async {
        loading = true
        failure = nil
        let w = span.window()
        do {
            ledger = try await client.ledger(from: w.from, to: w.to)
        } catch {
            failure = error.localizedDescription
        }
        loading = false
    }
}

/// One movement of money.
private struct FinanceRow: View {
    let entry: FinanceClient.Entry
    let remove: () async throws -> Void

    @State private var removing = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.category)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text(entry.when.formatted(.dateTime.day().month(.abbreviated)))
                    if !entry.note.isEmpty {
                        Text("·")
                        Text(entry.note).lineLimit(1)
                    }
                }
                .font(Theme.sans(11))
                .foregroundStyle(Theme.dust)
            }

            Spacer(minLength: 8)

            // Money out is the common case, so it stays in ink; money in is
            // the exception and gets the colour.
            Text((entry.spent ? "" : "+") + Money.text(entry.minor, entry.currency))
                .font(Theme.sans(13, medium: true))
                .foregroundStyle(entry.spent ? Theme.ink : Theme.sage)
        }
        .padding(.vertical, 13)
        .opacity(removing ? 0.4 : 1)
        // A context menu rather than a swipe: these rows are in a plain stack,
        // not a List, and swipeActions silently does nothing outside one.
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    removing = true
                    try? await remove()
                    removing = false
                }
            } label: {
                Label("Delete entry", systemImage: "trash")
            }
        }
    }
}

/// Writing one entry.
///
/// Deliberately short: a form long enough to put you off filling it in is a
/// ledger that stays empty. Amount, what it was for, and the sign. Everything
/// else has a sensible default you can leave alone.
struct FinanceEntrySheet: View {
    let currency: String
    /// Throws so the sheet can show why a rejected entry was rejected.
    let save: (Date, Int, String, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var spent = true
    @State private var amount = ""
    @State private var category = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var saving = false
    @State private var failure: String?
    @FocusState private var amountFocused: Bool

    private let suggestions = [
        "Food", "Transport", "Rent", "Bills", "Health", "Leisure", "Savings",
    ]

    private var minor: Int? {
        guard let m = Money.minor(from: amount, currency: currency), m > 0 else { return nil }
        return spent ? -m : m
    }

    private var ready: Bool {
        minor != nil && !category.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PillPicker(values: [true, false], selection: $spent) { $0 ? "Spent" : "Received" }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 34)

                Kicker(text: "Amount")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currency)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.dust)
                    TextField("0", text: $amount)
                        .font(Theme.serif(42))
                        .foregroundStyle(Theme.ink)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                }
                .padding(.top, 6)

                Kicker(text: "For what")
                    .padding(.top, 34)
                TextField("Groceries, rent, a haircut", text: $category)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                // Tapping beats typing for the handful of categories most
                // entries fall into.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(suggestions, id: \.self) { s in
                            Button {
                                Haptics.select()
                                category = s
                            } label: {
                                Text(s)
                                    .font(Theme.sans(11))
                                    .foregroundStyle(category == s ? Theme.warm : Theme.mid)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background {
                                        if category == s {
                                            Capsule().fill(Theme.ink)
                                        } else {
                                            Capsule().stroke(Theme.hairline, lineWidth: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.top, 14)

                Kicker(text: "Note")
                    .padding(.top, 34)
                TextField("Optional", text: $note)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Theme.amber)
                    .padding(.top, 30)

                if let failure {
                    Text(failure)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 18)
                }

                Button {
                    Task { await commit() }
                } label: {
                    ZStack {
                        Text("Write it down").opacity(saving ? 0 : 1)
                        if saving { ProgressView().tint(Theme.warm) }
                    }
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ready ? Theme.ink : Theme.dust)
                    .clipShape(Capsule())
                }
                .buttonStyle(.press)
                .disabled(!ready || saving)
                .padding(.top, 34)
                .animation(Theme.Motion.flow, value: ready)
            }
            .padding(.horizontal, 26)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .background(Theme.linen)
        .onAppear { amountFocused = true }
    }

    private func commit() async {
        guard let minor else { return }
        saving = true
        failure = nil
        do {
            try await save(date, minor, category.trimmingCharacters(in: .whitespaces), note)
            Haptics.tap()
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
        saving = false
    }
}
