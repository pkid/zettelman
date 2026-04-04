import SwiftUI

struct CognitoAuthView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: CognitoAuthManager

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var confirmationCode = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    enum AuthMode {
        case signIn
        case signUp
        case resetPassword
        case confirmResetPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        formCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .alert("auth.alert.title", isPresented: $showingAlert) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(iconColor)

            Text("auth.app.name")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)

            Text(modeSubtitle)
                .font(.subheadline)
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var formCard: some View {
        VStack(spacing: 18) {
            inputField(
                TextField("auth.email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textContentType(nil)
            )
            .disabled(isLoading)

            inputField(
                SecureField(mode == .confirmResetPassword ? "auth.new.password" : "auth.password", text: $password)
                    .textContentType(nil)
            )
            .disabled(isLoading)

            if mode == .signUp || mode == .confirmResetPassword {
                inputField(
                    SecureField("auth.confirm.password", text: $confirmPassword)
                        .textContentType(nil)
                )
                .disabled(isLoading)
            }

            if mode == .confirmResetPassword {
                inputField(
                    TextField("auth.reset.code", text: $confirmationCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(nil)
                )
                .disabled(isLoading)
            }

            Button(action: submit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryButtonTitle)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(primaryButtonColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isLoading || !isFormValid)

            footer
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            switch mode {
            case .signIn:
                Button("auth.create.account") { mode = .signUp }
                Button("auth.forgot.password") { mode = .resetPassword }
            case .signUp:
                Button("auth.already.have.account") { mode = .signIn }
            case .resetPassword:
                Button("auth.back.to.signin") { mode = .signIn }
            case .confirmResetPassword:
                Button("auth.back.to.signin") { mode = .signIn }
            }
        }
        .font(.footnote)
        .foregroundStyle(footerColor)
    }

    private var modeSubtitle: String {
        switch mode {
        case .signIn:
            return String(localized: "auth.signin.subtitle")
        case .signUp:
            return String(localized: "auth.signup.subtitle")
        case .resetPassword:
            return String(localized: "auth.reset.subtitle")
        case .confirmResetPassword:
            return String(localized: "auth.confirm.reset.subtitle")
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .signIn:
            return String(localized: "auth.signin.button")
        case .signUp:
            return String(localized: "auth.signup.button")
        case .resetPassword:
            return String(localized: "auth.reset.button")
        case .confirmResetPassword:
            return String(localized: "auth.confirm.reset.button")
        }
    }

    private var primaryButtonColor: Color {
        switch mode {
        case .signIn:
            return Color(red: 0.28, green: 0.45, blue: 0.34)
        case .signUp:
            return Color(red: 0.56, green: 0.35, blue: 0.14)
        case .resetPassword, .confirmResetPassword:
            return Color(red: 0.48, green: 0.35, blue: 0.19)
        }
    }

    private var isFormValid: Bool {
        guard !email.isEmpty else { return false }

        switch mode {
        case .signIn:
            return !password.isEmpty
        case .signUp:
            return !password.isEmpty && password == confirmPassword && password.count >= 8
        case .resetPassword:
            return true
        case .confirmResetPassword:
            return !confirmationCode.isEmpty && !password.isEmpty && password == confirmPassword
        }
    }

    private func submit() {
        guard !isLoading else { return }

        isLoading = true

        Task {
            let result: Result<Void, Error>

            switch mode {
            case .signIn:
                result = await authManager.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            case .signUp:
                result = await authManager.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            case .resetPassword:
                result = await authManager.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                if case .success = result {
                    mode = .confirmResetPassword
                }
            case .confirmResetPassword:
                result = await authManager.confirmResetPassword(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    newPassword: password,
                    confirmationCode: confirmationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            isLoading = false

            if case let .failure(error) = result {
                alertMessage = authManager.errorMessage ?? error.localizedDescription
                showingAlert = true
            } else if mode == .signUp {
                alertMessage = String(localized: "auth.signup.success")
                showingAlert = true
                mode = .signIn
            } else if mode == .confirmResetPassword {
                alertMessage = String(localized: "auth.confirm.reset.success")
                showingAlert = true
                mode = .signIn
            }
        }
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.09, green: 0.10, blue: 0.10), Color(red: 0.13, green: 0.16, blue: 0.14)]
        }

        return [Color(red: 0.97, green: 0.93, blue: 0.85), Color(red: 0.92, green: 0.96, blue: 0.92)]
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color(uiColor: .label) : Color(red: 0.16, green: 0.16, blue: 0.13)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? Color(uiColor: .secondaryLabel) : Color(red: 0.32, green: 0.32, blue: 0.28)
    }

    private var iconColor: Color {
        colorScheme == .dark ? Color(red: 0.83, green: 0.66, blue: 0.42) : Color(red: 0.39, green: 0.27, blue: 0.16)
    }

    private var footerColor: Color {
        colorScheme == .dark ? Color(uiColor: .secondaryLabel) : Color(red: 0.34, green: 0.26, blue: 0.16)
    }

    private var inputFillColor: Color {
        colorScheme == .dark ? Color(uiColor: .tertiarySystemBackground) : Color.white.opacity(0.95)
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    private func inputField<Content: View>(_ content: Content) -> some View {
        content
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(inputFillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(inputBorderColor, lineWidth: 1)
            )
    }
}
