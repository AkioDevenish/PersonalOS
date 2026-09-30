import Combine
import SwiftUI

/// The app's pages, picked from the sidebar.
enum AppTab: CaseIterable, Hashable {
    case home, meals, assistant, practitioners, profile

    /// What the sidebar lists. Home is hidden for now.
    static let visible: [AppTab] = [.meals, .assistant, .practitioners, .profile]

    /// The outline; the sidebar fills the selected one.
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
    @State private var menu = SideMenu()

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .overlay {
                SidebarPanel(selected: tab) { next in
                    selection.wrappedValue = next
                    menu.set(open: false)
                }
            }
            .environment(menu)
    }

    /// The pages, in a TabView whose own bar is hidden.
    private var page: some View {
        TabView(selection: selection) {
            ForEach(AppTab.visible, id: \.self) { t in
                Tab(value: t) { stack(for: t) }
            }
        }
        .tint(Theme.accent)
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
                // Pitchfork draws its own header, with the menu button in it.
                .modifier(RootHeader(tab: t))
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

/// Hides the system's tab bar: pages are picked from the sidebar instead.
private struct HidesSystemTabBar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbarVisibility(.hidden, for: .tabBar)
    }
}

/// The menu button over every root page but Pitchfork's, which has its own header.
private struct RootHeader: ViewModifier {
    let tab: AppTab

    func body(content: Content) -> some View {
        if tab == .assistant {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content.menuHeader()
        }
    }
}

extension View {
    func hidesSystemTabBar() -> some View { modifier(HidesSystemTabBar()) }
}
