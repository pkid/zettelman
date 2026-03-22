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
    @Published var userCompany: String?
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
            let company = attributes.first(where: { $0.key == .address })?.value

            isSignedIn = true
            userEmail = email
            userCompany = company
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
            errorMessage = error.localizedDescription
            return .failure(error)
        }
    }

    func signUp(email: String, password: String, company: String) async -> Result<Void, Error> {
        authState = .signingUp
        errorMessage = nil

        do {
            _ = try await Amplify.Auth.signUp(
                username: email,
                password: password,
                options: .init(
                    userAttributes: [
                        AuthUserAttribute(.email, value: email),
                        AuthUserAttribute(.address, value: company)
                    ]
                )
            )

            authState = .signedOut
            return .success(())
        } catch {
            authState = .signedOut
            errorMessage = error.localizedDescription
            return .failure(error)
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
            errorMessage = error.localizedDescription
            return .failure(error)
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
            errorMessage = error.localizedDescription
            return .failure(error)
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
        userCompany = nil
        authState = .signedOut
    }
}
