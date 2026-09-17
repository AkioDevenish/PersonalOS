import SwiftUI
import Observation

/// Whether the bar is at full size or tucked down.
///
/// Its own tiny object so that the only view reading it is the bar. A scroll
/// writes here many times a second; if the pages read it too, every one of
/// those writes would redraw the page being scrolled, which is the kind of
/// per-frame work this app has already spent four commits taking out.
@Observable
final class TabBarState {
    private(set) var compact = false

    func set(compact next: Bool) {
        guard next != compact else { return }
        withAnimation(Theme.Motion.flow) { compact = next }
    }
}

/// The bar, drawn by the app.
///
/// The system's floating bar has exactly one way of getting out of the way on
/// scroll, and it is to collapse to the single selected icon. That hides where
/// you can go at the moment you are furthest into a page. This keeps every tab
/// and shrinks instead: smaller glyphs, a tighter capsule, still one tap from
/// anywhere.
///
/// Liquid Glass comes from `glassEffect`, the same material the system bar
/// uses, so nothing about the look is lost in taking it over.
struct AppTabBar: View {
    let selected: AppTab
    let select: (AppTab) -> Void

    @Environment(TabBarState.self) private var state

    var body: some View {
        HStack(spacing: state.compact ? 6 : 10) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    select(tab)
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: state.compact ? 15 : 20, weight: .regular))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(tab == selected ? Theme.amber : Theme.ink.opacity(0.7))
                        .frame(
                            width: state.compact ? 40 : 58,
                            height: state.compact ? 32 : 44
                        )
                        .background {
                            if tab == selected {
                                Capsule().fill(Theme.amber.opacity(0.14))
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

    /// Room the pages leave at the bottom so their last line can be scrolled
    /// clear of the bar. Sized for the bar at full height, because the inset
    /// changing as the bar shrank would move the page under the reader's eye.
    static let clearance: CGFloat = 72
}

/// Reports which way a page is being scrolled, so the bar can follow.
///
/// Applied to each page's own scroll view rather than inferred from a gesture
/// over the whole app. A gesture on the page is what made the old drawer
/// flicker; reading the scroll view's own geometry competes with nothing.
struct CompactsTabBar: ViewModifier {
    @Environment(TabBarState.self) private var state: TabBarState?
    /// Where the current run of scrolling in one direction began.
    @State private var anchor: CGFloat = 0

    /// How far a reader has to travel before the bar changes. Small enough to
    /// feel immediate, large enough that the bounce at either end of a page
    /// does not flip it back and forth.
    private let travel: CGFloat = 28

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, y in
            guard let state else { return }
            // Near the top the bar is always full: there is nothing above to
            // be making room for.
            if y < travel {
                anchor = y
                state.set(compact: false)
                return
            }
            if state.compact {
                anchor = max(anchor, y)
                if anchor - y > travel {
                    anchor = y
                    state.set(compact: false)
                }
            } else {
                anchor = min(anchor, y)
                if y - anchor > travel {
                    anchor = y
                    state.set(compact: true)
                }
            }
        }
    }
}

extension View {
    func compactsTabBar() -> some View { modifier(CompactsTabBar()) }
}
