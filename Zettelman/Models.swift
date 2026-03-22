import Foundation

struct UploadedZettel: Codable, Hashable {
    let key: String
    let filename: String
    let uploadedAt: Date
}

struct Appointment: Identifiable, Codable, Hashable {
    let id: UUID
    var scheduledAt: Date
    var what: String
    var location: String
    let uploadedZettel: UploadedZettel
    let createdAt: Date

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        what: String,
        location: String,
        uploadedZettel: UploadedZettel,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.what = what
        self.location = location
        self.uploadedZettel = uploadedZettel
        self.createdAt = createdAt
    }
}

struct AppointmentDraft: Identifiable, Hashable {
    let id: UUID
    var scheduledAt: Date
    var what: String
    var location: String
    let uploadedZettel: UploadedZettel
    let previewImageData: Data?
    let rawDateTime: String?

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        what: String,
        location: String,
        uploadedZettel: UploadedZettel,
        previewImageData: Data?,
        rawDateTime: String?
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.what = what
        self.location = location
        self.uploadedZettel = uploadedZettel
        self.previewImageData = previewImageData
        self.rawDateTime = rawDateTime
    }
}

struct ZettelAnalysis: Hashable {
    let detectedDateTime: Date?
    let what: String
    let location: String
    let rawDateTime: String?
    let confidence: Double?
}

struct UserStorageContext: Hashable {
    let email: String
    let emailFolder: String
}

enum ZettelmanError: LocalizedError {
    case invalidImage
    case analysisTimeout
    case invalidAnalysisResponse
    case uploadFailed
    case unsupportedResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image could not be prepared for upload."
        case .analysisTimeout:
            return "Timed out waiting for Lambda analysis output in S3."
        case .invalidAnalysisResponse:
            return "The Lambda response could not be parsed."
        case .uploadFailed:
            return "Uploading the zettel failed."
        case let .unsupportedResponse(message):
            return message
        }
    }
}
