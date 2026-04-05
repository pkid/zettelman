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

        do {
            let uploadTask = Amplify.Storage.uploadData(
                path: .fromString(key),
                data: imageData,
                options: .init()
            )

            _ = try await uploadTask.value
            return UploadedZettel(key: key, filename: filename, uploadedAt: Date())
        } catch {
            throw normalizedStorageError(error, operation: String(localized: "storage.operation.upload.zettel.image"))
        }
    }

    func downloadZettelData(for key: String) async throws -> Data {
        try await downloadData(for: key, operation: String(localized: "storage.operation.download.zettel"))
    }

    func downloadData(for key: String, operation: String) async throws -> Data {
        do {
            let task = Amplify.Storage.downloadData(path: .fromString(key), options: .init())
            return try await task.value
        } catch {
            throw normalizedStorageError(error, operation: operation)
        }
    }

    func temporaryURL(for key: String) async throws -> URL {
        do {
            return try await Amplify.Storage.getURL(path: .fromString(key), options: .init())
        } catch {
            throw normalizedStorageError(error, operation: String(localized: "storage.operation.get.zettel.link"))
        }
    }

    func loadAppointmentsManifest() async throws -> [Appointment] {
        let context = try await currentUserContext()
        let manifestKey = appointmentsManifestKey(for: context)

        do {
            let downloadTask = Amplify.Storage.downloadData(path: .fromString(manifestKey), options: .init())
            let data = try await downloadTask.value
            return try decoder.decode([Appointment].self, from: data)
        } catch let storageError as StorageError {
            if case .keyNotFound = storageError {
                return []
            }

            throw normalizedStorageError(storageError, operation: String(localized: "storage.operation.load.appointments"))
        } catch {
            throw normalizedStorageError(error, operation: String(localized: "storage.operation.load.appointments"))
        }
    }

    func saveAppointmentsManifest(_ appointments: [Appointment]) async throws {
        let context = try await currentUserContext()
        let manifestKey = appointmentsManifestKey(for: context)
        let data = try encoder.encode(appointments)

        do {
            let uploadTask = Amplify.Storage.uploadData(
                path: .fromString(manifestKey),
                data: data,
                options: .init()
            )

            _ = try await uploadTask.value
        } catch {
            throw normalizedStorageError(error, operation: String(localized: "storage.operation.save.appointments"))
        }
    }

    func currentUserContext() async throws -> UserStorageContext {
        var email = ""
        var incognitoEnabled = false
        var debugFlagEnabled = false

        let attributes = try await Amplify.Auth.fetchUserAttributes()
        for attribute in attributes {
            if attribute.key == .email {
                email = attribute.value
            }

            let key = attribute.key.rawValue.lowercased()
            if key == "custom:incognito" {
                incognitoEnabled = parseBooleanAttribute(attribute.value)
            } else if key == "custom:debug"
                || key == "custom:debug_flag"
                || key == "custom:debugmode"
                || key == "custom:debug_mode"
                || key == "custom:is_debug" {
                debugFlagEnabled = parseBooleanAttribute(attribute.value)
            }
        }

        if email.isEmpty {
            let currentUser = try await Amplify.Auth.getCurrentUser()
            email = currentUser.username
        }

        return UserStorageContext(
            email: email,
            emailFolder: sanitize(email, lowercase: false),
            bypassUploadQuota: incognitoEnabled || debugFlagEnabled
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

    private func parseBooleanAttribute(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }

    private func normalizedStorageError(_ error: Error, operation: String) -> Error {
        guard let storageError = error as? StorageError else {
            return NSError(
                domain: "Zettelman.Storage",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.generic"), operation, error.localizedDescription)]
            )
        }

        switch storageError {
        case .accessDenied(let description, _, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.access.denied"), operation, description)]
            )
        case .authError(let description, _, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.auth"), operation, description)]
            )
        case .configuration(let description, _, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.configuration"), operation, description)]
            )
        case .httpStatusError(let statusCode, _, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.http.status"), statusCode, operation)]
            )
        case .keyNotFound:
            return NSError(
                domain: "Zettelman.Storage",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.key.not.found"), operation)]
            )
        case .localFileNotFound(let description, _, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.local.file.missing"), operation, description)]
            )
        case .service(let description, let recoverySuggestion, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.service"), operation, bestStorageMessage(description: description, fallback: recoverySuggestion))]
            )
        case .unknown(let description, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.unexpected"), operation, description)]
            )
        case .validation(_, let description, let recoverySuggestion, _):
            return NSError(
                domain: "Zettelman.Storage",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "storage.error.invalid.request"), operation, bestStorageMessage(description: description, fallback: recoverySuggestion))]
            )
        }
    }

    private func bestStorageMessage(description: String, fallback: String) -> String {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty, trimmedDescription != "unknown" {
            return trimmedDescription
        }

        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty, trimmedFallback != "unknown" {
            return trimmedFallback
        }

        return String(localized: "storage.error.no.details")
    }
}
