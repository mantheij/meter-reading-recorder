import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.appLanguage) private var appLanguage

    @State private var showLogoutConfirmation = false

    var body: some View {
        List {
            if let user = authService.currentUser {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.accentPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            if let name = user.displayName, !name.isEmpty {
                                Text(name)
                                    .font(.headline)
                            }
                            if let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }

                Section {
                    HStack {
                        Text(L10n.provider)
                        Spacer()
                        Text(user.provider.displayName)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(L10n.logout)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.account)
        .confirmationDialog(L10n.logout, isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button(L10n.logout, role: .destructive) {
                try? authService.signOut()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.logoutConfirmation)
        }
    }
}
