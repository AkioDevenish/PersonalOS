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
/// `AppTab` rather than `Tab` because SwiftUI's own `Tab` builds the bar now,
/// and two types of that name in one file is a coin toss over which one the
/// compiler reaches for.
///
/// Business, Creative and Data were here and are pulled for now. Their screens
/// and the route behind them are untouched in PillarViews.swift,
/// PillarClient.swift and /api/pillars — bringing them back is adding the
/// cases below and the matching lines in the switch, nothing more. They were
/// removed from view rather than deleted because they work and are wired to
/// live Convex modules.
enum AppTab: CaseIterable, Hashable {
    case health, finance, time, settings

    /// The system fills the selected one and tints it, so only the outline is
    /// named here. The hand-rolled bar used to keep a `.fill` twin for that
    /// job; it is the platform's now.
    var symbol: String {
        switch self {
        case .health: return "heart"
        case .finance: return "banknote"
        case .time: return "clock"
        case .settings: return "person.crop.circle"
        }
    }

    /// Single words, as the guidelines ask, and the label a screen reader
    /// announces either way.
    var title: String {
        switch self {
        case .health: return "Health"
        case .finance: return "Finance"
        case .time: return "Time"
        case .settings: return "Settings"
        }
    }
}

/// Everywhere you can go from a tab's root.
///
/// The pushes used to be view-based — `NavigationLink { TrendsView() }` — which
/// works until something other than a back button needs to move you. A stack
/// driven by a path can be emptied from anywhere, which is what makes tapping
/// the tab you're already on take you home.
enum Route: Hashable {
    case briefing, history, nutrition, specialists, paywall, goals
}

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @EnvironmentObject private var notifier: Notifier
    @State private var tab: AppTab = .health
    /// A stack per tab rather than one shared between them.
    ///
    /// The single stack was there to stop a drill-down in Health showing up
    /// under Settings. Giving each tab its own solves that properly and buys
    /// the behaviour the guidelines actually ask for: moving between sections
    /// keeps your place in each, so a glance at Finance doesn't cost you the
    /// specialist you were three screens into.
    @State private var paths: [AppTab: [Route]] = [:]
    @State private var drawer = false
    /// Live finger position while dragging the edge, so the panel tracks the
    /// thumb instead of waiting for the gesture to finish and then jumping.
    @State private var dragged: CGFloat = 0

    private var shift: CGFloat {
        let base = drawer ? LedgerDrawer.width : 0
        return min(max(base + dragged, 0), LedgerDrawer.width)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // The panel sits underneath and is revealed rather than laid over
            // the top, so the page moving aside is the whole explanation of
            // where it went.
            LedgerDrawer(open: drawer) { route in
                withAnimation(Theme.Motion.flow) {
                    drawer = false
                    tab = .health
                    paths[.health] = [route]
                }
            }

            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The floating bar sits in the home indicator's band, so the
                // TabView has to reach the true bottom of the screen to place
                // it. Held inside the safe area it lays the bar out against
                // the wrong edge and the drawer's clip shears the labels off.
                // Children still get correct insets: the TabView passes them
                // down itself.
                .ignoresSafeArea()
                // Everything that catches a touch has to be applied BEFORE the
                // offset, and this is why the drawer's entries did nothing when
                // tapped. `offset` moves what you see, not what the layout
                // thinks is there, so an overlay added after it is positioned
                // over the page's original, full-screen frame — including the
                // 268 points now showing the drawer. The invisible sheet that
                // closes the drawer was lying across the entries, swallowing
                // every tap. Inside the offset, it travels with the page.
                .overlay {
                    if drawer {
                        Theme.ink.opacity(0.05)
                            .onTapGesture { withAnimation(Theme.Motion.flow) { drawer = false } }
                    }
                }
                .overlay(alignment: .leading) {
                    if !drawer { DrawerHandle(open: $drawer) }
                }
                .gesture(edgeDrag)
                .clipShape(
                    PageReveal(
                        radius: shift > 0 ? 30 : 0,
                        // While the drawer is shut the clip runs past the
                        // bottom of the page, because the system draws the
                        // floating tab bar partly outside the TabView's own
                        // bounds and a clip that stops at the edge shears the
                        // labels off. As the page slides across, the overhang
                        // closes to nothing: by then the page has shrunk away
                        // from the bottom of the screen and the real corner is
                        // what should be showing.
                        overhang: 80 * (1 - shift / LedgerDrawer.width)
                    )
                )
                .scaleEffect(1 - (shift / LedgerDrawer.width) * 0.06, anchor: .center)
                .offset(x: shift)
                .shadow(color: Theme.ink.opacity(shift > 0 ? 0.16 : 0), radius: 22, x: -6)
        }
        .background(Theme.linen)
    }

    /// Drag from the left edge to open, drag back to close.
    private var edgeDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only from the edge when closed, so a swipe inside the page
                // is still the page's own gesture.
                guard drawer || value.startLocation.x < 28 else { return }
                dragged = value.translation.width
            }
            .onEnded { value in
                let travelled = value.translation.width
                guard drawer || value.startLocation.x < 28 else { return }
                withAnimation(Theme.Motion.flow) {
                    if drawer { drawer = travelled > -60 } else { drawer = travelled > 60 }
                    dragged = 0
                }
            }
    }

    /// The bar itself, the system's rather than ours.
    ///
    /// The hand-rolled version was an HStack of buttons with a hairline over
    /// it, pinned to the bottom. It could not be anything else. This one
    /// floats over the content on Liquid Glass, shrinks out of the way as you
    /// read down a long page, and becomes a sidebar on iPad — none of which is
    /// available to a stack of buttons, however carefully drawn.
    ///
    /// The cost is the avatar. A photograph cannot be handed to a tab that
    /// wants a symbol, so Settings is a drawn figure now and the face lives on
    /// the Settings screen itself.
    private var page: some View {
        TabView(selection: selection) {
            Tab(AppTab.health.title, systemImage: AppTab.health.symbol, value: AppTab.health) {
                stack(for: .health)
            }
            Tab(AppTab.finance.title, systemImage: AppTab.finance.symbol, value: AppTab.finance) {
                stack(for: .finance)
            }
            Tab(AppTab.time.title, systemImage: AppTab.time.symbol, value: AppTab.time) {
                stack(for: .time)
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: AppTab.settings) {
                stack(for: .settings)
            }
        }
        // iPhone is unaffected; iPad gets a bar it can turn into a sidebar.
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        // Otherwise the selected tab comes up system blue, which is the
        // one saturated colour this palette does not contain.
        .tint(Theme.amber)
        // A tapped notification should land on the thing it announced, not on
        // whatever screen the app was last showing.
        .onChange(of: notifier.opened) { _, route in
            guard let route else { return }
            withAnimation(Theme.Motion.flow) {
                tab = .health
                paths[.health] = [route]
            }
            notifier.opened = nil
        }
    }

    /// One tab's navigation stack.
    private func stack(for t: AppTab) -> some View {
        NavigationStack(path: binding(for: t)) {
            root(for: t)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .briefing:     BriefingView()
                    case .history:      TrendsView()
                    case .nutrition:    NutritionView()
                    case .specialists:  ExpertsView()
                    case .paywall:      PaywallView()
                    case .goals:        GoalsView()
                    }
                }
                .toolbarBackground(Theme.linen, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func root(for t: AppTab) -> some View {
        switch t {
        case .health:   HealthView()
        case .finance:  FinanceView()
        case .time:     TimeView()
        case .settings: ConnectionsView()
        }
    }

    /// A dictionary of stacks, read as a binding one tab at a time.
    private func binding(for t: AppTab) -> Binding<[Route]> {
        Binding(
            get: { paths[t] ?? [] },
            set: { paths[t] = $0 }
        )
    }

    /// Selection, with the re-tap gesture kept.
    ///
    /// The bar writes the tapped tab back even when it is the one already
    /// showing, and that second case is "take me home" — the gesture every iOS
    /// app has, and the only way out of a drill-down that doesn't involve
    /// reaching for the top-left corner. Emptying an already-empty stack would
    /// buzz for nothing, so it doesn't.
    private var selection: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { next in
                guard next != tab else {
                    guard !(paths[tab] ?? []).isEmpty else { return }
                    Haptics.tap()
                    withAnimation(Theme.Motion.flow) { paths[tab] = [] }
                    return
                }
                Haptics.select()
                tab = next
            }
        )
    }
}

/// The page's outline while the drawer moves it.
///
/// A plain rounded rectangle would do, were it not for the tab bar hanging
/// below the page's frame. Both numbers animate, so the corner rounds and the
/// overhang closes together as the drawer opens.
private struct PageReveal: Shape {
    var radius: CGFloat
    var overhang: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, overhang) }
        set {
            radius = newValue.first
            overhang = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height + max(0, overhang)
            ),
            cornerRadius: radius,
            style: .continuous
        )
    }
}
