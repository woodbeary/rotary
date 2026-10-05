import SwiftUI

struct AuthScreen: View {
    @Bindable var authStore: RotaryAuthStore

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    private let hostedAuthCoordinator = RotaryHostedAuthCoordinator.shared

    private var isVerifying: Bool {
        authStore.pendingVerification != nil || authStore.pendingSignInVerification != nil
    }

    var body: some View {
        RotaryCenteredShell {
            RotaryGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "phone.connection.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(RotaryTheme.accent)
                    Text("Rotary")
                        .font(.largeTitle.weight(.bold))
                    Text(isVerifying ? verificationPrompt : "Calls, messages, agents, and history together.")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.body)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: $mode) {
                    ForEach(AuthMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isVerifying)

                VStack(spacing: 12) {
                    TextField(
                        "",
                        text: $email,
                        prompt: Text("Email address")
                            .foregroundStyle(RotaryTheme.placeholderText)
                    )
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .rotaryTextFieldStyle()

                    if !isVerifying {
                        SecureField(
                            "",
                            text: $password,
                            prompt: Text(mode == .signIn ? "Password" : "Create a password")
                                .foregroundStyle(RotaryTheme.placeholderText)
                        )
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .rotaryTextFieldStyle()
                    } else {
                        TextField(
                            "",
                            text: $verificationCode,
                            prompt: Text("Verification code")
                                .foregroundStyle(RotaryTheme.placeholderText)
                        )
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .rotaryTextFieldStyle()
                    }
                }

                if !isVerifying {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(.separator.opacity(0.5))
                            .frame(height: 1)
                        Text("or")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(.separator.opacity(0.5))
                            .frame(height: 1)
                    }

                    Button("Continue with Google") {
                        Task { await startGoogleSignIn() }
                    }
                    .buttonStyle(RotarySecondaryButtonStyle())
                    .disabled(isWorking)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(isVerifying ? "Verify email" : mode.primaryButtonTitle) {
                    Task { await submit() }
                }
                .buttonStyle(RotaryPrimaryButtonStyle())
                .disabled(isWorking || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func startGoogleSignIn() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let ticket = try await hostedAuthCoordinator.startGoogleSignIn()
            try await authStore.signIn(ticket: ticket)
        } catch RotaryHostedAuthError.cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            if isVerifying {
                if authStore.pendingVerification != nil {
                    try await authStore.verifyEmail(code: verificationCode)
                } else {
                    try await authStore.verifySignIn(code: verificationCode)
                }
                return
            }

            switch mode {
            case .signIn:
                try await authStore.signIn(email: email, password: password)
            case .signUp:
                try await authStore.beginSignUp(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var verificationPrompt: String {
        if authStore.pendingSignInVerification != nil {
            return "Clerk wants a trust code for this iPhone. Enter the code it sent you."
        }
        return "Check your inbox and enter the code."
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn: return "Sign in"
        case .signUp: return "Create account"
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .signIn: return "Sign in"
        case .signUp: return "Create account"
        }
    }
}
