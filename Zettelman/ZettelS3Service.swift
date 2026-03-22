import Amplify
import Foundation
import UIKit

final class ZettelS3Service {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func uploadZettelImage(_ image: UIImage) async throws -> UploadedZettel {
        guard let imageData = image.jpegData(compressionQuality: 0.86) else {
            throw ZettelmanError.invalidImage
        }

        let context = try await currentUserContext()
        let filename = "\(timestampString())-\(UUID().uuidString.prefix(8)).jpg"
        let key = "received/\(context.emailFolder)/zettels/\(filename)"

        let uploadTask = Amplify.Storage.uploadData(
            path: .fromString(key),
            data: imageData,
            options: .init()
        )

        _ = try await uploadTask.value
        return UploadedZettel(key: key, filename: filename, uploadedAt: Date())
    }

    func downloadZettelData(for key: String) async throws -> Data {
        let task = Amplify.Storage.downloadData(path: .fromString(key), options: .init())
        return try await task.value
    }

    func temporaryURL(for key: String) async throws -> URL {
        try await Amplify.Storage.getURL(path: .fromString(key), options: .init())
    }

    func loadAppointmentsManifest() async throws -> [Appointment] {
        let context = try await currentUserContext()
        let directoryKey = appointmentsDirectoryKey(for: context)
        let manifestKey = appointmentsManifestKey(for: context)

        let listResult = try await Amplify.Storage.list(path: .fromString(directoryKey), options: .init())
        guard listResult.items.contains(where: { $0.path == manifestKey }) else {
            return []
        }

        let downloadTask = Amplify.Storage.downloadData(path: .fromString(manifestKey), options: .init())
        let data = try await downloadTask.value
        return try decoder.decode([Appointment].self, from: data)
    }

    func saveAppointmentsManifest(_ appointments: [Appointment]) async throws {
        let context = try await currentUserContext()
        let manifestKey = appointmentsManifestKey(for: context)
        let data = try encoder.encode(appointments)

        let uploadTask = Amplify.Storage.uploadData(
            path: .fromString(manifestKey),
            data: data,
            options: .init()
        )

        _ = try await uploadTask.value
    }

    func currentUserContext() async throws -> UserStorageContext {
        var email = ""

        let attributes = try await Amplify.Auth.fetchUserAttributes()
        for attribute in attributes {
            if attribute.key == .email {
                email = attribute.value
            }
        }

        if email.isEmpty {
            let currentUser = try await Amplify.Auth.getCurrentUser()
            email = currentUser.username
        }

        return UserStorageContext(
            email: email,
            emailFolder: sanitize(email, lowercase: false)
        )
    }

    private func appointmentsDirectoryKey(for context: UserStorageContext) -> String {
        "appointments/\(context.emailFolder)/"
    }

    private func appointmentsManifestKey(for context: UserStorageContext) -> String {
        appointmentsDirectoryKey(for: context) + "appointments.json"
    }

    private func sanitize(_ value: String, lowercase: Bool) -> String {
        let base = lowercase ? value.lowercased() : value

        return base
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
