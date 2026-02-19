import Foundation
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import Combine
import os

@MainActor
final class AuthService: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    static let shared = AuthService()

    private(set) var state: AuthState = .unauthenticated {
        willSet { objectWillChange.send() }
    }
    var loginSuccessEvent: UUID? = nil {
        willSet { objectWillChange.send() }
    }
    private var stateListener: AuthStateDidChangeListenerHandle?
    private let rateLimiter = RateLimiter()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meter-reading-recorder", category: "Auth")

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    var currentUserId: String? {
        if case .authenticated(let user) = state { return user.uid }
        return nil
    }

    var currentUser: AuthUser? {
        if case .authenticated(let user) = state { return user }
        return nil
    }

    private init() {
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self else { return }
                if let firebaseUser {
                    let user = self.mapFirebaseUser(firebaseUser)
                    // Block unverified email/password accounts
                    if user.provider == .emailPassword && !firebaseUser.isEmailVerified {
                        SyncService.shared.stopSync()
                        self.state = .emailNotVerified(user)
                        self.logger.info("User email not verified: \(firebaseUser.uid, privacy: .private)")
                    } else {
                        self.state = .authenticated(user)
                        self.logger.info("User authenticated: \(firebaseUser.uid, privacy: .private)")
                        self.adoptLocalDataIfNeeded(userId: user.uid)
                        SyncService.shared.startSync(for: user.uid)
                    }
                } else {
                    SyncService.shared.stopSync()
                    self.state = .unauthenticated
                    self.logger.info("User signed out")
                }
            }
        }
    }

    // MARK: - Sign In with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        state = .authenticating
        do {
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                state = .unauthenticated
                throw AuthError.unknown
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            let result = try await Auth.auth().signIn(with: firebaseCredential)
            loginSuccessEvent = UUID()
            logger.info("Apple sign-in successful: \(result.user.uid, privacy: .private)")

            // Store display name from Apple on first sign-in
            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !displayName.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                }
            }
        } catch let error as AuthError {
            state = .unauthenticated
            throw error
        } catch {
            state = .unauthenticated
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign In with Google

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        state = .authenticating
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                state = .unauthenticated
                throw AuthError.unknown
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            loginSuccessEvent = UUID()
            logger.info("Google sign-in successful: \(authResult.user.uid, privacy: .private)")
        } catch let error as GIDSignInError where error.code == .canceled {
            state = .unauthenticated
            throw AuthError.cancelled
        } catch let error as AuthError {
            state = .unauthenticated
            throw error
        } catch {
            state = .unauthenticated
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Email / Password Sign In

    func signInWithEmail(_ email: String, password: String) async throws {
        guard InputValidator.isValidEmail(email) else { throw AuthError.invalidEmail }

        guard await rateLimiter.canAttempt() else {
            let seconds = await rateLimiter.remainingLockoutSeconds
            throw AuthError.rateLimited(seconds: Int(seconds))
        }

        await rateLimiter.recordAttempt()
        state = .authenticating

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            loginSuccessEvent = UUID()
            logger.info("Email sign-in successful: \(result.user.uid, privacy: .private)")
            await rateLimiter.reset()
        } catch {
            state = .unauthenticated
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Create Account

    func createAccount(email: String, password: String) async throws {
        guard InputValidator.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard InputValidator.isValidPassword(password) else { throw AuthError.weakPassword }

        state = .authenticating
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            logger.info("Account created: \(result.user.uid, privacy: .private)")
            // State listener will set .emailNotVerified

            // Send verification email separately — account creation should not fail if this errors
            do {
                try await result.user.sendEmailVerification()
                logger.info("Verification email sent: \(result.user.uid, privacy: .private)")
            } catch {
                logger.error("Failed to send verification email: \(error.localizedDescription, privacy: .private)")
            }
        } catch {
            state = .unauthenticated
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        guard InputValidator.isValidEmail(email) else { throw AuthError.invalidEmail }

        guard await rateLimiter.canAttempt() else {
            let seconds = await rateLimiter.remainingLockoutSeconds
            throw AuthError.rateLimited(seconds: Int(seconds))
        }

        await rateLimiter.recordAttempt()

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            logger.info("Password reset email sent for: \(email, privacy: .private)")
            await rateLimiter.reset()
        } catch {
            let code = AuthErrorCode(rawValue: (error as NSError).code)
            // Swallow userNotFound to prevent info leaks — always show success
            if code == .userNotFound {
                logger.info("Password reset requested for non-existent email: \(email, privacy: .private)")
                await rateLimiter.reset()
                return
            }
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Email Verification

    func resendVerificationEmail() async throws {
        guard let firebaseUser = Auth.auth().currentUser else { throw AuthError.unknown }

        guard await rateLimiter.canAttempt() else {
            let seconds = await rateLimiter.remainingLockoutSeconds
            throw AuthError.rateLimited(seconds: Int(seconds))
        }

        await rateLimiter.recordAttempt()

        do {
            try await firebaseUser.sendEmailVerification()
            logger.info("Verification email resent: \(firebaseUser.uid, privacy: .private)")
            await rateLimiter.reset()
        } catch {
            throw mapFirebaseError(error)
        }
    }

    func reloadUser() async throws {
        guard let firebaseUser = Auth.auth().currentUser else { throw AuthError.unknown }
        try await firebaseUser.reload()
        let user = mapFirebaseUser(firebaseUser)
        if firebaseUser.isEmailVerified {
            state = .authenticated(user)
            loginSuccessEvent = UUID()
            adoptLocalDataIfNeeded(userId: user.uid)
            SyncService.shared.startSync(for: user.uid)
            logger.info("Email verified, user authenticated: \(firebaseUser.uid, privacy: .private)")
        } else {
            state = .emailNotVerified(user)
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            SyncService.shared.stopSync()
            try Auth.auth().signOut()
            KeychainService.shared.clearAll()
            state = .unauthenticated
            logger.info("Sign out successful")
        } catch {
            logger.error("Sign out failed: \(error.localizedDescription, privacy: .private)")
            throw AuthError.unknown
        }
    }

    // MARK: - Data Adoption

    private func adoptLocalDataIfNeeded(userId: String) {
        let key = "dataAdoptedForUser_\(userId)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        PersistenceController.shared.adoptLocalData(for: userId)
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Helpers

    private func mapFirebaseUser(_ user: FirebaseAuth.User) -> AuthUser {
        let provider: AuthProvider
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            provider = .apple
        } else if user.providerData.contains(where: { $0.providerID == "google.com" }) {
            provider = .google
        } else {
            provider = .emailPassword
        }

        return AuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL,
            provider: provider,
            emailVerified: user.isEmailVerified
        )
    }

    private func mapFirebaseError(_ error: Error) -> AuthError {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return .unknown
        }
        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .wrongPassword, .userNotFound, .invalidCredential:
            return .wrongCredentials
        case .networkError:
            return .networkError
        default:
            return .unknown
        }
    }
}

// MARK: - Apple Sign-In Nonce Helpers

import CryptoKit

enum AppleSignInNonce {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
