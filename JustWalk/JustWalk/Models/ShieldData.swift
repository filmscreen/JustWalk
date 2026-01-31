//
//  ShieldData.swift
//  JustWalk
//
//  Core data model for streak protection shields
//

import Foundation

struct ShieldData: Codable {
    var availableShields: Int
    var lastRefillDate: Date?
    var shieldsUsedThisMonth: Int
    var purchasedShields: Int // Shields bought via IAP
    var totalShieldsUsed: Int // Lifetime counter

    static let freeMaxBanked = 2
    static let proMaxBanked = 8
    static let freeMonthlyAllocation = 2
    static let proMonthlyAllocation = 4

    static func maxBanked(isPro: Bool) -> Int {
        isPro ? proMaxBanked : freeMaxBanked
    }

    static let empty = ShieldData(
        availableShields: 0,
        lastRefillDate: nil,
        shieldsUsedThisMonth: 0,
        purchasedShields: 0,
        totalShieldsUsed: 0
    )

    // Codable migration: decode totalShieldsUsed with default 0
    enum CodingKeys: String, CodingKey {
        case availableShields, lastRefillDate, shieldsUsedThisMonth, purchasedShields, totalShieldsUsed
    }

    init(availableShields: Int, lastRefillDate: Date?, shieldsUsedThisMonth: Int, purchasedShields: Int, totalShieldsUsed: Int = 0) {
        self.availableShields = availableShields
        self.lastRefillDate = lastRefillDate
        self.shieldsUsedThisMonth = shieldsUsedThisMonth
        self.purchasedShields = purchasedShields
        self.totalShieldsUsed = totalShieldsUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availableShields = try container.decode(Int.self, forKey: .availableShields)
        lastRefillDate = try container.decodeIfPresent(Date.self, forKey: .lastRefillDate)
        shieldsUsedThisMonth = try container.decode(Int.self, forKey: .shieldsUsedThisMonth)
        purchasedShields = try container.decode(Int.self, forKey: .purchasedShields)
        totalShieldsUsed = try container.decodeIfPresent(Int.self, forKey: .totalShieldsUsed) ?? 0
    }

    mutating func refillIfNeeded(isPro: Bool) {
        let calendar = Calendar.current
        let now = Date()

        // Check if we need to refill (new month)
        if let lastRefill = lastRefillDate,
           calendar.isDate(lastRefill, equalTo: now, toGranularity: .month) {
            return // Already refilled this month
        }

        // First launch / fresh install handling
        if lastRefillDate == nil {
            // This is a first-time initialization of shield data.
            // Could be:
            // 1. True fresh install (never had app)
            // 2. Reinstall where UserDefaults was cleared but Keychain persists
            // 3. Reinstall with iCloud data incoming (handled by CloudKit merge)
            //
            // For cases 1 & 2, we should grant starter shields.
            // The Keychain flag was previously used to prevent gaming, but it
            // caused legitimate returning users to get 0 shields.
            //
            // New approach: Always grant starter shields on first init.
            // CloudKit merge (which takes MIN of availableShields) will correct
            // any gaming attempts by syncing the lower value from cloud.
            // This is safe because:
            // - If user never used shields: cloud has 2, local has 2, MIN = 2 ✓
            // - If user used shields: cloud has 0-1, local has 2, MIN = 0-1 ✓
            // - If user tries to game by reinstalling: cloud has low value, MIN wins ✓
            if !isPro {
                availableShields = Self.freeMaxBanked
            } else {
                availableShields = Self.proMaxBanked
            }
        } else if isPro {
            // Pro users get monthly refills
            availableShields = min(availableShields + Self.proMonthlyAllocation, Self.proMaxBanked)
        } else {
            // Free users receive a monthly allocation up to the free max
            availableShields = min(availableShields + Self.freeMonthlyAllocation, Self.freeMaxBanked)
        }

        shieldsUsedThisMonth = 0
        lastRefillDate = now
    }
}
