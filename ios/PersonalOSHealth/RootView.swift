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
                    // Was a fixed 313 points, which is one phone's width and
                    // nobody else's: narrow and off-centre on a Pro Max, tight
                    // on an SE, and liable to clip the label at larger text
                    // sizes.
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.ink)
                    .clipShape(Capsule())
            }
            .buttonStyle(.press)
            .padding(.horizontal, 40)
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
///
/// Finance and Time are parked the same way. FinanceView.swift, TimeView.swift
/// and the Convex ledgers behind them are untouched and still deployed; only
/// the two cases here, their two `Tab`s and their two lines in the switch came
/// out. Home lost the tiles that pointed at them in the same breath.
enum AppTab: CaseIterable, Hashable {
    case home, health, settings

    /// The system fills the selected one and tints it, so only the outline is
    /// named here. The hand-rolled bar used to keep a `.fill` twin for that
    /// job; it is the platform's now.
    var symbol: String {
        switch self {
        case .home: return "house"
        case .health: return "heart"
        case .settings: return "person"
        }
    }

    /// Single words, as the guidelines ask, and the label a screen reader
    /// announces either way.
    var title: String {
        switch self {
        case .home: return "Home"
        case .health: return "Health"
        case .settings: return "Profile"
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
    case briefing, history, nutrition, specialists, professionals, paywall, goals
    /// One practitioner's page.
    ///
    /// Carries the whole record rather than an id, because the directory has
    /// already fetched it and the page would otherwise fetch it a second time
    /// to draw the same thing. A value-carrying case rather than a view-based
    /// link keeps every push in this app inside the one path the tab owns,
    /// which is what lets tapping the tab again empty it.
    case practitioner(SpecialistsClient.Specialist)
    /// The other side of the desk, for somebody who is listed.
    case practice
}

struct RootView: View {
    @EnvironmentObject private var notifier: Notifier
    @State private var tab: AppTab = .home
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

    /// Where the finger was when this drag's first movement was reported.
    ///
    /// `DragGesture(minimumDistance:)` does not begin reporting until the
    /// finger has already travelled that far, and then reports the whole
    /// distance — so the page jumped the threshold in one frame the instant it
    /// started moving. Subtracting the first reading makes the page start
    /// where the finger is.
    @State private var dragAnchor: CGFloat?

    private var shift: CGFloat {
        let base = drawer ? LedgerDrawer.width : 0
        return min(max(base + dragged, 0), LedgerDrawer.width)
    }

    /// How far open, nought to one.
    private var progress: CGFloat { shift / LedgerDrawer.width }

    /// Grown over the first eighth of the travel rather than switched on at
    /// the first pixel. A corner that appears in one frame invalidates the
    /// whole clip at exactly the moment the finger starts moving, which is the
    /// moment there is least to spare.
    private var pageRadius: CGFloat { 30 * min(1, progress * 8) }

    private var pageOverhang: CGFloat { 80 * (1 - progress) }

    private var pageScale: CGFloat { 1 - progress * 0.06 }

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

            // The page's shadow, cast by a shape rather than by the page.
            //
            // `.shadow` on the page itself meant Core Animation had to render
            // the entire app — TabView, scroll views, every tile — into an
            // offscreen buffer and Gaussian blur it, once per frame, for the
            // whole drag. Blurring this instead costs a rounded rectangle.
            // It is filled rather than stroked so the page sits on it exactly
            // and only the fringe shows, which is what a shadow is.
            if shift > 0 {
                PageReveal(radius: pageRadius, overhang: pageOverhang)
                    .fill(Theme.linen)
                    .ignoresSafeArea()
                    .scaleEffect(pageScale, anchor: .center)
                    .offset(x: shift)
                    .shadow(color: Theme.ink.opacity(0.16), radius: 22, x: -6)
                    .allowsHitTesting(false)
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
                //
                // The drag lives on these two layers rather than on the page,
                // and that is the whole of the flicker fix. A `.gesture` on
                // the page is a gesture on everything inside it: the TabView,
                // its scroll views, and a floating bar that minimises itself
                // when it thinks the content is scrolling. All of them were
                // being offered the same touch, and they took turns claiming
                // it — which is what a finger held still was showing.
                //
                // Both layers are plain colour with nothing underneath them
                // that wants a pan, so there is nothing left to arbitrate
                // against and the drag simply tracks.
                .overlay {
                    if drawer {
                        Theme.ink.opacity(0.05)
                            .contentShape(Rectangle())
                            .gesture(pageDrag)
                            .onTapGesture { withAnimation(Theme.Motion.flow) { drawer = false } }
                    }
                }
                .overlay(alignment: .leading) {
                    if !drawer {
                        // A strip the width of the reach, not the whole page.
                        Color.clear
                            .frame(width: 28)
                            .contentShape(Rectangle())
                            .gesture(pageDrag)
                            .overlay(alignment: .leading) { DrawerHandle(open: $drawer) }
                    }
                }
                // While the drawer is shut the clip runs past the bottom of
                // the page, because the system draws the floating tab bar
                // partly outside the TabView's own bounds and a clip that
                // stops at the edge shears the labels off. As the page slides
                // across, the overhang closes to nothing: by then the page has
                // shrunk away from the bottom of the screen and the real
                // corner is what should be showing.
                .clipShape(PageReveal(radius: pageRadius, overhang: pageOverhang))
                .scaleEffect(pageScale, anchor: .center)
                .offset(x: shift)
        }
        .background(Theme.linen)
    }

    /// Drag from the left edge to open, drag back over the page to close.
    ///
    /// Whichever layer is showing owns this: the edge strip when the drawer is
    /// shut, the dimming sheet when it is open. Neither has anything beneath
    /// it that competes for a pan, so it no longer matters that the page is
    /// full of scroll views.
    private var pageDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // A drag that is mostly up or down is somebody scrolling, or
                // starting to, and the page should not slide because of it.
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragAnchor = nil
                    return
                }
                let anchor = dragAnchor ?? value.translation.width
                if dragAnchor == nil { dragAnchor = anchor }
                dragged = value.translation.width - anchor
            }
            .onEnded { value in
                // Reset first and unconditionally. A gesture that is cancelled
                // rather than ended leaves nothing behind to poison the next
                // one with an offset measured from a finger that has gone.
                let travelled = value.translation.width - (dragAnchor ?? 0)
                dragAnchor = nil
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
            Tab(value: AppTab.home) { stack(for: .home) } label: { glyph(.home) }
            Tab(value: AppTab.health) { stack(for: .health) } label: { glyph(.health) }
            Tab(value: AppTab.settings) { stack(for: .settings) } label: { glyph(.settings) }
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


    /// A tab's mark, with no word under it.
    ///
    /// The title is emptied rather than dropped: it still travels as the
    /// accessibility label, so VoiceOver announces "Finance" where a sighted
    /// reader gets the banknote alone. An empty `Label` with nothing else said
    /// would leave a screen reader reading out "tab, two of four".
    private func glyph(_ t: AppTab) -> some View {
        Label { Text("") } icon: { Image(systemName: t.symbol) }
            // The bar substitutes the filled variant of every symbol on its
            // own. That turned the clock and the figure into two near-identical
            // dark discs sitting side by side, while the banknote — which has
            // no real filled form — stayed a line box next to them. Three
            // different densities in four glyphs.
            //
            // Outlines throughout instead: one stroke weight, four distinct
            // silhouettes, and a register that matches the engravings rather
            // than shouting over them. Selection is already carried by the
            // amber and by the capsule the bar draws behind the chosen tab, so
            // nothing is lost by refusing the fill.
            .environment(\.symbolVariants, .none)
            .accessibilityLabel(t.title)
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
                    case .professionals: SpecialistsView()
                    case .practitioner(let one): SpecialistProfileView(specialist: one)
                    case .practice: PractitionerView()
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
        // The rows on Home send you to a tab, which only the bar's selection
        // can do, so it is handed the way to ask.
        case .home:     HomeView { tab = $0 }
        case .health:   HealthView()
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
