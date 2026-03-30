import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage

    @State var email: String
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var lockoutSeconds: Int = 0
    @State private var lockoutTimer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text(L10n.resetPassword)
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.top, AppTheme.Spacing.lg)

                TextField(L10n.email, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if lockoutSeconds > 0 {
                    Text(L10n.authErrorRateLimited(lockoutSeconds))
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if showSuccess {
                    Text(L10n.resetEmailSent)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else {
                    Button(action: handleReset) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L10n.sendResetLink)
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accentPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .disabled(isLoading || lockoutSeconds > 0 || email.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.authErrorUnknown, isPresented: $showError, actions: {
                Button(L10n.confirm) {}
            }, message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            })
            .onDisappear {
                lockoutTimer?.invalidate()
            }
        }
    }

    private func handleReset() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces))
                showSuccess = true
                try? await Task.sleep(for: .seconds(2))
                dismiss()
            } catch let error as AuthError {
                if case .rateLimited(let seconds) = error {
                    startLockoutTimer(seconds: seconds)
                }
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
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
