import SwiftUI

struct AppointmentDetailView: View {
    let appointment: Appointment
    let onDelete: (() async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteErrorMessage: String?
    @State private var showingDeleteError = false
    @State private var showingImagePreview = false

    init(appointment: Appointment, onDelete: (() async throws -> Void)? = nil) {
        self.appointment = appointment
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailsCard

                S3ZettelImageView(
                    key: appointment.uploadedZettel.key,
                    cornerRadius: 28,
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 360)
                .padding(.top, 4)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    showingImagePreview = true
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("appointment.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .confirmationDialog("appointment.detail.delete.confirm.title", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("appointment.detail.delete.button", role: .destructive) {
                deleteAppointment()
            }
            Button("common.cancel", role: .cancel) { }
        } message: {
            Text("appointment.detail.delete.message")
        }
        .alert("appointment.detail.delete.alert.title", isPresented: $showingDeleteError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? String(localized: "appointment.detail.delete.error"))
        }
        .fullScreenCover(isPresented: $showingImagePreview) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                S3ZettelImageView(
                    key: appointment.uploadedZettel.key,
                    cornerRadius: 0,
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 24)

                Button {
                    showingImagePreview = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(title: String(localized: "appointment.detail.datetime"), value: formattedDate(appointment.scheduledAt))
            detailRow(title: String(localized: "appointment.detail.what"), value: appointment.what)
            if let withWhom = appointment.withWhom, !withWhom.isEmpty {
                detailRow(title: String(localized: "appointment.detail.withwhom"), value: withWhom)
            }
            locationRow
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func detailRow(title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(mono ? .system(.footnote, design: .monospaced) : .body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("appointment.detail.location")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            (
                Text(appointment.location)
                + Text(" ")
                + Text(Image(systemName: "arrow.up.right.square"))
                    .font(.caption2.weight(.semibold))
            )
            .font(.body)
            .foregroundStyle(.blue)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                openLocationInGoogleMaps()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openLocationInGoogleMaps() {
        guard let encodedLocation = appointment.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let webURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)") else {
            return
        }

        if let appURL = URL(string: "comgooglemaps://?q=\(encodedLocation)") {
            openURL(appURL) { accepted in
                if !accepted {
                    openURL(webURL)
                }
            }
        } else {
            openURL(webURL)
        }
    }

    private func deleteAppointment() {
        guard let onDelete else { return }

        isDeleting = true
        Task {
            do {
                try await onDelete()
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteErrorMessage = error.localizedDescription
                    showingDeleteError = true
                }
            }
        }
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.09, green: 0.10, blue: 0.10), Color(red: 0.12, green: 0.16, blue: 0.15)]
        }

        return [Color(red: 0.97, green: 0.95, blue: 0.90), Color.white]
    }

}
