//
//  StartWalkCardManager.swift
//  Just Walk
//
//  Manages visibility and variants for the StartWalkCard promotional component.
//  Handles dismissal logic, cooldown periods, and smart return triggers.
//

import Foundation
import Combine

// MARK: - Card Variants

enum StartWalkCardVariant: String, CaseIterable {
    case `default`
    case goalHit
    case weekend

    var headline: String {
        switch self {
        case .default: return "Walk with Intention"
        case .goalHit: return "Nice work!"
        case .weekend: return "Weekend walk?"
        }
    }

    var description: String {
        switch self {
        case .default: return "Track routes & try Interval Walking—free for 7 days"
        case .goalHit: return "Turn your next walk into a tracked workout—free for 7 days"
        case .weekend: return "Map your route with GPS tracking—free for 7 days"
        }
    }

    var ctaText: String {
        switch self {
        case .default: return "Try it"
        case .goalHit: return "Let's go"
        case .weekend: return "Start walk"
        }
    }
}

// MARK: - StartWalkCard Manager

@MainActor
final class StartWalkCardManager: ObservableObject {
    static let shared = StartWalkCardManager()

    // MARK: - UserDefaults Keys

    private let lastDismissedKey = "walkCardLastDismissed"
    private let dismissCountKey = "walkCardDismissCount"

    // MARK: - Published State

    @Published private(set) var shouldShowCard: Bool = false
    @Published private(set) var currentVariant: StartWalkCardVariant = .default

    // MARK: - Dependencies

    private let freeTierManager = FreeTierManager.shared

    private init() {
        evaluateVisibility()
    }

    // MARK: - Public Methods

    /// Dismiss the card (user tapped X)
    func dismiss() {
        // Save timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDismissedKey)

        // Increment counter
        let count = UserDefaults.standard.integer(forKey: dismissCountKey)
        UserDefaults.standard.set(count + 1, forKey: dismissCountKey)

        // Update published state
        shouldShowCard = false
    }

    /// Re-evaluate visibility (call on app foreground, goal hit, etc.)
    func evaluateVisibility() {
        // Check all visibility conditions
        guard shouldBeVisible() else {
            shouldShowCard = false
            return
        }

        // Determine variant
        currentVariant = determineVariant()
        shouldShowCard = true
    }

    /// Called when user hits daily goal (potential smart trigger)
    func onGoalHit() {
        evaluateVisibility()
    }

    // MARK: - Private Logic

    private func shouldBeVisible() -> Bool {
        // 1. Not Pro
        guard !freeTierManager.isPro else { return false }

        // 2. Dismiss count < 3 (three strikes rule)
        let dismissCount = UserDefaults.standard.integer(forKey: dismissCountKey)
        guard dismissCount < 3 else { return false }

        // 3. Time-based logic
        let lastDismissed = UserDefaults.standard.double(forKey: lastDismissedKey)

        // Never dismissed → show
        if lastDismissed == 0 { return true }

        let lastDismissedDate = Date(timeIntervalSince1970: lastDismissed)
        let daysSinceDismissal = Calendar.current.dateComponents([.day], from: lastDismissedDate, to: Date()).day ?? 0

        // 7+ days → show default
        if daysSinceDismissal >= 7 { return true }

        // 3+ days AND smart trigger active → show
        if daysSinceDismissal >= 3 {
            return isSmartTriggerActive()
        }

        return false
    }

    private func isSmartTriggerActive() -> Bool {
        // (a) User just hit daily goal today
        if didHitGoalToday() { return true }

        // (b) Weekend AND before 12pm
        if isWeekendMorning() { return true }

        return false
    }

    private func didHitGoalToday() -> Bool {
        let stepRepo = StepRepository.shared
        return stepRepo.todaySteps >= stepRepo.stepGoal
    }

    private func isWeekendMorning() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        // Saturday = 7, Sunday = 1
        let isWeekend = weekday == 1 || weekday == 7
        let isMorning = hour < 12

        return isWeekend && isMorning
    }

    private func determineVariant() -> StartWalkCardVariant {
        if didHitGoalToday() {
            return .goalHit
        } else if isWeekendMorning() {
            return .weekend
        }
        return .default
    }

    // MARK: - Debug

    #if DEBUG
    /// Reset all card state (for testing)
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: lastDismissedKey)
        UserDefaults.standard.removeObject(forKey: dismissCountKey)
        evaluateVisibility()
        print("🧪 StartWalkCardManager: Reset for testing")
    }
    #endif
}
