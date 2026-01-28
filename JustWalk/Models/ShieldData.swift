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

        // First launch: give new free-tier users the initial gift of 2 shields
        if lastRefillDate == nil && !isPro {
            availableShields = Self.freeMaxBanked
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
