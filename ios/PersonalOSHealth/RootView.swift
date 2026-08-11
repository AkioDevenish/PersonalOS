import SwiftUI
import ClerkKit
import ClerkKitUI

/// Sign-in per the Figma design.
///
/// One honest divergence from the mock: the primary button reads "Begin your
/// ledger" rather than "Sign in with Apple" — the Sign in with Apple
/// capability needs a paid developer account, and a button that names Apple
/// but doesn't call it would be worse than plain words. Clerk + SIWA replace
/// this when the account exists.
struct SignInView: View {
    @State private var showAuth = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.hairline, lineWidth: 1)
                    .frame(width: 72, height: 72)
                Text("❧")
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.amber)
            }

            Text("Personal OS")
                .font(Theme.serif(42))
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)

            Kicker(text: "Time well spent")
                .tracking(3)
                .padding(.top, 10)

            Rule().frame(width: 120).padding(.top, 36)

            Button {
                showAuth = true
            } label: {
                Text("Begin your ledger")
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.warm)
                    .frame(width: 313)
                    .padding(.vertical, 16)
                    .background(Theme.ink)
                    .clipShape(Capsule())
            }
            .buttonStyle(.press)
            .padding(.top, 44)

            Text("Your ledger stays yours.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.dust)
                .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.linen)
        // Clerk's prebuilt flow — email code, password, and any social
        // providers enabled in the dashboard, without hand-rolling forms.
        .sheet(isPresented: $showAuth) { AuthView() }
    }
}

/// A tasteful stub — the tab exists in the design; its content comes with
/// the resolver-backed history read.
struct HistoryView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Ornament().frame(width: 180)
            Text("The ledger's past")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)
            Text("Every day you've recorded, resolved and kept.\nArriving in a coming build.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.dust)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.linen)
    }
}

/// What the tab bar shows.
///
/// Business, Creative and Data were here and are pulled for now. Their screens
/// and the route behind them are untouched in PillarViews.swift,
/// PillarClient.swift and /api/pillars — bringing them back is adding the
/// cases below and the matching lines in the switch, nothing more. They were
/// removed from view rather than deleted because they work and are wired to
/// live Convex modules.
enum Tab: CaseIterable {
    case health, consult, settings

    /// Icons carry the meaning; there are no labels, so these have to read at
    /// a glance. Light weight keeps them in the same register as the type.
    var symbol: String {
        switch self {
        case .health: return "heart"
        case .consult: return "bubble.left"
        case .settings: return "person"   // replaced by the avatar when present
        }
    }

    var title: String {
        switch self {
        case .health: return "Health"
        case .consult: return "Ask a nutritionist"
        case .settings: return "Settings"
        }
    }

    /// The middle one is drawn as a filled circle rather than a bare glyph.
    ///
    /// Everything else in this app is a model reading numbers; this is the one
    /// place a person answers, and it is worth more than a third identical
    /// icon. A filled circle in ink is the only solid shape in the tab bar, so
    /// the eye finds it without a label — which matters, because this bar has
    /// no labels.
    var isAction: Bool { self == .consult }

    /// Position in the bar, which is what the content drifts along when you
    /// move between them.
    var index: Int { Tab.allCases.firstIndex(of: self) ?? 0 }
}

/// Everywhere you can go from a tab's root.
///
/// The pushes used to be view-based — `NavigationLink { TrendsView() }` — which
/// works until something other than a back button needs to move you. A stack
/// driven by a path can be emptied from anywhere, which is what makes tapping
/// the tab you're already on take you home.
enum Route: Hashable {
    case briefing, history, nutrition, specialists, paywall
}

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @EnvironmentObject private var notifier: Notifier
    @State private var tab: Tab = .health
    /// Which way the last tap moved, so the screens drift the way your thumb
    /// went rather than always the same way.
    @State private var forward = true
    /// One stack serves both tabs, so it empties when you change tab. Left
    /// alone, tapping Settings while three screens deep into Health left you
    /// looking at the specialist you were reading, under the wrong tab.
    @State private var path: [Route] = []
    @Namespace private var mark

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                Group {
                    switch tab {
                    case .health: HealthView()
                    case .consult: ConsultView()
                    case .settings: ConnectionsView()
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .briefing:     BriefingView()
                    case .history:      TrendsView()
                    case .nutrition:    NutritionView()
                    case .specialists:  ExpertsView()
                    case .paywall:      PaywallView()
                    }
                }
                // The identity changes with the tab, which is what lets one
                // screen leave while the other arrives instead of the content
                // being swapped underneath a static frame.
                .id(tab)
                .transition(.drift(forward ? 28 : -28))
                .toolbarBackground(Theme.linen, for: .navigationBar)
            }

            Rule()
            HStack {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button {
                        select(t)
                    } label: {
                        VStack(spacing: 7) {
                            Group {
                                if t.isAction {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.ink)
                                            .frame(width: 38, height: 38)
                                        Image(systemName: t.symbol)
                                            .font(.system(size: 15, weight: .light))
                                            .foregroundStyle(Theme.warm)
                                    }
                                    .frame(height: 22)
                                    .opacity(tab == t ? 1 : 0.82)
                                } else if t == .settings {
                                    Avatar(user: clerk.user, size: 22)
                                        .opacity(tab == t ? 1 : 0.55)
                                } else {
                                    Image(systemName: t.symbol)
                                        .font(.system(size: 17, weight: .light))
                                        .foregroundStyle(tab == t ? Theme.amber : Theme.dust)
                                        .frame(height: 22)
                                }
                            }
                            // The overshoot lives here: the icon springs past
                            // its size and settles back, which is the whole
                            // bounce. Anything larger and the bar wobbles.
                            .scaleEffect(tab == t ? 1.14 : 1)

                            // Amber is punctuation in this design, so the
                            // selected tab gets a full stop. One dot for the
                            // whole bar, matched between positions, so it
                            // slides across rather than blinking on and off.
                            ZStack {
                                Circle().fill(.clear).frame(width: 4, height: 4)
                                if tab == t {
                                    Circle()
                                        .fill(Theme.amber)
                                        .frame(width: 4, height: 4)
                                        .matchedGeometryEffect(id: "tab-mark", in: mark)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressRow)
                    .accessibilityLabel(t.title)
                }
            }
            .animation(Theme.Motion.pop, value: tab)
            // The circle is taller than a glyph and sits proud of the rule, so
            // the bar carries a little more air than it did with two icons.
            .padding(.top, 16)
            .padding(.bottom, 10)
            .background(Theme.linen)
        }
        .background(Theme.linen)
        // A tapped notification should land on the thing it announced, not on
        // whatever screen the app was last showing.
        .onChange(of: notifier.opened) { _, route in
            guard let route else { return }
            withAnimation(Theme.Motion.flow) {
                tab = .health
                path = [route]
            }
            notifier.opened = nil
        }
    }

    private func select(_ t: Tab) {
        // Tapping the tab you are already on means "take me back" — the
        // gesture every iOS app has, and the only way out of a drill-down
        // that doesn't involve reaching for the top-left corner.
        guard t != tab else {
            guard !path.isEmpty else { return }
            Haptics.tap()
            withAnimation(Theme.Motion.flow) { path.removeAll() }
            return
        }
        Haptics.select()
        forward = t.index > tab.index
        withAnimation(Theme.Motion.flow) {
            path.removeAll()
            tab = t
        }
    }
}
