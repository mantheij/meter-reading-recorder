import Foundation

// MARK: - Auth State

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(AuthUser)
    case emailNotVerified(AuthUser)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated): return true
        case (.authenticating, .authenticating): return true
        case (.authenticated(let a), .authenticated(let b)): return a.uid == b.uid
        case (.emailNotVerified(let a), .emailNotVerified(let b)): return a.uid == b.uid
        default: return false
        }
    }
}

// MARK: - Auth User

struct AuthUser {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: URL?
    let provider: AuthProvider
    let emailVerified: Bool
}

// MARK: - Auth Provider

enum AuthProvider: String {
    case apple
    case google
    case emailPassword

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .emailPassword: return "Email"
        }
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case wrongCredentials
    case networkError
    case rateLimited(seconds: Int)
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return L10n.authErrorInvalidEmail
        case .weakPassword:
            return L10n.authErrorWeakPassword
        case .emailAlreadyInUse:
            return L10n.authErrorEmailInUse
        case .wrongCredentials:
            return L10n.authErrorWrongCredentials
        case .networkError:
            return L10n.authErrorNetwork
        case .rateLimited(let seconds):
            return L10n.authErrorRateLimited(seconds)
        case .cancelled:
            return L10n.authErrorCancelled
        case .unknown:
            return L10n.authErrorUnknown
        }
    }
}
