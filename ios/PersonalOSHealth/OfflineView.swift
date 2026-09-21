import SwiftUI

/// What the app is when there is no connection.
///
/// Shown instead of everything, including the welcome page: an account cannot
/// be made without the database either, and a sign-up form that cannot
/// possibly work is worse than a page saying why.
struct OfflineView: View {
    @EnvironmentObject private var network: Network

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 54, weight: .ultraLight))
                .environment(\.symbolVariants, .none)
                .foregroundStyle(Theme.tertiaryText)

            Text("No connection.")
                .font(Theme.serif(32))
                .foregroundStyle(Theme.text)
                .padding(.top, 24)

            Text("Personal OS keeps your ledger on its own servers, so it needs a connection to show you anything at all. It picks up by itself the moment you have one.")
                .font(Theme.serifBody(17))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 12)

            Button { Task { await network.recheck() } } label: {
                ZStack {
                    Text("Try again").opacity(network.checking ? 0 : 1)
                    if network.checking { ProgressView().tint(Theme.background) }
                }
                .font(Theme.sans(16, medium: true))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.text, in: Capsule())
            }
            .buttonStyle(.press)
            .disabled(network.checking)
            .padding(.top, 34)

            Spacer()
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
