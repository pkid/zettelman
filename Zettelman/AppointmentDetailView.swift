import SwiftUI

struct AppointmentDetailView: View {
    let appointment: Appointment

    @State private var temporaryURL: URL?
    @State private var temporaryURLError: String?

    private let service = ZettelS3Service()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                S3ZettelImageView(key: appointment.uploadedZettel.key, cornerRadius: 28)
                    .frame(height: 320)

                detailsCard
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.90), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Appointment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTemporaryURL()
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(title: "Date and time", value: formattedDate(appointment.scheduledAt))
            detailRow(title: "What", value: appointment.what)
            detailRow(title: "Where", value: appointment.location)
            detailRow(title: "Uploaded zettel", value: appointment.uploadedZettel.key, mono: true)

            if let temporaryURL {
                Link("Open original upload", destination: temporaryURL)
                    .fontWeight(.semibold)
            } else if let temporaryURLError {
                Text(temporaryURLError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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

    @MainActor
    private func loadTemporaryURL() async {
        do {
            temporaryURL = try await service.temporaryURL(for: appointment.uploadedZettel.key)
        } catch {
            temporaryURLError = "Temporary link unavailable."
        }
    }
}
