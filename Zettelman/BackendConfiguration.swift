import Foundation

enum BackendConfiguration {
    // App waits for Lambda's S3 result file at processed/{email}/zettels/*.analysis.json.
    static let analysisPollIntervalSeconds: TimeInterval = 2.0
    static let analysisTimeoutSeconds: TimeInterval = 60.0
}
