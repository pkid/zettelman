import Foundation

final class ZettelAnalysisService {
    private let isoParser = ISO8601DateFormatter()
    private let pollIntervalNanoseconds: UInt64
    private let timeoutNanoseconds: UInt64

    init() {
        isoParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        pollIntervalNanoseconds = UInt64(BackendConfiguration.analysisPollIntervalSeconds * 1_000_000_000)
        timeoutNanoseconds = UInt64(BackendConfiguration.analysisTimeoutSeconds * 1_000_000_000)
    }

    func analyze(uploadedZettel: UploadedZettel, s3Service: ZettelS3Service) async throws -> ZettelAnalysis {
        let analysisKey = analysisOutputKey(for: uploadedZettel.key)
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            do {
                let data = try await s3Service.downloadData(
                    for: analysisKey,
                    operation: "downloading Lambda analysis output"
                )
                let payload = try decodePayload(from: data)

                return ZettelAnalysis(
                    detectedDateTime: parseDate(payload.dateTime),
                    what: payload.what.normalizedWhat(),
                    location: payload.location.trimmingCharacters(in: .whitespacesAndNewlines),
                    withWhom: (payload.withWhom ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    rawDateTime: payload.dateTime,
                    confidence: payload.confidence
                )
            } catch {
                if !isLikelyNotReadyError(error) {
                    throw error
                }
            }

            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        throw ZettelmanError.unsupportedResponse(
            "Timed out waiting for Lambda analysis output in S3. Expected key: \(analysisKey)"
        )
    }

    private func analysisOutputKey(for sourceKey: String) -> String {
        let trimmedSourceKey = sourceKey.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let processedKey: String

        if trimmedSourceKey.hasPrefix("received/") {
            let suffix = trimmedSourceKey.dropFirst("received/".count)
            processedKey = "processed/\(suffix)"
        } else {
            processedKey = trimmedSourceKey.replacingOccurrences(of: "received/", with: "processed/")
        }

        let withoutExtension = (processedKey as NSString).deletingPathExtension
        return withoutExtension + ".analysis.json"
    }

    private func isLikelyNotReadyError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("not found")
            || message.contains("nosuchkey")
            || message.contains("404")
            || message.contains("key does not exist")
    }

    private func decodePayload(from data: Data) throws -> AnalyzeResponse {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(AnalyzeResponse.self, from: data) else {
            throw ZettelmanError.invalidAnalysisResponse
        }
        return payload
    }

    private func parseDate(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        if let parsed = isoParser.date(from: rawValue) {
            return parsed
        }

        let alternateISO = ISO8601DateFormatter()
        alternateISO.formatOptions = [.withInternetDateTime]
        if let parsed = alternateISO.date(from: rawValue) {
            return parsed
        }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yy HH:mm",
            "dd.MM.yyyy",
            "dd.MM.yy"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: rawValue) {
                return parsed
            }
        }

        return nil
    }

    private struct AnalyzeResponse: Decodable {
        let dateTime: String?
        let what: String
        let location: String
        let withWhom: String?
        let confidence: Double?

        enum CodingKeys: String, CodingKey {
            case dateTime = "date_time"
            case what
            case location = "where"
            case withWhom = "with_whom"
            case confidence
        }
    }
}

extension String {
    func normalizedWhat() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Review appointment" }

        let words = trimmed.split(whereSeparator: \.isWhitespace)
        if words.count <= 5 {
            return trimmed
        }

        return words.prefix(5).joined(separator: " ")
    }
}
