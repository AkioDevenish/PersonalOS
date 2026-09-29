import SwiftUI

/// Getting set up, eleven pages, two or three minutes.
struct OnboardingView: View {
    /// Called once the person is through, whatever they chose along the way.
    var finish: () -> Void

    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var session: Session

    @State private var page = 0
    @State private var forward = true
    @State private var healthConnected = false
    @State private var notificationsOn = false
    @State private var chosenFocus: Set<String> = []
    @State private var rhythm: String?
    @State private var chosenGoals: Set<String> = []
    @State private var showingPlans = false
    @State private var working = false
    @State private var todaySteps: Double?

    private let pages = 11

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 10)

            ZStack {
                Group {
                    switch page {
                    case 0: hello
                    case 1: focusPage
                    case 2: encouragementPage
                    case 3: rhythmPage
                    case 4: goalsPage
                    case 5: privacyPage
                    case 6: healthPage
                    case 7: notificationsPage
                    case 8: tourPage
                    case 9: planPage
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
        .background(Theme.background)
        .sheet(isPresented: $showingPlans) {
            PaywallView(reason: "read what practitioners write and keep your readings")
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

    /// One tappable answer: a pill that fills in when it is chosen.
    private func choice(_ label: String, _ symbol: String?, on: Bool, tap: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            withAnimation(Theme.Motion.bouncy, tap)
        } label: {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .light))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(on ? Theme.background : Theme.accent)
                        .frame(width: 22)
                }
                Text(label)
                    .font(Theme.sans(16, medium: true))
                    .foregroundStyle(on ? Theme.background : Theme.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(on ? Theme.text : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(on ? .clear : Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.press)
    }

    // MARK: 1 · Hello

    private var hello: some View {
        layout(
            kicker: "Welcome",
            title: firstName.isEmpty ? "Let's get you set up." : "Hello, \(firstName).",
            body: "A few quick questions. Skip any of them.",
            art: { WalkingVideo().accessibilityHidden(true) },
            primary: "Begin",
            action: { go(1) }
        )
    }

    // MARK: 2 · What you care about

    /// The focus options, and the metric each one is really about.
    private struct Focus {
        let id: String
        let label: String
        let symbol: String
        let metric: String?
    }

    private let focuses: [Focus] = [
        .init(id: "move", label: "Move more", symbol: "figure.walk", metric: "steps"),
        .init(id: "sleep", label: "Sleep better", symbol: "moon.stars", metric: "sleep"),
        .init(id: "outside", label: "Get outside", symbol: "sun.max", metric: "daylight"),
        .init(id: "calm", label: "Feel calmer", symbol: "brain.head.profile", metric: "mindful"),
        .init(id: "cycle", label: "Follow my cycle", symbol: "drop", metric: nil),
        .init(id: "other", label: "Something else", symbol: "sparkles", metric: nil),
    ]

    private var focusPage: some View {
        layout(
            kicker: "To begin with",
            title: "What would you like to take care of?",
            body: "Pick as many as you like.",
            artHeight: nil,
            art: {
                VStack(spacing: 8) {
                    ForEach(focuses, id: \.id) { f in
                        choice(f.label, f.symbol, on: chosenFocus.contains(f.id)) {
                            if chosenFocus.contains(f.id) { chosenFocus.remove(f.id) }
                            else { chosenFocus.insert(f.id) }
                        }
                    }
                }
            },
            primary: "Continue",
            reassurance: "You'll still have access to everything.",
            action: {
                chosenGoals = Set(focuses.filter { chosenFocus.contains($0.id) }.compactMap(\.metric))
                go(2)
            },
            skip: "Skip"
        )
    }

    // MARK: 3 · A word back

    private var encouragementPage: some View {
        layout(
            kicker: "Nice",
            title: "That's the hard part done.",
            body: "The rest is just a few switches.",
            art: { plate("stride").padding(.horizontal, 40) },
            primary: "Keep going",
            action: { go(3) }
        )
    }

    // MARK: 4 · How the week usually goes

    private let rhythms: [(id: String, label: String, scale: Double)] = [
        ("rarely", "Rarely — I'm mostly sitting", 0.70),
        ("sometimes", "A few times a week", 0.85),
        ("most", "Most days", 1.00),
        ("daily", "Every day, without fail", 1.20),
    ]

    private var rhythmPage: some View {
        layout(
            kicker: "Your week",
            title: "How often do you get moving?",
            body: "So your first target is one you can hit.",
            artHeight: nil,
            art: {
                VStack(spacing: 8) {
                    ForEach(rhythms, id: \.id) { r in
                        choice(r.label, nil, on: rhythm == r.id) { rhythm = r.id }
                    }
                }
            },
            primary: "Continue",
            reassurance: "You can change targets any time.",
            action: { go(4) },
            skip: "Skip"
        )
    }

    // MARK: 5 · A first goal

    private struct Suggestion {
        let id: String
        let symbol: String
        let label: String
        let value: String
        let target: Double
    }

    /// What the goals page offers: whatever the focus page implied, then the usual three to fill
    /// out the list, never the same one twice.
    private var suggestions: [Suggestion] {
        let wanted = focuses.filter { chosenFocus.contains($0.id) }.compactMap(\.metric)
        var ids = wanted
        for id in ["steps", "sleep", "daylight"] where !ids.contains(id) { ids.append(id) }

        return ids.prefix(4).compactMap { id in
            guard let spec = Metrics.by(id: id), let base = Goals.suggestion(for: spec) else { return nil }
            let target = id == "steps" ? scaled(base) : base
            let unit = spec.unit.isEmpty ? "" : " \(spec.unit)"
            let shown = spec.precision == 0 ? MetricSpec.grouped(target) : Goals.editable(spec, target)
            return Suggestion(id: id, symbol: spec.symbol, label: spec.label, value: "\(shown)\(unit)", target: target)
        }
    }

    /// The step target, moved to meet the week that was described.
    private func scaled(_ base: Double) -> Double {
        guard let id = rhythm, let scale = rhythms.first(where: { $0.id == id })?.scale else { return base }
        return (base * scale / 100).rounded() * 100
    }

    private var goalsPage: some View {
        layout(
            kicker: "Something to aim at",
            title: "Pick a first goal.",
            body: "Change them any time.",
            artHeight: nil,
            art: {
                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.id) { s in
                        goalCard(s)
                    }
                }
                .padding(.horizontal, 4)
            },
            primary: chosenGoals.isEmpty ? "Continue" : "Set \(chosenGoals.count == 1 ? "this goal" : "these goals")",
            action: {
                for s in suggestions where chosenGoals.contains(s.id) {
                    Goals.set(s.id, s.target)
                }
                go(5)
            },
            skip: "Skip"
        )
    }

    private func goalCard(_ s: Suggestion) -> some View {
        let on = chosenGoals.contains(s.id)
        return Button {
            Haptics.select()
            withAnimation(Theme.Motion.bouncy) {
                if on { chosenGoals.remove(s.id) } else { chosenGoals.insert(s.id) }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: s.symbol)
                    .font(.system(size: 18, weight: .light))
                    .environment(\.symbolVariants, .none)
                    .foregroundStyle(on ? Theme.background : Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(on ? Theme.text : Theme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.label)
                        .font(Theme.sans(16, medium: true))
                        .foregroundStyle(Theme.text)
                    Text(s.value)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Theme.text : Theme.separator)
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(on ? Theme.text : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.press)
    }

    // MARK: 6 · What happens to it

    /// Said before Apple Health is asked for, not after.
    private var privacyPage: some View {
        layout(
            kicker: "Privacy",
            title: "Your data stays yours.",
            body: "Readings are written on this phone. Your health data is never sold or sent to an AI company.",
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
            action: { go(6) }
        )
    }

    // MARK: 7 · Apple Health

    /// Named after the goal that was just set, when there was one, so the permission arrives
    /// attached to something the person asked for.
    private var healthReason: String {
        guard let first = suggestions.first(where: { chosenGoals.contains($0.id) }) else {
            return "Steps, sleep, heart rate and more, straight from your iPhone and watch."
        }
        return "So \(first.label.lowercased()) counts itself."
    }

    private var healthPage: some View {
        layout(
            kicker: "Your readings",
            title: "Connect Apple Health.",
            body: healthReason,
            art: { plate("watch") },
            primary: healthConnected ? "Connected" : "Connect Apple Health",
            primaryDone: healthConnected,
            reassurance: "You choose what to share, and can change it later.",
            action: {
                if healthConnected { go(7); return }
                healthConnected = (try? await health.requestAuthorization()) != nil
                // Nothing, or zero, reads as a broken app rather than a quiet morning; Health also
                // returns nothing when access was declined.
                if let steps = try? await health.fetchTodaySnapshot().steps, steps > 0 { todaySteps = steps }
                try? await Task.sleep(for: .milliseconds(450))
                go(7)
            },
            skip: "Not now"
        )
    }

    // MARK: 8 · Notifications

    private var notificationsPage: some View {
        layout(
            kicker: "Staying in touch",
            title: "Hear back when it matters.",
            body: "Only when a practitioner replies or a reading is ready.",
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
                if notificationsOn { go(8); return }
                if await Notifier.shared.permitted() {
                    notificationsOn = true
                    Push.register()
                }
                try? await Task.sleep(for: .milliseconds(450))
                go(8)
            },
            skip: "Not now"
        )
    }

    // MARK: 9 · What is in here

    private var tourPage: some View {
        layout(
            kicker: "What you'll find",
            title: "Here's what's inside.",
            body: "",
            artHeight: nil,
            art: {
                VStack(spacing: 2) {
                    tourRow("newspaper", "Daily news", "What changed since yesterday.")
                    tourRow("waveform.path.ecg", "Your readings", "Everything your phone and watch record.")
                    tourRow("stethoscope", "Practitioners", "Ask a qualified practitioner.")
                    tourRow("drop", "Your cycle", "Tracked on this phone only.")
                }
            },
            primary: "Nearly there",
            action: { go(9) }
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

    // MARK: 10 · What costs money

    /// Said plainly rather than hidden, because the free app is genuinely usable and a paywall that
    /// overstates itself is both dishonest and a review risk.
    private var planPage: some View {
        layout(
            kicker: "Pricing",
            title: "Most of it is free.",
            body: "Charts, goals and cycle tracking are free. A subscription adds readings, meal ideas and practitioners' articles.",
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

    // MARK: 11 · Ready

    private var readyPage: some View {
        layout(
            kicker: "All set",
            title: todaySteps.map { _ in "Your day, already counted." } ?? "You're ready.",
            body: todaySteps != nil
                ? "Apple Health keeps this up to date on its own."
                : "Everything updates on its own.",
            art: {
                if let steps = todaySteps {
                    VStack(spacing: 4) {
                        Text(MetricSpec.grouped(steps))
                            .font(Theme.serif(76))
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText(value: steps))
                            .monospacedDigit()
                        Text("steps today")
                            .font(Theme.sans(14, medium: true))
                            .tracking(1.2)
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else {
                    ZStack {
                        Circle().fill(Theme.positive.opacity(0.12)).frame(width: 150, height: 150)
                        Image(systemName: "checkmark")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(Theme.positive)
                            .symbolEffect(.bounce, value: page)
                    }
                    .accessibilityHidden(true)
                }
            },
            primary: "Open Personal OS",
            action: {
                Haptics.tap()
                finish()
            }
        )
        .task {
            // Counted up from nothing the first time the page appears, so the figure arrives rather
            // than simply sitting there.
            guard let steps = try? await health.fetchTodaySnapshot().steps, steps > 0 else { return }
            todaySteps = 0
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) { todaySteps = steps }
        }
    }
}

/// Shows the introduction once, then gets out of the way for good.
struct OnboardingGate<Content: View>: View {
    @AppStorage(LocalData.onboardedKey) private var done = false
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
