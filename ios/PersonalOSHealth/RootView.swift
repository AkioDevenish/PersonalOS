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

enum Tab: CaseIterable {
    case today, history, account

    /// Icons carry the meaning; there are no labels, so these have to read at
    /// a glance. Light weight keeps them in the same register as the type.
    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .history: return "clock"
        case .account: return "person"   // replaced by the avatar when present
        }
    }
}

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @State private var tab: Tab = .today

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                Group {
                    switch tab {
                    case .today: TodayView()
                    case .history: HistoryView()
                    case .account: ConnectionsView()
                    }
                }
                .toolbarBackground(Theme.linen, for: .navigationBar)
            }

            Rule()
            HStack {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button {
                        tab = t
                    } label: {
                        Group {
                            if t == .account {
                                Avatar(user: clerk.user, size: 24)
                                    .opacity(tab == t ? 1 : 0.55)
                            } else {
                                Image(systemName: t.symbol)
                                    .font(.system(size: 19, weight: .light))
                                    .foregroundStyle(tab == t ? Theme.amber : Theme.dust)
                                    .frame(height: 24)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(describing: t))
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(Theme.linen)
        }
        .background(Theme.linen)
    }
}
