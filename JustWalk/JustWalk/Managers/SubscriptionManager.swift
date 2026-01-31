//
//  SubscriptionManager.swift
//  JustWalk
//
//  StoreKit 2 integration for Pro subscription and Shield consumable
//

import Foundation
import StoreKit
import Combine

@Observable
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // Product IDs
    static let proAnnualID = "com.onworldtech.justwalk.pro.annual"
    static let proMonthlyID = "com.onworldtech.justwalk.pro.monthly"
    static let shieldProductID = "com.onworldtech.justwalk.shield"

    // State
    var products: [Product] = []
    var shieldProduct: Product?
    var purchasedProductIDs: Set<String> = []
    var isPro: Bool = false
    var isLoading: Bool = false

    private var updateListenerTask: Task<Void, Error>?

    // Tester mode key (debug-only)
    private static let testerModeKey = "tester_mode_enabled"
    private static let lastProStatusKey = "last_known_pro_status"
    
    init() {
        updateListenerTask = listenForTransactions()

        // Check tester mode (works in TestFlight)
        if UserDefaults.standard.bool(forKey: Self.testerModeKey) {
            isPro = true
        }

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debug_overridePro") {
            isPro = true
        }
        #endif

        // Check existing entitlements on launch (Pro status persistence)
        Task {
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = [Self.proAnnualID, Self.proMonthlyID, Self.shieldProductID]
            products = try await Product.products(for: productIDs)
            shieldProduct = products.first { $0.id == Self.shieldProductID }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()

            return transaction

        case .userCancelled, .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Shield Purchase

    func purchaseShield() async throws -> Bool {
        guard let product = shieldProduct else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            ShieldManager.shared.addShields(1)
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    /// Restore purchases and return true if Pro subscription was restored
    func restorePurchases() async -> Bool {
        var restored: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                restored.insert(transaction.productID)
            }
        }

        await MainActor.run {
            purchasedProductIDs = restored
            updateProStatus()
        }

        return isPro
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Update State

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }

        let finalPurchased = purchased
        await MainActor.run {
            purchasedProductIDs = finalPurchased
            updateProStatus()
        }
    }

    private func updateProStatus() {
        let newIsPro = purchasedProductIDs.contains(Self.proAnnualID) ||
            purchasedProductIDs.contains(Self.proMonthlyID)

        handleProStatusChange(newIsPro: newIsPro)

        // Tester mode override (works in TestFlight)
        if UserDefaults.standard.bool(forKey: Self.testerModeKey) {
            isPro = true
        }

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debug_overridePro") {
            isPro = true
        }
        #endif
    }

    private func handleProStatusChange(newIsPro: Bool) {
        let wasPro = UserDefaults.standard.bool(forKey: Self.lastProStatusKey)
        isPro = newIsPro

        if newIsPro && !wasPro {
            ShieldManager.shared.grantProUpgradeShields()
        }

        UserDefaults.standard.set(newIsPro, forKey: Self.lastProStatusKey)
    }

    // MARK: - Product Helpers

    var proAnnualProduct: Product? {
        products.first { $0.id == Self.proAnnualID }
    }

    var proMonthlyProduct: Product? {
        products.first { $0.id == Self.proMonthlyID }
    }

    var shieldDisplayPrice: String {
        shieldProduct?.displayPrice ?? "$2.99"
    }

    // MARK: - Pro Feature Access

    var monthlyShieldAllocation: Int {
        isPro ? ShieldData.proMonthlyAllocation : 0 // Free users get no monthly refill
    }

    var canAccessUnlimitedIntervals: Bool {
        isPro
    }

    var canAccessDetailedStats: Bool {
        isPro
    }

    var hasAdsRemoved: Bool {
        isPro
    }

    var canAccessUnlimitedHistory: Bool {
        isPro
    }

    // MARK: - Price Formatting

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func formattedSubscriptionPeriod(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        switch subscription.subscriptionPeriod.unit {
        case .year:
            return "year"
        case .month:
            return "month"
        case .week:
            return "week"
        case .day:
            return "day"
        @unknown default:
            return nil
        }
    }

    // MARK: - Tester Mode (works in TestFlight for beta testing)

    var isTesterModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.testerModeKey)
    }

    func enableTesterMode() {
        UserDefaults.standard.set(true, forKey: Self.testerModeKey)
        isPro = true
    }

    func disableTesterMode() {
        UserDefaults.standard.set(false, forKey: Self.testerModeKey)
        Task { await updatePurchasedProducts() }
    }
    
    // MARK: - Debug

    func setDebugProStatus(_ isPro: Bool) {
        #if DEBUG
        self.isPro = isPro
        UserDefaults.standard.set(isPro, forKey: "debug_isPro")
        #endif
    }

    func loadDebugStatus() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debug_isPro") {
            isPro = true
        }
        #endif
    }

    // MARK: - Errors

    enum StoreError: Error, LocalizedError {
        case failedVerification
        case productNotFound

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Transaction verification failed"
            case .productNotFound:
                return "Product not found"
            }
        }
    }
}
