import Combine
import SwiftUI

/// What the tab bar shows.
enum AppTab: CaseIterable, Hashable {
    case home, meals, assistant, practitioners, profile

    /// What the tab bar shows. Home is hidden for now.
    static let visible: [AppTab] = [.meals, .assistant, .practitioners, .profile]

    /// The system fills the selected one and tints it, so only the outline is named here.
    var symbol: String {
        switch self {
        case .home: return "house"
        case .meals: return "leaf"
        case .assistant: return "sparkles"
        case .practitioners: return "person.2"
        case .profile: return "person.crop.circle"
        }
    }

    /// Single words, as the guidelines ask, and the label a screen reader announces either way.
    var title: String {
        switch self {
        case .home: return "Home"
        case .meals: return "Meals"
        case .assistant: return "Pitchfork"
        case .practitioners: return "Experts"
        case .profile: return "Profile"
        }
    }
}

/// Everywhere you can go from a tab's root.
enum Route: Hashable {
    case professionals, paywall
    /// One practitioner's page.
    case practitioner(SpecialistsClient.Specialist)
    /// The other side of the desk, for somebody who is listed.
    case practice
    /// Profile, pushed from the picture at the top right of Home.
    case profile
    /// An author's own articles, and the way to write one.
    case myArticles
    /// A practitioner's consultations, articles and listing.
    case practiceHub
    /// Articles waiting for a reviewer.
    case reviewArticles
    /// A practitioner's Stripe account, and what the platform keeps.
    case payouts
    /// One article, carried whole like a practitioner: the card already has it.
    case article(Article)
    /// Every article, or one category's.
    case articles(String?)
}

struct RootView: View {
    @EnvironmentObject private var notifier: Notifier
    @State private var tab: AppTab = .meals
    /// A stack per tab rather than one shared between them.
    @State private var paths: [AppTab: [Route]] = [:]
    @State private var bar = TabBarState()

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            // Laid over the pages rather than beneath them, so content scrolls under the glass the
            // way it does under the system's own bar.
            .overlay(alignment: .bottom) {
                if !bar.keyboard {
                    AppTabBar(selected: tab) { selection.wrappedValue = $0 }
                        .transition(.opacity)
                }
            }
            .environment(bar)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                bar.set(keyboard: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                bar.set(keyboard: false)
            }
    }

    /// The pages, in a TabView whose own bar is hidden.
    private var page: some View {
        TabView(selection: selection) {
            ForEach(AppTab.visible, id: \.self) { t in
                Tab(value: t) { stack(for: t) }
            }
        }
        .tint(Theme.accent)
        // A new tab starts with the bar at full size: the shrink belonged to how far down the last
        // page you had read, not to this one.
        .onChange(of: tab) { _, _ in bar.set(compact: false) }
        // A tapped notification should land on the thing it announced, not on whatever screen the
        // app was last showing.
        .onChange(of: notifier.opened) { _, route in
            guard route != nil else { return }
            withAnimation(Theme.Motion.flow) {
                tab = .practitioners
                paths[.practitioners] = []
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
                    case .professionals: SpecialistsView()
                    case .practitioner(let one): SpecialistProfileView(specialist: one)
                    case .practice: PractitionerView()
                    case .paywall:      PaywallView()
                    case .profile:      ProfileView()
                    case .practiceHub:  PracticeHubView()
                    case .myArticles:   MyArticlesView()
                    case .reviewArticles: ArticleReviewQueueView()
                    case .payouts:      PayoutsView()
                    case .article(let one): ArticleView(article: one)
                    case .articles(let category): ArticleListView(category: category)
                    }
                    }
                    // Set on every pushed page too.
                    .hidesSystemTabBar()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func root(for t: AppTab) -> some View {
        switch t {
        // The rows on Home send you to a tab, which only the bar's selection can do, so it is
        // handed the way to ask.
        case .home:          HomeView()
        case .meals:         NutritionView()
        case .assistant:     AssistantView()
        case .practitioners: SpecialistsView()
        case .profile:       ProfileView()
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

/// Hides the system's tab bar and leaves room at the bottom for the app's, except while the keyboard
/// is up and the bar has stepped aside.
private struct HidesSystemTabBar: ViewModifier {
    @Environment(TabBarState.self) private var bar: TabBarState?

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(.hidden, for: .tabBar)
            .safeAreaPadding(.bottom, bar?.keyboard == true ? 0 : AppTabBar.clearance)
    }
}

extension View {
    func hidesSystemTabBar() -> some View { modifier(HidesSystemTabBar()) }
}
