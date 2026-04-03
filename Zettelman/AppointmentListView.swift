import SwiftUI

struct AppointmentListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: CognitoAuthManager
    @StateObject private var store = AppointmentStore()
    @State private var showingComposer = false
    @State private var showingAccountPopup = false

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
            .navigationTitle("Appointments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingAccountPopup = true }) {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Appointments")
                        .font(.headline)
                }

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
        .alert("Signed In Account", isPresented: $showingAccountPopup) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authManager.userEmail ?? "Unknown user")
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
                .foregroundStyle(emptyIconColor)

            Text("No appointments saved yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(emptyTitleColor)

            Text("Add your first zettel, let Lambda extract the appointment, and confirm the details.")
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

                            if let withWhom = appointment.withWhom, !withWhom.isEmpty {
                                Label(withWhom, systemImage: "person.text.rectangle")
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }

                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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

}
