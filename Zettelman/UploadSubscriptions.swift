import Foundation
import StoreKit

enum UploadPlan: Int, CaseIterable, Identifiable {
    case free = 0
    case starter10 = 1
    case pro50 = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .free:
            return "Free"
        case .starter10:
            return "Starter"
        case .pro50:
            return "Pro"
        }
    }

    var monthlyUploadLimit: Int {
        switch self {
        case .free:
            return 3
        case .starter10:
            return 10
        case .pro50:
            return 50
        }
    }

    var fallbackPricePerMonth: String {
        switch self {
        case .free:
            return "€0.00"
        case .starter10:
            return "€0.99"
        case .pro50:
            return "€3.99"
        }
    }

    var summary: String {
        "\(monthlyUploadLimit) captures per month"
    }

    var productID: String? {
        switch self {
        case .free:
            return nil
        case .starter10:
            return "com.zettelman.uploads.starter10.monthly"
        case .pro50:
            return "org.pkidpkid.zettelscan.uploads.pro50.monthly.v2"
        }
    }

    static func plan(for productID: String) -> UploadPlan? {
        allCases.first(where: { $0.productID == productID })
    }
}

enum SubscriptionError: LocalizedError {
    case productUnavailable
    case purchasePending
    case userCancelled
    case unverifiedTransaction
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This subscription is currently unavailable."
        case .purchasePending:
            return "Purchase is pending approval."
        case .userCancelled:
            return "Purchase was cancelled."
        case .unverifiedTransaction:
            return "Unable to verify purchase."
        case .unknown:
            return "Purchase failed. Please try again."
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var currentPlan: UploadPlan = .free
    @Published private(set) var productsByPlan: [UploadPlan: Product] = [:]
    @Published private(set) var isRefreshing = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }

        Task {
            await refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await loadProducts()
        await refreshEntitlements()
    }

    func displayPrice(for plan: UploadPlan) -> String {
        if plan == .free {
            return plan.fallbackPricePerMonth
        }

        return productsByPlan[plan]?.displayPrice ?? plan.fallbackPricePerMonth
    }

    func canPurchase(_ plan: UploadPlan) -> Bool {
        guard plan != .free else { return false }
        return productsByPlan[plan] != nil
    }

    func purchase(plan: UploadPlan) async throws {
        guard plan != .free else { return }

        if productsByPlan[plan] == nil {
            await loadProducts()
        }

        guard let product = productsByPlan[plan] else {
            throw SubscriptionError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            await refreshEntitlements()
        case .pending:
            throw SubscriptionError.purchasePending
        case .userCancelled:
            throw SubscriptionError.userCancelled
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func loadProducts() async {
        let productIDs = UploadPlan.allCases.compactMap(\.productID)
        guard !productIDs.isEmpty else {
            productsByPlan = [:]
            return
        }

        do {
            let products = try await Product.products(for: productIDs)
            var byPlan: [UploadPlan: Product] = [:]

            for product in products {
                guard let plan = UploadPlan.plan(for: product.id) else { continue }
                byPlan[plan] = product
            }

            productsByPlan = byPlan
        } catch {
            productsByPlan = [:]
        }
    }

    private func refreshEntitlements() async {
        var resolvedPlan: UploadPlan = .free
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < now {
                continue
            }
            guard let plan = UploadPlan.plan(for: transaction.productID) else { continue }
            if plan.rawValue > resolvedPlan.rawValue {
                resolvedPlan = plan
            }
        }

        currentPlan = resolvedPlan
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case let .verified(transaction) = result {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case let .verified(transaction):
            return transaction
        case .unverified:
            throw SubscriptionError.unverifiedTransaction
        }
    }
}

struct UploadQuotaError: LocalizedError {
    let plan: UploadPlan

    var errorDescription: String? {
        if plan == .free {
            return "Free plan limit reached (3 captures this month). Upgrade to Starter (€0.99/month, 10 captures) or Pro (€3.99/month, 50 captures)."
        }

        return "\(plan.title) limit reached (\(plan.monthlyUploadLimit) captures this month). Upgrade your plan to continue capturing."
    }
}

final class UploadQuotaTracker {
    private struct UsageRecord: Codable {
        var monthKey: String
        var count: Int
    }

    private let defaults: UserDefaults
    private let storageKey = "com.zettelman.upload.usage.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentUsage(for userEmail: String, now: Date = Date()) -> Int {
        let key = normalizedUserKey(from: userEmail)
        let monthKey = currentMonthKey(from: now)
        let records = loadRecords()
        guard let record = records[key], record.monthKey == monthKey else {
            return 0
        }
        return record.count
    }

    @discardableResult
    func incrementUsage(for userEmail: String, now: Date = Date()) -> Int {
        let key = normalizedUserKey(from: userEmail)
        let monthKey = currentMonthKey(from: now)
        var records = loadRecords()
        let currentCount = (records[key]?.monthKey == monthKey) ? (records[key]?.count ?? 0) : 0
        let nextCount = currentCount + 1
        records[key] = UsageRecord(monthKey: monthKey, count: nextCount)
        saveRecords(records)
        return nextCount
    }

    private func currentMonthKey(from date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private func normalizedUserKey(from email: String) -> String {
        email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadRecords() -> [String: UsageRecord] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        guard let decoded = try? decoder.decode([String: UsageRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveRecords(_ records: [String: UsageRecord]) {
        guard let data = try? encoder.encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
