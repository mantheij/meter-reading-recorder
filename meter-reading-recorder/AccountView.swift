import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                AccountDetailView()
            } else {
                LoginView()
            }
        }
    }
}
