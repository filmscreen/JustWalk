//
//  ShieldDataTests.swift
//  JustWalkTests
//
//  Tests for ShieldData model and refill logic
//

import Testing
import Foundation
@testable import JustWalk

struct ShieldDataTests {

    // MARK: - Free User Refill

    @Test func freeUserRefill_adds2Shields() {
        var data = ShieldData.empty
        data.refillIfNeeded(isPro: false)
        #expect(data.availableShields == 2)
    }

    // MARK: - Pro User Refill

    @Test func proUserRefill_adds4Shields() {
        var data = ShieldData.empty
        data.refillIfNeeded(isPro: true)
        #expect(data.availableShields == 4)
    }

    // MARK: - No Double-Refill

    @Test func refill_onlyHappensOncePerMonth() {
        var data = ShieldData.empty
        data.refillIfNeeded(isPro: false)
        let firstRefillShields = data.availableShields
        // Second refill same month should not change
        data.refillIfNeeded(isPro: false)
        #expect(data.availableShields == firstRefillShields)
    }

    // MARK: - Purchased Shields

    @Test func purchasedShields_addCorrectly() {
        var data = ShieldData.empty
        data.purchasedShields += 2
        data.availableShields += 2
        #expect(data.purchasedShields == 2)
        #expect(data.availableShields == 2)
    }

    // MARK: - Max Banked

    @Test func availableShields_dontExceedMaxBanked_free() {
        var data = ShieldData(
            availableShields: 1,
            lastRefillDate: nil,
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        data.refillIfNeeded(isPro: false) // Tries to add 2, cap is 2
        #expect(data.availableShields <= ShieldData.freeMaxBanked)
        #expect(data.availableShields == 2)
    }

    @Test func availableShields_dontExceedMaxBanked_pro() {
        var data = ShieldData(
            availableShields: 6,
            lastRefillDate: nil,
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        data.refillIfNeeded(isPro: true) // Tries to add 4, cap is 8
        #expect(data.availableShields <= ShieldData.proMaxBanked)
        #expect(data.availableShields == 8)
    }

    // MARK: - Monthly Usage Tracking

    @Test func shieldsUsedThisMonth_tracksUsage() {
        var data = ShieldData(
            availableShields: 3,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        data.availableShields -= 1
        data.shieldsUsedThisMonth += 1
        #expect(data.shieldsUsedThisMonth == 1)
        #expect(data.availableShields == 2)
    }

    // MARK: - Codable

    @Test func codableRoundTrip() throws {
        let original = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 1,
            purchasedShields: 3
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ShieldData.self, from: data)

        #expect(decoded.availableShields == original.availableShields)
        #expect(decoded.shieldsUsedThisMonth == original.shieldsUsedThisMonth)
        #expect(decoded.purchasedShields == original.purchasedShields)
    }

    // MARK: - Refill Respects lastRefillDate

    @Test func refillIfNeeded_respectsLastRefillDate() {
        var data = ShieldData(
            availableShields: 1,
            lastRefillDate: Date(), // Already refilled this month
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        data.refillIfNeeded(isPro: true)
        // Should not change since lastRefillDate is this month
        #expect(data.availableShields == 1)
    }

    // MARK: - Constants

    @Test func constants_areCorrect() {
        #expect(ShieldData.freeMaxBanked == 2)
        #expect(ShieldData.proMaxBanked == 8)
        #expect(ShieldData.freeMonthlyAllocation == 2)
        #expect(ShieldData.proMonthlyAllocation == 4)
        #expect(ShieldData.maxBanked(isPro: false) == 2)
        #expect(ShieldData.maxBanked(isPro: true) == 8)
    }
}
