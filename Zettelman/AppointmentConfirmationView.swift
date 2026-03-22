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
                Section("Original Zettel") {
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    }

                    if let rawDateTime = editedDraft.rawDateTime, !rawDateTime.isEmpty {
                        LabeledContent("Model date/time") {
                            Text(rawDateTime)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    LabeledContent("S3 key") {
                        Text(editedDraft.uploadedZettel.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Confirm Appointment") {
                    DatePicker("Date and time", selection: $editedDraft.scheduledAt)

                    TextField("What", text: $editedDraft.what)
                        .textInputAutocapitalization(.sentences)

                    TextField("Where", text: $editedDraft.location)
                        .textInputAutocapitalization(.words)

                    Text("\(wordCount(of: editedDraft.what))/5 words")
                        .font(.caption)
                        .foregroundStyle(wordCount(of: editedDraft.what) > 5 ? .red : .secondary)
                }
            }
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert("Save Appointment", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
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
            alertMessage = "Enter a short description for the appointment."
            showingAlert = true
            return
        }

        guard wordCount(of: trimmedWhat) <= 5 else {
            alertMessage = "Keep the 'what' field to five words or fewer."
            showingAlert = true
            return
        }

        guard !trimmedWhere.isEmpty else {
            alertMessage = "Enter the location before saving."
            showingAlert = true
            return
        }

        editedDraft.what = trimmedWhat
        editedDraft.location = trimmedWhere
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
