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

    private let detailImageHeight: CGFloat = 320

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
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity)
                .frame(height: detailImageHeight)
                .padding(.top, 4)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)
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
        .navigationTitle("Appointment")
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
        .confirmationDialog("Delete this appointment?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Appointment", role: .destructive) {
                deleteAppointment()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes it from your appointments folder in S3.")
        }
        .alert("Delete Appointment", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? "Couldn't delete this appointment.")
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(title: "Date and time", value: formattedDate(appointment.scheduledAt))
            detailRow(title: "What", value: appointment.what)
            if let withWhom = appointment.withWhom, !withWhom.isEmpty {
                detailRow(title: "With whom", value: withWhom)
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
            Text("Where")
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
