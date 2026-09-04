import SwiftUI

/// The time tab.
///
/// The money tab's twin, and built to look like it on purpose: the same window
/// picker, the same headline-then-breakdown-then-entries shape. Two ledgers
/// that behave differently would be two apps.
struct TimeView: View {
    @State private var span: LedgerSpan = .week
    @State private var ledger = TimeClient.Ledger.empty
    @State private var loading = true
    @State private var failure: String?
    @State private var composing = false

    private let client = TimeClient()

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
                    Text("Log some time")
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

                if loading && ledger.blocks.isEmpty {
                    Composing(lines: 4)
                        .frame(height: 96)
                        .padding(.top, 40)
                // Only claim the ledger is empty when it actually read
                // as empty. A failed read shows nothing either, and
                // "nothing written yet" over a network error tells the
                // reader their entries are gone.
                } else if ledger.blocks.isEmpty && failure == nil {
                    empty
                } else {
                    if !ledger.byCategory.isEmpty {
                        SectionRule(text: "Where it went")
                            .padding(.top, 44)
                            .padding(.bottom, 18)
                        categories
                    }

                    SectionRule(text: "Blocks")
                        .padding(.top, 44)
                        .padding(.bottom, 6)
                    blocks
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
            TimeBlockSheet { start, minutes, activity, category, note in
                try await client.add(
                    start: start, minutes: minutes, activity: activity,
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

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Duration.hours(ledger.totalMinutes))
                    .font(Theme.serif(46))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(ledger.totalMinutes == 60 ? "hour" : "hours")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.dust)
            }
            .padding(.top, 8)

            Text("Across \(ledger.blocks.count) \(ledger.blocks.count == 1 ? "block" : "blocks").")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.mid)
                .padding(.top, 12)
        }
    }

    private var categories: some View {
        let widest = ledger.byCategory.first?.minutes ?? 1
        return VStack(spacing: 14) {
            ForEach(Array(ledger.byCategory.prefix(6).enumerated()), id: \.element.id) { i, row in
                VStack(spacing: 6) {
                    HStack {
                        Text(row.category)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(Duration.text(row.minutes))
                            .font(Theme.sans(12, medium: true))
                            .foregroundStyle(Theme.mid)
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.sage.opacity(0.6))
                            .frame(width: max(2, geo.size.width * bar(row.minutes, widest)))
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

    private var blocks: some View {
        VStack(spacing: 0) {
            ForEach(Array(ledger.blocks.enumerated()), id: \.element.id) { i, block in
                TimeRow(block: block) {
                    try await client.remove(id: block.id)
                    await load()
                }
                .flowIn(min(i, 8))
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("No time logged yet")
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)
            Text("Write down where the hours went, and the week starts explaining itself.")
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

/// One stretch of time.
private struct TimeRow: View {
    let block: TimeClient.Block
    let remove: () async throws -> Void

    @State private var removing = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(block.activity)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text(block.began.formatted(.dateTime.day().month(.abbreviated)))
                    Text("·")
                    Text(block.category)
                    if !block.note.isEmpty {
                        Text("·")
                        Text(block.note).lineLimit(1)
                    }
                }
                .font(Theme.sans(11))
                .foregroundStyle(Theme.dust)
            }

            Spacer(minLength: 8)

            Text(Duration.text(block.minutes))
                .font(Theme.sans(13, medium: true))
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 13)
        .opacity(removing ? 0.4 : 1)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    removing = true
                    try? await remove()
                    removing = false
                }
            } label: {
                Label("Delete block", systemImage: "trash")
            }
        }
    }
}

/// Writing one block.
struct TimeBlockSheet: View {
    let save: (Date, Int, String, String, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var activity = ""
    @State private var category = ""
    @State private var minutes = 60
    @State private var start = Date()
    @State private var note = ""
    @State private var saving = false
    @State private var failure: String?
    @FocusState private var activityFocused: Bool

    private let suggestions = ["Deep work", "Meetings", "Admin", "Study", "Exercise", "Rest"]
    /// The lengths a block actually tends to be, so the common case is a tap.
    private let lengths = [15, 30, 45, 60, 90, 120, 180, 240]

    private var ready: Bool {
        !activity.trimmingCharacters(in: .whitespaces).isEmpty
            && !category.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "How long")
                Text(Duration.text(minutes))
                    .font(Theme.serif(42))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .padding(.top, 6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(lengths, id: \.self) { m in
                            Button {
                                Haptics.select()
                                withAnimation(Theme.Motion.bouncy) { minutes = m }
                            } label: {
                                Text(Duration.text(m))
                                    .font(Theme.sans(11))
                                    .foregroundStyle(minutes == m ? Theme.warm : Theme.mid)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background {
                                        if minutes == m {
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
                .padding(.top, 16)

                Kicker(text: "Doing what")
                    .padding(.top, 34)
                TextField("Writing the brief", text: $activity)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.ink)
                    .focused($activityFocused)
                    .padding(.top, 8)

                Kicker(text: "Kind of work")
                    .padding(.top, 30)
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
                .padding(.top, 10)

                TextField("Or type your own", text: $category)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 14)

                DatePicker("", selection: $start)
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
        .onAppear { activityFocused = true }
    }

    private func commit() async {
        saving = true
        failure = nil
        do {
            try await save(
                start, minutes,
                activity.trimmingCharacters(in: .whitespaces),
                category.trimmingCharacters(in: .whitespaces),
                note
            )
            Haptics.tap()
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
        saving = false
    }
}
