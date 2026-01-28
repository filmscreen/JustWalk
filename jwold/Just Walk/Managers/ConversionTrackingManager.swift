//
//  ConversionTrackingManager.swift
//  Just Walk
//
//  Tracks Just Walk completions and free trial usage for conversion prompts.
//  Triggers conversion cards at optimal moments without being aggressive.
//

import Foundation
import Combine

/// Manages conversion tracking for free-to-Pro upgrade prompts
@MainActor
final class ConversionTrackingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ConversionTrackingManager()

    // MARK: - Published Properties

    @Published private(set) var justWalkCompletedCount: Int = 0
    @Published private(set) var hasUsedFreeTrial: Bool = false
    @Published private(set) var lastConversionPromptDismissDate: Date?

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let justWalkCount = "conversion_justWalkCompletedCount"
        static let hasUsedFreeTrial = "conversion_hasUsedPowerWalkFreeTrial"
        static let lastPromptDismiss = "conversion_lastPromptDismissDate"
        static let powerWalksThisWeek = "conversion_powerWalksThisWeek"
        static let weekStartDate = "conversion_weekStartDate"
        static let conversionDismissCount = "conversion_cardDismissCount"
    }

    // MARK: - Weekly Tracking

    @Published private(set) var powerWalksThisWeek: Int = 0
    private var weekStartDate: Date?

    // MARK: - Initialization

    private init() {
        loadState()
        resetWeeklyCountIfNeeded()
    }

    // MARK: - Just Walk Tracking

    /// Record completion of a Just Walk (classic mode) session
    func recordJustWalkCompletion() {
        guard !FreeTierManager.shared.isPro else { return }
        justWalkCompletedCount += 1
        saveState()
    }

    // MARK: - Power Walk Tracking

    /// Record completion of a Power Walk session
    func recordPowerWalkCompletion() {
        resetWeeklyCountIfNeeded()
        powerWalksThisWeek += 1
        saveState()
    }

    // MARK: - Free Trial

    /// Record that the user has used their one free Power Walk trial
    func recordFreeTrialUsed() {
        hasUsedFreeTrial = true
        saveState()
    }

    /// Check if user is eligible for free trial
    var canUseFreeTrial: Bool {
        !FreeTierManager.shared.isPro && !hasUsedFreeTrial
    }

    // MARK: - Dismissal Tracking

    /// Number of times the conversion card has been dismissed
    @Published private(set) var conversionDismissCount: Int = 0

    /// Increment the dismiss count (card hidden after 3 dismissals)
    func incrementDismissCount() {
        conversionDismissCount += 1
        saveState()
    }

    /// Whether the conversion card has been dismissed too many times
    var hasReachedDismissLimit: Bool {
        conversionDismissCount >= 3
    }

    // MARK: - Conversion Triggers

    /// Determine if conversion card should be shown on post-walk summary
    /// - Parameters:
    ///   - timeSavedMinutes: Estimated minutes saved if using Power Walk
    ///   - steps: Number of steps in the walk session
    /// - Returns: True if conversion card should be displayed
    func shouldShowConversionCard(timeSavedMinutes: Int, steps: Int = 0) -> Bool {
        // Never show to Pro users
        guard !FreeTierManager.shared.isPro else { return false }

        // Don't show if dismissed too many times (3+)
        guard !hasReachedDismissLimit else { return false }

        // Don't show for very short walks (< 500 steps)
        guard steps >= 500 else { return false }

        // Check if recently dismissed (within 24 hours)
        if let lastDismiss = lastConversionPromptDismissDate {
            let hoursSinceDismiss = Date().timeIntervalSince(lastDismiss) / 3600
            if hoursSinceDismiss < 24 {
                return false
            }
        }

        // Trigger conditions:
        // 1. After 3+ Just Walk completions (user is forming a habit)
        // 2. OR when time saved would be significant (>10 minutes)
        return justWalkCompletedCount >= 3 || timeSavedMinutes > 10
    }

    /// Record that user dismissed the conversion card
    func recordConversionPromptDismissed() {
        lastConversionPromptDismissDate = Date()
        saveState()
    }

    // MARK: - Time Calculations

    /// Calculate estimated time saved by using Power Walk
    /// - Parameters:
    ///   - steps: Number of steps taken
    ///   - duration: Actual walk duration in seconds
    /// - Returns: Minutes saved (0 if Power Walk would take longer)
    func calculateTimeSaved(steps: Int, duration: TimeInterval) -> Int {
        // Regular walk: ~100 steps/min
        // Power Walk: ~120 steps/min
        let regularWalkMinutes = Double(steps) / 100.0
        let actualMinutes = duration / 60.0
        return max(0, Int(regularWalkMinutes - actualMinutes))
    }

    /// Estimate how long a Power Walk would take for a given step count
    /// - Parameter steps: Target step count
    /// - Returns: Estimated duration in seconds
    func estimatePowerWalkDuration(forSteps steps: Int) -> TimeInterval {
        // Power Walk averages 120 steps/min
        return (Double(steps) / 120.0) * 60.0
    }

    // MARK: - Weekly Reset

    private func resetWeeklyCountIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get the start of the current week (Monday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        let currentWeekStart = calendar.date(from: components) ?? today

        if let savedWeekStart = weekStartDate {
            if currentWeekStart > savedWeekStart {
                // New week started, reset counter
                powerWalksThisWeek = 0
                weekStartDate = currentWeekStart
                saveState()
            }
        } else {
            weekStartDate = currentWeekStart
            saveState()
        }
    }

    // MARK: - Persistence

    private func saveState() {
        UserDefaults.standard.set(justWalkCompletedCount, forKey: Keys.justWalkCount)
        UserDefaults.standard.set(hasUsedFreeTrial, forKey: Keys.hasUsedFreeTrial)
        UserDefaults.standard.set(powerWalksThisWeek, forKey: Keys.powerWalksThisWeek)
        UserDefaults.standard.set(conversionDismissCount, forKey: Keys.conversionDismissCount)

        if let date = lastConversionPromptDismissDate {
            UserDefaults.standard.set(date, forKey: Keys.lastPromptDismiss)
        }
        if let date = weekStartDate {
            UserDefaults.standard.set(date, forKey: Keys.weekStartDate)
        }
    }

    private func loadState() {
        justWalkCompletedCount = UserDefaults.standard.integer(forKey: Keys.justWalkCount)
        hasUsedFreeTrial = UserDefaults.standard.bool(forKey: Keys.hasUsedFreeTrial)
        powerWalksThisWeek = UserDefaults.standard.integer(forKey: Keys.powerWalksThisWeek)
        conversionDismissCount = UserDefaults.standard.integer(forKey: Keys.conversionDismissCount)
        lastConversionPromptDismissDate = UserDefaults.standard.object(forKey: Keys.lastPromptDismiss) as? Date
        weekStartDate = UserDefaults.standard.object(forKey: Keys.weekStartDate) as? Date
    }

    // MARK: - Debug

    /// Reset all conversion tracking (for testing)
    func resetForTesting() {
        justWalkCompletedCount = 0
        hasUsedFreeTrial = false
        powerWalksThisWeek = 0
        conversionDismissCount = 0
        lastConversionPromptDismissDate = nil
        weekStartDate = nil

        UserDefaults.standard.removeObject(forKey: Keys.justWalkCount)
        UserDefaults.standard.removeObject(forKey: Keys.hasUsedFreeTrial)
        UserDefaults.standard.removeObject(forKey: Keys.powerWalksThisWeek)
        UserDefaults.standard.removeObject(forKey: Keys.conversionDismissCount)
        UserDefaults.standard.removeObject(forKey: Keys.lastPromptDismiss)
        UserDefaults.standard.removeObject(forKey: Keys.weekStartDate)
    }
}
