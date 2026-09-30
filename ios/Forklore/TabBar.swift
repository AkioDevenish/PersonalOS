import SwiftUI
import Observation

/// Whether the bar is at full size, tucked down, or out of the way.
@Observable
final class TabBarState {
    private(set) var compact = false
    /// Gone altogether, for a page that would rather have the room while it is scrolled.
    private(set) var hidden = false
    /// Whether the keyboard is up. The bar steps aside while it is, so whatever is being typed into
    /// sits straight on top of the keys.
    private(set) var keyboard = false

    func set(compact next: Bool) {
        guard next != compact else { return }
        withAnimation(Theme.Motion.flow) { compact = next }
    }

    func set(hidden next: Bool) {
        guard next != hidden else { return }
        withAnimation(Theme.Motion.flow) { hidden = next }
    }

    /// Whether the bar is off screen, so pages can take back the room they leave for it.
    var away: Bool { keyboard || hidden }

    func set(keyboard next: Bool) {
        guard next != keyboard else { return }
        withAnimation(Theme.Motion.flow) { keyboard = next }
    }
}

/// The bar, drawn by the app.
struct AppTabBar: View {
    let selected: AppTab
    let select: (AppTab) -> Void

    @Environment(TabBarState.self) private var state

    var body: some View {
        HStack(spacing: state.compact ? 6 : 10) {
            ForEach(AppTab.visible, id: \.self) { tab in
                Button {
                    select(tab)
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: state.compact ? 15 : 20, weight: .regular))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(tab == selected ? Theme.accent : Theme.text.opacity(0.7))
                        .frame(
                            width: state.compact ? 40 : 58,
                            height: state.compact ? 32 : 44
                        )
                        .background {
                            if tab == selected {
                                Capsule().fill(Theme.accent.opacity(0.14))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.press)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, state.compact ? 6 : 8)
        .padding(.vertical, state.compact ? 5 : 7)
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.bottom, state.compact ? 2 : 6)
    }

    /// Room the pages leave at the bottom so their last line can be scrolled clear of the bar.
    static let clearance: CGFloat = 72
}

/// Reports which way a page is being scrolled, so the bar can follow: shrinking it, or hiding it.
struct CompactsTabBar: ViewModifier {
    /// Hide the bar outright instead of shrinking it.
    var hides = false
    @Environment(TabBarState.self) private var state: TabBarState?
    /// Where the current run of scrolling in one direction began.
    @State private var anchor: CGFloat = 0

    /// How far a reader has to travel before the bar changes.
    private let travel: CGFloat = 28

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, y in
            guard let state else { return }
            // Near the top the bar is always full: there is nothing above to be making room for.
            if y < travel {
                anchor = y
                set(state, tucked: false)
                return
            }
            if tucked(state) {
                anchor = max(anchor, y)
                if anchor - y > travel {
                    anchor = y
                    set(state, tucked: false)
                }
            } else {
                anchor = min(anchor, y)
                if y - anchor > travel {
                    anchor = y
                    set(state, tucked: true)
                }
            }
        }
        .onDisappear { if hides { state?.set(hidden: false) } }
    }

    private func tucked(_ state: TabBarState) -> Bool { hides ? state.hidden : state.compact }

    private func set(_ state: TabBarState, tucked: Bool) {
        if hides { state.set(hidden: tucked) } else { state.set(compact: tucked) }
    }
}

extension View {
    func compactsTabBar() -> some View { modifier(CompactsTabBar()) }
    /// Like `compactsTabBar`, but the bar leaves the screen instead of shrinking.
    func hidesTabBarOnScroll() -> some View { modifier(CompactsTabBar(hides: true)) }
}
