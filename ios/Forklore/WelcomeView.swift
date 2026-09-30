import SwiftUI

/// The first thing anybody sees, before they have an account.
struct WelcomeView: View {
    @State private var mode: AuthSheet.Mode?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            ForkloreWordmark(size: 54)
                .flowIn(0, distance: 16)

            Text("Meals, experts and articles for your health.")
                .font(Theme.serifBody(18))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .flowIn(1)

            Spacer(minLength: 28)

            VStack(spacing: 12) {
                Button { mode = .signUp } label: {
                    Text("Get started")
                        .font(Theme.sans(16, medium: true))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.text, in: Capsule())
                }
                .buttonStyle(.press)

                Button { mode = .signIn } label: {
                    Text("I already have an account")
                        .font(Theme.sans(15, medium: true))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.press)
            }
            .padding(.bottom, 10)
            .flowIn(2)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .appBackground()
        .sheet(item: $mode) { mode in
            AuthSheet(mode: mode)
        }
    }
}
