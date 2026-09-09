import SwiftUI

/// The people you can ask, as cards.
///
/// A list of names would not answer the question anyone actually arrives with,
/// which is "who here knows about the thing that is wrong with me". So the
/// specialisms are the loudest part of each card, above the qualifications and
/// well above the price.
struct SpecialistsView: View {
    @AppStorage(Cuisine.key) private var country = Cuisine.deviceDefault

    @State private var desk = SpecialistsClient.Desk.empty
    @State private var loading = true
    @State private var failure: String?
    @State private var applying = false

    private let client = SpecialistsClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Ask a person")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 6)
                    .flowIn(0)

                Text("Practitioners who read what you have recorded and write back in their own words. Every one of them has been checked before appearing here.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .flowIn(1)

                if let failure {
                    Text(failure)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 20)
                }

                if loading && desk.specialists.isEmpty {
                    Composing(lines: 4)
                        .frame(height: 96)
                        .padding(.top, 32)
                } else if desk.specialists.isEmpty && failure == nil {
                    empty
                } else {
                    VStack(spacing: 14) {
                        ForEach(Array(desk.specialists.enumerated()), id: \.element.id) { i, one in
                            NavigationLink(value: one) {
                                card(one)
                            }
                            .buttonStyle(.pressRow)
                            .flowIn(min(i, 6) + 2)
                        }
                    }
                    .padding(.top, 30)
                }

                practitionerFooter
                    .padding(.top, 38)

                Ornament()
                    .padding(.top, 40)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 22)
        }
        .background(Theme.linen)
        .refreshable { await load() }
        .task { await load() }
        .navigationDestination(for: SpecialistsClient.Specialist.self) { one in
            SpecialistProfileView(specialist: one)
        }
        .sheet(isPresented: $applying) {
            SpecialistApplicationSheet(
                existing: desk.application,
                defaultCountry: country
            ) { await load() }
        }
    }

    // MARK: One card

    private func card(_ one: SpecialistsClient.Specialist) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(one.name)
                    .font(Theme.serif(23))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(one.place)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
            }

            Text(one.credentials)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.mid)
                .padding(.top, 3)

            // The reason someone is scanning this page at all.
            if !one.specialties.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(one.specialties, id: \.self) { s in
                        Text(s)
                            .font(Theme.sans(11, medium: true))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.amber.opacity(0.18), in: Capsule())
                    }
                }
                .padding(.top, 14)
            }

            if !one.bio.isEmpty {
                Text(one.bio)
                    .font(Theme.serifBody(15))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            HStack(spacing: 10) {
                Text(one.free ? "Free" : one.price)
                    .font(Theme.sans(12, medium: true))
                    .foregroundStyle(one.free ? Theme.sage : Theme.dust)

                // What you can actually do with them, said on the card so
                // nobody taps through to find out there is no call.
                Label("Chat", systemImage: "bubble.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Theme.dust)
                if one.offers_video {
                    Label("Video", systemImage: "video")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Theme.dust)
                }

                Spacer()
                Text("View  \u{2192}")
                    .font(Theme.sans(12, medium: true))
                    .foregroundStyle(Theme.amber)
            }
            .padding(.top, 18)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warm, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Nobody listed yet")
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)
            Text("No practitioner has been approved for the directory so far.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.dust)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    // MARK: The way in, for practitioners

    @ViewBuilder
    private var practitionerFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionRule(text: "Are you a specialist?")

            if let application = desk.application {
                Text(statusLine(application))
                    .font(Theme.sans(13))
                    .foregroundStyle(application.approved ? Theme.sage : Theme.mid)
                    .fixedSize(horizontal: false, vertical: true)

                Button(application.approved ? "Edit your listing" : "Edit your application") {
                    Haptics.tap()
                    applying = true
                }
                .font(Theme.sans(12, medium: true))
                .foregroundStyle(Theme.amber)
                .buttonStyle(.press)
            } else {
                Text("Practitioners can apply to appear here. Applications are checked before anyone is listed.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.tap()
                    applying = true
                } label: {
                    Text("Apply to be listed")
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.ink, in: Capsule())
                }
                .buttonStyle(.press)
                .padding(.top, 4)
            }
        }
    }

    private func statusLine(_ a: SpecialistsClient.Application) -> String {
        if a.approved {
            return a.active
                ? "You are listed and taking questions."
                : "You are approved, but your listing is switched off."
        }
        if a.declined {
            return "Your application was not approved. You can change it and apply again."
        }
        return "Your application is with us. You will appear once it has been checked."
    }

    // MARK: Behaviour

    private func load() async {
        loading = true
        failure = nil
        do {
            desk = try await client.desk()
        } catch {
            failure = error.localizedDescription
        }
        loading = false
    }
}

/// A row of chips that wraps, which SwiftUI has no stock container for.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Applying to appear in the directory, or editing an application already made.
struct SpecialistApplicationSheet: View {
    let existing: SpecialistsClient.Application?
    let defaultCountry: String
    let done: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var credentials = ""
    @State private var bio = ""
    @State private var specialties: [String] = []
    @State private var draftSpecialty = ""
    @State private var country = ""
    @State private var price = "0"
    @State private var active = true
    @State private var offersVideo = false
    @State private var saving = false
    @State private var failure: String?

    /// The things people most often want a practitioner for, so the common
    /// case is a tap rather than typing.
    private let suggested = [
        "Diabetes", "Sports nutrition", "Sleep", "Weight", "Gut health",
        "Heart health", "Pregnancy", "Vegetarian",
    ]

    private var ready: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !credentials.trimmingCharacters(in: .whitespaces).isEmpty
            && !specialties.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(existing == nil ? "Apply to be listed" : "Your listing")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)

                Text("What you write here is what someone reads before deciding to ask you. Applications are checked before anyone appears.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                field("Name", "How you want to be listed", $name)
                field("Qualifications", "RD, MSc Nutrition", $credentials)

                Kicker(text: "What you specialise in")
                    .padding(.top, 30)
                if !specialties.isEmpty {
                    FlowRow(spacing: 6) {
                        ForEach(specialties, id: \.self) { s in
                            Button {
                                Haptics.select()
                                specialties.removeAll { $0 == s }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(s)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .semibold))
                                }
                                .font(Theme.sans(11, medium: true))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.amber.opacity(0.18), in: Capsule())
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.top, 10)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(suggested.filter { !specialties.contains($0) }, id: \.self) { s in
                            Button {
                                Haptics.select()
                                add(s)
                            } label: {
                                Text(s)
                                    .font(Theme.sans(11))
                                    .foregroundStyle(Theme.mid)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().stroke(Theme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.top, 12)

                HStack(spacing: 10) {
                    TextField("Or type your own", text: $draftSpecialty)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink)
                        .onSubmit { add(draftSpecialty) }
                    Button("Add") { add(draftSpecialty) }
                        .font(Theme.sans(12, medium: true))
                        .foregroundStyle(Theme.amber)
                        .buttonStyle(.press)
                        .disabled(draftSpecialty.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 14)

                Kicker(text: "About you")
                    .padding(.top, 30)
                TextField("A few lines about how you work", text: $bio, axis: .vertical)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3...8)
                    .padding(.top, 8)

                field("Country", "TT", $country)

                Kicker(text: "Price in credits")
                    .padding(.top, 30)
                TextField("0", text: $price)
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.ink)
                    .keyboardType(.numberPad)
                    .padding(.top, 6)
                Text("Zero means free.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
                    .padding(.top, 4)

                Toggle(isOn: $offersVideo) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Take video calls")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink)
                        Text("Plenty of practitioners answer in writing only.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.dust)
                    }
                }
                .tint(Theme.sage)
                .padding(.top, 26)

                Toggle(isOn: $active) {
                    Text("Taking questions")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.sage)
                .padding(.top, 18)

                if let failure {
                    Text(failure)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 16)
                }

                Button {
                    Task { await save() }
                } label: {
                    ZStack {
                        Text(existing == nil ? "Send application" : "Save").opacity(saving ? 0 : 1)
                        if saving { ProgressView().tint(Theme.warm) }
                    }
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ready ? Theme.ink : Theme.dust, in: Capsule())
                }
                .buttonStyle(.press)
                .disabled(!ready || saving)
                .padding(.top, 30)
                .animation(Theme.Motion.flow, value: ready)
            }
            .padding(.horizontal, 26)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .background(Theme.linen)
        .onAppear(perform: prefill)
    }

    private func field(_ label: String, _ hint: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: label)
            TextField(hint, text: text)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
        }
        .padding(.top, 30)
    }

    private func add(_ raw: String) {
        let s = raw.trimmingCharacters(in: .whitespaces)
        // Six is as many as a card can show without becoming a list.
        guard !s.isEmpty, specialties.count < 6, !specialties.contains(s) else { return }
        specialties.append(s)
        draftSpecialty = ""
    }

    private func prefill() {
        guard let existing, name.isEmpty else {
            if country.isEmpty { country = defaultCountry }
            return
        }
        name = existing.name
        credentials = existing.credentials
        bio = existing.bio
        specialties = existing.specialties
        offersVideo = existing.offers_video
        country = existing.country
        price = String(existing.price_credits)
        active = existing.active
    }

    private func save() async {
        saving = true
        failure = nil
        do {
            _ = try await SpecialistsClient().apply(
                name: name.trimmingCharacters(in: .whitespaces),
                country: country.trimmingCharacters(in: .whitespaces),
                credentials: credentials.trimmingCharacters(in: .whitespaces),
                bio: bio.trimmingCharacters(in: .whitespaces),
                specialties: specialties,
                offersVideo: offersVideo,
                priceCredits: Int(price.filter(\.isNumber)) ?? 0,
                active: active
            )
            Haptics.tap()
            await done()
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
        saving = false
    }
}
