//
//  InsightEvaluator.swift
//  Just Walk
//
//  Evaluates user state against insight conditions to find the best match.
//

import Foundation

class InsightEvaluator {
    private let insights: [Insight]
    private let shownInsightsStore: ShownInsightsStore

    init() {
        self.insights = Self.loadInsights()
        self.shownInsightsStore = ShownInsightsStore()
    }

    private static func loadInsights() -> [Insight] {
        guard let url = Bundle.main.url(forResource: "Insights", withExtension: "json") else {
            print("⚠️ InsightEvaluator: Insights.json not found in bundle. Make sure it's added to the target.")
            return Self.fallbackInsights()
        }
        guard let data = try? Data(contentsOf: url),
              let insights = try? JSONDecoder().decode([Insight].self, from: data) else {
            print("⚠️ InsightEvaluator: Failed to decode Insights.json")
            return Self.fallbackInsights()
        }
        print("✅ InsightEvaluator: Loaded \(insights.count) insights from Insights.json")
        return insights
    }

    /// Fallback insights if JSON fails to load
    private static func fallbackInsights() -> [Insight] {
        [
            Insight(
                id: "fallback_general",
                category: .general,
                priority: 50,
                conditions: InsightConditions(),
                messages: [
                    "Every step counts. Keep moving!",
                    "Walking is the best medicine.",
                    "Small steps lead to big changes."
                ],
                proOnly: false,
                cooldownHours: 1
            )
        ]
    }

    func getBestInsight(for state: UserState) -> (id: String, message: String)? {
        print("🔍 InsightEvaluator: getBestInsight called")
        print("   📊 Total insights loaded: \(insights.count)")

        // Step 1: Filter by conditions
        let matchedConditions = insights.filter { matchesConditions($0.conditions, state: state) }
        print("   ✅ Passed condition filters: \(matchedConditions.count)")
        for insight in matchedConditions {
            print("      - \(insight.id) (priority: \(insight.priority))")
        }

        // Step 2: Filter by pro status
        let passedProFilter = matchedConditions.filter { !$0.proOnly || state.isPro }
        print("   👤 Passed pro filter: \(passedProFilter.count)")

        // Step 3: Filter by cooldown
        let notOnCooldown = passedProFilter.filter {
            let onCooldown = shownInsightsStore.isOnCooldown($0.id, cooldownHours: $0.cooldownHours)
            if onCooldown {
                print("      ❄️ \($0.id) is on cooldown")
            }
            return !onCooldown
        }
        print("   🕐 Not on cooldown: \(notOnCooldown.count)")

        // Step 4: Sort and select (prefer non-cooldown, but fallback to cooldown if needed)
        let validInsights = notOnCooldown.sorted { $0.priority < $1.priority }

        // If all matching insights are on cooldown, use the best matching one anyway
        // This ensures the insight card is always visible
        let fallbackInsights = passedProFilter.sorted { $0.priority < $1.priority }

        guard let best = validInsights.first ?? fallbackInsights.first,
              let message = best.messages.randomElement() else {
            // Ultimate fallback - generic motivation message
            print("   ⚠️ No matching insights, using generic fallback")
            return ("generic_fallback", "Every step brings you closer to your goal.")
        }

        let usedFallback = validInsights.isEmpty && !fallbackInsights.isEmpty
        if usedFallback {
            print("   ♻️ All on cooldown, reusing: \(best.id)")
        }

        print("   🎯 Selected: \(best.id) (priority: \(best.priority))")

        let personalizedMessage = personalize(message, with: state)

        // Only mark as shown if this wasn't a cooldown fallback
        // (avoids resetting cooldown timer when reusing)
        if !usedFallback {
            shownInsightsStore.markAsShown(best.id)
            print("   ✅ Marked \(best.id) as shown")
        }

        return (best.id, personalizedMessage)
    }

    // MARK: - Condition Matching

    private func matchesConditions(_ conditions: InsightConditions, state: UserState) -> Bool {
        // Step conditions
        if let c = conditions.stepsToday, !c.evaluate(Double(state.stepsToday)) { return false }
        if let c = conditions.stepsRemaining, !c.evaluate(Double(state.stepsRemaining)) { return false }
        if let c = conditions.percentComplete, !c.evaluate(state.percentComplete) { return false }

        // Streak conditions
        if let c = conditions.currentStreak, !c.evaluate(Double(state.currentStreak)) { return false }
        if let streakAtRisk = conditions.streakAtRisk {
            let isAtRisk = state.stepsRemaining > 0 && state.minutesUntilMidnight <= 240
            if streakAtRisk != isAtRisk { return false }
        }

        // Comparison conditions
        if let aheadOfYesterday = conditions.aheadOfYesterday {
            let isAhead = state.stepsToday > state.stepsYesterdaySameTime
            if aheadOfYesterday != isAhead { return false }
        }
        if let c = conditions.aheadOfYesterdayPercent {
            let percent = state.stepsYesterdaySameTime > 0
                ? (Double(state.stepsToday - state.stepsYesterdaySameTime) / Double(state.stepsYesterdaySameTime)) * 100
                : 0
            if !c.evaluate(percent) { return false }
        }
        if let aboveAvg = conditions.aboveWeeklyAverage {
            let isAbove = state.stepsToday > state.averageDailySteps
            if aboveAvg != isAbove { return false }
        }

        // Time conditions
        if let c = conditions.hourOfDay, !c.evaluate(Double(state.hourOfDay)) { return false }
        if let c = conditions.minutesUntilMidnight, !c.evaluate(Double(state.minutesUntilMidnight)) { return false }
        if let isWeekend = conditions.isWeekend, isWeekend != state.isWeekend { return false }

        // State conditions
        if let goalMet = conditions.goalMetToday, goalMet != state.goalMetToday { return false }
        if let goalMetYesterday = conditions.goalMetYesterday, goalMetYesterday != state.goalMetYesterday { return false }
        if let justHit = conditions.justHitGoal, justHit != state.justHitGoal { return false }
        if let isPro = conditions.isPro, isPro != state.isPro { return false }

        return true
    }

    // MARK: - Personalization

    private func personalize(_ message: String, with state: UserState) -> String {
        var result = message
        result = result.replacingOccurrences(of: "{steps_today}", with: "\(state.stepsToday.formatted())")
        result = result.replacingOccurrences(of: "{steps_remaining}", with: "\(state.stepsRemaining.formatted())")
        result = result.replacingOccurrences(of: "{step_goal}", with: "\(state.stepGoal.formatted())")
        result = result.replacingOccurrences(of: "{current_streak}", with: "\(state.currentStreak)")
        result = result.replacingOccurrences(of: "{percent_complete}", with: "\(Int(state.percentComplete))")
        result = result.replacingOccurrences(of: "{shields_remaining}", with: "\(state.shieldsRemaining)")
        result = result.replacingOccurrences(of: "{hours_left}", with: "\(state.minutesUntilMidnight / 60)")
        result = result.replacingOccurrences(of: "{distance_today}", with: String(format: "%.1f", state.distanceToday))
        result = result.replacingOccurrences(of: "{calories_today}", with: "\(state.caloriesToday)")
        return result
    }
}
