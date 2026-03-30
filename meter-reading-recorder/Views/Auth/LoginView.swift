import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.appLanguage) private var appLanguage

    @State private var email = ""
    @State private var password = ""
    @State private var isCreateMode = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var currentNonce: String?
    @State private var lockoutSeconds: Int = 0
    @State private var lockoutTimer: Timer?
    @State private var showPasswordReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Header
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.accentPrimary)
                    .padding(.top, AppTheme.Spacing.xl)

                Text(isCreateMode ? L10n.createAccount : L10n.login)
                    .font(.largeTitle.bold())
                    .foregroundColor(AppTheme.textPrimary)

                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleSignInNonce.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

                // Google Sign In
                Button(action: handleGoogleSignIn) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text(L10n.signInWithGoogle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .foregroundColor(AppTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }

                // Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                    Text(L10n.orSeparator)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                }

                // Email/Password form
                VStack(spacing: AppTheme.Spacing.sm) {
                    TextField(L10n.email, text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField(L10n.password, text: $password)
                        .textContentType(isCreateMode ? .newPassword : .password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Forgot password
                if !isCreateMode {
                    Button(action: { showPasswordReset = true }) {
                        Text(L10n.forgotPassword)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.accentPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Rate limiter feedback
                if lockoutSeconds > 0 {
                    Text(L10n.authErrorRateLimited(lockoutSeconds))
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Submit button
                Button(action: handleEmailAuth) {
                    if case .authenticating = authService.state {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isCreateMode ? L10n.createAccount : L10n.signIn)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentPrimary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .disabled(lockoutSeconds > 0 || authService.state == .authenticating)

                // Toggle create/sign-in mode
                Button(action: { isCreateMode.toggle() }) {
                    Text(isCreateMode ? L10n.alreadyHaveAccount : L10n.noAccountYet)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accentPrimary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .alert(L10n.authErrorUnknown, isPresented: $showError, actions: {
            Button(L10n.confirm) {}
        }, message: {
            if let errorMessage {
                Text(errorMessage)
            }
        })
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView(email: email)
                .environmentObject(authService)
        }
        .onDisappear {
            lockoutTimer?.invalidate()
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else { return }
            Task {
                do {
                    try await authService.signInWithApple(credential: credential, nonce: nonce)
                } catch {
                    showAuthError(error)
                }
            }
        case .failure:
            // User cancelled — no error shown
            break
        }
    }

    // MARK: - Google Sign In

    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        Task {
            do {
                try await authService.signInWithGoogle(presenting: rootVC)
            } catch let error as AuthError where error == .cancelled {
                // User cancelled — no error shown
            } catch {
                showAuthError(error)
            }
        }
    }

    // MARK: - Email Auth

    private func handleEmailAuth() {
        Task {
            do {
                if isCreateMode {
                    try await authService.createAccount(email: email, password: password)
                } else {
                    try await authService.signInWithEmail(email, password: password)
                }
            } catch let error as AuthError {
                if case .rateLimited(let seconds) = error {
                    startLockoutTimer(seconds: seconds)
                }
                showAuthError(error)
            } catch {
                showAuthError(error)
            }
        }
    }

    private func showAuthError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func startLockoutTimer(seconds: Int) {
        lockoutSeconds = seconds
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if lockoutSeconds > 0 {
                    lockoutSeconds -= 1
                } else {
                    lockoutTimer?.invalidate()
                }
            }
        }
    }
}

// Equatable conformance for comparing AuthError in catch
extension AuthError: Equatable {
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}
