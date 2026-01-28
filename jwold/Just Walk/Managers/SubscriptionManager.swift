//
//  SubscriptionManager.swift
//  Just Walk
//
//  RevenueCat-powered subscription manager for Just Walk Pro.
//  Handles UUID sync, entitlement verification, and restore purchases.
//

import Foundation
import RevenueCat
import Combine
// WatchConnectivity removed - Watch and iPhone are independent

/// RevenueCat API Key - Replace with production key before release
enum RevenueCatConfig {
    // TODO: Replace with production appl_ key before App Store release
    static let apiKey = "test_qTmhUMbZlHfqGxtJFgXsVixTzFw"

    /// Entitlement identifier configured in RevenueCat dashboard
    static let proEntitlementId = "pro"

    /// Offering identifier for Just Walk Pro
    static let proOfferingId = "default"
}

/// Subscription Manager using RevenueCat for Just Walk Pro
@MainActor
final class SubscriptionManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = SubscriptionManager()

    // MARK: - Published State

    /// Current Pro subscription status
    @Published private(set) var isPro: Bool = {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debugProOverride")
        #else
        return false
        #endif
    }()

    /// Current RevenueCat customer info
    @Published private(set) var customerInfo: CustomerInfo?

    /// Available offerings from RevenueCat
    @Published private(set) var offerings: Offerings?

    /// Loading state for async operations
    @Published private(set) var isLoading: Bool = false

    /// Error message for UI display
    @Published var errorMessage: String?

    /// Purchase in progress
    @Published private(set) var isPurchasing: Bool = false

    // MARK: - Computed Properties

    /// Monthly package from default offering
    var monthlyPackage: Package? {
        offerings?.current?.monthly
    }

    /// Annual package from default offering
    var annualPackage: Package? {
        offerings?.current?.annual
    }

    /// Lifetime package from default offering
    var lifetimePackage: Package? {
        offerings?.current?.lifetime
    }

    /// Check if user has active subscription
    var hasActiveSubscription: Bool {
        customerInfo?.entitlements[RevenueCatConfig.proEntitlementId]?.isActive == true
    }

    /// Expiration date of current subscription
    var subscriptionExpirationDate: Date? {
        customerInfo?.entitlements[RevenueCatConfig.proEntitlementId]?.expirationDate
    }

    /// Whether subscription will renew
    var willRenew: Bool {
        customerInfo?.entitlements[RevenueCatConfig.proEntitlementId]?.willRenew == true
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    /// Tracks whether RevenueCat SDK has been configured
    private(set) var isConfigured: Bool = false

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Configure RevenueCat SDK - Call once at app launch
    func configure() {
        guard !isConfigured else {
            print("⚠️ SubscriptionManager already configured")
            return
        }

        Purchases.logLevel = .debug // Set to .warn for production
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)

        // Set delegate for customer info updates
        Purchases.shared.delegate = self

        isConfigured = true

        // Initial fetch
        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }

        print("✅ SubscriptionManager configured with RevenueCat")
    }

    // MARK: - Supabase UUID Sync

    /// Sync Supabase User UUID to RevenueCat App User ID
    /// Call this immediately after successful Supabase authentication
    func syncUserIdentity(supabaseUserId: UUID) async {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, skipping identity sync")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Login to RevenueCat with Supabase UUID
            let (customerInfo, created) = try await Purchases.shared.logIn(supabaseUserId.uuidString)

            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)

            if created {
                print("✅ RevenueCat: New user created with ID: \(supabaseUserId)")
            } else {
                print("✅ RevenueCat: Existing user logged in: \(supabaseUserId)")
            }


        } catch {
            print("❌ RevenueCat login failed: \(error)")
            errorMessage = "Failed to sync subscription status"
        }
    }

    /// Logout from RevenueCat (call on Supabase sign-out)
    func logout() async {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, skipping logout")
            return
        }

        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
            print("✅ RevenueCat: User logged out")
        } catch {
            print("❌ RevenueCat logout failed: \(error)")
        }
    }

    // MARK: - Entitlement Verification

    /// Refresh customer info from RevenueCat
    func refreshCustomerInfo() async {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, skipping customer info refresh")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
            print("✅ RevenueCat: Customer info refreshed")
        } catch {
            print("❌ RevenueCat: Failed to fetch customer info: \(error)")
            errorMessage = "Failed to verify subscription status"
        }
    }

    /// Check if user has Pro entitlement
    func checkProEntitlement() async -> Bool {
        await refreshCustomerInfo()
        return isPro
    }

    // MARK: - Offerings

    /// Fetch available subscription offerings
    func fetchOfferings() async {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, skipping offerings fetch")
            return
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings

            if let current = offerings.current {
                print("✅ RevenueCat: Fetched offerings - \(current.availablePackages.count) packages")
            } else {
                print("⚠️ RevenueCat: No current offering configured")
            }
        } catch {
            print("❌ RevenueCat: Failed to fetch offerings: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }

    // MARK: - Purchases

    /// Purchase a subscription package
    func purchase(_ package: Package) async -> Bool {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, cannot purchase")
            errorMessage = "Subscription service not available"
            return false
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            // Check if transaction was successful
            if !result.userCancelled {
                self.customerInfo = result.customerInfo
                updateProStatus(from: result.customerInfo)


                print("✅ RevenueCat: Purchase successful")
                return true
            } else {
                print("ℹ️ RevenueCat: User cancelled purchase")
                return false
            }
        } catch {
            print("❌ RevenueCat: Purchase failed: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases - Critical for sandbox testing
    /// Maps the sandbox receipt to the current RevenueCat App User ID (Supabase UUID)
    func restorePurchases() async -> Bool {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, cannot restore purchases")
            errorMessage = "Subscription service not available"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)


            if isPro {
                print("✅ RevenueCat: Purchases restored - Pro entitlement active")
                return true
            } else {
                print("ℹ️ RevenueCat: No active subscriptions found to restore")
                errorMessage = "No active subscriptions found"
                return false
            }
        } catch {
            print("❌ RevenueCat: Restore failed: \(error)")
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Private Helpers

    /// Update Pro status from CustomerInfo
    private func updateProStatus(from info: CustomerInfo) {
        #if DEBUG
        // In debug builds, check debug override first
        if UserDefaults.standard.bool(forKey: "debugProOverride") {
            if !isPro {
                print("🔄 Pro status changed via debug override: \(isPro) -> true")
                isPro = true
            }
            return
        }
        #endif

        let newProStatus = info.entitlements[RevenueCatConfig.proEntitlementId]?.isActive == true

        if isPro != newProStatus {
            print("🔄 Pro status changed: \(isPro) -> \(newProStatus)")
            isPro = newProStatus
        }
    }

    // MARK: - Shield Consumable Purchases

    /// Product IDs for streak shield consumables
    static let shieldSingleProductId = "com.onworldtech.justwalk.shield.single"
    static let shieldTripleProductId = "com.onworldtech.JustWalk.shield.triple"

    /// Purchase streak shields (consumable) and grant to user
    /// - Parameter productId: The product ID to purchase
    /// - Returns: Number of shields granted
    func purchaseShields(productId: String) async throws -> Int {
        guard isConfigured else {
            throw ShieldPurchaseError.notConfigured
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        // Get StoreProduct from RevenueCat
        let products = try await Purchases.shared.products([productId])
        guard let product = products.first else {
            throw ShieldPurchaseError.productNotFound
        }

        // Make purchase
        let result = try await Purchases.shared.purchase(product: product)

        // Check if cancelled
        if result.userCancelled {
            throw ShieldPurchaseError.cancelled
        }

        // Determine shield count from product
        let shieldsToGrant = productId == Self.shieldTripleProductId ? 3 : 1

        // Grant shields via StreakService
        StreakService.shared.addPurchasedShields(shieldsToGrant)

        print("✅ Shield purchase successful: +\(shieldsToGrant) shields")
        return shieldsToGrant
    }

    /// Errors that can occur during shield purchase
    enum ShieldPurchaseError: LocalizedError {
        case notConfigured
        case productNotFound
        case purchaseFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Purchase service not available"
            case .productNotFound:
                return "Shield product not found"
            case .purchaseFailed:
                return "Purchase failed. Please try again."
            case .cancelled:
                return "Purchase was cancelled"
            }
        }
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {

    /// Called whenever customer info is updated (purchases, restores, subscription renewals/expirations)
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateProStatus(from: customerInfo)


            print("🔄 RevenueCat: Customer info updated via delegate")
        }
    }
}

// MARK: - Sandbox Testing Helpers

extension SubscriptionManager {

    /// Debug: Print current subscription status
    func debugPrintStatus() {
        print("""
        ====== Subscription Status ======
        Is Configured: \(isConfigured)
        Is Pro: \(isPro)
        Customer ID: \(customerInfo?.originalAppUserId ?? "nil")
        Entitlement Active: \(hasActiveSubscription)
        Expiration: \(subscriptionExpirationDate?.description ?? "nil")
        Will Renew: \(willRenew)
        =================================
        """)
    }

    /// Debug: Force refresh all subscription data
    func debugForceRefresh() async {
        guard isConfigured else {
            print("⚠️ RevenueCat not configured, skipping debug refresh")
            debugPrintStatus()
            return
        }
        await refreshCustomerInfo()
        await fetchOfferings()
        debugPrintStatus()
    }
}
