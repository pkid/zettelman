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
    @State private var showingPlans = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearDesign.Colors.panelDark
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
                        heroCard
                        uploadQuotaCard
                        captureControls
                    }
                    .padding(LinearDesign.Spacing.medium)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                analyzeButtonBar
            }
            .navigationTitle("appointment.new.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LinearDesign.Colors.level3Surface.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        dismiss()
                    }
                    .font(LinearDesign.Typography.body)
                    .foregroundStyle(LinearDesign.Colors.secondaryText)
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
        .sheet(isPresented: $showingPlans) {
            UploadPlansView(store: store)
        }
        .alert("appointment.add.alert.title", isPresented: $showingAlert) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .task {
            await store.refreshSubscriptionState()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
            Text("appointment.capture.title")
                .font(LinearDesign.Typography.heading2)
                .foregroundStyle(LinearDesign.Colors.primaryText)

            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous)
                        .fill(LinearDesign.Colors.level3Surface)
                        .frame(height: 260)
                        .overlay {
                            VStack(spacing: LinearDesign.Spacing.medium) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 36, weight: .medium))
                                Text("appointment.capture.no.zettel")
                                    .font(LinearDesign.Typography.body)
                            }
                            .foregroundStyle(LinearDesign.Colors.tertiaryText)
                        }
                }
            }
        }
        .padding(LinearDesign.Spacing.large)
        .linearCard()
    }

    private var captureControls: some View {
        VStack(spacing: LinearDesign.Spacing.small) {
            captureButton(title: String(localized: "appointment.capture.take.picture"), icon: "camera") {
                showingCamera = true
            }

            captureButton(title: String(localized: "appointment.capture.choose.photos"), icon: "photo.on.rectangle") {
                showingPhotoPicker = true
            }
        }
    }

    private var uploadQuotaCard: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                    Text("Monthly uploads")
                        .font(LinearDesign.Typography.captionMedium)
                        .foregroundStyle(LinearDesign.Colors.tertiaryText)
                    Text(verbatim: store.isUploadQuotaBypassed ? "Unlimited (debug)" : "\(store.uploadsRemainingThisMonth) left this month")
                        .font(LinearDesign.Typography.bodyMedium)
                        .foregroundStyle(LinearDesign.Colors.primaryText)
                }

                Spacer()

                if !store.isUploadQuotaBypassed {
                    Button("Upgrade") {
                        showingPlans = true
                    }
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
                }
            }

            ProgressView(value: Double(store.uploadsUsedThisMonth), total: Double(store.uploadLimitThisMonth))
                .tint(LinearDesign.Colors.accentViolet)

            if store.isUploadQuotaBypassed {
                Text(verbatim: "\(store.uploadsUsedThisMonth) uploads tracked this month (quota bypass enabled)")
                    .font(LinearDesign.Typography.caption)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
            } else {
                Text(verbatim: "\(store.uploadsUsedThisMonth)/\(store.uploadLimitThisMonth) used (\(store.uploadPlan.title))")
                    .font(LinearDesign.Typography.caption)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
            }
        }
        .padding(LinearDesign.Spacing.medium)
        .linearCard()
    }

    private func captureButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(LinearDesign.Typography.bodyMedium)
                Text(title)
                    .font(LinearDesign.Typography.bodyMedium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(LinearDesign.Typography.caption)
                    .foregroundStyle(LinearDesign.Colors.quaternaryText)
            }
            .padding(LinearDesign.Spacing.medium)
            .frame(height: 54)
            .background(LinearDesign.Colors.level3Surface)
            .foregroundStyle(LinearDesign.Colors.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.medium)
                    .stroke(LinearDesign.Colors.borderSubtle, lineWidth: 1)
            )
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

                Text(isAnalyzing ? "appointment.analyzing" : "appointment.analyze.button")
                    .font(LinearDesign.Typography.bodyMedium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isAnalyzeButtonDisabled ? LinearDesign.Colors.borderSecondary : LinearDesign.Colors.accentViolet)
            .foregroundStyle(isAnalyzeButtonDisabled ? LinearDesign.Colors.tertiaryText : .white)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
        }
        .disabled(isAnalyzeButtonDisabled)
    }

    private var analyzeButtonBar: some View {
        VStack(spacing: LinearDesign.Spacing.small) {
            analyzeButton

            if !store.canUploadMoreThisMonth {
                Button("Upgrade plan") {
                    showingPlans = true
                }
                .font(LinearDesign.Typography.labelMedium)
                .foregroundStyle(LinearDesign.Colors.accentViolet)
            }
        }
        .padding(.horizontal, LinearDesign.Spacing.medium)
        .padding(.top, LinearDesign.Spacing.small)
        .padding(.bottom, LinearDesign.Spacing.small)
        .background(LinearDesign.Colors.panelDark)
    }

    private func analyze() {
        guard let selectedImage else { return }

        isAnalyzing = true

        Task {
            do {
                let draft = try await store.createDraft(from: selectedImage)
                isAnalyzing = false
                pendingDraft = draft
            } catch let uploadLimitError as UploadQuotaError {
                isAnalyzing = false
                alertMessage = uploadLimitError.localizedDescription
                showingAlert = true
                showingPlans = true
            } catch {
                isAnalyzing = false
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }

    private var isAnalyzeButtonDisabled: Bool {
        selectedImage == nil || isAnalyzing || !store.canUploadMoreThisMonth
    }
}
