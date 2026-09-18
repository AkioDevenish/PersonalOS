import SwiftUI

/// Getting set up, five pages, about a minute.
///
/// An introduction that only describes the app is skipped by everybody, so
/// each page here does something: it connects Apple Health, sets a first
/// goal, and asks about notifications, each at the moment its reason is on
/// screen. Every step can be passed over; nothing is required to get in.
///
/// It opens with the walking figure and closes on a real number from the
/// person's own day, so the last thing they see before the app is the app
/// already working for them.
struct OnboardingView: View {
    /// Called once the person is through, whatever they chose along the way.
    var finish: () -> Void

    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var session: Session

    @State private var page = 0
    @State private var forward = true
    @State private var healthConnected = false
    @State private var notificationsOn = false
    @State private var chosenGoals: Set<String> = ["steps"]
    @State private var working = false
    @State private var todaySteps: Double?

    private let pages = 5

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 10)

            ZStack {
                Group {
                    switch page {
                    case 0: hello
                    case 1: healthPage
                    case 2: goalsPage
                    case 3: notificationsPage
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
    }

    // MARK: Chrome

    /// A back arrow, and one segment of progress per page, filling as you go.
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

            HStack(spacing: 6) {
                ForEach(0..<pages, id: \.self) { i in
                    Capsule()
                        .fill(i <= page ? Theme.text : Theme.separator)
                        .frame(height: 4)
                }
            }
            .animation(Theme.Motion.flow, value: page)

            Color.clear.frame(width: 32, height: 32)
        }
    }

    private func go(_ next: Int) {
        guard next >= 0, next < pages else { return }
        forward = next > page
        Haptics.select()
        withAnimation(Theme.Motion.settle) { page = next }
    }

    /// The layout every page shares: picture, words, then the buttons pinned
    /// to the bottom where a thumb already is.
    private func layout<Art: View>(
        kicker: String,
        title: String,
        body: String,
        @ViewBuilder art: () -> Art,
        primary: String,
        primaryDone: Bool = false,
        action: @escaping () async -> Void,
        skip: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            art()
                .frame(maxWidth: .infinity)
                .frame(height: 230)
            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 10) {
                Text(kicker.uppercased())
                    .font(Theme.sans(11, medium: true))
                    .tracking(1.8)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(body)
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 20)

            VStack(spacing: 6) {
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
            body: "Three quick things and you're in. It takes about a minute, and you can skip any of them.",
            art: { WalkingVideo().accessibilityHidden(true) },
            primary: "Begin",
            action: { go(1) }
        )
    }

    // MARK: 2 · Apple Health

    private var healthPage: some View {
        layout(
            kicker: "Your readings",
            title: "Connect Apple Health.",
            body: "Steps, sleep, heart rate and the rest, read straight from your iPhone and watch. Nothing to type in, ever.",
            art: { plate("watch") },
            primary: healthConnected ? "Connected" : "Connect Apple Health",
            primaryDone: healthConnected,
            action: {
                if healthConnected { go(2); return }
                try? await health.requestAuthorization()
                healthConnected = true
                // Nothing, or zero, reads as a broken app rather than a quiet
                // morning; Health also returns nothing when access was declined.
                if let steps = try? await health.fetchTodaySnapshot().steps, steps > 0 { todaySteps = steps }
                try? await Task.sleep(for: .milliseconds(450))
                go(2)
            },
            skip: "Not now"
        )
    }

    // MARK: 3 · A first goal

    private struct Suggestion {
        let id: String
        let symbol: String
        let label: String
        let value: String
    }

    private var suggestions: [Suggestion] {
        ["steps", "sleep", "daylight"].compactMap { id in
            guard let spec = Metrics.by(id: id), let target = Goals.suggestion(for: spec) else { return nil }
            let unit = spec.unit.isEmpty ? "" : " \(spec.unit)"
            let shown = spec.precision == 0 ? MetricSpec.grouped(target) : Goals.editable(spec, target)
            return Suggestion(id: id, symbol: spec.symbol, label: spec.label, value: "\(shown)\(unit)")
        }
    }

    private var goalsPage: some View {
        layout(
            kicker: "Something to aim at",
            title: "Pick a first goal.",
            body: "The daily briefing closes with whichever ones the day hasn't met. You can change them any time.",
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
                for s in suggestions {
                    guard let spec = Metrics.by(id: s.id) else { continue }
                    if chosenGoals.contains(s.id) { Goals.set(s.id, Goals.suggestion(for: spec)) }
                }
                go(3)
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

    // MARK: 4 · Notifications

    private var notificationsPage: some View {
        layout(
            kicker: "Staying in touch",
            title: "Hear back when it matters.",
            body: "Only when a practitioner replies or a reading you asked for is ready. Never to tell you to open the app.",
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

    // MARK: 5 · Ready

    private var readyPage: some View {
        layout(
            kicker: "All set",
            title: todaySteps.map { _ in "Your day, already counted." } ?? "You're ready.",
            body: todaySteps != nil
                ? "Apple Health is already filling in your ledger, and it will keep doing so on its own."
                : "Everything you connect later fills in on its own. There's nothing to maintain.",
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
            // Counted up from nothing the first time the page appears, so the
            // figure arrives rather than simply sitting there.
            guard let steps = try? await health.fetchTodaySnapshot().steps, steps > 0 else { return }
            todaySteps = 0
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) { todaySteps = steps }
        }
    }
}

/// Shows the introduction once, then gets out of the way for good.
struct OnboardingGate<Content: View>: View {
    /// Versioned, so a new introduction is shown once even to people who
    /// finished the old one.
    @AppStorage("onboarded_v2") private var done = false
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

    /// Lets a debug build be launched with RESET_ONBOARDING set to see the
    /// introduction again.
    ///
    /// The alternative is deleting the app, which clears the flag but takes
    /// the signed-in session and the granted Health permissions with it. This
    /// is compiled out of release builds entirely.
    private func honourResetRequest() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["RESET_ONBOARDING"] != nil {
            done = false
        }
        #endif
    }
}
