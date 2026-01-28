//
//  ShieldManager.swift
//  JustWalk
//
//  Shield economy with auto-deploy, retroactive repair, and allocation logic
//

import Foundation

@Observable
class ShieldManager {
    static let shared = ShieldManager()

    private let persistence = PersistenceManager.shared
    private let streakManager = StreakManager.shared

    var shieldData: ShieldData = .empty

    /// Set when a shield was auto-deployed overnight
    var lastDeployedOvernight: Bool = false

    private init() {}

    // MARK: - Initialization

    func load() {
        shieldData = persistence.loadShieldData()
        refillIfNeeded()
    }

    // MARK: - Monthly Refill

    func refillIfNeeded() {
        let isPro = SubscriptionManager.shared.isPro
        shieldData.refillIfNeeded(isPro: isPro)
        persistence.saveShieldData(shieldData)
    }

    // MARK: - Auto-Deploy

    /// Call this at end of day (or app launch next day) when goal was not met
    /// Returns true if shield was deployed
    /// When `silent == true`, skips notification and haptics (used for batch deployment on app open)
    @discardableResult
    func autoDeployIfAvailable(forDate date: Date, silent: Bool = false) -> Bool {
        guard shieldData.availableShields > 0 else { return false }

        // Use a shield
        shieldData.availableShields -= 1
        shieldData.shieldsUsedThisMonth += 1
        shieldData.totalShieldsUsed += 1
        persistence.saveShieldData(shieldData)

        // Update streak (preserves count but doesn't contribute to weekly jackpot)
        streakManager.recordShieldUsed(forDate: date)

        // Update daily log
        if var log = persistence.loadDailyLog(for: date) {
            log.shieldUsed = true
            persistence.saveDailyLog(log)
        } else {
            // Create log for missed day (user didn't open app)
            let newLog = DailyLog(id: UUID(), date: date, steps: 0, goalMet: false,
                                  shieldUsed: true, trackedWalkIDs: [])
            persistence.saveDailyLog(newLog)
        }

        // Flag for dynamic card engine
        lastDeployedOvernight = true

        if !silent {
            // Send notification
            NotificationManager.shared.sendShieldDeployedNotification(remainingShields: shieldData.availableShields)

            // Haptic
            HapticsManager.shared.shieldAutoDeploy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                JustWalkHaptics.success()
            }
        }

        return true
    }

    // MARK: - Missed Day Check

    struct MissedDayResult {
        let shieldsDeployed: Int
        let streakBroken: Bool
    }

    /// Check for missed days since last goal and auto-deploy shields.
    /// Called on app open to retroactively protect the streak.
    @discardableResult
    func checkAndDeployForMissedDays() -> MissedDayResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // No streak → nothing to protect
        guard streakManager.streakData.currentStreak > 0 else {
            return MissedDayResult(shieldsDeployed: 0, streakBroken: false)
        }

        // No last goal date → nothing to check
        guard let lastGoalDate = streakManager.streakData.lastGoalMetDate else {
            return MissedDayResult(shieldsDeployed: 0, streakBroken: false)
        }

        let lastGoalDay = calendar.startOfDay(for: lastGoalDate)
        guard let daysBetween = calendar.dateComponents([.day], from: lastGoalDay, to: today).day,
              daysBetween > 1 else {
            // No gap (0 = today, 1 = yesterday was last goal day → no missed day yet)
            return MissedDayResult(shieldsDeployed: 0, streakBroken: false)
        }

        var shieldsDeployed = 0
        var streakBroken = false

        // Iterate each missed day: day after lastGoalDate through yesterday
        for offset in 1..<daysBetween {
            guard let missedDate = calendar.date(byAdding: .day, value: offset, to: lastGoalDay) else { continue }

            // Skip if goal was actually met (HealthKit sync lag) or shield already used
            if let log = persistence.loadDailyLog(for: missedDate) {
                if log.goalMet || log.shieldUsed { continue }
            }

            // Try to deploy shield (silent — user is in-app, DynamicCard handles UX)
            if autoDeployIfAvailable(forDate: missedDate, silent: true) {
                shieldsDeployed += 1
            } else {
                // No shields left → streak breaks
                streakManager.breakStreak()
                streakBroken = true
                break
            }
        }

        // If any shields deployed, set flag for DynamicCard
        if shieldsDeployed > 0 {
            lastDeployedOvernight = true
        }

        return MissedDayResult(shieldsDeployed: shieldsDeployed, streakBroken: streakBroken)
    }

    // MARK: - Queries

    var availableShields: Int {
        shieldData.availableShields
    }

    var canBuyMoreShields: Bool {
        shieldData.availableShields < ShieldData.maxBanked(isPro: SubscriptionManager.shared.isPro)
    }

    var shieldsUsedThisMonth: Int {
        shieldData.shieldsUsedThisMonth
    }

    var nextRefillDate: Date? {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) else { return nil }
        return calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))
    }

    var nextRefillDateFormatted: String {
        guard let date = nextRefillDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Shield Purchases (IAP integration hook)

    func addPurchasedShields(_ count: Int) {
        shieldData.purchasedShields += count
        shieldData.availableShields = min(
            shieldData.availableShields + count,
            ShieldData.maxBanked(isPro: SubscriptionManager.shared.isPro)
        )
        persistence.saveShieldData(shieldData)
    }

    // MARK: - Event Flag Clearing

    func clearLastDeployedOvernight() {
        lastDeployedOvernight = false
    }

    // MARK: - Retroactive Repair API

    /// Returns true if the given date is eligible for repair with a shield.
    /// Rules: within the last 7 days (not today), and the day is missing or not already marked as goalMet/shieldUsed.
    func canRepairDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        guard let days = calendar.dateComponents([.day], from: target, to: today).day else { return false }
        guard days > 0 && days <= 7 else { return false }

        if let log = persistence.loadDailyLog(for: target) {
            if log.goalMet || log.shieldUsed { return false }
        }

        return true
    }

    /// Attempts to repair the given date using one shield. Returns true on success.
    @discardableResult
    func repairDate(_ date: Date) -> Bool {
        guard canRepairDate(date) else { return false }
        guard shieldData.availableShields > 0 else { return false }

        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)

        if var log = persistence.loadDailyLog(for: target) {
            log.goalMet = true
            log.shieldUsed = true
            persistence.saveDailyLog(log)
        } else {
            let newLog = DailyLog(id: UUID(), date: target, steps: 0, goalMet: true, shieldUsed: true, trackedWalkIDs: [])
            persistence.saveDailyLog(newLog)
        }

        // Consume shield
        shieldData.availableShields -= 1
        shieldData.shieldsUsedThisMonth += 1
        shieldData.totalShieldsUsed += 1
        persistence.saveShieldData(shieldData)

        // Update streak state to reflect a repaired day
        streakManager.recordShieldUsed(forDate: target)

        return true
    }
}
