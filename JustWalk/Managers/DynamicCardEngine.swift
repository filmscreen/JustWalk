//
//  DynamicCardEngine.swift
//  JustWalk
//
//  3-tier card evaluation: P1 (urgent) → P2 (contextual) → P3 (fallback tips)
//  Always shows one card — never empty.
//

import Foundation

@Observable
class DynamicCardEngine {
    static let shared = DynamicCardEngine()

    private let streakManager = StreakManager.shared
    private let shieldManager = ShieldManager.shared
    private let persistence = PersistenceManager.shared

    /// Always has a value — guaranteed fallback via P3 tips
    var currentCard: DynamicCardType = .tip(DailyTip.allTips[0])

    // MARK: - Tip Recency Tracking

    /// IDs of recently shown tips (to avoid repeats)
    private var recentTipIds: [Int] = []

    /// Current session's tip (persists during app session, changes on app open)
    private var sessionTip: DailyTip?

    // MARK: - Frequency Tracking

    /// Show counts per card per day
    private var cardShowCounts: [String: Int] = [:]

    /// Cards acted upon today (button tapped)
    private var actedUponToday: Set<String> = []

    /// Last date daily counters were reset
    private var lastResetDate: Date?

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

        // Increment show count when displaying a new card
        if currentCard.cardKey != result.cardKey {
            debugLog("New card: \(result.cardKey)")
            incrementShowCount(result)
        }

        return result
    }

    private func evaluateInternal(dailyGoal: Int, currentSteps: Int) -> DynamicCardType {
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
        let goalMet = currentSteps >= dailyGoal

        // Almost there: after 5PM, 50-99% of goal
        if isAfter5PM() && !goalMet && dailyGoal > 0 {
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
        if isMonday() {
            let card = DynamicCardType.newWeekNewGoal
            if canShowToday(card) { return card }
        }

        // Weekend warrior: Saturday/Sunday
        if isWeekend() {
            let card = DynamicCardType.weekendWarrior
            if canShowToday(card) { return card }
        }

        // Evening nudge: after 5PM, goal not yet met
        if isAfter5PM() && !goalMet && dailyGoal > 0 {
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

        // Check if acted upon today
        if actedUponToday.contains(key) {
            return false
        }

        // Check frequency limits
        let currentCount = cardShowCounts[key] ?? 0
        let maxShows = maxShowsPerDay(for: cardType)
        return currentCount < maxShows
    }

    private func maxShowsPerDay(for cardType: DynamicCardType) -> Int {
        switch cardType {
        case .streakAtRisk:          return 1
        case .shieldDeployed:        return 1
        case .welcomeBack:           return 1
        case .almostThere:           return 1
        case .milestoneCelebration:  return 1
        case .tryIntervals:          return 1
        case .trySyncWithWatch:      return 1
        case .newWeekNewGoal:        return 1
        case .weekendWarrior:        return 1
        case .eveningNudge:          return 1
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

    // MARK: - Testing Support

    func resetForTesting() {
        currentCard = .tip(DailyTip.allTips[0])
        cardShowCounts.removeAll()
        actedUponToday.removeAll()
        recentTipIds.removeAll()
        sessionTip = nil
        lastEvaluationTime = nil
        lastResetDate = nil
        saveShowCounts()
        saveActedUpon()
        saveRecentTipIds()
    }
}
