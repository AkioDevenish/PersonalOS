import SwiftUI
import ClerkKitUI

/// The first thing anybody sees, before they have an account.
///
/// It has one job: say in a few seconds what this is, then get out of the
/// way. A picture, a name, three plain lines about what it does, and two
/// ways in — one for somebody new and one for somebody coming back, because
/// "sign in" is the wrong first word to somebody who has never had an account.
///
/// Replaces a screen that was a name, a slogan and a button reading "Begin
/// your ledger", which told a stranger nothing about what they were beginning.
struct WelcomeView: View {
    @State private var mode: AuthView.Mode?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            WalkingFigure()
                .frame(maxWidth: 230, maxHeight: 200)
                .flowIn(0, distance: 16)

            Text("Personal OS")
                .font(Theme.serif(40))
                .foregroundStyle(Theme.text)
                .padding(.top, 26)
                .flowIn(1)

            Text("Your health, read clearly and kept close.")
                .font(Theme.serifBody(18))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .flowIn(1)

            VStack(alignment: .leading, spacing: 16) {
                line("heart.text.square", "Reads Apple Health, so there is nothing to type")
                line("sparkles", "Readings written on your phone, not on a server")
                line("person.2", "Real practitioners, whenever you want one")
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

            Text("Your cycle and your readings stay on this phone.")
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
        .background(Theme.background)
        .sheet(item: $mode) { mode in
            AuthView(mode: mode)
        }
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .environment(\.symbolVariants, .none)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension AuthView.Mode: @retroactive Identifiable {
    public var id: String { rawValue }
}
