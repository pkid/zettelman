import SwiftUI

struct CognitoAuthView: View {
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
        ZStack {
            LinearDesign.Colors.panelDark
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LinearDesign.Spacing.xxLarge) {
                    headerSection
                    formSection
                    footerSection
                }
                .padding(LinearDesign.Spacing.xLarge)
            }
        }
        .alert("auth.alert.title", isPresented: $showingAlert) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var headerSection: some View {
        VStack(spacing: LinearDesign.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(LinearDesign.Colors.accentViolet.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            }

            Text("auth.app.name")
                .font(LinearDesign.Typography.heading1)
                .foregroundStyle(LinearDesign.Colors.primaryText)

            Text(modeSubtitle)
                .font(LinearDesign.Typography.body)
                .foregroundStyle(LinearDesign.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, LinearDesign.Spacing.xxxLarge)
    }

    private var formSection: some View {
        VStack(spacing: LinearDesign.Spacing.medium) {
            LinearTextField(
                placeholder: "auth.email",
                text: $email
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textContentType(nil)
            .disabled(isLoading)

            LinearTextField(
                placeholder: mode == .confirmResetPassword ? "auth.new.password" : "auth.password",
                text: $password,
                isSecure: true
            )
            .textContentType(nil)
            .disabled(isLoading)

            if mode == .signUp || mode == .confirmResetPassword {
                LinearTextField(
                    placeholder: "auth.confirm.password",
                    text: $confirmPassword,
                    isSecure: true
                )
                .textContentType(nil)
                .disabled(isLoading)
            }

            if mode == .confirmResetPassword {
                LinearTextField(
                    placeholder: "auth.reset.code",
                    text: $confirmationCode
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(nil)
                .disabled(isLoading)
            }

            Button(action: submit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryButtonTitle)
                            .font(LinearDesign.Typography.bodyMedium)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(LinearDesign.Colors.accentViolet)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            }
            .disabled(isLoading || !isFormValid)
        }
        .linearCard()
        .padding(.horizontal, LinearDesign.Spacing.xxSmall)
    }

    private var footerSection: some View {
        VStack(spacing: LinearDesign.Spacing.small) {
            switch mode {
            case .signIn:
                Button("auth.create.account") { mode = .signUp }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
                Button("auth.forgot.password") { mode = .resetPassword }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .signUp:
                Button("auth.already.have.account") { mode = .signIn }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .resetPassword:
                Button("auth.back.to.signin") { mode = .signIn }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .confirmResetPassword:
                Button("auth.back.to.signin") { mode = .signIn }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            }
        }
        .font(LinearDesign.Typography.small)
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
}

struct LinearTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .linearInputField()
    }
}

extension View {
    func linearGhostButton() -> some View {
        self
            .font(LinearDesign.Typography.small)
            .foregroundStyle(LinearDesign.Colors.accentViolet)
    }
}
