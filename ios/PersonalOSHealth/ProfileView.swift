import SwiftUI

/// The account, and only the account.
struct ProfileView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.openURL) private var openURL

    @State private var application: SpecialistsClient.Application?
    @State private var abilities = ArticlesClient.Abilities(canWrite: false, canReview: false)
    @State private var showAccount = false
    @State private var applying = false
    @State private var confirmingSignOut = false

    private let margin: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Profile")
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 12)

                you
                    .padding(.top, 18)

                Divider().padding(.top, 18)

                practiceCard
                    .padding(.top, 22)

                Text("Settings")
                    .font(Theme.sans(22, medium: true))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 34)
                    .padding(.bottom, 6)

                if Paywall.enabled {
                    row("creditcard", "Plan and payments", route: .paywall)
                }
                row("bell", "Notifications") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                // An app that sells an auto-renewing subscription has to carry working links to
                // both of these, and somebody handing over their health data is owed a way to read
                // what happens to it without going looking for a website.
                row("hand.raised", "Privacy") { openURL(AppConfig.privacyURL) }
                row("doc.text", "Terms") { openURL(AppConfig.termsURL) }

                if abilities.canReview {
                    Text("Team")
                        .font(Theme.sans(22, medium: true))
                        .foregroundStyle(Theme.text)
                        .padding(.top, 30)
                        .padding(.bottom, 6)
                    row("checkmark.seal", "Review articles", route: .reviewArticles)
                }

                Button("Log out") { confirmingSignOut = true }
                    .font(Theme.sans(16, medium: true))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 30)

                Text(buildStamp)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, margin)
        }
        .compactsTabBar()
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { application = try? await SpecialistsClient().desk().application }
        .task { if let a = try? await ArticlesClient().abilities() { abilities = a } }
        .sheet(isPresented: $showAccount) { AccountView() }
        .sheet(isPresented: $applying) {
            SpecialistApplicationSheet(existing: application, defaultCountry: Cuisine.deviceDefault) {
                application = try? await SpecialistsClient().desk().application
            }
        }
        .confirmationDialog("Log out of Personal OS?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                Task {
                    // Hand the device back before the session goes, or the token stays pointed at
                    // an account nobody is signed in to.
                    await Push.handBack()
                    await session.signOut()
                }
            }
        }
    }

    // MARK: You

    private var you: some View {
        Button { showAccount = true } label: {
            HStack(spacing: 14) {
                Avatar(account: session.account, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(Theme.sans(18, medium: true))
                        .foregroundStyle(Theme.text)
                    Text("Show profile and account")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }

    private var displayName: String {
        session.account?.displayName ?? "Your account"
    }

    // MARK: The card

    /// The one thing worth putting in front of somebody here: becoming a practitioner, or, once
    /// they are one, the way into their practice.
    @ViewBuilder
    private var practiceCard: some View {
        if application?.approved == true {
            NavigationLink(value: Route.practiceHub) {
                card(
                    title: "Your practice",
                    note: abilities.canWrite
                        ? "Consultations, your articles and your listing."
                        : "Consultations and your listing."
                )
            }
            .buttonStyle(.pressRow)
        } else {
            Button { applying = true } label: {
                card(
                    title: application == nil ? "Join as a nutritionist" : "Your application",
                    note: application == nil
                        ? "Get verified, take clients and write articles."
                        : (application?.declined == true
                           ? "Not approved yet. You can update it and send it again."
                           : "We're reviewing it. You'll be listed once it's approved.")
                )
            }
            .buttonStyle(.pressRow)
        }
    }

    private func card(title: String, note: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Theme.sans(17, medium: true))
                    .foregroundStyle(Theme.text)
                Text(note)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image("ledger")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.text)
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 4)
    }

    // MARK: Rows

    private func row(_ symbol: String, _ title: String, route: Route) -> some View {
        NavigationLink(value: route) { rowLabel(symbol, title) }
            .buttonStyle(.pressRow)
    }

    private func row(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(symbol, title) }
            .buttonStyle(.pressRow)
    }

    private func rowLabel(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .light))
                    .environment(\.symbolVariants, .none)
                    .foregroundStyle(Theme.text)
                    .frame(width: 26)
                Text(title)
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.text)
                Spacer()
                chevron
            }
            .padding(.vertical, 17)
            Divider()
        }
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
    }

    private var buildStamp: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}

/// The practitioner's side of the app, gathered in one place.
struct PracticeHubView: View {
    @State private var application: SpecialistsClient.Application?
    @State private var abilities = ArticlesClient.Abilities(canWrite: false, canReview: false)
    @State private var editing = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.practice) {
                    Label("Consultations", systemImage: "bubble.left.and.bubble.right")
                }
                if abilities.canWrite {
                    NavigationLink(value: Route.myArticles) {
                        Label("Your articles", systemImage: "doc.text")
                    }
                }
                Button { editing = true } label: {
                    Label("Your listing", systemImage: "person.text.rectangle")
                }
                NavigationLink(value: Route.payouts) {
                    Label("Getting paid", systemImage: "building.columns")
                }
            } footer: {
                Text(application?.active == false
                     ? "Your listing is switched off, so people can't book you right now."
                     : "People can find and book you in Practitioners.")
            }
        }
        .navigationTitle("Your practice")
        .task { application = try? await SpecialistsClient().desk().application }
        .task { if let a = try? await ArticlesClient().abilities() { abilities = a } }
        .sheet(isPresented: $editing) {
            SpecialistApplicationSheet(existing: application, defaultCountry: Cuisine.deviceDefault) {
                application = try? await SpecialistsClient().desk().application
            }
        }
    }
}

/// Circular profile picture, or the person's initials when there is none.
struct Avatar: View {
    let account: Session.Account?
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle().fill(Theme.surface)
            if let link = account?.image, let url = URL(string: link) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { initials }
                }
                .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var initials: some View {
        let letters = (account?.name ?? "")
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
        if letters.isEmpty {
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(Theme.tertiaryText)
        } else {
            Text(letters)
                .font(Theme.sans(size * 0.36, medium: true))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

/// The account itself: a name to change, the email it signs in with, and the way out.
struct AccountView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var failure: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Avatar(account: session.account, size: 84)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Name") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .submitLabel(.done)
                        .onSubmit { Task { await save() } }
                }
                Section("Email") {
                    Text(session.account?.email ?? "")
                        .foregroundStyle(Theme.secondaryText)
                }
                if let failure {
                    Section { Text(failure).foregroundStyle(.red) }
                }
                Section {
                    Button("Delete account", role: .destructive) { confirmingDelete = true }
                } footer: {
                    Text("Removes your account and signs you out everywhere. This can't be undone.")
                }
            }
            .navigationTitle("Account")
            .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    Task {
                        await Push.handBack()
                        do { try await session.deleteAccount() } catch { failure = error.localizedDescription }
                    }
                }
            } message: {
                Text("This deletes your account and all your data.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(saving || name == (session.account?.name ?? ""))
                }
            }
            .onAppear { name = session.account?.name ?? "" }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await session.rename(name)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
