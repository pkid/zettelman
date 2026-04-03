import SwiftUI
import UIKit

struct AddAppointmentView: View {
    @ObservedObject var store: AppointmentStore

    @Environment(\.colorScheme) private var colorScheme
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
                    colors: backgroundGradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCard
                        captureControls
                    }
                    .padding(20)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                analyzeButtonBar
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
                .foregroundStyle(heroTitleColor)

            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(heroPlaceholderFillColor)
                        .frame(height: 260)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 36, weight: .medium))
                                Text("No zettel selected yet")
                                    .font(.headline)
                            }
                            .foregroundStyle(heroPlaceholderAccentColor)
                        }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(heroCardFillColor)
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
            .background(isAnalyzeButtonDisabled ? disabledAnalyzeButtonColor : analyzeButtonColor)
            .foregroundStyle(isAnalyzeButtonDisabled ? disabledAnalyzeButtonTextColor : .white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(isAnalyzeButtonDisabled)
    }

    private var analyzeButtonBar: some View {
        analyzeButton
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
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
        .background(actionButtonFillColor)
        .foregroundStyle(actionButtonTextColor)
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

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.09, green: 0.10, blue: 0.10), Color(red: 0.12, green: 0.16, blue: 0.15)]
        }

        return [Color(red: 0.98, green: 0.96, blue: 0.90), Color.white]
    }

    private var heroCardFillColor: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(red: 0.96, green: 0.90, blue: 0.76)
    }

    private var heroPlaceholderFillColor: Color {
        colorScheme == .dark ? Color(uiColor: .tertiarySystemBackground) : Color.white.opacity(0.85)
    }

    private var heroTitleColor: Color {
        colorScheme == .dark ? Color(uiColor: .label) : Color(red: 0.24, green: 0.18, blue: 0.10)
    }

    private var heroPlaceholderAccentColor: Color {
        colorScheme == .dark ? Color(red: 0.83, green: 0.66, blue: 0.42) : Color(red: 0.43, green: 0.30, blue: 0.19)
    }

    private var actionButtonFillColor: Color {
        colorScheme == .dark ? Color(uiColor: .tertiarySystemBackground) : Color.white.opacity(0.96)
    }

    private var actionButtonTextColor: Color {
        Color(uiColor: .label)
    }

    private var analyzeButtonColor: Color {
        Color(red: 0.28, green: 0.45, blue: 0.34)
    }

    private var isAnalyzeButtonDisabled: Bool {
        selectedImage == nil || isAnalyzing
    }

    private var disabledAnalyzeButtonColor: Color {
        Color(uiColor: .systemGray4)
    }

    private var disabledAnalyzeButtonTextColor: Color {
        Color(uiColor: .label)
    }
}
