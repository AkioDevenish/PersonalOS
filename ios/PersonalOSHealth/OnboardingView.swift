import SwiftUI

/// The three pages between signing in and the ledger itself.
///
/// It exists for one practical reason beyond introductions: Health access was
/// being asked for from seven different screens, whichever the person happened
/// to open first, so the request arrived with no explanation attached. Asking
/// once, here, after saying what the app does with the data, is both a kinder
/// prompt and a better-answered one.
///
/// The plates are 19th century engravings, masked to ink on a transparent
/// ground so the linen shows through them rather than a white square sitting
/// on the page. The pocket watch is the app icon, so the last page closes a
/// loop back to the thing they tapped to get here.
struct OnboardingView: View {
    /// Called once the person is through, whether or not they granted access.
    var finish: () -> Void

    @EnvironmentObject private var health: HealthKitManager
    @State private var page = 0
    @State private var connecting = false
    @State private var failure: String?

    private struct Leaf {
        let plate: String
        let kicker: String
        let title: String
        let body: String
    }

    private let leaves = [
        Leaf(
            plate: "ledger",
            kicker: "The idea",
            title: "A ledger, not a dashboard",
            body: """
            Personal OS keeps a written record of your days. Figures where \
            figures help, sentences where they do not. A page to read, rather \
            than a wall of dials to interpret.
            """
        ),
        Leaf(
            plate: "stride",
            kicker: "The record",
            title: "Your body, recorded",
            body: """
            Eighteen measures arrive from Apple Health on their own: steps and \
            sleep, heart and gait, and the quieter ones underneath. Nothing is \
            typed in by hand, and nothing is guessed at.
            """
        ),
        Leaf(
            plate: "watch",
            kicker: "The reading",
            title: "Time well spent",
            body: """
            A specialist reads the ledger and writes back in plain words. What \
            moved, what it means, and the one thing worth doing about it today. \
            Your ledger stays yours.
            """
        ),
    ]

    private var last: Bool { page == leaves.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 8)

            // Keyed on the page so the whole leaf is torn off and replaced,
            // which is what makes the drift read as turning to the next one
            // rather than the words changing underneath a static picture.
            leaf(leaves[page])
                .id(page)
                .transition(.drift(28))

            Spacer(minLength: 8)

            marks
                .padding(.bottom, 26)

            actions
                .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.linen)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                    go(to: page + (drag.translation.width < 0 ? 1 : -1))
                }
        )
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Spacer()
            // Only worth offering while there is something to skip past. On
            // the last page the buttons underneath already say both things.
            if !last {
                Button("Skip") { Haptics.tap(); finish() }
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.dust)
                    .buttonStyle(.press)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .animation(Theme.Motion.flow, value: last)
    }

    private func leaf(_ leaf: Leaf) -> some View {
        VStack(spacing: 0) {
            Image(leaf.plate)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 196)
                .accessibilityHidden(true)
                .flowIn(0, distance: 16)

            Kicker(text: leaf.kicker)
                .padding(.top, 30)
                .flowIn(1)

            Text(leaf.title)
                .font(Theme.serif(34))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)
                .flowIn(2)

            Text(leaf.body)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.mid)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 14)
                .flowIn(3)
        }
        .padding(.horizontal, 38)
    }

    private var marks: some View {
        HStack(spacing: 7) {
            ForEach(leaves.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.amber : Theme.hairline)
                    .frame(width: i == page ? 18 : 6, height: 6)
            }
        }
        .animation(Theme.Motion.bouncy, value: page)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 0) {
            if let failure {
                Text(failure)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.amber)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 38)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }

            Button {
                if last { Task { await connect() } } else { go(to: page + 1) }
            } label: {
                ZStack {
                    // Held at full width while the request is out, so the row
                    // does not collapse and jump the buttons under the thumb.
                    Text(last ? "Connect Apple Health" : "Continue")
                        .opacity(connecting ? 0 : 1)
                    if connecting {
                        ProgressView().tint(Theme.warm)
                    }
                }
                .font(Theme.sans(15, medium: true))
                .foregroundStyle(Theme.warm)
                .frame(width: 313)
                .padding(.vertical, 16)
                .background(Theme.ink)
                .clipShape(Capsule())
            }
            .buttonStyle(.press)
            .disabled(connecting)

            // Health access is not a price of entry: the ledger still holds
            // anything written by hand, and Connections asks again later.
            Button(last ? "Not now" : "Your ledger stays yours.") {
                guard last else { return }
                Haptics.tap()
                finish()
            }
            .font(Theme.sans(12))
            .foregroundStyle(Theme.dust)
            .buttonStyle(.press)
            .allowsHitTesting(last)
            .padding(.top, 22)
        }
        .animation(Theme.Motion.flow, value: connecting)
        .animation(Theme.Motion.flow, value: failure)
    }

    // MARK: Behaviour

    private func go(to next: Int) {
        guard next >= 0, next < leaves.count, next != page else { return }
        Haptics.select()
        withAnimation(Theme.Motion.settle) { page = next }
    }

    /// HealthKit deliberately will not say which types were granted, so a
    /// refusal is indistinguishable from a grant here. Only a thrown error is
    /// a real failure, and even then the way forward stays open.
    private func connect() async {
        connecting = true
        failure = nil
        do {
            try await health.requestAuthorization()
            Haptics.tap()
            finish()
        } catch {
            failure = error.localizedDescription
        }
        connecting = false
    }
}

/// Shows the introduction once, then gets out of the way for good.
struct OnboardingGate<Content: View>: View {
    @AppStorage("has_onboarded") private var done = false
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
    }
}
