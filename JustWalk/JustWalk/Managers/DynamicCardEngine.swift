//
//  DynamicCardEngine.swift
//  JustWalk
//
//  4-tier card evaluation: P0 (smart walk) → P1 (urgent) → P2 (contextual) → P3 (fallback tips)
//  Always shows one card — never empty.
//

import Combine
import Foundation

@MainActor
final class DynamicCardEngine: ObservableObject {
    static let shared = DynamicCardEngine()

    private let streakManager = StreakManager.shared
    private let shieldManager = ShieldManager.shared
    private let persistence = PersistenceManager.shared

    /// Always has a value — guaranteed fallback via P3 tips
    @Published var currentCard: DynamicCardType = .tip(DailyTip.allTips[0])

    // MARK: - Walk Pattern Analysis

    /// Cached user walk pattern (refreshed periodically)
    private var cachedWalkPattern: WalkPatternResult?
    private var lastPatternAnalysis: Date?
    private let patternAnalysisCooldown: TimeInterval = 3600 // 1 hour

    // MARK: - Tip Recency Tracking

    /// IDs of recently shown tips (to avoid repeats)
    private var recentTipIds: [Int] = []

    /// Current session's tip (persists during app session, changes on app open)
    private var sessionTip: DailyTip?
    
    /// Testing mode: when `true` certain time/day based P2 checks are skipped to keep tests deterministic.
    private var isTesting: Bool = false

    // MARK: - Streak Protection Tracking

    /// Dates where streak protection has been addressed (user chose to use shield or break)
    /// Stored as day keys (yyyy-MM-dd) to prevent re-showing the card
    private var addressedStreakDates: Set<String> = []

    // MARK: - Frequency Tracking

    /// Show counts per card per day
    private var cardShowCounts: [String: Int] = [:]

    /// Cards acted upon today (button tapped)
    private var actedUponToday: Set<String> = []

    /// Last date daily counters were reset
    private var lastResetDate: Date?

    // MARK: - Fuel Upsell Tracking

    /// Streak milestones that trigger fuel upsell for free users
    private let fuelUpsellMilestones: Set<Int> = [7, 14, 21, 30, 60, 90]

    /// Milestones where user dismissed the fuel upsell (won't show again for those)
    private var dismissedFuelUpsellMilestones: Set<Int> = []

    // MARK: - Evaluation Rate Limiting

    private var lastEvaluationTime: Date?
    private let evaluationCooldown: TimeInterval = 2.0

    private func shouldEvaluate() -> Bool {
        guard let lastTime = lastEvaluationTime else { return true }
        return Date().timeIntervalSince(lastTime) >= evaluationCooldown
    }

    // MARK: - Debug Logging

    #if DEBUG
    private func debugLog(_ message: String) {
        print("[DynamicCardEngine] \(message)")
    }
    #else
    private func debugLog(_ message: String) {}
    #endif

    private init() {
        loadShowCounts()
        loadActedUpon()
        loadRecentTipIds()
        loadAddressedStreakDates()
        loadDismissedFuelUpsellMilestones()
        lastResetDate = UserDefaults.standard.object(forKey: "dynamic_card_last_reset") as? Date
        checkAndResetDaily()

        // Pick a random tip for this app session
        sessionTip = pickRandomTip()
    }

    // MARK: - Time / Date Helpers

    private func isAfter5PM() -> Bool {
        Calendar.current.component(.hour, from: Date()) >= 17
    }

    private func isAfter7PM() -> Bool {
        Calendar.current.component(.hour, from: Date()) >= 19
    }

    private func isMonday() -> Bool {
        Calendar.current.component(.weekday, from: Date()) == 2 // 1=Sun … 2=Mon
    }

    private func isWeekend() -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7 // Sun or Sat
    }

    // MARK: - Evaluation

    func evaluate(dailyGoal: Int, currentSteps: Int) -> DynamicCardType {
        guard shouldEvaluate() else {
            debugLog("Evaluation skipped (cooldown)")
            return currentCard
        }
        lastEvaluationTime = Date()

        checkAndResetDaily()

        let result = evaluateInternal(dailyGoal: dailyGoal, currentSteps: currentSteps)

        // Increment show count when displaying a new card, then update currentCard
        if currentCard.cardKey != result.cardKey {
            debugLog("New card: \(result.cardKey)")
            incrementShowCount(result)
        }

        currentCard = result

        return result
    }

    private func evaluateInternal(dailyGoal: Int, currentSteps: Int) -> DynamicCardType {
        // 0. P0 Critical — Streak Protection (requires immediate user decision)
        if let p0Critical = evaluateP0Critical() {
            return p0Critical
        }

        // 0.5. P0 — Smart Walk Invitation (highest priority)
        if let p0 = evaluateP0SmartWalk(dailyGoal: dailyGoal, currentSteps: currentSteps) {
            return p0
        }

        // 1. P1 — Urgent
        if let p1 = evaluateP1(dailyGoal: dailyGoal, currentSteps: currentSteps) {
            return p1
        }

        // 2. P2 — Contextual
        if let p2 = evaluateP2(dailyGoal: dailyGoal, currentSteps: currentSteps) {
            return p2
        }

        // 3. P3 — Fallback tip (deterministic daily rotation)
        return evaluateP3Tip()
    }

    // MARK: - P0 Critical Evaluation (Streak Protection)

    private func evaluateP0Critical() -> DynamicCardType? {
        // Check if yesterday's goal was missed and user has an active streak + shields
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }

        let yesterdayKey = makeDayKey(for: yesterday)

        // Skip if already addressed for this date
        guard !addressedStreakDates.contains(yesterdayKey) else {
            return nil
        }

        // Check if user has an active streak
        let currentStreak = streakManager.streakData.currentStreak
        guard currentStreak > 0 else {
            return nil
        }

        // Check if user has shields available
        guard shieldManager.availableShields > 0 else {
            return nil
        }

        // Check if yesterday's goal was NOT met
        if let yesterdayLog = persistence.loadDailyLog(for: yesterday) {
            // If goal was met or shield already used, no need for protection
            if yesterdayLog.goalMet || yesterdayLog.shieldUsed {
                return nil
            }
        } else {
            // No log for yesterday means they didn't open the app
            // Check if yesterday even happened (first day of using app?)
            guard let streakStart = streakManager.streakData.streakStartDate,
                  yesterday >= streakStart else {
                return nil
            }
        }

        // All conditions met: show streak protection card
        let card = DynamicCardType.streakProtection(streakDays: currentStreak, missedDate: yesterday)
        if canShowToday(card) {
            return card
        }

        return nil
    }

    /// Creates a day key string for date tracking (yyyy-MM-dd format)
    private func makeDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - P0 Evaluation (Smart Walk Invitation)

    private func evaluateP0SmartWalk(dailyGoal: Int, currentSteps: Int) -> DynamicCardType? {
        // Skip in testing mode
        if isTesting { return nil }

        let goalMet = currentSteps >= dailyGoal
        let stepsRemaining = max(dailyGoal - currentSteps, 0)
        let hour = Calendar.current.component(.hour, from: Date())

        // Priority 1: Pattern-based suggestion (user typically walks around now)
        if let patternCheck = isNearTypicalWalkTime(), patternCheck.isNear {
            let card = DynamicCardType.smartWalkPattern(preferredMode: patternCheck.preferredMode)
            if canShowToday(card) { return card }
        }

        // Priority 2: Close to goal (< 1,000 steps remaining)
        if !goalMet && stepsRemaining < 1000 {
            let card = DynamicCardType.smartWalkCloseToGoal(stepsRemaining: stepsRemaining)
            if canShowToday(card) { return card }
        }

        // Priority 3: Post-meal windows (12:00-1:30pm or 6:00-8:00pm)
        if !goalMet && isPostMealWindow(hour: hour) {
            let card = DynamicCardType.smartWalkPostMeal
            if canShowToday(card) { return card }
        }

        // Priority 4: Evening rescue (after 6pm, goal not met, < 3,000 steps remaining)
        if !goalMet && hour >= 18 && stepsRemaining < 3000 && stepsRemaining >= 1000 {
            let card = DynamicCardType.smartWalkEveningRescue(stepsRemaining: stepsRemaining)
            if canShowToday(card) { return card }
        }

        // Priority 5: Morning invitation (6-9am, < 1,000 steps so far)
        if !goalMet && hour >= 6 && hour < 9 && currentSteps < 1000 {
            let card = DynamicCardType.smartWalkMorning
            if canShowToday(card) { return card }
        }

        // Priority 6: Goal already met (bonus walk suggestion)
        if goalMet {
            let card = DynamicCardType.smartWalkGoalMet
            if canShowToday(card) { return card }
        }

        // Priority 7: Default (fallback smart walk prompt)
        // Only show if no other card would show and user hasn't walked today
        let todayWalks = getTodayWalkCount()
        if todayWalks == 0 {
            let card = DynamicCardType.smartWalkDefault
            if canShowToday(card) { return card }
        }

        return nil
    }

    private func isPostMealWindow(hour: Int) -> Bool {
        // Lunch window: 12:00pm - 1:30pm (hours 12-13)
        // Dinner window: 6:00pm - 8:00pm (hours 18-19)
        return (hour >= 12 && hour <= 13) || (hour >= 18 && hour <= 19)
    }

    private func getTodayWalkCount() -> Int {
        let log = persistence.loadDailyLog(for: Date())
        return log?.trackedWalkIDs.count ?? 0
    }

    // MARK: - P1 Evaluation (Urgent)

    private func evaluateP1(dailyGoal: Int, currentSteps: Int) -> DynamicCardType? {
        let goalMet = currentSteps >= dailyGoal

        // Streak at risk: 7PM+, goal not met, active streak
        if isAfter7PM() && !goalMet && streakManager.streakData.currentStreak >= 1 {
            let card = DynamicCardType.streakAtRisk(stepsRemaining: max(dailyGoal - currentSteps, 0))
            if canShowToday(card) { return card }
        }

        // Shield deployed overnight
        if shieldManager.lastDeployedOvernight {
            let card = DynamicCardType.shieldDeployed(
                remainingShields: shieldManager.availableShields,
                nextRefill: shieldManager.nextRefillDateFormatted
            )
            if canShowToday(card) { return card }
        }

        // Welcome back: streak was broken (currentStreak == 0 and had a streak before)
        if streakManager.streakData.currentStreak == 0 && streakManager.streakData.longestStreak > 0 {
            let card = DynamicCardType.welcomeBack
            if canShowToday(card) { return card }
        }

        return nil
    }

    // MARK: - P2 Evaluation (Contextual)

    private func evaluateP2(dailyGoal: Int, currentSteps: Int) -> DynamicCardType? {
        // In testing mode skip contextual P2 checks to keep evaluation deterministic.
        if isTesting { return nil }
        let goalMet = currentSteps >= dailyGoal

        // Almost there: after 5PM, 50-99% of goal
        if !isTesting && isAfter5PM() && !goalMet && dailyGoal > 0 {
            let progress = Double(currentSteps) / Double(dailyGoal)
            if progress >= 0.5 {
                let card = DynamicCardType.almostThere(stepsRemaining: dailyGoal - currentSteps)
                if canShowToday(card) { return card }
            }
        }

        // Milestone celebration
        if let event = MilestoneManager.shared.popNextTier2() {
            let card = DynamicCardType.milestoneCelebration(event: event)
            if canShowToday(card) { return card }
        }

        // Fuel milestone upsell: free users at streak milestones
        if !SubscriptionManager.shared.isPro {
            let currentStreak = streakManager.streakData.currentStreak
            if fuelUpsellMilestones.contains(currentStreak) &&
               !dismissedFuelUpsellMilestones.contains(currentStreak) {
                let card = DynamicCardType.fuelMilestoneUpsell(streakDays: currentStreak)
                if canShowToday(card) { return card }
            }
        }

        // Insight card (pattern-based personalization, rare)
        if let insightCard = InsightCardManager.shared.selectInsight() {
            let card = DynamicCardType.insight(insightCard)
            if canShowToday(card) {
                InsightCardManager.shared.markInsightShown(insightCard.type)
                return card
            }
        }

        // Try intervals: user has free usage remaining
        if let remaining = WalkUsageManager.shared.remainingFree(for: .interval), remaining > 0 {
            let card = DynamicCardType.tryIntervals
            if canShowToday(card) { return card }
        }

        // Try sync with Watch: Watch not paired
        if !PhoneConnectivityManager.shared.canCommunicateWithWatch {
            let card = DynamicCardType.trySyncWithWatch
            if canShowToday(card) { return card }
        }

        // New week new goal: Monday
        if !isTesting && isMonday() {
            let card = DynamicCardType.newWeekNewGoal
            if canShowToday(card) { return card }
        }

        // Weekend warrior: Saturday/Sunday
        if !isTesting && isWeekend() {
            let card = DynamicCardType.weekendWarrior
            if canShowToday(card) { return card }
        }

        // Evening nudge: after 5PM, goal not yet met
        if !isTesting && isAfter5PM() && !goalMet && dailyGoal > 0 {
            let card = DynamicCardType.eveningNudge(stepsRemaining: max(dailyGoal - currentSteps, 0))
            if canShowToday(card) { return card }
        }

        return nil
    }

    // MARK: - P3 Evaluation (Fallback Tips)

    private func evaluateP3Tip() -> DynamicCardType {
        // Use the session tip (picked on app open)
        if let tip = sessionTip {
            return .tip(tip)
        }
        // Fallback: pick a new random tip
        return .tip(pickRandomTip())
    }

    // MARK: - Tip Rotation (Random with Recency Filter)

    /// Pick a random tip, avoiding recently shown ones
    private func pickRandomTip() -> DailyTip {
        let allTips = DailyTip.allTips

        // Get tip IDs not recently shown
        let availableIds = allTips.map(\.id).filter { !recentTipIds.contains($0) }

        // If we've shown most tips, allow all except the last 10
        let idsToChooseFrom: [Int]
        if availableIds.isEmpty {
            let last10 = Set(recentTipIds.suffix(10))
            idsToChooseFrom = allTips.map(\.id).filter { !last10.contains($0) }
        } else {
            idsToChooseFrom = availableIds
        }

        // Pick a random tip ID
        let chosenId = idsToChooseFrom.randomElement() ?? 1

        // Track this tip as recently shown (keep last 25)
        recentTipIds.append(chosenId)
        if recentTipIds.count > 25 {
            recentTipIds.removeFirst()
        }
        saveRecentTipIds()

        // Return the chosen tip
        return allTips.first { $0.id == chosenId } ?? allTips[0]
    }

    /// Called when app opens to get a new random tip
    func refreshSessionTip() {
        sessionTip = pickRandomTip()
    }

    // MARK: - Frequency / Show Limits

    private func canShowToday(_ cardType: DynamicCardType) -> Bool {
        let key = cardType.cardKey

        // Check if acted upon today (soft dismiss) - this takes priority
        if actedUponToday.contains(key) {
            return false
        }

        // Allow the currently displayed card to persist across refreshes
        // (but only if not acted upon)
        if key == currentCard.cardKey {
            return true
        }

        // Check frequency limits
        let currentCount = cardShowCounts[key] ?? 0
        let maxShows = maxShowsPerDay(for: cardType)
        return currentCount < maxShows
    }

    private func maxShowsPerDay(for cardType: DynamicCardType) -> Int {
        switch cardType {
        // P0 — Critical (show once per day)
        case .streakProtection:      return 1
        // P0.5 — Smart Walk (show once per day each)
        case .smartWalkPattern:      return 1
        case .smartWalkPostMeal:     return 1
        case .smartWalkEveningRescue: return 1
        case .smartWalkCloseToGoal:  return 1
        case .smartWalkMorning:      return 1
        case .smartWalkGoalMet:      return 1
        case .smartWalkDefault:      return 1
        // P1 — Urgent
        case .streakAtRisk:          return 1
        case .shieldDeployed:        return 1
        case .welcomeBack:           return 1
        // P2 — Contextual
        case .almostThere:           return 1
        case .milestoneCelebration:  return 1
        case .fuelMilestoneUpsell:   return 1
        case .tryIntervals:          return 1
        case .trySyncWithWatch:      return 1
        case .newWeekNewGoal:        return 1
        case .weekendWarrior:        return 1
        case .eveningNudge:          return 1
        // P2.5 — Insight
        case .insight:               return 1
        // P3 — Tips
        case .tip:                   return 999 // tips always available as fallback
        }
    }

    func incrementShowCount(_ cardType: DynamicCardType) {
        let key = cardType.cardKey
        cardShowCounts[key] = (cardShowCounts[key] ?? 0) + 1
        saveShowCounts()
    }

    func markAsActedUpon(_ cardType: DynamicCardType) {
        actedUponToday.insert(cardType.cardKey)
        saveActedUpon()
    }

    // MARK: - Daily Reset

    private func checkAndResetDaily() {
        let calendar = Calendar.current
        let now = Date()

        if let lastReset = lastResetDate {
            if !calendar.isDate(lastReset, inSameDayAs: now) {
                performDailyReset()
            }
        } else {
            performDailyReset()
        }
    }

    func performDailyReset() {
        cardShowCounts.removeAll()
        actedUponToday.removeAll()

        lastResetDate = Date()
        saveShowCounts()
        saveActedUpon()
        UserDefaults.standard.set(lastResetDate, forKey: "dynamic_card_last_reset")
    }

    /// Public entry point for TodayView to trigger daily reset on date change
    func checkDailyReset() {
        checkAndResetDaily()
    }

    // MARK: - Refresh

    func refresh(dailyGoal: Int, currentSteps: Int) {
        // Reset cooldown for explicit refresh
        lastEvaluationTime = nil
        currentCard = evaluate(dailyGoal: dailyGoal, currentSteps: currentSteps)
    }

    // MARK: - Persistence

    private func saveShowCounts() {
        UserDefaults.standard.set(cardShowCounts, forKey: "dynamic_card_show_counts")
    }

    private func loadShowCounts() {
        if let counts = UserDefaults.standard.dictionary(forKey: "dynamic_card_show_counts") as? [String: Int] {
            cardShowCounts = counts
        }
    }

    private func saveActedUpon() {
        UserDefaults.standard.set(Array(actedUponToday), forKey: "dynamic_card_acted_upon")
    }

    private func loadActedUpon() {
        if let acted = UserDefaults.standard.stringArray(forKey: "dynamic_card_acted_upon") {
            actedUponToday = Set(acted)
        }
    }

    private func saveRecentTipIds() {
        UserDefaults.standard.set(recentTipIds, forKey: "dynamic_card_recent_tip_ids")
    }

    private func loadRecentTipIds() {
        if let ids = UserDefaults.standard.array(forKey: "dynamic_card_recent_tip_ids") as? [Int] {
            recentTipIds = ids
        }
    }

    private func saveAddressedStreakDates() {
        UserDefaults.standard.set(Array(addressedStreakDates), forKey: "dynamic_card_addressed_streak_dates")
    }

    private func loadAddressedStreakDates() {
        if let dates = UserDefaults.standard.stringArray(forKey: "dynamic_card_addressed_streak_dates") {
            addressedStreakDates = Set(dates)
        }
    }

    private func saveDismissedFuelUpsellMilestones() {
        UserDefaults.standard.set(Array(dismissedFuelUpsellMilestones), forKey: "dynamic_card_dismissed_fuel_milestones")
    }

    private func loadDismissedFuelUpsellMilestones() {
        if let milestones = UserDefaults.standard.array(forKey: "dynamic_card_dismissed_fuel_milestones") as? [Int] {
            dismissedFuelUpsellMilestones = Set(milestones)
        }
    }

    // MARK: - Streak Protection Actions

    /// Marks a date as addressed for streak protection (prevents card from showing again for that date)
    func markStreakProtectionAddressed(for date: Date) {
        let key = makeDayKey(for: date)
        addressedStreakDates.insert(key)
        saveAddressedStreakDates()
        debugLog("Marked streak protection addressed for \(key)")
    }

    // MARK: - Fuel Upsell Actions

    /// Marks a fuel upsell milestone as dismissed (won't show again for this milestone)
    func markFuelUpsellDismissed(milestone: Int) {
        dismissedFuelUpsellMilestones.insert(milestone)
        saveDismissedFuelUpsellMilestones()
        debugLog("Marked fuel upsell dismissed for milestone \(milestone)")
    }

    // MARK: - Testing Support

    func resetForTesting() {
        currentCard = .tip(DailyTip.allTips[0])
        cardShowCounts.removeAll()
        actedUponToday.removeAll()
        recentTipIds.removeAll()
        addressedStreakDates.removeAll()
        dismissedFuelUpsellMilestones.removeAll()
        sessionTip = nil
        isTesting = true
        lastEvaluationTime = nil
        lastResetDate = nil
        cachedWalkPattern = nil
        lastPatternAnalysis = nil
        saveShowCounts()
        saveActedUpon()
        saveRecentTipIds()
        saveAddressedStreakDates()
        saveDismissedFuelUpsellMilestones()
    }

    // MARK: - Walk Pattern Analysis

    /// Analyzes user's walk history to detect typical walking time and preferred mode
    private func analyzeWalkPatterns() -> WalkPatternResult? {
        // Check cache
        if let cached = cachedWalkPattern,
           let lastAnalysis = lastPatternAnalysis,
           Date().timeIntervalSince(lastAnalysis) < patternAnalysisCooldown {
            return cached
        }

        // Load recent walks (last 30 days)
        let allWalks = persistence.loadAllTrackedWalks()
            .filter(\.isDisplayable)

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWalks = allWalks.filter { $0.startTime >= thirtyDaysAgo }

        // Need at least 5 walks to establish a pattern
        guard recentWalks.count >= 5 else {
            cachedWalkPattern = nil
            lastPatternAnalysis = Date()
            return nil
        }

        // Analyze walk times (group by hour)
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        var modeCounts: [WalkMode: Int] = [:]

        for walk in recentWalks {
            let hour = calendar.component(.hour, from: walk.startTime)
            hourCounts[hour, default: 0] += 1
            modeCounts[walk.mode, default: 0] += 1
        }

        // Find most common hour (with ±1 hour tolerance)
        var bestHourRange: (start: Int, count: Int) = (0, 0)
        for hour in 0..<24 {
            let count = (hourCounts[hour] ?? 0)
                + (hourCounts[(hour + 23) % 24] ?? 0)  // hour - 1
                + (hourCounts[(hour + 1) % 24] ?? 0)   // hour + 1
            if count > bestHourRange.count {
                bestHourRange = (hour, count)
            }
        }

        // Find most common mode
        let preferredMode = modeCounts.max(by: { $0.value < $1.value })?.key ?? .free

        // Only return pattern if it's strong enough (at least 40% of walks in that window)
        let patternStrength = Double(bestHourRange.count) / Double(recentWalks.count)
        guard patternStrength >= 0.4 else {
            cachedWalkPattern = nil
            lastPatternAnalysis = Date()
            return nil
        }

        let result = WalkPatternResult(
            typicalHour: bestHourRange.start,
            preferredMode: preferredMode,
            walkCount: recentWalks.count,
            patternStrength: patternStrength
        )

        cachedWalkPattern = result
        lastPatternAnalysis = Date()
        return result
    }

    /// Checks if current time is within ±30 minutes of user's typical walk time
    private func isNearTypicalWalkTime() -> (isNear: Bool, preferredMode: WalkMode)? {
        guard let pattern = analyzeWalkPatterns() else { return nil }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let currentMinute = calendar.component(.minute, from: Date())

        // Convert to minutes from midnight for easier comparison
        let currentMinutes = currentHour * 60 + currentMinute
        let typicalMinutes = pattern.typicalHour * 60 + 30 // middle of the typical hour

        // Check if within ±30 minutes
        let difference = abs(currentMinutes - typicalMinutes)
        let isNear = difference <= 30 || difference >= (24 * 60 - 30) // handle midnight wrap

        return (isNear, pattern.preferredMode)
    }
}

// MARK: - Walk Pattern Result

struct WalkPatternResult {
    let typicalHour: Int          // 0-23, the hour user typically walks
    let preferredMode: WalkMode   // Most used walk mode
    let walkCount: Int            // Number of walks analyzed
    let patternStrength: Double   // 0.0-1.0, how strong the pattern is
}
