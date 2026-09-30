import SwiftUI
import Observation

/// Whether the sidebar is out. The app has no tab bar: every page is reached from here.
@Observable
final class SideMenu {
    private(set) var open = false

    func set(open next: Bool) {
        guard next != open else { return }
        withAnimation(Theme.Motion.flow) { open = next }
    }
}

/// The round glass button at the top left of a page's root that brings the sidebar out.
struct MenuButton: View {
    @Environment(SideMenu.self) private var menu: SideMenu?

    var body: some View {
        Button {
            Haptics.select()
            menu?.set(open: true)
        } label: {
            Image(systemName: "text.alignleft")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: GlassCircle.size, height: GlassCircle.size)
                .glassCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
    }
}

/// A round Liquid Glass backing, for the buttons at the top of a page.
enum GlassCircle {
    static let size: CGFloat = 46
}

extension View {
    func glassCircle() -> some View {
        glassEffect(.regular.interactive(), in: Circle())
            .contentShape(Circle())
    }
}

/// Keeps the menu button at the top left of a page's root, over the content as it scrolls.
private struct MenuHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .top, spacing: 0) {
                HStack {
                    MenuButton()
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
    }
}

extension View {
    func menuHeader() -> some View { modifier(MenuHeader()) }
}

/// The sidebar, sliding in from the left over a dimmed page.
struct SidebarPanel: View {
    let selected: AppTab
    let select: (AppTab) -> Void

    @Environment(SideMenu.self) private var menu

    static let width: CGFloat = 290

    var body: some View {
        ZStack(alignment: .leading) {
            if menu.open {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { menu.set(open: false) }
                    .transition(.opacity)
                    .accessibilityHidden(true)

                panel
                    .transition(.move(edge: .leading))
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Forklore")
                    .font(.custom("SnellRoundhand-Bold", size: 28))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button {
                    menu.set(open: false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.press)
                .accessibilityLabel("Close menu")
            }
            .padding(.bottom, 16)

            ForEach(AppTab.visible, id: \.self) { tab in
                row(tab)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            Theme.gradient
                .overlay(alignment: .trailing) { Rectangle().fill(Theme.separator).frame(width: 1) }
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.12), radius: 24, x: 4)
        }
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.width < -60 { menu.set(open: false) }
            }
        )
        .accessibilityAddTraits(.isModal)
    }

    private func row(_ tab: AppTab) -> some View {
        let on = tab == selected
        return Button {
            select(tab)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 18))
                    .environment(\.symbolVariants, on ? .fill : .none)
                    .frame(width: 26)
                Text(tab.title)
                    .font(Theme.sans(17, medium: on))
                Spacer()
            }
            .foregroundStyle(on ? Theme.accent : Theme.text)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background {
                if on { Capsule().fill(Theme.accent.opacity(0.14)) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.press)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
