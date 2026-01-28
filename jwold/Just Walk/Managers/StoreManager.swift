//
//  StoreManager.swift
//  Just Walk
//
//  Created by Just Walk Team.
//

import Foundation
import StoreKit
import Combine

@MainActor
class StoreManager: ObservableObject {

    static let shared = StoreManager()

    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchaseError: Error?
    @Published var isPurchasing = false
    @Published var subscriptionExpirationDate: Date?
    @Published var willRenew: Bool = false
    @Published var ownsLifetime: Bool = false
    @Published private(set) var hasActiveSubscription: Bool = false

    #if DEBUG
    @Published var debugOverridePro: Bool = UserDefaults.standard.bool(forKey: "debugProOverride") {
        didSet {
            UserDefaults.standard.set(debugOverridePro, forKey: "debugProOverride")
            // Sync to App Group for Watch app access
            UserDefaults(suiteName: "group.com.onworldtech.JustWalk")?.set(debugOverridePro, forKey: "debugProOverride")
        }
    }
    #endif

    // MARK: - Computed Properties
    var isPro: Bool {
        #if DEBUG
        if debugOverridePro { return true }
        #endif
        return hasActiveSubscription || ownsLifetime
    }

    // Product IDs - Just Walk Pro (NEW FORMAT)
    let proMonthlyProductId = "com.onworldtech.justwalk.monthly"
    let proAnnualProductId = "com.onworldtech.justwalk.annual"
    let proLifetimeProductId = "com.onworldtech.justwalk.lifetime"

    // Product IDs - Consumables (Streak Repair)
    static let streakRepairProductId = "com.justwalk.streak_repair"

    var isProLifetime: Bool {
        UserDefaults.standard.bool(forKey: "isProLifetime")
    }

    var allProductIdentifiers: Set<String> {
        [proMonthlyProductId, proAnnualProductId, proLifetimeProductId]
    }

    // MARK: - Pro Product Helpers

    var proMonthlyProduct: Product? {
        products.first { $0.id == proMonthlyProductId }
    }

    var proAnnualProduct: Product? {
        products.first { $0.id == proAnnualProductId }
    }

    var proLifetimeProduct: Product? {
        products.first { $0.id == proLifetimeProductId }
    }
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        // Start listening for transaction updates (external, restores, etc.)
        updates = newTransactionListenerTask()

        // Fetch products on launch
        Task {
            await fetchProducts()
            await updateProStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Product Fetching
    
    func fetchProducts() async {
        do {
            let products = try await Product.products(for: allProductIdentifiers)
            self.products = products
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    // MARK: - Purchasing

    func purchase(_ product: Product) async {
        isPurchasing = true

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if let transaction = try? verification.payloadValue {
                    await transaction.finish()

                    // Handle Pro purchases
                    if transaction.productID == proMonthlyProductId ||
                       transaction.productID == proAnnualProductId {
                        self.hasActiveSubscription = true
                    } else if transaction.productID == proLifetimeProductId {
                        self.ownsLifetime = true
                        UserDefaults.standard.set(true, forKey: "isProLifetime")
                    }

                    await updateProStatus()
                }
            case .userCancelled:
                print("User cancelled")
            case .pending:
                print("Purchase pending")
            @unknown default:
                break
            }
        } catch {
            self.purchaseError = error
            print("Purchase failed: \(error)")
        }

        isPurchasing = false
    }

    func restorePurchases() async {
        await updateProStatus()
    }
    
    // MARK: - Status Updates

    func checkLifetimeOwnership() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == proLifetimeProductId {
                    return true
                }
            }
        }
        return false
    }

    func updateProStatus() async {
        var activeSubscription = false
        var lifetime = false
        var expirationDate: Date?
        var autoRenews = false

        // Check UserDefaults first for persisted lifetime
        if UserDefaults.standard.bool(forKey: "isProLifetime") {
            lifetime = true
        }

        // Check for active entitlements
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                if transaction.productID == proLifetimeProductId {
                    lifetime = true
                    UserDefaults.standard.set(true, forKey: "isProLifetime")
                } else if transaction.productID == proMonthlyProductId ||
                          transaction.productID == proAnnualProductId {
                    activeSubscription = true
                    expirationDate = transaction.expirationDate
                    autoRenews = transaction.revocationDate == nil
                }
            }
        }

        self.hasActiveSubscription = activeSubscription
        self.ownsLifetime = lifetime
        self.subscriptionExpirationDate = expirationDate
        self.willRenew = autoRenews
    }

    // MARK: - Transaction Listener
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await self.updateProStatus()
                }
            }
        }
    }
}
