import SwiftUI

struct AppointmentDetailView: View {
    let appointment: Appointment
    let onDelete: (() async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
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
            VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
                detailsCard

                imageSection
            }
            .padding(LinearDesign.Spacing.medium)
        }
        .background(
            LinearDesign.Colors.panelDark
                .ignoresSafeArea()
        )
        .navigationTitle("appointment.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LinearDesign.Colors.level3Surface.opacity(0.8), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(LinearDesign.Typography.bodyMedium)
                            .foregroundStyle(LinearDesign.Colors.Semantic.destructive)
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

                if let key = uploadedZettelKey {
                    S3ZettelImageView(
                        key: key,
                        cornerRadius: 0,
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, LinearDesign.Spacing.small)
                    .padding(.vertical, LinearDesign.Spacing.medium)
                }

                Button {
                    showingImagePreview = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, LinearDesign.Spacing.medium)
                .padding(.trailing, LinearDesign.Spacing.medium)
            }
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if let key = uploadedZettelKey {
            S3ZettelImageView(
                key: key,
                cornerRadius: LinearDesign.Radius.xLarge,
                contentMode: .fit
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 360)
            .padding(.top, LinearDesign.Spacing.xxSmall)
            .clipShape(RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                showingImagePreview = true
            }
        } else {
            RoundedRectangle(cornerRadius: LinearDesign.Radius.xLarge, style: .continuous)
                .fill(LinearDesign.Colors.level3Surface)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 220)
                .overlay {
                    VStack(spacing: LinearDesign.Spacing.small) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 36, weight: .medium))
                        Text("appointment.detail.no.source.image")
                            .font(LinearDesign.Typography.caption)
                    }
                    .foregroundStyle(LinearDesign.Colors.tertiaryText)
                }
                .padding(.top, LinearDesign.Spacing.xxSmall)
        }
    }

    private var uploadedZettelKey: String? {
        appointment.uploadedZettel?.key
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.medium) {
            detailRow(title: String(localized: "appointment.detail.datetime"), value: formattedDate(appointment.scheduledAt))
            detailRow(title: String(localized: "appointment.detail.what"), value: appointment.what)
            if let withWhom = appointment.withWhom, !withWhom.isEmpty {
                detailRow(title: String(localized: "appointment.detail.withwhom"), value: withWhom)
            }
            if hasLocation {
                locationRow
            }
        }
        .padding(LinearDesign.Spacing.large)
        .linearCard()
    }

    private func detailRow(title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
            Text(title)
                .font(LinearDesign.Typography.labelMedium)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)

            Text(value)
                .font(mono ? LinearDesign.Typography.caption : LinearDesign.Typography.body)
                .foregroundStyle(LinearDesign.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var hasLocation: Bool {
        !appointment.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var locationRow: some View {
        VStack(alignment: .leading, spacing: LinearDesign.Spacing.xxSmall) {
            Text("appointment.detail.location")
                .font(LinearDesign.Typography.labelMedium)
                .foregroundStyle(LinearDesign.Colors.tertiaryText)

            (
                Text(appointment.location)
                + Text(" ")
                + Text(Image(systemName: "arrow.up.right.square"))
                    .font(LinearDesign.Typography.label)
            )
            .font(LinearDesign.Typography.body)
            .foregroundStyle(LinearDesign.Colors.accentViolet)
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
}
