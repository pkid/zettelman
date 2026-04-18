import SwiftUI

struct AppointmentConfirmationView: View {
    let draft: AppointmentDraft
    let onConfirm: (AppointmentDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var editedDraft: AppointmentDraft
    @State private var isSaving = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    init(draft: AppointmentDraft, onConfirm: @escaping (AppointmentDraft) async throws -> Void) {
        self.draft = draft
        self.onConfirm = onConfirm
        _editedDraft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LinearDesign.Spacing.medium) {
                    formSection
                    if previewImage != nil {
                        imageSection
                    }
                }
                .padding(LinearDesign.Spacing.medium)
            }
            .background(LinearDesign.Colors.panelDark)
            .navigationTitle("appointment.confirm.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LinearDesign.Colors.level3Surface.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                    .font(LinearDesign.Typography.body)
                    .foregroundStyle(LinearDesign.Colors.secondaryText)
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "appointment.confirm.saving" : "appointment.confirm.save") {
                        save()
                    }
                    .font(LinearDesign.Typography.bodyMedium)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
                    .disabled(isSaving)
                }
            }
        }
        .alert("appointment.confirm.save.alert.title", isPresented: $showingAlert) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var formSection: some View {
        VStack(spacing: LinearDesign.Spacing.medium) {
            dateTimeRow
            ToggleRow(
                title: "appointment.confirm.reminder",
                isOn: $editedDraft.reminderEnabled
            )
            ToggleRow(
                title: "appointment.confirm.calendar.toggle",
                isOn: $editedDraft.addToCalendar
            )
            InputRow(
                title: "appointment.confirm.what.field",
                text: $editedDraft.what
            )
            .textInputAutocapitalization(.sentences)
            InputRow(
                title: "appointment.confirm.location.field",
                text: $editedDraft.location
            )
            .textInputAutocapitalization(.words)
            InputRow(
                title: "appointment.confirm.withwhom.field",
                text: $editedDraft.withWhom
            )
            .textInputAutocapitalization(.words)

            Text(verbatim: "\(wordCount(of: editedDraft.what))/5 words")
                .font(LinearDesign.Typography.caption)
                .foregroundStyle(wordCount(of: editedDraft.what) > 5 ? LinearDesign.Colors.Semantic.destructive : LinearDesign.Colors.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(LinearDesign.Spacing.medium)
        .linearCard()
    }

    private var dateTimeRow: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
            Text("appointment.confirm.datetime")
                .font(LinearDesign.Typography.labelMedium)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)
            DatePicker("", selection: $editedDraft.scheduledAt)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(LinearDesign.Colors.accentViolet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.small) {
            Text("appointment.confirm.original.zettel")
                .font(LinearDesign.Typography.labelMedium)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)

            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            }
        }
        .padding(LinearDesign.Spacing.medium)
        .linearCard()
    }

    private var previewImage: UIImage? {
        guard let data = editedDraft.previewImageData else { return nil }
        return UIImage(data: data)
    }

    private var isLocationRequired: Bool {
        editedDraft.uploadedZettel != nil || editedDraft.previewImageData != nil
    }

    private func save() {
        let trimmedWhat = editedDraft.what.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWhere = editedDraft.location.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedWhat.isEmpty else {
            alertMessage = String(localized: "appointment.confirm.save.error.what")
            showingAlert = true
            return
        }

        guard wordCount(of: trimmedWhat) <= 5 else {
            alertMessage = String(localized: "appointment.confirm.save.error.wordcount")
            showingAlert = true
            return
        }

        guard !isLocationRequired || !trimmedWhere.isEmpty else {
            alertMessage = String(localized: "appointment.confirm.save.error.location")
            showingAlert = true
            return
        }

        editedDraft.what = trimmedWhat
        editedDraft.location = trimmedWhere
        editedDraft.withWhom = editedDraft.withWhom.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true

        Task {
            do {
                try await onConfirm(editedDraft)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }

    private func wordCount(of value: String) -> Int {
        value.split(whereSeparator: \.isWhitespace).count
    }
}

private struct InputRow: View {
    let title: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
            Text(title)
                .font(LinearDesign.Typography.labelMedium)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)
            TextField("", text: $text)
                .linearInputField()
        }
    }
}

private struct ToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(LinearDesign.Typography.body)
                .foregroundStyle(LinearDesign.Colors.primaryText)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(LinearDesign.Colors.accentViolet)
        }
    }
}
