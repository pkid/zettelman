import Foundation
import UIKit
import UserNotifications

@MainActor
final class AppointmentStore: ObservableObject {
    @Published private(set) var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let s3Service: ZettelS3Service
    private let analysisService: ZettelAnalysisService
    private let reminderService: AppointmentReminderService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var hasLoaded = false

    init(
        s3Service: ZettelS3Service = ZettelS3Service(),
        analysisService: ZettelAnalysisService = ZettelAnalysisService(),
        reminderService: AppointmentReminderService = AppointmentReminderService()
    ) {
        self.s3Service = s3Service
        self.analysisService = analysisService
        self.reminderService = reminderService

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadAppointments(forceRefresh: Bool = false) async {
        if hasLoaded && !forceRefresh { return }

        isLoading = true
        errorMessage = nil

        if let cachedAppointments = loadFromDisk() {
            appointments = sort(cachedAppointments)
        }

        do {
            let remoteAppointments = try await s3Service.loadAppointmentsManifest()
            appointments = sort(remoteAppointments)
            persistLocally()
            hasLoaded = true
        } catch {
            if appointments.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        await reminderService.syncReminders(with: appointments)
        isLoading = false
    }

    func createDraft(from image: UIImage) async throws -> AppointmentDraft {
        let previewData = image.jpegData(compressionQuality: 0.72)
        let uploadedZettel = try await s3Service.uploadZettelImage(image)
        let analysis = try await analysisService.analyze(uploadedZettel: uploadedZettel, s3Service: s3Service)

        return AppointmentDraft(
            scheduledAt: analysis.detectedDateTime ?? Date(),
            reminderEnabled: true,
            what: analysis.what,
            location: analysis.location.isEmpty ? "Unknown location" : analysis.location,
            withWhom: analysis.withWhom,
            uploadedZettel: uploadedZettel,
            previewImageData: previewData,
            rawDateTime: analysis.rawDateTime
        )
    }

    func saveDraft(_ draft: AppointmentDraft) async throws {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let appointment = Appointment(
            scheduledAt: draft.scheduledAt,
            reminderEnabled: draft.reminderEnabled,
            what: draft.what.trimmingCharacters(in: .whitespacesAndNewlines).normalizedWhat(),
            location: draft.location.trimmingCharacters(in: .whitespacesAndNewlines),
            withWhom: draft.withWhom.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            uploadedZettel: draft.uploadedZettel
        )

        appointments.insert(appointment, at: 0)
        appointments = sort(appointments)
        persistLocally()
        await reminderService.scheduleReminder(for: appointment, requestAuthorizationIfNeeded: true)

        do {
            try await s3Service.saveAppointmentsManifest(appointments)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func deleteAppointment(_ appointment: Appointment) async throws {
        errorMessage = nil

        guard let index = appointments.firstIndex(where: { $0.id == appointment.id }) else {
            return
        }

        let removedAppointment = appointments.remove(at: index)
        persistLocally()
        await reminderService.syncReminders(with: appointments)

        do {
            try await s3Service.saveAppointmentsManifest(appointments)
        } catch {
            appointments.insert(removedAppointment, at: min(index, appointments.count))
            appointments = sort(appointments)
            persistLocally()
            await reminderService.syncReminders(with: appointments)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func reset() {
        appointments = []
        errorMessage = nil
        isLoading = false
        isSaving = false
        hasLoaded = false

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.removeItem(at: cacheURL)
        }

        Task {
            await reminderService.clearAllReminders()
        }
    }

    private func sort(_ values: [Appointment]) -> [Appointment] {
        values.sorted { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.scheduledAt < rhs.scheduledAt
        }
    }

    private func persistLocally() {
        do {
            let data = try encoder.encode(appointments)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFromDisk() -> [Appointment]? {
        guard let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }

        return try? decoder.decode([Appointment].self, from: data)
    }

    private var cacheURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return documentsURL.appendingPathComponent("appointments_cache.json")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class AppointmentReminderService {
    private let notificationCenter: UNUserNotificationCenter
    private let reminderLeadTime: TimeInterval = 30 * 60
    private let identifierPrefix = "appointment-reminder-"

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func syncReminders(with appointments: [Appointment]) async {
        guard await hasNotificationPermission() else { return }

        let pendingRequests = await pendingNotificationRequests()
        let staleIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        if !staleIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        }

        for appointment in appointments {
            try? await scheduleReminderRequest(for: appointment)
        }
    }

    func scheduleReminder(for appointment: Appointment, requestAuthorizationIfNeeded: Bool) async {
        let hasPermission = await ensureNotificationPermission(requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
        guard hasPermission else { return }

        try? await scheduleReminderRequest(for: appointment)
    }

    func clearAllReminders() async {
        let pendingRequests = await pendingNotificationRequests()
        let reminderIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        if !reminderIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
        }
    }

    private func scheduleReminderRequest(for appointment: Appointment) async throws {
        let reminderDate = appointment.scheduledAt.addingTimeInterval(-reminderLeadTime)
        let identifier = reminderIdentifier(for: appointment.id)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard appointment.reminderEnabled else { return }
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Appointment in 30 minutes"
        content.body = reminderBody(for: appointment)
        content.sound = .default

        let triggerDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await add(request)
    }

    private func reminderBody(for appointment: Appointment) -> String {
        let withWhomPart: String
        if let withWhom = appointment.withWhom, !withWhom.isEmpty {
            withWhomPart = " with \(withWhom)"
        } else {
            withWhomPart = ""
        }

        return "\(appointment.what) at \(appointment.location)\(withWhomPart)."
    }

    private func ensureNotificationPermission(requestAuthorizationIfNeeded: Bool) async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard requestAuthorizationIfNeeded else { return false }
            return await requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func hasNotificationPermission() async -> Bool {
        await ensureNotificationPermission(requestAuthorizationIfNeeded: false)
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationCenter.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func reminderIdentifier(for appointmentID: UUID) -> String {
        identifierPrefix + appointmentID.uuidString
    }
}
