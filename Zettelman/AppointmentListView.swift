import SwiftUI

struct AppointmentListView: View {
    @EnvironmentObject private var authManager: CognitoAuthManager
    @StateObject private var store = AppointmentStore()
    @State private var showingComposer = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [Color(red: 0.97, green: 0.95, blue: 0.88), Color(red: 0.92, green: 0.96, blue: 0.93)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

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
            .navigationTitle("Appointments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task {
                            store.reset()
                            await authManager.signOut()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingComposer) {
            AddAppointmentView(store: store)
        }
        .task {
            await store.loadAppointments()
        }
        .refreshable {
            await store.loadAppointments(forceRefresh: true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload, confirm, and keep every appointment zettel in one place.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.19, green: 0.18, blue: 0.13))

            HStack(spacing: 12) {
                badge(title: authManager.userEmail ?? "Unknown user", systemImage: "person.crop.circle")

                if let company = authManager.userCompany, !company.isEmpty {
                    badge(title: company, systemImage: "building.2")
                }
            }

            if let errorMessage = store.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading appointments from S3...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.45, green: 0.34, blue: 0.22))

            Text("No appointments saved yet")
                .font(.title3.weight(.semibold))

            Text("Add your first zettel, let Lambda extract the appointment, and confirm the details.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var appointmentCards: some View {
        LazyVStack(spacing: 14) {
            ForEach(store.appointments) { appointment in
                NavigationLink {
                    AppointmentDetailView(appointment: appointment)
                } label: {
                    HStack(spacing: 14) {
                        S3ZettelImageView(key: appointment.uploadedZettel.key, cornerRadius: 22)
                            .frame(width: 110, height: 110)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(appointment.what)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Label(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                .font(.subheadline)

                            Label(appointment.location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .lineLimit(2)

                            Text(appointment.uploadedZettel.filename)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addButton: some View {
        Button(action: { showingComposer = true }) {
            Label("Add Zettel", systemImage: "plus")
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

    private func badge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.75), in: Capsule())
    }
}
