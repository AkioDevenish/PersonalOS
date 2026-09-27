import SwiftUI
import StoreKit

// MARK: - Writing

/// Writing or editing one article.
///
/// Save keeps a draft even when it is unfinished and shows what the automatic
/// check still wants. Send for review saves first and then submits, and the
/// server refuses anything that fails a check, so the button cannot be the
/// thing that decides. Preview shows the article exactly as a reader will see
/// it, because that is what the reviewer approves.
struct ArticleEditorView: View {
    let existing: ArticlesClient.Draft?
    let done: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var id: String?
    @State private var title = ""
    @State private var category = Articles.categories[0]
    @State private var summary = ""
    @State private var bodyText = ""
    @State private var symbol = Articles.symbols[0]
    @State private var colour = Articles.colours[0]

    @State private var errors: [String] = []
    @State private var flags: [String] = []
    @State private var failure: String?
    @State private var working = false
    @State private var previewing = false

    private let client = ArticlesClient()

    private var paragraphs: [String] {
        bodyText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    private var words: Int {
        paragraphs.joined(separator: " ").split(whereSeparator: \.isWhitespace).count
    }

    private var draftArticle: Article {
        Article(
            id: id ?? "preview", title: title, category: category,
            minutes: max(1, Int((Double(words) / 220).rounded())),
            symbol: symbol, colour: colour, summary: summary, body: paragraphs
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let note = existing?.review_note, existing?.status == "changes_requested" {
                        notice(title: "The reviewer asked for changes", lines: [note], tint: Theme.accent)
                            .padding(.bottom, 20)
                    }

                    field("Title") {
                        TextField("What the article is about", text: $title)
                    }

                    label("Category")
                    chips(Articles.categories, selection: $category)

                    field("Summary", hint: "One or two sentences. Shown under the title.") {
                        TextField("", text: $summary, axis: .vertical).lineLimit(2...4)
                    }

                    label("Article")
                    Text("Separate paragraphs with a blank line. No links, emails or phone numbers.")
                        .font(Theme.sans(12)).foregroundStyle(Theme.tertiaryText)
                    TextEditor(text: $bodyText)
                        .font(Theme.serifBody(17))
                        .frame(minHeight: 260)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 8)
                    Text("\(words) words · \(paragraphs.count) paragraphs")
                        .font(Theme.sans(12)).foregroundStyle(Theme.secondaryText)
                        .padding(.top, 6)

                    label("Picture")
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Articles.symbols, id: \.self) { s in
                                Button { symbol = s } label: {
                                    Image(systemName: s)
                                        .font(.system(size: 18))
                                        .environment(\.symbolVariants, .none)
                                        .foregroundStyle(symbol == s ? .white : Theme.text)
                                        .frame(width: 44, height: 44)
                                        .background(symbol == s ? Theme.accent : Theme.surface, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(s)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    HStack(spacing: 10) {
                        ForEach(Articles.colours, id: \.self) { c in
                            Button { colour = c } label: {
                                Circle()
                                    .fill(Article.tint(for: c))
                                    .frame(width: 30, height: 30)
                                    .overlay { Circle().stroke(Theme.text, lineWidth: colour == c ? 2.5 : 0).padding(-3) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.leading, 3)

                    if !errors.isEmpty {
                        notice(title: "Before it can be sent for review", lines: errors, tint: .red)
                            .padding(.top, 24)
                    }
                    if !flags.isEmpty {
                        notice(title: "The reviewer will look closely at", lines: flags, tint: Theme.accent)
                            .padding(.top, 12)
                    }
                    if let failure {
                        Text(failure).font(Theme.sans(13)).foregroundStyle(.red).padding(.top, 16)
                    }

                    VStack(spacing: 10) {
                        primary(working ? "Sending…" : "Send for review") { await sendForReview() }
                        HStack(spacing: 10) {
                            secondary("Preview") { previewing = true }
                            secondary("Save draft") { _ = await save() }
                        }
                    }
                    .padding(.top, 28)
                    .disabled(working || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(existing == nil ? "New article" : "Edit article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $previewing) {
                NavigationStack {
                    ArticleView(article: draftArticle)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { previewing = false } } }
                }
            }
        }
        .onAppear(perform: fill)
    }

    // MARK: Actions

    private func fill() {
        guard let existing, id == nil else { return }
        id = existing.id
        title = existing.title
        category = existing.category
        summary = existing.summary
        bodyText = existing.body
        symbol = existing.symbol
        colour = existing.colour
        flags = existing.flags
    }

    /// Returns whether the draft is clean enough to submit.
    private func save() async -> Bool {
        working = true
        failure = nil
        defer { working = false }
        do {
            let saved = try await client.save(
                id: id, title: title, category: category, summary: summary,
                body: bodyText, symbol: symbol, colour: colour
            )
            id = saved.id
            errors = saved.errors
            flags = saved.flags
            await done()
            return saved.errors.isEmpty
        } catch {
            failure = error.localizedDescription
            return false
        }
    }

    private func sendForReview() async {
        guard await save(), let id else { return }
        working = true
        defer { working = false }
        do {
            try await client.submit(id: id)
            Haptics.tap()
            await done()
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    // MARK: Pieces

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(13, medium: true))
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }

    private func field<Content: View>(_ name: String, hint: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            label(name)
            content()
                .font(Theme.sans(16))
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let hint {
                Text(hint).font(Theme.sans(12)).foregroundStyle(Theme.tertiaryText).padding(.top, 6)
            }
        }
    }

    private func chips(_ values: [String], selection: Binding<String>) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { v in
                    Button { selection.wrappedValue = v } label: {
                        Text(v)
                            .font(Theme.sans(14))
                            .foregroundStyle(selection.wrappedValue == v ? .white : Theme.text)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(selection.wrappedValue == v ? Theme.accent : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func primary(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title)
                .font(Theme.sans(16, medium: true))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.text, in: Capsule())
        }
        .buttonStyle(.press)
    }

    private func secondary(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title)
                .font(Theme.sans(15, medium: true))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Theme.surface, in: Capsule())
        }
        .buttonStyle(.press)
    }
}

/// A boxed list, for what blocks a submission and what a reviewer should weigh.
func notice(title: String, lines: [String], tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(Theme.sans(13, medium: true)).foregroundStyle(tint)
        ForEach(lines, id: \.self) { line in
            Text("• " + line)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
}

// MARK: - An author's articles

struct MyArticlesView: View {
    @State private var drafts: [ArticlesClient.Draft] = []
    @State private var loading = true
    @State private var failure: String?
    @State private var editing: ArticlesClient.Draft?
    @State private var writing = false
    @State private var paying: String?
    @State private var price: String?

    private let client = ArticlesClient()

    var body: some View {
        List {
            Section {
                Button { writing = true } label: {
                    Label("Write an article", systemImage: "square.and.pencil")
                        .font(Theme.sans(16, medium: true))
                        .foregroundStyle(Theme.accent)
                }
            } footer: {
                Text("Our team verifies each article. Once verified, pay to show it on Home for 30 days\(price.map { " (\($0))" } ?? ""). Editing takes it off Home until it is verified again.")
            }

            if let failure {
                Text(failure).foregroundStyle(.red)
            } else if !loading && drafts.isEmpty {
                Text("Nothing written yet.").foregroundStyle(Theme.secondaryText)
            }

            ForEach(drafts) { draft in
                Button { editing = draft } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(draft.title).font(Theme.sans(16, medium: true)).foregroundStyle(Theme.text)
                            Spacer()
                            status(draft)
                        }
                        Text("\(draft.category) · \(draft.minutes) min read")
                            .font(Theme.sans(13)).foregroundStyle(Theme.secondaryText)
                        if let note = draft.review_note, draft.status == "changes_requested" {
                            Text("Reviewer: " + note)
                                .font(Theme.sans(13)).foregroundStyle(Theme.accent)
                        }
                        if draft.status == "published", let until = draft.liveUntil {
                            Text("On Home until \(until.formatted(date: .abbreviated, time: .omitted))")
                                .font(Theme.sans(13)).foregroundStyle(Theme.positive)
                        }
                        if draft.canPay {
                            Button {
                                Task { await pay(draft) }
                            } label: {
                                Text(paying == draft.id ? "Opening the App Store…"
                                     : draft.status == "approved" ? "Publish for 30 days" : "Add 30 days")
                                    .font(Theme.sans(14, medium: true))
                                    .foregroundStyle(Theme.background)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Theme.text, in: Capsule())
                            }
                            .buttonStyle(.borderless)
                            .disabled(paying != nil)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions {
                    if draft.status == "published" || draft.status == "submitted" {
                        Button("Withdraw") { Task { try? await client.withdraw(id: draft.id); await load() } }
                            .tint(.orange)
                    } else {
                        Button("Delete", role: .destructive) { Task { try? await client.remove(id: draft.id); await load() } }
                    }
                }
            }
        }
        .navigationTitle("Your articles")
        .task { await load() }
        .task { price = await ArticlePlacement.product()?.displayPrice }
        .refreshable { await load() }
        .sheet(item: $editing) { draft in
            ArticleEditorView(existing: draft) { await load() }
        }
        .sheet(isPresented: $writing) {
            ArticleEditorView(existing: nil) { await load() }
        }
    }

    private func status(_ draft: ArticlesClient.Draft) -> some View {
        let tint: Color = switch draft.status {
        case "published": Theme.positive
        case "approved", "changes_requested": Theme.accent
        case "submitted": Theme.secondaryText
        default: Theme.tertiaryText
        }
        return Text(draft.statusText)
            .font(Theme.sans(11, medium: true))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func pay(_ draft: ArticlesClient.Draft) async {
        paying = draft.id
        defer { paying = nil }
        do {
            switch try await ArticlePlacement.buy(articleID: draft.id) {
            case .placed: Haptics.tap()
            case .pending: failure = "Waiting for the purchase to be approved. It goes up once that's done."
            case .cancelled: break
            }
        } catch {
            failure = error.localizedDescription
        }
        await load()
    }

    private func load() async {
        do {
            drafts = try await client.mine()
            failure = nil
        } catch where !error.isCancellation {
            failure = error.localizedDescription
        } catch {}
        loading = false
    }
}

// MARK: - Reviewing

struct ArticleReviewQueueView: View {
    @State private var items: [ArticlesClient.Submission] = []
    @State private var loading = true
    @State private var failure: String?

    private let client = ArticlesClient()

    var body: some View {
        List {
            if let failure {
                Text(failure).foregroundStyle(.red)
            } else if !loading && items.isEmpty {
                Text("Nothing waiting for review.").foregroundStyle(Theme.secondaryText)
            }
            ForEach(items) { item in
                NavigationLink {
                    ArticleReviewView(item: item) { await load() }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.article.title).font(Theme.sans(16, medium: true))
                        Text([item.article.author, item.article.category].compactMap { $0 }.joined(separator: " · "))
                            .font(Theme.sans(13)).foregroundStyle(Theme.secondaryText)
                        if !item.flags.isEmpty {
                            Text("\(item.flags.count) \(item.flags.count == 1 ? "thing" : "things") to check")
                                .font(Theme.sans(12, medium: true)).foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Review articles")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            items = try await client.queue()
            failure = nil
        } catch where !error.isCancellation {
            failure = error.localizedDescription
        } catch {}
        loading = false
    }
}

/// One submission: what the check found first, then the article as readers
/// will see it, then the decision.
struct ArticleReviewView: View {
    let item: ArticlesClient.Submission
    let done: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var working = false
    @State private var failure: String?

    private let client = ArticlesClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if item.own {
                    notice(title: "This is your own article", lines: ["Someone else on the review list has to approve it."], tint: Theme.accent)
                }
                if !item.flags.isEmpty {
                    notice(title: "Check these before approving", lines: item.flags, tint: .orange)
                }
                Text([item.article.author, item.article.credentials].compactMap { $0 }.joined(separator: ", "))
                    .font(Theme.sans(14, medium: true))

                ArticleContent(article: item.article)
                    .padding(.vertical, 8)
                Divider()

                Text("Note to the author")
                    .font(Theme.sans(13, medium: true)).foregroundStyle(Theme.secondaryText)
                TextField("Required when sending back", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

                if let failure {
                    Text(failure).font(Theme.sans(13)).foregroundStyle(.red)
                }

                HStack(spacing: 10) {
                    decide("Send back", approve: false, fill: Theme.surface, text: Theme.text)
                    decide("Approve", approve: true, fill: Theme.positive, text: .white)
                }
                .disabled(working || item.own)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .hidesSystemTabBar()
    }

    private func decide(_ title: String, approve: Bool, fill: Color, text: Color) -> some View {
        Button {
            Task {
                working = true
                failure = nil
                do {
                    try await client.review(id: item.id, approve: approve, note: note)
                    Haptics.tap()
                    await ArticleLibrary.shared.refresh()
                    await done()
                    dismiss()
                } catch {
                    failure = error.localizedDescription
                }
                working = false
            }
        } label: {
            Text(title)
                .font(Theme.sans(16, medium: true))
                .foregroundStyle(text)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.press)
    }
}
