import Amplify
import Foundation

@MainActor
final class CognitoAuthManager: ObservableObject {
    enum AuthState {
        case loading
        case signedOut
        case signingIn
        case signingUp
        case resettingPassword
        case confirmingResetPassword
        case signedIn
    }

    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    func checkAuthStatus() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard session.isSignedIn else {
                resetSessionState()
                return
            }

            let currentUser = try await Amplify.Auth.getCurrentUser()
            let attributes = try await Amplify.Auth.fetchUserAttributes()
            let email = attributes.first(where: { $0.key == .email })?.value ?? currentUser.username

            isSignedIn = true
            userEmail = email
            authState = .signedIn
            errorMessage = nil
        } catch {
            resetSessionState()
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async -> Result<Void, Error> {
        authState = .signingIn
        errorMessage = nil

        do {
            let result = try await Amplify.Auth.signIn(username: email, password: password)
            guard result.isSignedIn else {
                authState = .signedOut
                return .failure(AuthError.unknown("Additional sign-in steps are required"))
            }

            await checkAuthStatus()
            return .success(())
        } catch {
            authState = .signedOut
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func signUp(email: String, password: String) async -> Result<Void, Error> {
        authState = .signingUp
        errorMessage = nil

        do {
            _ = try await Amplify.Auth.signUp(
                username: email,
                password: password,
                options: .init(
                    userAttributes: [
                        AuthUserAttribute(.email, value: email)
                    ]
                )
            )

            authState = .signedOut
            return .success(())
        } catch {
            authState = .signedOut
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func resetPassword(email: String) async -> Result<Void, Error> {
        authState = .resettingPassword
        errorMessage = nil

        do {
            let result = try await Amplify.Auth.resetPassword(for: email)
            authState = result.isPasswordReset ? .signedOut : .confirmingResetPassword
            return .success(())
        } catch {
            authState = .signedOut
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func confirmResetPassword(email: String, newPassword: String, confirmationCode: String) async -> Result<Void, Error> {
        authState = .confirmingResetPassword
        errorMessage = nil

        do {
            try await Amplify.Auth.confirmResetPassword(
                for: email,
                with: newPassword,
                confirmationCode: confirmationCode
            )
            authState = .signedOut
            return .success(())
        } catch {
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func signOut() async {
        _ = await Amplify.Auth.signOut()
        resetSessionState()
        errorMessage = nil
    }

    private func resetSessionState() {
        isSignedIn = false
        userEmail = nil
        authState = .signedOut
    }

    private func normalizedAuthError(from error: Error) -> Error {
        guard let authError = error as? AuthError else {
            return error
        }

        switch authError {
        case .service(let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .validation(_, let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .notAuthorized(let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .unknown(let description, _):
            let message = description.trimmingCharacters(in: .whitespacesAndNewlines)
            return NSError(
                domain: "Zettelman.Auth",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Authentication failed. Please try again." : message]
            )
        default:
            return error
        }
    }

    private func bestMessage(description: String, fallback: String) -> String {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty, trimmedDescription != "unknown" {
            if trimmedDescription.localizedCaseInsensitiveContains("UsernameExistsException")
                || trimmedDescription.localizedCaseInsensitiveContains("already exists") {
                return "An account with this email already exists. Please sign in instead."
            }

            return trimmedDescription
        }

        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty, trimmedFallback != "unknown" {
            return trimmedFallback
        }

        return "Authentication failed. Please check your input and try again."
    }
}
