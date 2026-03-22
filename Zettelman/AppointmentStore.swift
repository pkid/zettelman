import Foundation
import UIKit

@MainActor
final class AppointmentStore: ObservableObject {
    @Published private(set) var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let s3Service: ZettelS3Service
    private let analysisService: ZettelAnalysisService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var hasLoaded = false

    init(
        s3Service: ZettelS3Service = ZettelS3Service(),
        analysisService: ZettelAnalysisService = ZettelAnalysisService()
    ) {
        self.s3Service = s3Service
        self.analysisService = analysisService

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

        isLoading = false
    }

    func createDraft(from image: UIImage) async throws -> AppointmentDraft {
        let previewData = image.jpegData(compressionQuality: 0.72)
        let uploadedZettel = try await s3Service.uploadZettelImage(image)
        let analysis = try await analysisService.analyze(uploadedZettel: uploadedZettel, s3Service: s3Service)

        return AppointmentDraft(
            scheduledAt: analysis.detectedDateTime ?? Date(),
            what: analysis.what,
            location: analysis.location.isEmpty ? "Unknown location" : analysis.location,
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
            what: draft.what.trimmingCharacters(in: .whitespacesAndNewlines).normalizedWhat(),
            location: draft.location.trimmingCharacters(in: .whitespacesAndNewlines),
            uploadedZettel: draft.uploadedZettel
        )

        appointments.insert(appointment, at: 0)
        appointments = sort(appointments)
        persistLocally()

        do {
            try await s3Service.saveAppointmentsManifest(appointments)
        } catch {
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
