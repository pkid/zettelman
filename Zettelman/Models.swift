import Foundation

struct UploadedZettel: Codable, Hashable {
    let key: String
    let filename: String
    let uploadedAt: Date
}

struct Appointment: Identifiable, Codable, Hashable {
    let id: UUID
    var scheduledAt: Date
    var reminderEnabled: Bool
    var addToCalendar: Bool
    var calendarEventIdentifier: String?
    var what: String
    var location: String
    var withWhom: String?
    let uploadedZettel: UploadedZettel?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        reminderEnabled: Bool = true,
        addToCalendar: Bool = true,
        calendarEventIdentifier: String? = nil,
        what: String,
        location: String,
        withWhom: String? = nil,
        uploadedZettel: UploadedZettel? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.reminderEnabled = reminderEnabled
        self.addToCalendar = addToCalendar
        self.calendarEventIdentifier = calendarEventIdentifier
        self.what = what
        self.location = location
        self.withWhom = withWhom
        self.uploadedZettel = uploadedZettel
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case scheduledAt
        case reminderEnabled
        case addToCalendar
        case calendarEventIdentifier
        case what
        case location
        case withWhom
        case uploadedZettel
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scheduledAt = try container.decode(Date.self, forKey: .scheduledAt)
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? true
        addToCalendar = try container.decodeIfPresent(Bool.self, forKey: .addToCalendar) ?? true
        calendarEventIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarEventIdentifier)
        what = try container.decode(String.self, forKey: .what)
        location = try container.decode(String.self, forKey: .location)
        withWhom = try container.decodeIfPresent(String.self, forKey: .withWhom)
        uploadedZettel = try container.decodeIfPresent(UploadedZettel.self, forKey: .uploadedZettel)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(scheduledAt, forKey: .scheduledAt)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(addToCalendar, forKey: .addToCalendar)
        try container.encodeIfPresent(calendarEventIdentifier, forKey: .calendarEventIdentifier)
        try container.encode(what, forKey: .what)
        try container.encode(location, forKey: .location)
        try container.encodeIfPresent(withWhom, forKey: .withWhom)
        try container.encodeIfPresent(uploadedZettel, forKey: .uploadedZettel)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct AppointmentDraft: Identifiable, Hashable {
    let id: UUID
    var scheduledAt: Date
    var reminderEnabled: Bool
    var addToCalendar: Bool
    var what: String
    var location: String
    var withWhom: String
    let uploadedZettel: UploadedZettel?
    let previewImageData: Data?
    let rawDateTime: String?

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        reminderEnabled: Bool = true,
        addToCalendar: Bool = true,
        what: String,
        location: String,
        withWhom: String,
        uploadedZettel: UploadedZettel? = nil,
        previewImageData: Data?,
        rawDateTime: String?
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.reminderEnabled = reminderEnabled
        self.addToCalendar = addToCalendar
        self.what = what
        self.location = location
        self.withWhom = withWhom
        self.uploadedZettel = uploadedZettel
        self.previewImageData = previewImageData
        self.rawDateTime = rawDateTime
    }
}

struct ZettelAnalysis: Hashable {
    let detectedDateTime: Date?
    let what: String
    let location: String
    let withWhom: String
    let rawDateTime: String?
    let confidence: Double?
}

struct UserStorageContext: Hashable {
    let email: String
    let emailFolder: String
    let bypassUploadQuota: Bool
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
            return String(localized: "error.invalid.image")
        case .analysisTimeout:
            return String(localized: "error.timeout")
        case .invalidAnalysisResponse:
            return String(localized: "error.invalid.response")
        case .uploadFailed:
            return String(localized: "error.upload.failed")
        case let .unsupportedResponse(message):
            return message
        }
    }
}
