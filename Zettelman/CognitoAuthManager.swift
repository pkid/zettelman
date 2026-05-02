import Amplify
import Foundation

@MainActor
final class CognitoAuthManager: ObservableObject {
    enum AuthState {
        case loading
        case signedOut
        case signingIn
        case signingUp
        case confirmingSignUp
        case resendingSignUpCode
        case resettingPassword
        case confirmingResetPassword
        case signedIn
    }

    enum SignUpOutcome {
        case completed
        case needsConfirmation
    }

    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?
    @Published var pendingSignUpEmail: String?

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
                errorMessage = nil
                return
            }

            do {
                let currentUser = try await Amplify.Auth.getCurrentUser()
                let attributes = try await Amplify.Auth.fetchUserAttributes()
                let email = attributes.first(where: { $0.key == .email })?.value ?? currentUser.username

                isSignedIn = true
                userEmail = email
                authState = .signedIn
                errorMessage = nil
            } catch {
                await clearRemoteSession()
                resetSessionState()
                errorMessage = normalizedAuthError(from: error).localizedDescription
            }
        } catch {
            await clearRemoteSession()
            resetSessionState()
            errorMessage = normalizedAuthError(from: error).localizedDescription
        }
    }

    func signIn(email: String, password: String) async -> Result<Void, Error> {
        authState = .signingIn
        errorMessage = nil

        do {
            let result = try await signInWithRecovery(email: email, password: password)
            guard result.isSignedIn else {
                authState = .signedOut
                return .failure(AuthError.unknown(String(localized: "auth.error.additional.steps")))
            }

            await checkAuthStatus()
            return .success(())
        } catch {
            authState = .signedOut
            if isUserNotConfirmedError(error) {
                pendingSignUpEmail = email
            }
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func signUp(email: String, password: String) async -> Result<SignUpOutcome, Error> {
        authState = .signingUp
        errorMessage = nil

        do {
            let result = try await Amplify.Auth.signUp(
                username: email,
                password: password,
                options: .init(
                    userAttributes: [
                        AuthUserAttribute(.email, value: email)
                    ]
                )
            )

            authState = .signedOut
            if result.isSignUpComplete {
                pendingSignUpEmail = nil
                return .success(.completed)
            } else {
                pendingSignUpEmail = email
                return .success(.needsConfirmation)
            }
        } catch {
            authState = .signedOut
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func confirmSignUp(email: String, confirmationCode: String) async -> Result<Void, Error> {
        authState = .confirmingSignUp
        errorMessage = nil

        do {
            let result = try await Amplify.Auth.confirmSignUp(
                for: email,
                confirmationCode: confirmationCode
            )

            guard result.isSignUpComplete else {
                authState = .signedOut
                return .failure(AuthError.unknown(String(localized: "auth.error.additional.steps")))
            }

            pendingSignUpEmail = nil
            authState = .signedOut
            return .success(())
        } catch {
            authState = .signedOut
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    func resendSignUpCode(email: String) async -> Result<Void, Error> {
        authState = .resendingSignUpCode
        errorMessage = nil

        do {
            _ = try await Amplify.Auth.resendSignUpCode(for: email)
            pendingSignUpEmail = email
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
            await clearRemoteSession()
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

    func deleteAccount() async -> Result<Void, Error> {
        errorMessage = nil

        do {
            try await Amplify.Auth.deleteUser()
            resetSessionState()
            return .success(())
        } catch {
            let friendlyError = normalizedAuthError(from: error)
            errorMessage = friendlyError.localizedDescription
            return .failure(friendlyError)
        }
    }

    private func resetSessionState() {
        isSignedIn = false
        userEmail = nil
        pendingSignUpEmail = nil
        authState = .signedOut
    }

    private func signInWithRecovery(email: String, password: String) async throws -> AuthSignInResult {
        do {
            return try await Amplify.Auth.signIn(username: email, password: password)
        } catch {
            guard isInvalidStateError(error) else {
                throw error
            }

            await clearRemoteSession()
            return try await Amplify.Auth.signIn(username: email, password: password)
        }
    }

    private func clearRemoteSession() async {
        _ = await Amplify.Auth.signOut()
    }

    private func isUserNotConfirmedError(_ error: Error) -> Bool {
        let message = "\(error)"
        return message.localizedCaseInsensitiveContains("UserNotConfirmedException")
            || message.localizedCaseInsensitiveContains("not confirmed")
    }

    private func isInvalidStateError(_ error: Error) -> Bool {
        guard let authError = error as? AuthError else {
            return false
        }

        if case .invalidState = authError {
            return true
        }

        return false
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
        case .invalidState(let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .configuration(let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .signedOut(let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .sessionExpired(let description, let recoverySuggestion, _):
            let message = bestMessage(description: description, fallback: recoverySuggestion)
            return NSError(
                domain: "Zettelman.Auth",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .unknown(let description, _):
            let message = description.trimmingCharacters(in: .whitespacesAndNewlines)
            return NSError(
                domain: "Zettelman.Auth",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? String(localized: "auth.error.failed.tryagain") : message]
            )
        }
    }

    private func bestMessage(description: String, fallback: String) -> String {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty, trimmedDescription != "unknown" {
            if trimmedDescription.localizedCaseInsensitiveContains("UserNotConfirmedException")
                || trimmedDescription.localizedCaseInsensitiveContains("not confirmed") {
                return String(localized: "auth.error.account.not.confirmed")
            }

            if trimmedDescription.localizedCaseInsensitiveContains("CodeMismatchException")
                || trimmedDescription.localizedCaseInsensitiveContains("Invalid verification code") {
                return String(localized: "auth.error.invalid.code")
            }

            if trimmedDescription.localizedCaseInsensitiveContains("ExpiredCodeException")
                || trimmedDescription.localizedCaseInsensitiveContains("expired code") {
                return String(localized: "auth.error.code.expired")
            }

            if trimmedDescription.localizedCaseInsensitiveContains("UsernameExistsException")
                || trimmedDescription.localizedCaseInsensitiveContains("already exists") {
                return String(localized: "auth.error.account.exists")
            }

            return trimmedDescription
        }

        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty, trimmedFallback != "unknown" {
            return trimmedFallback
        }

        return String(localized: "auth.error.failed.checkinput")
    }
}
