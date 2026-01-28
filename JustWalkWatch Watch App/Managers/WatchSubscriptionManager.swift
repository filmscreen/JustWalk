//
//  WatchSubscriptionManager.swift
//  JustWalkWatch Watch App
//
//  Lightweight StoreKit 2 Pro status checker (read-only, no purchase flow)
//

import Foundation
import StoreKit
import os

@Observable
class WatchSubscriptionManager {
    static let shared = WatchSubscriptionManager()

    private static let logger = Logger(subsystem: "com.justwalk.watch", category: "Subscription")

    private static let proAnnualID = "com.onworldtech.justwalk.pro.annual"
    private static let proMonthlyID = "com.onworldtech.justwalk.pro.monthly"
    private static let proIDs: Set<String> = [proAnnualID, proMonthlyID]
    
    // Tester mode key (works in production)
    private static let testerModeKey = "tester_mode_enabled"

    var isPro: Bool = false
    var statusChecked: Bool = false

    private var updateTask: Task<Void, Never>?

    private init() {
        // Check tester mode on init
        if UserDefaults.standard.bool(forKey: Self.testerModeKey) {
            isPro = true
        }
        
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if Self.proIDs.contains(transaction.productID) {
                        await self?.checkProStatus()
                    }
                }
            }
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func checkProStatus() async {
        var foundPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if Self.proIDs.contains(transaction.productID),
                   transaction.revocationDate == nil {
                    foundPro = true
                    break
                }
            }
        }
        
        // Check tester mode override
        if UserDefaults.standard.bool(forKey: Self.testerModeKey) {
            foundPro = true
        }
        
        isPro = foundPro
        statusChecked = true
        Self.logger.info("Pro status checked: \(foundPro)")
    }
    
    // MARK: - Tester Mode (Production-safe)
    
    var isTesterModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.testerModeKey)
    }
    
    func enableTesterMode() {
        UserDefaults.standard.set(true, forKey: Self.testerModeKey)
        isPro = true
    }
    
    func disableTesterMode() {
        UserDefaults.standard.set(false, forKey: Self.testerModeKey)
        Task { await checkProStatus() }
    }
}

