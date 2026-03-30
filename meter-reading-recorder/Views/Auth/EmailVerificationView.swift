import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var isResending = false
    @State private var isChecking = false
    @State private var showResendSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var userEmail: String {
        if case .emailNotVerified(let user) = authService.state {
            return user.email ?? ""
        }
        return ""
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.accentPrimary)

            Text(L10n.emailVerificationTitle)
                .font(.largeTitle.bold())
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.emailVerificationMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.md)

            if !userEmail.isEmpty {
                Text(userEmail)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Text(L10n.checkSpamFolder)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // "I've verified" button
            Button(action: checkVerification) {
                if isChecking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L10n.alreadyVerified)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.accentPrimary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .disabled(isChecking || isResending)

            // Resend button
            Button(action: resendEmail) {
                if isResending {
                    ProgressView()
                } else {
                    Text(L10n.resendVerificationEmail)
                }
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.accentPrimary)
            .disabled(isResending || isChecking)

            // Sign out link
            Button(action: {
                try? authService.signOut()
            }) {
                Text(L10n.logout)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.xl)
        .alert(L10n.authErrorUnknown, isPresented: $showError, actions: {
            Button(L10n.confirm) {}
        }, message: {
            if let errorMessage {
                Text(errorMessage)
            }
        })
        .overlay(alignment: .top) {
            if showResendSuccess {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L10n.verificationEmailSent)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .shadow(radius: 4)
                .padding(.top, AppTheme.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showResendSuccess)
    }

    private func checkVerification() {
        isChecking = true
        Task {
            do {
                try await authService.reloadUser()
                if case .emailNotVerified = authService.state {
                    errorMessage = L10n.emailNotYetVerified
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isChecking = false
        }
    }

    private func resendEmail() {
        isResending = true
        Task {
            do {
                try await authService.resendVerificationEmail()
                withAnimation { showResendSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showResendSuccess = false }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isResending = false
        }
    }
}
