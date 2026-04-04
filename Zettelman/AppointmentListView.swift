import SwiftUI
import UIKit

struct AppointmentListView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authManager: CognitoAuthManager
    @StateObject private var store = AppointmentStore()
    @State private var showingComposer = false
    @State private var showingAccountPopup = false
    @State private var confirmationDismissTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LinearDesign.Colors.panelDark
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
                        if let errorMessage = store.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(LinearDesign.Typography.small)
                                .foregroundStyle(LinearDesign.Colors.Semantic.destructive)
                        }

                        if store.isLoading && store.appointments.isEmpty {
                            loadingState
                        } else if store.appointments.isEmpty {
                            emptyState
                        } else {
                            appointmentCards
                        }
                    }
                    .padding(LinearDesign.Spacing.medium)
                }

                addButton
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: store.saveConfirmation)
            .navigationTitle("appointments.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingAccountPopup = true }) {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundStyle(LinearDesign.Colors.secondaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("appointments.sign.out") {
                        Task {
                            store.reset()
                            await authManager.signOut()
                        }
                    }
                    .font(LinearDesign.Typography.small)
                    .foregroundStyle(LinearDesign.Colors.secondaryText)
                }
            }
        }
        .alert("appointments.signed.in.account", isPresented: $showingAccountPopup) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(authManager.userEmail ?? String(localized: "appointments.unknown.user"))
        }
        .sheet(isPresented: $showingComposer) {
            AddAppointmentView(store: store)
        }
        .overlay(alignment: .center) {
            if store.saveConfirmation != nil {
                saveConfirmationBanner
                    .padding(.horizontal, LinearDesign.Spacing.medium)
                    .frame(maxWidth: 440)
            }
        }
        .task {
            await store.loadAppointments()
        }
        .refreshable {
            await store.loadAppointments(forceRefresh: true)
        }
        .onChange(of: store.saveConfirmation) { confirmation in
            scheduleSaveConfirmationDismiss(for: confirmation)
        }
        .onDisappear {
            confirmationDismissTask?.cancel()
            confirmationDismissTask = nil
        }
    }

    private var loadingState: some View {
        VStack(spacing: LinearDesign.Spacing.medium) {
            ProgressView()
                .tint(LinearDesign.Colors.accentViolet)
            Text("appointments.loading")
                .font(LinearDesign.Typography.small)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LinearDesign.Spacing.xxLarge)
    }

    private var emptyState: some View {
        VStack(spacing: LinearDesign.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(LinearDesign.Colors.level3Surface)
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(LinearDesign.Colors.accentViolet)
            }

            Text("appointments.empty.title")
                .font(LinearDesign.Typography.heading3)
                .foregroundStyle(LinearDesign.Colors.primaryText)

            Text("appointments.empty.subtitle")
                .font(LinearDesign.Typography.body)
                .foregroundStyle(LinearDesign.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(LinearDesign.Spacing.xLarge)
        .linearCard()
    }

    private var appointmentCards: some View {
        LazyVStack(spacing: LinearDesign.Spacing.small) {
            ForEach(store.appointments) { appointment in
                NavigationLink {
                    AppointmentDetailView(appointment: appointment, onDelete: {
                        try await store.deleteAppointment(appointment)
                    })
                } label: {
                    AppointmentCardRow(appointment: appointment)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addButton: some View {
        Button(action: { showingComposer = true }) {
            Label("appointments.add.button", systemImage: "plus")
                .font(LinearDesign.Typography.bodyMedium)
                .padding(.horizontal, LinearDesign.Spacing.medium)
                .frame(height: 48)
                .background(LinearDesign.Colors.accentViolet)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: LinearDesign.Colors.accentViolet.opacity(0.3), radius: 12, y: 8)
        }
        .padding(LinearDesign.Spacing.medium)
    }

    @ViewBuilder
    private var saveConfirmationBanner: some View {
        if let confirmation = store.saveConfirmation {
            VStack(alignment: .leading, spacing: LinearDesign.Spacing.small) {
                HStack(alignment: .top, spacing: LinearDesign.Spacing.small) {
                    Image(systemName: confirmation.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(LinearDesign.Typography.body)
                        .foregroundStyle(confirmation.isSuccess ? LinearDesign.Colors.successGreen : LinearDesign.Colors.Semantic.destructive)

                    Text(confirmation.message)
                        .font(LinearDesign.Typography.small)
                        .foregroundStyle(LinearDesign.Colors.primaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: LinearDesign.Spacing.small) {
                    if confirmation.requiresCalendarAccessPrompt {
                        Button("common.open.settings") {
                            openCalendarSettings()
                        }
                        .font(LinearDesign.Typography.labelMedium)
                        .padding(.horizontal, LinearDesign.Spacing.small)
                        .padding(.vertical, LinearDesign.Spacing.xxSmall)
                        .background(LinearDesign.Colors.level3Surface, in: Capsule())
                        .foregroundStyle(LinearDesign.Colors.primaryText)
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    Button("common.dismiss") {
                        withAnimation {
                            store.clearSaveConfirmation()
                        }
                    }
                    .font(LinearDesign.Typography.labelMedium)
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
                    .buttonStyle(.plain)
                }
            }
            .padding(LinearDesign.Spacing.medium)
            .background(LinearDesign.Colors.level3Surface, in: RoundedRectangle(cornerRadius: LinearDesign.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: LinearDesign.Radius.large)
                    .stroke(confirmation.isSuccess ? LinearDesign.Colors.successGreen.opacity(0.3) : LinearDesign.Colors.Semantic.destructive.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private func scheduleSaveConfirmationDismiss(for confirmation: SaveConfirmation?) {
        confirmationDismissTask?.cancel()
        confirmationDismissTask = nil

        guard let confirmation else { return }
        guard confirmation.isSuccess else { return }

        confirmationDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation {
                    store.clearSaveConfirmation()
                }
            }
        }
    }

    private func openCalendarSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

private struct AppointmentCardRow: View {
    let appointment: Appointment
    private let thumbnailSide: CGFloat = 86

    var body: some View {
        HStack(alignment: .top, spacing: LinearDesign.Spacing.medium) {
            S3ZettelImageView(
                key: appointment.uploadedZettel.key,
                cornerRadius: LinearDesign.Radius.large,
                contentMode: .fit
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(width: thumbnailSide, height: thumbnailSide)
            .background(LinearDesign.Colors.level3Surface, in: RoundedRectangle(cornerRadius: LinearDesign.Radius.large))
            .clipped()

            VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
                Text(appointment.what)
                    .font(LinearDesign.Typography.bodyMedium)
                    .foregroundStyle(LinearDesign.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: LinearDesign.Spacing.xxSmall) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                        .font(LinearDesign.Typography.caption)
                }
                .foregroundStyle(LinearDesign.Colors.secondaryText)

                HStack(spacing: LinearDesign.Spacing.xxSmall) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                    Text(appointment.location)
                        .font(LinearDesign.Typography.caption)
                }
                .foregroundStyle(LinearDesign.Colors.secondaryText)
                .lineLimit(2)

                if let withWhom = appointment.withWhom, !withWhom.isEmpty {
                    HStack(spacing: LinearDesign.Spacing.xxSmall) {
                        Image(systemName: "person.text.rectangle")
                            .font(.caption)
                        Text(withWhom)
                            .font(LinearDesign.Typography.caption)
                    }
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(LinearDesign.Colors.quaternaryText)
        }
        .padding(LinearDesign.Spacing.medium)
        .background(LinearDesign.Colors.level3Surface, in: RoundedRectangle(cornerRadius: LinearDesign.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: LinearDesign.Radius.large)
                .stroke(LinearDesign.Colors.borderSubtle, lineWidth: 1)
        )
    }
}
