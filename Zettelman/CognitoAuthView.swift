import SwiftUI
import UIKit

struct CognitoAuthView: View {
    @EnvironmentObject private var authManager: CognitoAuthManager

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var lastTypedPassword = ""
    @State private var confirmPassword = ""
    @State private var confirmationCode = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    enum AuthMode {
        case signIn
        case signUp
        case confirmSignUp
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
            Button("common.ok", role: .cancel) {
                restorePasswordIfUnexpectedlyCleared()
            }
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
                    .font(.system(.largeTitle, design: .default).weight(.medium))
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
            .textContentType(.username)
            .disabled(isLoading)

            if mode == .signIn || mode == .signUp || mode == .confirmResetPassword {
                LinearPasswordField(
                    placeholder: mode == .confirmResetPassword
                        ? String(localized: "auth.new.password")
                        : String(localized: "auth.password"),
                    text: $password,
                    textContentType: mode == .signIn ? .password : .newPassword
                )
                .onChange(of: password) { newValue in
                    if !newValue.isEmpty {
                        lastTypedPassword = newValue
                    }
                }
                .disabled(isLoading)
            }

            if mode == .signUp || mode == .confirmResetPassword {
                LinearPasswordField(
                    placeholder: String(localized: "auth.confirm.password"),
                    text: $confirmPassword,
                    textContentType: .newPassword
                )
                .disabled(isLoading)
            }

            if mode == .confirmSignUp || mode == .confirmResetPassword {
                LinearTextField(
                    placeholder: "auth.reset.code",
                    text: $confirmationCode
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
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
                .frame(minHeight: 44)
                .padding(.vertical, LinearDesign.Spacing.xSmall)
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
                Button("auth.create.account") { transition(to: .signUp) }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
                Button("auth.forgot.password") { transition(to: .resetPassword) }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .signUp:
                Button("auth.already.have.account") { transition(to: .signIn) }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .confirmSignUp:
                Button("auth.resend.code") {
                    resendSignUpCode()
                }
                .font(LinearDesign.Typography.small)
                .foregroundStyle(LinearDesign.Colors.accentViolet)
                .disabled(isLoading)

                Button("auth.back.to.signin") { transition(to: .signIn) }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .resetPassword:
                Button("auth.back.to.signin") { transition(to: .signIn) }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            case .confirmResetPassword:
                Button("auth.back.to.signin") { transition(to: .signIn) }
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
        case .confirmSignUp:
            return String(localized: "auth.confirm.signup.subtitle")
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
        case .confirmSignUp:
            return String(localized: "auth.confirm.signup.button")
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
        case .confirmSignUp:
            return !confirmationCode.isEmpty
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
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let submittedMode = mode

            switch submittedMode {
            case .signIn:
                result = await authManager.signIn(email: normalizedEmail, password: password)
            case .signUp:
                let signUpResult = await authManager.signUp(
                    email: normalizedEmail,
                    password: password
                )
                switch signUpResult {
                case .success(let outcome):
                    result = .success(())
                    switch outcome {
                    case .completed:
                        alertMessage = String(localized: "auth.signup.success")
                        showingAlert = true
                        transition(to: .signIn)
                    case .needsConfirmation:
                        alertMessage = String(localized: "auth.signup.code.sent")
                        showingAlert = true
                        transition(to: .confirmSignUp)
                    }
                case .failure(let error):
                    result = .failure(error)
                }
            case .confirmSignUp:
                result = await authManager.confirmSignUp(
                    email: normalizedEmail,
                    confirmationCode: confirmationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            case .resetPassword:
                result = await authManager.resetPassword(email: normalizedEmail)
                if case .success = result {
                    transition(to: .confirmResetPassword)
                }
            case .confirmResetPassword:
                result = await authManager.confirmResetPassword(
                    email: normalizedEmail,
                    newPassword: password,
                    confirmationCode: confirmationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            isLoading = false

            if case let .failure(error) = result {
                alertMessage = authManager.errorMessage ?? error.localizedDescription
                showingAlert = true
                restorePasswordIfUnexpectedlyCleared()
                if submittedMode == .signIn,
                   authManager.pendingSignUpEmail?.lowercased() == normalizedEmail.lowercased() {
                    transition(to: .confirmSignUp)
                }
            } else if submittedMode == .confirmSignUp {
                alertMessage = String(localized: "auth.confirm.signup.success")
                showingAlert = true
                transition(to: .signIn)
            } else if submittedMode == .confirmResetPassword {
                alertMessage = String(localized: "auth.confirm.reset.success")
                showingAlert = true
                transition(to: .signIn)
            }
        }
    }

    private func resendSignUpCode() {
        guard !isLoading else { return }

        isLoading = true
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let result = await authManager.resendSignUpCode(email: normalizedEmail)
            isLoading = false

            switch result {
            case .success:
                alertMessage = String(localized: "auth.signup.code.resent")
                showingAlert = true
            case .failure(let error):
                alertMessage = authManager.errorMessage ?? error.localizedDescription
                showingAlert = true
            }
        }
    }

    private func restorePasswordIfUnexpectedlyCleared() {
        guard mode == .signIn,
              password.isEmpty,
              !lastTypedPassword.isEmpty else { return }
        password = lastTypedPassword
    }

    private func transition(to newMode: AuthMode) {
        mode = newMode
        clearSensitiveFields()
    }

    private func clearSensitiveFields() {
        password = ""
        lastTypedPassword = ""
        confirmPassword = ""
        confirmationCode = ""
    }
}

struct LinearTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .linearInputField()
    }
}

struct LinearPasswordField: View {
    let placeholder: String
    @Binding var text: String
    let textContentType: UITextContentType
    @State private var isTextVisible = false

    var body: some View {
        HStack(spacing: LinearDesign.Spacing.small) {
            SecureToggleTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: !isTextVisible,
                textContentType: textContentType
            )
            .frame(maxWidth: .infinity)

            Button {
                isTextVisible.toggle()
            } label: {
                Image(systemName: isTextVisible ? "eye.slash" : "eye")
                    .font(.system(.body, design: .default).weight(.medium))
                    .foregroundStyle(LinearDesign.Colors.secondaryText)
                    .frame(minWidth: 20, minHeight: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTextVisible ? "Hide password" : "Show password")
        }
        .linearInputField()
    }
}

struct SecureToggleTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let textContentType: UITextContentType

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = UIColor(LinearDesign.Colors.primaryText)
        textField.tintColor = UIColor(LinearDesign.Colors.accentViolet)
        textField.isSecureTextEntry = isSecure
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.textContentType = textContentType
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        uiView.placeholder = placeholder
        uiView.isEnabled = context.environment.isEnabled
        uiView.textContentType = textContentType

        if uiView.text != text {
            uiView.text = text
        }

        if uiView.isSecureTextEntry != isSecure {
            let currentText = uiView.text
            let selectedRange = uiView.selectedTextRange
            let wasFirstResponder = uiView.isFirstResponder

            uiView.isSecureTextEntry = isSecure

            if uiView.text != currentText {
                uiView.text = currentText
            }

            if wasFirstResponder {
                uiView.becomeFirstResponder()
            }

            if let selectedRange {
                uiView.selectedTextRange = selectedRange
            } else {
                let end = uiView.endOfDocument
                uiView.selectedTextRange = uiView.textRange(from: end, to: end)
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SecureToggleTextField

        init(_ parent: SecureToggleTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }
    }
}
extension View {
    func linearGhostButton() -> some View {
        self
            .font(LinearDesign.Typography.small)
            .foregroundStyle(LinearDesign.Colors.accentViolet)
    }
}
