import SwiftUI

/// Creating an account, or signing back in.
struct AuthSheet: View {
    enum Mode: String, Identifiable {
        case signUp, signIn
        var id: String { rawValue }
    }

    @State var mode: Mode

    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var failure: String?
    @State private var providers = Session.Providers(password: true, google: false, facebook: false, apple: false)
    /// Apple's own sheet needs nothing on the server; the browser route needs Apple's web credentials.
    private var appleOffered: Bool { AppConfig.appleSignInSheet || providers.apple }
    @FocusState private var field: Field?

    private enum Field { case name, email, password }

    private var ready: Bool {
        email.contains("@") && password.count >= 8 && !working
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(mode == .signUp ? "Create your account" : "Welcome back")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.text)

                    Text(mode == .signUp
                         ? "It only takes a minute."
                         : "Sign in to pick up where you left off.")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            input("Your name", text: $name, field: .name)
                                .textContentType(.name)
                        }
                        input("Email", text: $email, field: .email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .focused($field, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await submit() } }
                            .modifier(FieldStyle())
                        if mode == .signUp {
                            Text("At least 8 characters.")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.tertiaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 26)

                    if let failure {
                        Text(failure)
                            .font(Theme.sans(13))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)
                    }

                    Button { Task { await submit() } } label: {
                        ZStack {
                            Text(mode == .signUp ? "Create account" : "Sign in").opacity(working ? 0 : 1)
                            if working { ProgressView().tint(Theme.background) }
                        }
                        .font(Theme.sans(16, medium: true))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ready ? Theme.text : Theme.tertiaryText, in: Capsule())
                    }
                    .buttonStyle(.press)
                    .disabled(!ready)
                    .padding(.top, 22)

                    if appleOffered || providers.google || providers.facebook {
                        HStack {
                            Rectangle().fill(Theme.separator).frame(height: 1)
                            Text("or").font(Theme.sans(12)).foregroundStyle(Theme.tertiaryText)
                            Rectangle().fill(Theme.separator).frame(height: 1)
                        }
                        .padding(.vertical, 22)

                        VStack(spacing: 10) {
                            if appleOffered {
                                social("Continue with Apple", .apple) {
                                    // Apple's mark ships with the system, and is the one logo here
                                    // that should take the text colour: black on white, white on
                                    // black.
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 19))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                            if providers.google {
                                social("Continue with Google", .google) { mark("GoogleG") }
                            }
                            if providers.facebook {
                                social("Continue with Facebook", .facebook) { mark("FacebookF") }
                            }
                        }
                    }

                    Button {
                        failure = nil
                        withAnimation(Theme.Motion.flow) { mode = mode == .signUp ? .signIn : .signUp }
                    } label: {
                        Text(mode == .signUp ? "I already have an account" : "Create an account instead")
                            .font(Theme.sans(14, medium: true))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.press)
                    .padding(.top, 18)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .task { providers = await session.providers() }
    }

    private func input(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(placeholder, text: text)
            .focused($field, equals: field)
            .submitLabel(.next)
            .modifier(FieldStyle())
    }

    /// A provider's own logo, drawn from the vector in the asset catalogue.
    private func mark(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 19, height: 19)
    }

    private func social<Mark: View>(
        _ title: String,
        _ provider: Session.Provider,
        @ViewBuilder mark: () -> Mark
    ) -> some View {
        let logo = mark()
        return Button {
            Task {
                working = true
                failure = nil
                defer { working = false }
                do {
                    try await session.signIn(with: provider)
                    dismiss()
                } catch SessionError.cancelled {
                    // Closing the sheet is a choice, not an error.
                } catch {
                    failure = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 12) {
                logo
                Text(title)
            }
            .font(Theme.sans(16, medium: true))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            // The same corner as the fields above, so the sheet reads as one set of controls.
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.press)
        .disabled(working)
    }

    private func submit() async {
        guard ready else { return }
        working = true
        failure = nil
        defer { working = false }
        do {
            if mode == .signUp {
                try await session.signUp(email: email, password: password, name: name)
            } else {
                try await session.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            failure = Self.plain(error)
        }
    }

    /// What went wrong, in words, without the server's request id attached.
    private static func plain(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("InvalidSecret") || text.contains("InvalidAccountId") {
            return "That email and password don't match an account."
        }
        if text.contains("already exists") { return "There's already an account with that email. Sign in instead." }
        if let range = text.range(of: "Uncaught Error: ") {
            return String(text[range.upperBound...]).components(separatedBy: "\n").first ?? text
        }
        return text
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.sans(16))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
