import SwiftUI

/// The three pillars beside Health.
///
/// All three follow the Consult idiom: a kicker, a serif title, plates for the
/// few numbers worth a glance, then a hairline-ruled list. No boxes — the rule
/// is the only structural mark this design has, and repeating it is what makes
/// five different screens feel like one app.

// MARK: - Business

struct BusinessView: View {
    @State private var payload: PillarClient.BusinessPayload?
    @State private var status = ""
    @State private var loading = true

    /// The order a relationship actually travels in, so the plates read left
    /// to right as a funnel rather than as an alphabetised set.
    private let stages = ["lead", "prospect", "proposal", "client"]

    var body: some View {
        PillarScaffold(
            kicker: "Business",
            title: "Who you're\ntalking to.",
            blurb: "Contacts and where each one stands.",
            status: status,
            loading: loading,
            isEmpty: (payload?.contacts.isEmpty ?? true),
            emptyNote: "No contacts yet."
        ) {
            if let summary = payload?.pipeline?.summary, !summary.isEmpty {
                SectionRule(text: "Pipeline").padding(.top, 28)
                HStack(spacing: 10) {
                    ForEach(stages, id: \.self) { stage in
                        Plate {
                            VStack(alignment: .leading, spacing: 5) {
                                Kicker(text: stage, size: 8.5)
                                Text("\(summary[stage] ?? 0)")
                                    .font(Theme.serif(26))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }

            if let contacts = payload?.contacts, !contacts.isEmpty {
                SectionRule(text: "Contacts").padding(.top, 30)
                VStack(spacing: 0) {
                    ForEach(contacts) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(c.name)
                                    .font(Theme.serif(19))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text(c.status.uppercased())
                                    .font(Theme.sans(9))
                                    .tracking(1.4)
                                    .foregroundStyle(Theme.amber)
                            }
                            if let sub = [c.company, c.email].compactMap({ $0 }).first {
                                Text(sub)
                                    .font(Theme.sans(10.5))
                                    .foregroundStyle(Theme.dust)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.top, 16)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { payload = try await PillarClient().business(); status = "" }
        catch { status = error.localizedDescription }
    }
}

// MARK: - Creative

struct CreativeView: View {
    @State private var payload: PillarClient.CreativePayload?
    @State private var status = ""
    @State private var loading = true

    var body: some View {
        PillarScaffold(
            kicker: "Creative",
            title: "What you've\nput out.",
            blurb: "Posts, drafts and where they went.",
            status: status,
            loading: loading,
            isEmpty: (payload?.posts.isEmpty ?? true),
            emptyNote: "Nothing written yet."
        ) {
            if let s = payload?.stats {
                HStack(spacing: 10) {
                    statPlate("Total", s.total)
                    statPlate("Published", s.published)
                    statPlate("This week", s.this_week)
                }
                .padding(.top, 24)
            }

            if let posts = payload?.posts, !posts.isEmpty {
                SectionRule(text: "Recent").padding(.top, 30)
                VStack(spacing: 0) {
                    ForEach(posts) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Kicker(text: p.platform, size: 8.5)
                                if !p.published {
                                    Text("draft")
                                        .font(Theme.sans(9))
                                        .foregroundStyle(Theme.dust)
                                }
                                Spacer()
                                if let t = p.topic, !t.isEmpty {
                                    Text(t)
                                        .font(Theme.sans(10))
                                        .foregroundStyle(Theme.dust)
                                }
                            }
                            Text(p.content)
                                .font(Theme.serifBody(16))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(4)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.top, 16)
            }
        }
        .task { await load() }
    }

    private func statPlate(_ label: String, _ n: Int) -> some View {
        Plate {
            VStack(alignment: .leading, spacing: 5) {
                Kicker(text: label, size: 8.5)
                Text("\(n)").font(Theme.serif(26)).foregroundStyle(Theme.ink)
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { payload = try await PillarClient().creative(); status = "" }
        catch { status = error.localizedDescription }
    }
}

// MARK: - Data

struct DataView: View {
    @State private var payload: PillarClient.DataPayload?
    @State private var status = ""
    @State private var loading = true

    var body: some View {
        PillarScaffold(
            kicker: "Data",
            title: "What you're\nbuilding.",
            blurb: "Projects, and how far along each one is.",
            status: status,
            loading: loading,
            isEmpty: (payload?.projects.isEmpty ?? true),
            emptyNote: "No projects yet."
        ) {
            if let projects = payload?.projects, !projects.isEmpty {
                SectionRule(text: "Projects").padding(.top, 28)
                VStack(spacing: 0) {
                    ForEach(projects) { p in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(p.name)
                                    .font(Theme.serif(19))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text(p.status)
                                    .font(Theme.sans(10))
                                    .foregroundStyle(p.status.lowercased() == "completed"
                                                     ? Theme.sage : Theme.amber)
                            }
                            if let d = p.description, !d.isEmpty {
                                Text(d)
                                    .font(Theme.sans(11))
                                    .foregroundStyle(Theme.dust)
                                    .lineSpacing(3)
                                    .lineLimit(3)
                            }
                            if let url = p.deployed_url ?? p.github_url,
                               !url.isEmpty, let link = URL(string: url) {
                                Link(destination: link) {
                                    Kicker(text: "Open", color: Theme.amber, size: 9)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.top, 16)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { payload = try await PillarClient().data(); status = "" }
        catch { status = error.localizedDescription }
    }
}

// MARK: - Shared shell

/// The chrome every pillar shares, so a new one is a list and nothing else.
private struct PillarScaffold<Content: View>: View {
    let kicker: String
    let title: String
    let blurb: String
    let status: String
    let loading: Bool
    let isEmpty: Bool
    let emptyNote: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: kicker, color: Theme.amber, size: 11)
                    .padding(.top, 8)

                Text(title)
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 8)

                Text(blurb)
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 18)
                }

                content

                if loading {
                    Text("Reading…")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 24)
                } else if isEmpty && status.isEmpty {
                    Text(emptyNote)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 24)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
    }
}
