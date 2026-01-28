//
//  FreeTierManager.swift
//  Just Walk
//
//  Centralized manager for free tier limitations.
//  Controls feature gating to encourage Pro upgrades while keeping core value accessible.
//

import Foundation
import Combine

/// Manages free tier limitations to optimize conversion while maintaining value
@MainActor
final class FreeTierManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FreeTierManager()

    // MARK: - Published Properties

    /// Tracks daily coaching tips shown to free users
    @Published private(set) var coachingTipsShownToday: Int = 0

    /// Tracks magic route walks started today (counts when walk STARTS, not generation)
    @Published private(set) var magicRoutesStartedToday: Int = 0

    /// Date when tips counter was last reset
    private var lastTipResetDate: Date?

    /// Date when magic route counter was last reset
    private var lastMagicRouteResetDate: Date?

    // MARK: - Limits Configuration

    /// Free users can see last 30 days of history (standard month view)
    /// Pro users get unlimited history (all available HealthKit data)
    static let historyDaysLimit = 30

    /// Coaching tips are FREE for all users (not a premium feature)
    static let dailyCoachingTipsLimit = Int.max

    /// Leaderboards are FREE for all users (not a premium feature)
    static let leaderboardVisibleMembers = Int.max

    /// Free users can START 1 magic route walk per day
    /// (Generation is unlimited, but actually starting a walk counts)
    static let dailyMagicRouteLimit = 1

    // MARK: - Initialization

    private init() {
        loadState()
        resetTipsIfNewDay()
    }

    // MARK: - Pro Status Check

    /// Check if user has Pro access (uses SubscriptionManager)
    var isPro: Bool {
        SubscriptionManager.shared.isPro || StoreManager.shared.isPro
    }

    // MARK: - History Limitation

    /// Returns the number of days of history the user can access
    /// Free: 30 days, Pro: Unlimited (365 * 10 = 10 years, effectively all HealthKit data)
    var historyDaysAllowed: Int {
        isPro ? 3650 : Self.historyDaysLimit
    }

    /// Filters history data based on user's tier
    func filterHistoryData<T>(_ data: [T], dateKeyPath: KeyPath<T, Date>) -> [T] {
        guard !isPro else { return data }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -Self.historyDaysLimit, to: Date()) ?? Date()

        return data.filter { item in
            item[keyPath: dateKeyPath] >= cutoffDate
        }
    }

    /// Check if user can view extended history
    var canViewExtendedHistory: Bool {
        isPro
    }

    // MARK: - Coaching Tips Limitation

    /// Check if user can receive a new coaching tip
    var canReceiveCoachingTip: Bool {
        if isPro { return true }
        resetTipsIfNewDay()
        return coachingTipsShownToday < Self.dailyCoachingTipsLimit
    }

    /// Remaining tips for free users today
    var remainingTipsToday: Int {
        if isPro { return Int.max }
        resetTipsIfNewDay()
        return max(0, Self.dailyCoachingTipsLimit - coachingTipsShownToday)
    }

    /// Record that a coaching tip was shown
    func recordCoachingTipShown() {
        guard !isPro else { return }
        resetTipsIfNewDay()
        coachingTipsShownToday += 1
        saveState()
    }

    /// Reset tips counter if it's a new day
    private func resetTipsIfNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastReset = lastTipResetDate {
            let lastResetDay = calendar.startOfDay(for: lastReset)
            if today > lastResetDay {
                coachingTipsShownToday = 0
                lastTipResetDate = today
                saveState()
            }
        } else {
            lastTipResetDate = today
            saveState()
        }
    }

    // MARK: - Leaderboard Limitation

    /// Number of leaderboard members visible to user
    var leaderboardVisibleCount: Int {
        isPro ? Int.max : Self.leaderboardVisibleMembers
    }

    /// Check if user can see full leaderboard
    var canViewFullLeaderboard: Bool {
        isPro
    }

    /// Filter leaderboard members based on user's tier
    func filterLeaderboard<T>(_ members: [T]) -> [T] {
        guard !isPro else { return members }
        return Array(members.prefix(Self.leaderboardVisibleMembers))
    }

    /// Get count of hidden members (for upsell messaging)
    func hiddenMemberCount<T>(_ members: [T]) -> Int {
        guard !isPro else { return 0 }
        return max(0, members.count - Self.leaderboardVisibleMembers)
    }

    // MARK: - Magic Route Limitation

    /// Check if user can START a magic route walk today
    /// Note: Generation is unlimited; this only restricts starting the actual walk
    var canStartMagicRouteToday: Bool {
        if isPro { return true }
        resetMagicRouteIfNewDay()
        return magicRoutesStartedToday < Self.dailyMagicRouteLimit
    }

    /// Remaining magic route walks for free users today
    var remainingMagicRoutesToday: Int {
        if isPro { return Int.max }
        resetMagicRouteIfNewDay()
        return max(0, Self.dailyMagicRouteLimit - magicRoutesStartedToday)
    }

    /// Record that a magic route walk was STARTED (not just generated)
    /// Call this when the user taps "Walk This Route"
    func recordMagicRouteWalkStarted() {
        guard !isPro else { return }
        resetMagicRouteIfNewDay()
        magicRoutesStartedToday += 1
        saveMagicRouteState()
    }

    /// Reset magic route counter if it's a new day
    private func resetMagicRouteIfNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastReset = lastMagicRouteResetDate {
            let lastResetDay = calendar.startOfDay(for: lastReset)
            if today > lastResetDay {
                magicRoutesStartedToday = 0
                lastMagicRouteResetDate = today
                saveMagicRouteState()
            }
        } else {
            lastMagicRouteResetDate = today
            saveMagicRouteState()
        }
    }

    // MARK: - Power Walk Free Trial

    private let powerWalkFreeTrialUsedKey = "freeTier_powerWalkTrialUsed"

    /// Check if user has used their one free Power Walk trial
    var hasUsedPowerWalkFreeTrial: Bool {
        UserDefaults.standard.bool(forKey: powerWalkFreeTrialUsedKey)
    }

    /// Record that the user has used their free Power Walk trial
    func recordPowerWalkFreeTrialUsed() {
        UserDefaults.standard.set(true, forKey: powerWalkFreeTrialUsedKey)
    }

    // MARK: - Persistence

    private let tipsShownKey = "freeTier_coachingTipsShownToday"
    private let lastResetKey = "freeTier_lastTipResetDate"
    private let magicRoutesStartedKey = "freeTier_magicRoutesStartedToday"
    private let lastMagicRouteResetKey = "freeTier_lastMagicRouteResetDate"

    private func saveState() {
        UserDefaults.standard.set(coachingTipsShownToday, forKey: tipsShownKey)
        if let date = lastTipResetDate {
            UserDefaults.standard.set(date, forKey: lastResetKey)
        }
    }

    private func saveMagicRouteState() {
        UserDefaults.standard.set(magicRoutesStartedToday, forKey: magicRoutesStartedKey)
        if let date = lastMagicRouteResetDate {
            UserDefaults.standard.set(date, forKey: lastMagicRouteResetKey)
        }
    }

    private func loadState() {
        coachingTipsShownToday = UserDefaults.standard.integer(forKey: tipsShownKey)
        lastTipResetDate = UserDefaults.standard.object(forKey: lastResetKey) as? Date
        magicRoutesStartedToday = UserDefaults.standard.integer(forKey: magicRoutesStartedKey)
        lastMagicRouteResetDate = UserDefaults.standard.object(forKey: lastMagicRouteResetKey) as? Date
    }

    // MARK: - Debug

    /// Reset all limitations (for testing)
    func resetForTesting() {
        coachingTipsShownToday = 0
        lastTipResetDate = nil
        magicRoutesStartedToday = 0
        lastMagicRouteResetDate = nil
        UserDefaults.standard.removeObject(forKey: tipsShownKey)
        UserDefaults.standard.removeObject(forKey: lastResetKey)
        UserDefaults.standard.removeObject(forKey: magicRoutesStartedKey)
        UserDefaults.standard.removeObject(forKey: lastMagicRouteResetKey)
    }
}
