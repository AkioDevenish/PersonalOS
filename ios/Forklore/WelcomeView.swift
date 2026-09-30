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

            VStack(alignment: .leading, spacing: 16) {
                line("Uses Apple Health, so there's nothing to type")
                line("Meal ideas made on your phone")
                line("Chat with a nutritionist")
            }
            .padding(.top, 34)
            .padding(.horizontal, 8)
            .flowIn(2)

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
            .flowIn(3)

            Text("Your health data is never sold.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .flowIn(3)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .appBackground()
        .sheet(item: $mode) { mode in
            AuthSheet(mode: mode)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(15))
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
    }
}
