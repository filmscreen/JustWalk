//
//  StreakData.swift
//  Just Walk
//
//  SwiftData model for tracking user's walking streaks.
//

import Foundation
import SwiftData

@Model
final class StreakData {
    var id: UUID = UUID()

    /// Current consecutive days meeting step goal
    var currentStreak: Int = 0

    /// All-time longest streak
    var longestStreak: Int = 0

    /// Last date the daily goal was met (start of day)
    var lastGoalMetDate: Date?

    /// Date when the current streak began
    var streakStartDate: Date?

    /// Lifetime total days where goal was met
    var totalDaysGoalMet: Int = 0

    /// Last time this record was updated
    var updatedAt: Date = Date()

    // MARK: - Streak Shield (Premium Feature)

    /// Dates that have been shielded (pardoned missed days)
    var shieldedDates: [Date] = []

    /// DEPRECATED: Use proMonthlyShieldsRemaining + purchasedShieldsRemaining
    /// Kept for migration - existing shields move to purchasedShieldsRemaining
    var shieldsRemaining: Int = 0

    /// Month number (1-12) when shield was last granted
    var lastShieldGrantMonth: Int = 0

    /// Year when shield was last granted
    var lastShieldGrantYear: Int = 0

    // MARK: - Split Shield Tracking (New)

    /// Pro monthly shields (0-3), refreshes each billing month
    var proMonthlyShieldsRemaining: Int = 0

    /// Purchased shields (one-time), never expire
    var purchasedShieldsRemaining: Int = 0

    /// Date when Pro monthly shields were last refreshed
    var proShieldsLastRefreshDate: Date?

    init() {
        self.id = UUID()
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastGoalMetDate = nil
        self.streakStartDate = nil
        self.totalDaysGoalMet = 0
        self.updatedAt = Date()
        self.shieldedDates = []
        self.shieldsRemaining = 0  // Deprecated
        self.lastShieldGrantMonth = 0
        self.lastShieldGrantYear = 0
        self.proMonthlyShieldsRemaining = 0
        self.purchasedShieldsRemaining = 0
        self.proShieldsLastRefreshDate = nil
    }

    // MARK: - Computed Properties

    /// Whether the streak is still active (not broken)
    /// A streak is active if:
    /// - Goal was met today, OR
    /// - Goal was met yesterday (today still has time)
    var isStreakActive: Bool {
        guard let lastDate = lastGoalMetDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastGoalDay = calendar.startOfDay(for: lastDate)

        // Goal met today = streak is active
        if calendar.isDate(lastGoalDay, inSameDayAs: today) {
            return true
        }

        // Goal met yesterday = streak still has today to continue
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(lastGoalDay, inSameDayAs: yesterday) {
            return true
        }

        // More than 1 day gap = streak is broken
        return false
    }

    /// Days until next milestone (7, 14, 30, 60, 90, 100, 365)
    var nextMilestone: Int {
        let milestones = [7, 14, 30, 60, 90, 100, 180, 365]
        for milestone in milestones {
            if currentStreak < milestone {
                return milestone
            }
        }
        // Beyond 365, next milestone is next multiple of 100
        let nextHundred = ((currentStreak / 100) + 1) * 100
        return nextHundred
    }

    /// Progress toward next milestone (0.0 to 1.0)
    var milestoneProgress: Double {
        let milestones = [0, 7, 14, 30, 60, 90, 100, 180, 365]

        // Find current tier
        var previousMilestone = 0
        var targetMilestone = 7

        for (index, milestone) in milestones.enumerated() {
            if currentStreak < milestone {
                targetMilestone = milestone
                previousMilestone = index > 0 ? milestones[index - 1] : 0
                break
            }
            if milestone == milestones.last {
                // Beyond 365
                previousMilestone = milestone
                targetMilestone = ((currentStreak / 100) + 1) * 100
            }
        }

        let streakInTier = currentStreak - previousMilestone
        let tierSize = targetMilestone - previousMilestone

        guard tierSize > 0 else { return 1.0 }
        return Double(streakInTier) / Double(tierSize)
    }

    /// Human-readable streak status
    var statusText: String {
        if currentStreak == 0 {
            return "Start your streak today!"
        } else if currentStreak == 1 {
            return "1 day streak"
        } else {
            return "\(currentStreak) day streak"
        }
    }

    /// Motivational text based on streak length
    var motivationalText: String {
        switch currentStreak {
        case 0:
            return "Every journey begins with a single step"
        case 1...6:
            return "Great start! Keep building momentum"
        case 7...13:
            return "One week strong! You're building a habit"
        case 14...29:
            return "Two weeks! Consistency is your superpower"
        case 30...59:
            return "A full month! You're unstoppable"
        case 60...89:
            return "Two months of dedication!"
        case 90...99:
            return "Three months! You're a walking champion"
        case 100...179:
            return "Triple digits! Incredible commitment"
        case 180...364:
            return "Half a year of daily walks!"
        case 365...:
            return "A full year! You're a legend"
        default:
            return "Keep walking!"
        }
    }

    // MARK: - Streak Shield Methods

    /// Total shields available (Pro monthly + purchased)
    var totalShieldsRemaining: Int {
        proMonthlyShieldsRemaining + purchasedShieldsRemaining
    }

    /// Whether user has shields available to use
    var canUseShield: Bool {
        totalShieldsRemaining > 0
    }

    /// Whether a new monthly shield should be granted (DEPRECATED - use shouldRefreshProShields)
    /// Returns true if current month/year differs from last grant month/year
    var shouldGrantMonthlyShield: Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Grant if we haven't granted this month yet
        return lastShieldGrantMonth != currentMonth || lastShieldGrantYear != currentYear
    }

    /// Whether Pro monthly shields should be refreshed (new month)
    var shouldRefreshProShields: Bool {
        guard let lastRefresh = proShieldsLastRefreshDate else { return true }
        let calendar = Calendar.current
        return !calendar.isDate(lastRefresh, equalTo: Date(), toGranularity: .month)
    }

    /// Grant a monthly shield and update the grant tracking (DEPRECATED)
    func grantMonthlyShield() {
        let calendar = Calendar.current
        let now = Date()

        shieldsRemaining += 1
        lastShieldGrantMonth = calendar.component(.month, from: now)
        lastShieldGrantYear = calendar.component(.year, from: now)
        updatedAt = now
    }

    /// Grant 3 Pro monthly shields (called at start of each billing month)
    func grantProMonthlyShields() {
        proMonthlyShieldsRemaining = 3
        proShieldsLastRefreshDate = Date()
        updatedAt = Date()
    }

    /// Add purchased shields (from one-time IAP)
    func addPurchasedShields(_ count: Int) {
        purchasedShieldsRemaining += count
        updatedAt = Date()
    }

    /// Use one shield - consumes purchased first, then Pro monthly
    /// Returns true if shield was used, false if none available
    func useShield() -> Bool {
        // Consume purchased shields first (they never expire)
        if purchasedShieldsRemaining > 0 {
            purchasedShieldsRemaining -= 1
            updatedAt = Date()
            return true
        }

        // Then consume Pro monthly shields
        if proMonthlyShieldsRemaining > 0 {
            proMonthlyShieldsRemaining -= 1
            updatedAt = Date()
            return true
        }

        return false
    }

    /// Check if a specific date has been shielded
    func isDateShielded(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return shieldedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    /// Calculate when Pro shields will refresh (first of next month)
    var proShieldsRefreshDate: Date? {
        guard let lastRefresh = proShieldsLastRefreshDate else { return nil }
        let calendar = Calendar.current

        // Get first day of next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: lastRefresh),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
            return nil
        }
        return firstOfMonth
    }

    /// Migrate old shieldsRemaining to purchasedShieldsRemaining
    func migrateShieldInventory() {
        if shieldsRemaining > 0 && purchasedShieldsRemaining == 0 && proMonthlyShieldsRemaining == 0 {
            // Move all existing shields to purchased (user paid for them)
            purchasedShieldsRemaining = shieldsRemaining
            shieldsRemaining = 0
            updatedAt = Date()
        }
    }
}
