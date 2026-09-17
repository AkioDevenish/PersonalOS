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
                    .stroke(Theme.separator, lineWidth: 1)
                    .frame(width: 72, height: 72)
                Text("❧")
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.accent)
            }

            Text("Personal OS")
                .font(Theme.serif(42))
                .foregroundStyle(Theme.text)
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
                    .foregroundStyle(Theme.surface)
                    // Was a fixed 313 points, which is one phone's width and
                    // nobody else's: narrow and off-centre on a Pro Max, tight
                    // on an SE, and liable to clip the label at larger text
                    // sizes.
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.text)
                    .clipShape(Capsule())
            }
            .buttonStyle(.press)
            .padding(.horizontal, 40)
            .padding(.top, 44)

            Text("Your ledger stays yours.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
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
    case home, health

    /// The system fills the selected one and tints it, so only the outline is
    /// named here. The hand-rolled bar used to keep a `.fill` twin for that
    /// job; it is the platform's now.
    var symbol: String {
        switch self {
        case .home: return "house"
        case .health: return "heart"
        }
    }

    /// Single words, as the guidelines ask, and the label a screen reader
    /// announces either way.
    var title: String {
        switch self {
        case .home: return "Home"
        case .health: return "Health"
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
    case briefing, history, nutrition, specialists, professionals, paywall, goals, cycle
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
    /// Profile, pushed from the picture at the top right of Home. It was a
    /// tab as well, and one way in is enough.
    case profile
    /// An author's own articles, and the way to write one.
    case myArticles
    /// A practitioner's consultations, articles and listing.
    case practiceHub
    /// Articles waiting for a reviewer.
    case reviewArticles
    /// One article, carried whole like a practitioner: the card already has it.
    case article(Article)
    /// Every article, or one category's.
    case articles(String?)
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
    @State private var bar = TabBarState()

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            // Laid over the pages rather than beneath them, so content scrolls
            // under the glass the way it does under the system's own bar.
            .overlay(alignment: .bottom) {
                AppTabBar(selected: tab) { selection.wrappedValue = $0 }
            }
            .environment(bar)
    }

    /// The pages, in a TabView whose own bar is hidden.
    ///
    /// The TabView stays for what it is good at — keeping each tab's stack
    /// alive while another is showing — and gives up only the bar, which is
    /// drawn by `AppTabBar` so that it can shrink rather than collapse to one
    /// icon. The iPad sidebar went with the system bar; this app has not been
    /// laid out for iPad, and a sidebar over phone-width pages was not a
    /// feature anybody was using.
    private var page: some View {
        TabView(selection: selection) {
            Tab(value: AppTab.home) { stack(for: .home) }
            Tab(value: AppTab.health) { stack(for: .health) }
        }
        .tint(Theme.accent)
        // A new tab starts with the bar at full size: the shrink belonged to
        // how far down the last page you had read, not to this one.
        .onChange(of: tab) { _, _ in bar.set(compact: false) }
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
                .hidesSystemTabBar()
                .navigationDestination(for: Route.self) { route in
                    Group {
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
                    case .cycle:        CycleView()
                    case .profile:      ProfileView()
                    case .practiceHub:  PracticeHubView()
                    case .myArticles:   MyArticlesView()
                    case .reviewArticles: ArticleReviewQueueView()
                    case .article(let one): ArticleView(article: one)
                    case .articles(let category): ArticleListView(category: category)
                    }
                    }
                    // Set on every pushed page too. Visibility belongs to the
                    // page showing, so a destination without it would bring
                    // the system bar back on top of ours.
                    .hidesSystemTabBar()
                }
                .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func root(for t: AppTab) -> some View {
        switch t {
        // The rows on Home send you to a tab, which only the bar's selection
        // can do, so it is handed the way to ask.
        case .home:     HomeView { tab = $0 }
        case .health:   HealthView()
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

extension View {
    /// Hides the system's tab bar and leaves room at the bottom for the app's.
    func hidesSystemTabBar() -> some View {
        self
            .toolbarVisibility(.hidden, for: .tabBar)
            .safeAreaPadding(.bottom, AppTabBar.clearance)
    }
}
