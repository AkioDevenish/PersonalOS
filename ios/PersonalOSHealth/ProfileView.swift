import SwiftUI
import ClerkKit
import ClerkKitUI

/// The account, and only the account.
///
/// A title, who you are, one card for the thing you might do next on the
/// platform, and a list of settings. It used to also hold goals, the sync
/// buttons, a practitioner's queue and a reviewer's tools, which made it the
/// place everything without a home was put. Those now live with what they
/// belong to: goals in Health, sync and sources behind Health data, and the
/// practitioner's work behind the card.
struct ProfileView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.openURL) private var openURL

    @State private var application: SpecialistsClient.Application?
    @State private var abilities = ArticlesClient.Abilities(canWrite: false, canReview: false)
    @State private var showAccount = false
    @State private var applying = false
    @State private var showModels = false
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

                row("person.crop.circle", "Personal information") { showAccount = true }
                row("creditcard", "Plan and payments", route: .paywall)
                row("heart.text.square", "Health data", route: .healthData)
                row("sparkles", "AI model and keys") { showModels = true }
                row("bell", "Notifications") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                row("lock.shield", "Login and security") { showAccount = true }

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
                    .underline()
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
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { application = try? await SpecialistsClient().desk().application }
        .task { if let a = try? await ArticlesClient().abilities() { abilities = a } }
        .sheet(isPresented: $showAccount) { UserProfileView() }
        .sheet(isPresented: $showModels) { NavigationStack { ModelSettingsView() } }
        .sheet(isPresented: $applying) {
            SpecialistApplicationSheet(existing: application, defaultCountry: Cuisine.deviceDefault) {
                application = try? await SpecialistsClient().desk().application
            }
        }
        .confirmationDialog("Log out of Personal OS?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                Task {
                    // Hand the device back before the session goes, or the
                    // token stays pointed at an account nobody is signed in to.
                    await Push.handBack()
                    try? await clerk.auth.signOut()
                }
            }
        }
    }

    // MARK: You

    private var you: some View {
        Button { showAccount = true } label: {
            HStack(spacing: 14) {
                Avatar(user: clerk.user, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(Theme.sans(18, medium: true))
                        .foregroundStyle(Theme.text)
                    Text("Show profile")
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
        guard let u = clerk.user else { return "Not signed in" }
        let name = [u.firstName, u.lastName].compactMap { $0 }.joined(separator: " ")
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return u.emailAddresses.first?.emailAddress ?? "Your account"
    }

    // MARK: The card

    /// The one thing worth putting in front of somebody here: becoming a
    /// practitioner, or, once they are one, the way into their practice.
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
                    title: application == nil ? "Practise on Personal OS" : "Your application",
                    note: application == nil
                        ? "Get verified, offer consultations and write for Home."
                        : (application?.declined == true
                           ? "Not approved yet. You can update it and send it again."
                           : "With our team. You'll be listed once it's checked.")
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

/// Circular profile picture, falling back to the mark so the row never
/// collapses while the image loads or when no photo has been set.
struct Avatar: View {
    let user: User?
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle().fill(Theme.surface)

            if let user, user.hasImage, let url = URL(string: user.imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
                .clipShape(Circle())
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.42))
            .foregroundStyle(Theme.tertiaryText)
    }
}
