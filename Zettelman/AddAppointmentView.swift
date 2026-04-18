import SwiftUI
import UIKit

struct AddAppointmentView: View {
    private enum CaptureMode: String, CaseIterable, Identifiable {
        case scan
        case manual

        var id: String { rawValue }
    }

    @ObservedObject var store: AppointmentStore

    @Environment(\.dismiss) private var dismiss

    @State private var captureMode: CaptureMode = .scan
    @State private var selectedImage: UIImage?
    @State private var manualScheduledAt = Date()
    @State private var manualWhat = ""
    @State private var manualLocation = ""
    @State private var manualWithWhom = ""
    @State private var pendingDraft: AppointmentDraft?
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingCaptureSourceDialog = false
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
                        captureModeSelector
                        heroCard
                        if captureMode == .scan {
                            uploadQuotaCard
                        }
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
        .confirmationDialog("appointment.capture.source.title", isPresented: $showingCaptureSourceDialog, titleVisibility: .visible) {
            if isCameraAvailable {
                Button("appointment.capture.take.picture") {
                    showingCamera = true
                }
            }

            Button("appointment.capture.choose.photos") {
                showingPhotoPicker = true
            }

            Button("common.cancel", role: .cancel) { }
        } message: {
            Text("appointment.capture.source.message")
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

    private var captureModeSelector: some View {
        Picker("appointment.capture.mode.label", selection: $captureMode) {
            Text("appointment.capture.mode.scan")
                .tag(CaptureMode.scan)
            Text("appointment.capture.mode.manual")
                .tag(CaptureMode.manual)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, LinearDesign.Spacing.xxSmall)
        .disabled(isAnalyzing)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
            Text("appointment.capture.title")
                .font(LinearDesign.Typography.heading2)
                .foregroundStyle(LinearDesign.Colors.primaryText)

            Group {
                switch captureMode {
                case .scan:
                    scanHero
                case .manual:
                    manualHero
                }
            }
        }
        .padding(LinearDesign.Spacing.large)
        .linearCard()
    }

    private var uploadQuotaCard: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                    Text("Monthly uploads")
                        .font(LinearDesign.Typography.captionMedium)
                        .foregroundStyle(LinearDesign.Colors.tertiaryText)
                    Text(verbatim: store.isUploadQuotaBypassed ? "Unlimited (debug)" : "\(store.uploadsRemainingThisMonth) left this month")
                        .font(LinearDesign.Typography.smallMedium)
                        .foregroundStyle(LinearDesign.Colors.secondaryText)
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
                    .font(LinearDesign.Typography.label)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, LinearDesign.Spacing.medium)
        .padding(.vertical, LinearDesign.Spacing.small)
        .linearCard()
    }

    private var primaryActionButton: some View {
        Button(action: primaryAction) {
            HStack {
                if captureMode == .scan && isAnalyzing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: captureMode == .scan ? "wand.and.stars" : "square.and.pencil")
                }

                Text(primaryActionTitle)
                    .font(LinearDesign.Typography.bodyMedium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isPrimaryActionDisabled ? LinearDesign.Colors.borderSecondary : LinearDesign.Colors.accentViolet)
            .foregroundStyle(isPrimaryActionDisabled ? LinearDesign.Colors.tertiaryText : .white)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
        }
        .disabled(isPrimaryActionDisabled)
    }

    private var analyzeButtonBar: some View {
        VStack(spacing: LinearDesign.Spacing.small) {
            primaryActionButton

            if captureMode == .scan && !store.canUploadMoreThisMonth {
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

    private var scanHero: some View {
        VStack(spacing: LinearDesign.Spacing.small) {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous))

                selectedImageActions
            } else {
                emptyCaptureButton
            }
        }
    }

    private var emptyCaptureButton: some View {
        Button(action: presentCaptureSourceDialog) {
            VStack(spacing: LinearDesign.Spacing.large) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(LinearDesign.Colors.secondaryText)

                VStack(spacing: LinearDesign.Spacing.xSmall) {
                    Text("appointment.capture.empty.title")
                        .font(LinearDesign.Typography.heading3)
                        .foregroundStyle(LinearDesign.Colors.primaryText)

                    Text("appointment.capture.empty.detail")
                        .font(LinearDesign.Typography.body)
                        .foregroundStyle(LinearDesign.Colors.tertiaryText)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: LinearDesign.Spacing.xSmall) {
                    Image(systemName: "plus")
                    Text("appointment.capture.add.note")
                }
                .font(LinearDesign.Typography.bodyMedium)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(LinearDesign.Colors.accentViolet)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            }
            .padding(LinearDesign.Spacing.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 260)
            .background(LinearDesign.Colors.secondarySurface.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous)
                    .stroke(LinearDesign.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing)
        .opacity(isAnalyzing ? 0.6 : 1)
    }

    private var selectedImageActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LinearDesign.Spacing.small) {
                if isCameraAvailable {
                    compactCaptureActionButton(title: "appointment.capture.retake.photo", icon: "camera") {
                        showingCamera = true
                    }
                }

                compactCaptureActionButton(title: "appointment.capture.choose.different.photo", icon: "photo.on.rectangle") {
                    showingPhotoPicker = true
                }
            }

            VStack(spacing: LinearDesign.Spacing.small) {
                if isCameraAvailable {
                    compactCaptureActionButton(title: "appointment.capture.retake.photo", icon: "camera") {
                        showingCamera = true
                    }
                }

                compactCaptureActionButton(title: "appointment.capture.choose.different.photo", icon: "photo.on.rectangle") {
                    showingPhotoPicker = true
                }
            }
        }
    }

    private func compactCaptureActionButton(title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } icon: {
                Image(systemName: icon)
            }
            .font(LinearDesign.Typography.smallMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .padding(.horizontal, LinearDesign.Spacing.small)
            .background(Color.white.opacity(0.04))
            .foregroundStyle(LinearDesign.Colors.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.medium)
                    .stroke(LinearDesign.Colors.borderStandard, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing)
        .opacity(isAnalyzing ? 0.6 : 1)
    }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private func presentCaptureSourceDialog() {
        guard !isAnalyzing else { return }
        showingCaptureSourceDialog = true
    }

    private var manualHero: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                Text("appointment.confirm.datetime")
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)

                DatePicker("", selection: $manualScheduledAt)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(LinearDesign.Colors.accentViolet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                Text("appointment.confirm.what.field")
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)

                TextField("", text: $manualWhat)
                    .linearInputField()
                    .textInputAutocapitalization(.sentences)
            }

            VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                Text("appointment.confirm.location.field")
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)

                TextField("", text: $manualLocation)
                    .linearInputField()
                    .textInputAutocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                Text("appointment.confirm.withwhom.field")
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)

                TextField("", text: $manualWithWhom)
                    .linearInputField()
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var primaryActionTitle: LocalizedStringKey {
        if captureMode == .scan {
            return isAnalyzing ? "appointment.analyzing" : "appointment.analyze.button"
        }

        return "appointment.capture.enter.manually"
    }

    private func primaryAction() {
        if captureMode == .scan {
            analyze()
        } else {
            createManualDraft()
        }
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

    private func createManualDraft() {
        var draft = store.createManualDraft()
        draft.scheduledAt = manualScheduledAt
        draft.what = trimmedManualWhat
        draft.location = trimmedManualLocation
        draft.withWhom = trimmedManualWithWhom
        pendingDraft = draft
    }

    private var isPrimaryActionDisabled: Bool {
        if captureMode == .manual {
            return isAnalyzing || trimmedManualWhat.isEmpty
        }

        return selectedImage == nil || isAnalyzing || !store.canUploadMoreThisMonth
    }

    private var trimmedManualWhat: String {
        manualWhat.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedManualLocation: String {
        manualLocation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedManualWithWhom: String {
        manualWithWhom.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
