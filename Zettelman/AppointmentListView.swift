import SwiftUI
import UIKit

struct AppointmentListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authManager: CognitoAuthManager
    @StateObject private var store = AppointmentStore()
    @State private var showingComposer = false
    @State private var showingAccountPopup = false
    @State private var confirmationDismissTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let errorMessage = store.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if store.isLoading && store.appointments.isEmpty {
                            loadingState
                        } else if store.appointments.isEmpty {
                            emptyState
                        } else {
                            appointmentCards
                        }
                    }
                    .padding(20)
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
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("appointments.title")
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("appointments.sign.out") {
                        Task {
                            store.reset()
                            await authManager.signOut()
                        }
                    }
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
                    .padding(.horizontal, 20)
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
        VStack(spacing: 16) {
            ProgressView()
            Text("appointments.loading")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(emptyIconColor)

            Text("appointments.empty.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(emptyTitleColor)

            Text("appointments.empty.subtitle")
                .font(.subheadline)
                .foregroundStyle(emptySubtitleColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(emptyCardColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var appointmentCards: some View {
        LazyVStack(spacing: 14) {
            ForEach(store.appointments) { appointment in
                NavigationLink {
                    AppointmentDetailView(appointment: appointment, onDelete: {
                        try await store.deleteAppointment(appointment)
                    })
                } label: {
                    AppointmentCardRow(appointment: appointment)
                    .padding(10)
                    .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addButton: some View {
        Button(action: { showingComposer = true }) {
            Label("appointments.add.button", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(Color(red: 0.28, green: 0.45, blue: 0.34))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
        }
        .padding(20)
    }

    @ViewBuilder
    private var saveConfirmationBanner: some View {
        if let confirmation = store.saveConfirmation {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: confirmation.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(confirmation.isSuccess ? Color.green : Color.orange)

                    Text(confirmation.message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    if confirmation.requiresCalendarAccessPrompt {
                        Button("common.open.settings") {
                            openCalendarSettings()
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                        .foregroundStyle(Color(uiColor: .label))
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    Button("common.dismiss") {
                        withAnimation {
                            store.clearSaveConfirmation()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(confirmationBorderColor(isSuccess: confirmation.isSuccess), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.14), radius: 8, y: 4)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.09, green: 0.10, blue: 0.10), Color(red: 0.12, green: 0.16, blue: 0.15)]
        }

        return [Color(red: 0.97, green: 0.95, blue: 0.88), Color(red: 0.92, green: 0.96, blue: 0.93)]
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color.white.opacity(0.88)
    }

    private var emptyCardColor: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color.white.opacity(0.7)
    }

    private var emptyTitleColor: Color {
        Color(uiColor: .label)
    }

    private var emptySubtitleColor: Color {
        Color(uiColor: .secondaryLabel)
    }

    private var emptyIconColor: Color {
        colorScheme == .dark ? Color(red: 0.83, green: 0.66, blue: 0.42) : Color(red: 0.45, green: 0.34, blue: 0.22)
    }

    private func confirmationBackgroundColor(isSuccess: Bool) -> Color {
        let baseColor = isSuccess ? Color.green : Color.orange
        return baseColor.opacity(colorScheme == .dark ? 0.28 : 0.2)
    }

    private func confirmationBorderColor(isSuccess: Bool) -> Color {
        let baseColor = isSuccess ? Color.green : Color.orange
        return baseColor.opacity(colorScheme == .dark ? 0.75 : 0.45)
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
    private let thumbnailSide: CGFloat = 64

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            S3ZettelImageView(
                key: appointment.uploadedZettel.key,
                cornerRadius: 16,
                contentMode: .fit
            )
                .aspectRatio(1, contentMode: .fit)
                .frame(width: thumbnailSide, height: thumbnailSide)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(appointment.what)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Label(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.subheadline)

                Label(appointment.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .lineLimit(2)

                if let withWhom = appointment.withWhom, !withWhom.isEmpty {
                    Label(withWhom, systemImage: "person.text.rectangle")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
