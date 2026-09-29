import SwiftUI

/// Getting set up, seven pages.
struct OnboardingView: View {
    /// Called once the person is through, whatever they chose along the way.
    var finish: () -> Void

    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var session: Session

    @State private var page = 0
    @State private var forward = true
    @State private var healthConnected = false
    @State private var notificationsOn = false
    @State private var showingPlans = false
    @State private var working = false

    private let pages = Paywall.enabled ? 7 : 6

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 10)

            ZStack {
                Group {
                    switch page {
                    case 0: hello
                    case 1: privacyPage
                    case 2: healthPage
                    case 3: notificationsPage
                    case 4: tourPage
                    case 5 where Paywall.enabled: planPage
                    default: readyPage
                    }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .appBackground()
        .sheet(isPresented: $showingPlans) {
            PaywallView(reason: "suggest meals and read what practitioners write")
        }
    }

    // MARK: Chrome

    /// A back arrow and one continuous bar.
    private var header: some View {
        HStack(spacing: 14) {
            Button { go(page - 1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.press)
            .opacity(page == 0 || page == pages - 1 ? 0 : 1)
            .disabled(page == 0 || page == pages - 1)
            .accessibilityLabel("Back")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.separator)
                    Capsule()
                        .fill(Theme.text)
                        .frame(width: max(6, geo.size.width * progress))
                }
            }
            .frame(height: 4)
            .animation(Theme.Motion.flow, value: page)
            .accessibilityLabel("Step \(page + 1) of \(pages)")

            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var progress: Double { Double(page + 1) / Double(pages) }

    private func go(_ next: Int) {
        guard next >= 0, next < pages else { return }
        forward = next > page
        Haptics.select()
        withAnimation(Theme.Motion.settle) { page = next }
    }

    /// The layout every page shares: picture, words, then the buttons pinned to the bottom where a
    /// thumb already is.
    private func layout<Art: View>(
        kicker: String,
        title: String,
        body: String,
        artHeight: CGFloat? = 230,
        @ViewBuilder art: () -> Art,
        primary: String,
        primaryDone: Bool = false,
        reassurance: String? = nil,
        action: @escaping () async -> Void,
        skip: String? = nil
    ) -> some View {
        let words = VStack(alignment: .leading, spacing: 10) {
            Text(kicker.uppercased())
                .font(Theme.sans(11, medium: true))
                .tracking(1.8)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(Theme.serif(artHeight == nil ? 28 : 34))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if !body.isEmpty {
                Text(body)
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return VStack(spacing: 0) {
            if artHeight == nil {
                // A page that asks something puts the question above the answers, the way a
                // question works.
                words.padding(.top, 10)
                ScrollView {
                    art().frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                Spacer(minLength: 8)
                art()
                    .frame(maxWidth: .infinity)
                    .frame(height: artHeight)
                Spacer(minLength: 8)
                words
                Spacer(minLength: 20)
            }

            VStack(spacing: 6) {
                // Said before the button, not after it, because the worry it answers is the reason
                // somebody's thumb is hovering.
                if let reassurance {
                    Text(reassurance)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }

                Button {
                    Task {
                        working = true
                        await action()
                        working = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(Theme.background) }
                        else if primaryDone { Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)) }
                        Text(primary)
                    }
                    .font(Theme.sans(16, medium: true))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Theme.text, in: Capsule())
                }
                .buttonStyle(.press)
                .disabled(working)

                if let skip {
                    Button { go(page + 1) } label: {
                        Text(skip)
                            .font(Theme.sans(15, medium: true))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.press)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 8)
    }

    private func plate(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.text)
            .accessibilityHidden(true)
    }

    private var firstName: String {
        guard let name = session.account?.name, !name.isEmpty else { return "" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    // MARK: 1 · Hello

    private var hello: some View {
        layout(
            kicker: "Welcome",
            title: firstName.isEmpty ? "Let's get you set up." : "Hello, \(firstName).",
            body: "A few quick steps. Skip any of them.",
            art: { WalkingVideo().accessibilityHidden(true) },
            primary: "Begin",
            action: { go(1) }
        )
    }

    // MARK: 2 · Privacy

    /// Said before Apple Health is asked for, not after.
    private var privacyPage: some View {
        layout(
            kicker: "Privacy",
            title: "Your data stays yours.",
            body: "Meal ideas are made on your phone. We never sell your health data or send it to an AI company.",
            art: {
                ZStack {
                    Circle().fill(Theme.positive.opacity(0.10)).frame(width: 180, height: 180)
                    Circle().fill(Theme.positive.opacity(0.16)).frame(width: 120, height: 120)
                    Image(systemName: "lock")
                        .font(.system(size: 46, weight: .light))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(Theme.positive)
                        .symbolEffect(.bounce, value: page)
                }
                .accessibilityHidden(true)
            },
            primary: "Good to know",
            action: { go(2) }
        )
    }

    // MARK: 3 · Apple Health

    private var healthPage: some View {
        layout(
            kicker: "Meals",
            title: "Connect Apple Health.",
            body: "So meal ideas fit your sleep, activity and glucose.",
            art: { plate("watch") },
            primary: healthConnected ? "Connected" : "Connect Apple Health",
            primaryDone: healthConnected,
            reassurance: "You choose what to share, and can change it later.",
            action: {
                if healthConnected { go(3); return }
                try? await health.requestAuthorization()
                healthConnected = true
                try? await Task.sleep(for: .milliseconds(450))
                go(3)
            },
            skip: "Not now"
        )
    }

    // MARK: 4 · Notifications

    private var notificationsPage: some View {
        layout(
            kicker: "Notifications",
            title: "Know when they reply.",
            body: "We'll only notify you when a nutritionist replies.",
            art: {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.10)).frame(width: 180, height: 180)
                    Circle().fill(Theme.accent.opacity(0.16)).frame(width: 120, height: 120)
                    Image(systemName: "bell")
                        .font(.system(size: 46, weight: .light))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.wiggle, options: .repeat(2), value: page)
                }
                .accessibilityHidden(true)
            },
            primary: notificationsOn ? "Turned on" : "Turn on notifications",
            primaryDone: notificationsOn,
            reassurance: "Turn them off any time in Settings.",
            action: {
                if notificationsOn { go(4); return }
                if await Notifier.shared.permitted() {
                    notificationsOn = true
                    Push.register()
                }
                try? await Task.sleep(for: .milliseconds(450))
                go(4)
            },
            skip: "Not now"
        )
    }

    // MARK: 5 · What is in here

    private var tourPage: some View {
        layout(
            kicker: "What you'll find",
            title: "Here's what's inside.",
            body: "",
            artHeight: nil,
            art: {
                VStack(spacing: 2) {
                    tourRow("leaf", "Meals", "What to eat next, with food from where you live.")
                    tourRow("stethoscope", "Experts", "Chat with a nutritionist.")
                    tourRow("newspaper", "Articles", "Written by practitioners, checked by our team.")
                }
            },
            primary: "Nearly there",
            action: { go(5) }
        )
    }

    private func tourRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .environment(\.symbolVariants, .none)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sans(16, medium: true))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    // MARK: 6 · What costs money

    /// Said plainly rather than hidden, because the free app is genuinely usable and a paywall that
    /// overstates itself is both dishonest and a review risk.
    private var planPage: some View {
        layout(
            kicker: "Pricing",
            title: "Start free.",
            body: "Browsing experts and articles is free. A subscription adds meal ideas and the full article library.",
            art: {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.10)).frame(width: 180, height: 180)
                    Image(systemName: "sparkles")
                        .font(.system(size: 46, weight: .light))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.bounce, value: page)
                }
                .accessibilityHidden(true)
            },
            primary: "See what's included",
            action: { showingPlans = true },
            skip: "Continue with the free app"
        )
    }

    // MARK: 7 · Ready

    private var readyPage: some View {
        layout(
            kicker: "All set",
            title: "You're ready.",
            body: "Everything updates on its own.",
            art: {
                ZStack {
                    Circle().fill(Theme.positive.opacity(0.12)).frame(width: 150, height: 150)
                    Image(systemName: "checkmark")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Theme.positive)
                        .symbolEffect(.bounce, value: page)
                }
                .accessibilityHidden(true)
            },
            primary: "Open Personal OS",
            action: {
                Haptics.tap()
                finish()
            }
        )
    }
}

/// Shows the introduction once, then gets out of the way for good.
struct OnboardingGate<Content: View>: View {
    /// Versioned, so a new introduction is shown once even to people who finished the old one.
    @AppStorage("onboarded_v4") private var done = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            if done {
                content
            } else {
                OnboardingView {
                    withAnimation(Theme.Motion.settle) { done = true }
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: honourResetRequest)
    }

    /// Lets a debug build be launched with RESET_ONBOARDING set to see the introduction again.
    private func honourResetRequest() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["RESET_ONBOARDING"] != nil {
            done = false
        }
        #endif
    }
}
