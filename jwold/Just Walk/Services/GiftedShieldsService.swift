//
//  GiftedShieldsService.swift
//  Just Walk
//
//  Service for checking and claiming gifted streak shields from Supabase.
//  Used by support staff to compensate users for bugs or issues.
//

import Foundation
import Supabase

/// Service for fetching and claiming gifted shields from Supabase
@MainActor
final class GiftedShieldsService {

    // MARK: - Singleton

    static let shared = GiftedShieldsService()

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Public API

    /// Check for and claim any unclaimed shield gifts for this user
    /// Call this on app launch after services are configured
    func checkAndClaimGifts() async {
        // Skip if Supabase is not configured
        guard SupabaseManager.shared.isConfigured else {
            print("🎁 GiftedShieldsService: Skipping - Supabase not configured")
            return
        }

        // Get user email from CloudSync/UserDefaults
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"),
              !userEmail.isEmpty else {
            print("🎁 GiftedShieldsService: Skipping - No user email set")
            return
        }

        print("🎁 GiftedShieldsService: Checking for gifts for \(userEmail)")

        do {
            // Fetch unclaimed gifts for this email
            let gifts: [GiftedShield] = try await supabase
                .from("gifted_shields")
                .select()
                .eq("user_email", value: userEmail.lowercased())
                .eq("claimed", value: false)
                .execute()
                .value

            guard !gifts.isEmpty else {
                print("🎁 GiftedShieldsService: No unclaimed gifts found")
                return
            }

            // Sum total shields to add
            let totalShields = gifts.reduce(0) { $0 + $1.shieldCount }
            print("🎁 GiftedShieldsService: Found \(gifts.count) gift(s) totaling \(totalShields) shields")

            // Add shields to local streak data
            StreakService.shared.addPurchasedShields(totalShields)

            // Mark all as claimed
            let claimedAt = ISO8601DateFormatter().string(from: Date())
            for gift in gifts {
                let updateData = GiftedShieldUpdate(claimed: true, claimedAt: claimedAt)
                try await supabase
                    .from("gifted_shields")
                    .update(updateData)
                    .eq("id", value: gift.id.uuidString)
                    .execute()
            }

            print("🎁 GiftedShieldsService: Claimed \(totalShields) shields successfully")

            // Notify UI to show gift alert
            NotificationCenter.default.post(
                name: .shieldsGifted,
                object: nil,
                userInfo: ["count": totalShields]
            )

        } catch {
            print("❌ GiftedShieldsService: Failed to check/claim gifts: \(error)")
        }
    }
}

// MARK: - Data Models

/// Represents a gifted shield record from Supabase
struct GiftedShield: Codable {
    let id: UUID
    let userEmail: String
    let shieldCount: Int
    let reason: String?
    let grantedBy: String?
    let grantedAt: Date
    let claimedAt: Date?
    let claimed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userEmail = "user_email"
        case shieldCount = "shield_count"
        case reason
        case grantedBy = "granted_by"
        case grantedAt = "granted_at"
        case claimedAt = "claimed_at"
        case claimed
    }
}

/// Update payload for marking a gift as claimed
struct GiftedShieldUpdate: Encodable {
    let claimed: Bool
    let claimedAt: String

    enum CodingKeys: String, CodingKey {
        case claimed
        case claimedAt = "claimed_at"
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when gifted shields are claimed
    /// userInfo contains "count" (Int) with number of shields received
    static let shieldsGifted = Notification.Name("shieldsGifted")
}
