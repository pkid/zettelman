import SwiftUI
import UIKit

struct AddAppointmentView: View {
    @ObservedObject var store: AppointmentStore

    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var pendingDraft: AppointmentDraft?
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var isAnalyzing = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.96, blue: 0.90), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCard
                        captureControls
                        analyzeButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isAnalyzing)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(
                onImagePicked: { selectedImage = $0 },
                isPresented: $showingCamera
            )
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryImagePicker(
                onImagePicked: { selectedImage = $0 },
                isPresented: $showingPhotoPicker
            )
        }
        .sheet(item: $pendingDraft) { draft in
            AppointmentConfirmationView(draft: draft) { confirmedDraft in
                try await store.saveDraft(confirmedDraft)
                await MainActor.run {
                    pendingDraft = nil
                    dismiss()
                }
            }
        }
        .alert("Add Appointment", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Capture a zettel")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.18, blue: 0.10))

            Text("Take a picture or select a photo. The app uploads it to S3, asks Lambda + Claude for the date/time, what, and where, then lets the user confirm everything before saving.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(height: 260)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 36, weight: .medium))
                                Text("No zettel selected yet")
                                    .font(.headline)
                                Text("Use one of the actions below.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(Color(red: 0.43, green: 0.30, blue: 0.19))
                        }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.96, green: 0.90, blue: 0.76))
        )
    }

    private var captureControls: some View {
        VStack(spacing: 12) {
            Button(action: { showingCamera = true }) {
                label(title: "Take Picture", icon: "camera")
            }

            Button(action: { showingPhotoPicker = true }) {
                label(title: "Choose from Photos", icon: "photo.on.rectangle")
            }
        }
    }

    private var analyzeButton: some View {
        Button(action: analyze) {
            HStack {
                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }

                Text(isAnalyzing ? "Uploading and analyzing..." : "Analyze Zettel")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(selectedImage == nil || isAnalyzing ? Color.gray : Color(red: 0.28, green: 0.45, blue: 0.34))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(selectedImage == nil || isAnalyzing)
    }

    private func label(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
            Text(title)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Color.white.opacity(0.96))
        .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func analyze() {
        guard let selectedImage else { return }

        isAnalyzing = true

        Task {
            do {
                let draft = try await store.createDraft(from: selectedImage)
                isAnalyzing = false
                pendingDraft = draft
            } catch {
                isAnalyzing = false
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}
