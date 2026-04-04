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
            Form {
                Section("appointment.confirm.section") {
                    DatePicker("appointment.confirm.datetime", selection: $editedDraft.scheduledAt)

                    Toggle("appointment.confirm.reminder", isOn: $editedDraft.reminderEnabled)
                    Toggle("appointment.confirm.calendar.toggle", isOn: $editedDraft.addToCalendar)

                    TextField("appointment.confirm.what.field", text: $editedDraft.what)
                        .textInputAutocapitalization(.sentences)

                    TextField("appointment.confirm.location.field", text: $editedDraft.location)
                        .textInputAutocapitalization(.words)

                    TextField("appointment.confirm.withwhom.field", text: $editedDraft.withWhom)
                        .textInputAutocapitalization(.words)

                    Text(String(format: String(localized: "appointment.confirm.wordcount"), wordCount(of: editedDraft.what)))
                        .font(.caption)
                        .foregroundStyle(wordCount(of: editedDraft.what) > 5 ? .red : .secondary)
                }

                Section("appointment.confirm.original.zettel") {
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    }
                }
            }
            .navigationTitle("appointment.confirm.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "appointment.confirm.saving" : "appointment.confirm.save") {
                        save()
                    }
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

    private var previewImage: UIImage? {
        guard let data = editedDraft.previewImageData else { return nil }
        return UIImage(data: data)
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

        guard !trimmedWhere.isEmpty else {
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
