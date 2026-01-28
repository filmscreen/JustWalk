//
//  DynamicCardDismissalStore.swift
//  Just Walk
//
//  Persistence layer for dynamic card dismissal states.
//

import Foundation

@MainActor
final class DynamicCardDismissalStore {
    static let shared = DynamicCardDismissalStore()

    // MARK: - Storage Keys

    private let foreverDismissedKey = "dynamicCards.foreverDismissed"
    private let dismissedUntilKey = "dynamicCards.dismissedUntil"
    private let seenMilestonesKey = "dynamicCards.seenMilestones"
    private let seenStreakMilestonesKey = "dynamicCards.seenStreakMilestones"
    private let lastInactiveCheckKey = "dynamicCards.lastInactiveCheck"
    private let weeklyDismissWeekKey = "dynamicCards.weeklyDismissWeek"

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Check if Dismissed

    func isDismissed(_ card: DynamicCardType) -> Bool {
        let cardId = card.id

        switch card.dismissBehavior {
        case .hideForever:
            return isForeverDismissed(cardId)

        case .hideUntilTomorrow:
            return isDismissedUntilTomorrow(cardId)

        case .hideUntilNextWeek:
            return isDismissedUntilNextWeek(cardId)

        case .hideUntilNextInactive:
            return isDismissedUntilNextInactive(cardId)

        case .hideForDays(let days):
            return isDismissedForDays(cardId, days: days)
        }
    }

    // MARK: - Dismiss Card

    func dismiss(_ card: DynamicCardType) {
        let cardId = card.id

        switch card.dismissBehavior {
        case .hideForever:
            addToForeverDismissed(cardId)

        case .hideUntilTomorrow:
            setDismissedUntil(cardId, date: startOfTomorrow())

        case .hideUntilNextWeek:
            setWeeklyDismissed(cardId)

        case .hideUntilNextInactive:
            setLastInactiveCheck()

        case .hideForDays(let days):
            let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
            setDismissedUntil(cardId, date: futureDate)
        }
    }

    // MARK: - Milestone Tracking

    func hasSeenMilestone(_ milestone: String) -> Bool {
        let seen = defaults.stringArray(forKey: seenMilestonesKey) ?? []
        return seen.contains(milestone)
    }

    func markMilestoneSeen(_ milestone: String) {
        var seen = defaults.stringArray(forKey: seenMilestonesKey) ?? []
        if !seen.contains(milestone) {
            seen.append(milestone)
            defaults.set(seen, forKey: seenMilestonesKey)
        }
    }

    func hasSeenStreakMilestone(_ days: Int) -> Bool {
        let seen = defaults.array(forKey: seenStreakMilestonesKey) as? [Int] ?? []
        return seen.contains(days)
    }

    func markStreakMilestoneSeen(_ days: Int) {
        var seen = defaults.array(forKey: seenStreakMilestonesKey) as? [Int] ?? []
        if !seen.contains(days) {
            seen.append(days)
            defaults.set(seen, forKey: seenStreakMilestonesKey)
        }
    }

    // MARK: - Private Helpers

    private func isForeverDismissed(_ cardId: String) -> Bool {
        let dismissed = defaults.stringArray(forKey: foreverDismissedKey) ?? []
        return dismissed.contains(cardId)
    }

    private func addToForeverDismissed(_ cardId: String) {
        var dismissed = defaults.stringArray(forKey: foreverDismissedKey) ?? []
        if !dismissed.contains(cardId) {
            dismissed.append(cardId)
            defaults.set(dismissed, forKey: foreverDismissedKey)
        }
    }

    private func isDismissedUntilTomorrow(_ cardId: String) -> Bool {
        guard let dismissedUntil = getDismissedUntilDate(cardId) else { return false }
        return Date() < dismissedUntil
    }

    private func isDismissedForDays(_ cardId: String, days: Int) -> Bool {
        guard let dismissedUntil = getDismissedUntilDate(cardId) else { return false }
        return Date() < dismissedUntil
    }

    private func isDismissedUntilNextWeek(_ cardId: String) -> Bool {
        guard let dismissedWeek = defaults.object(forKey: weeklyDismissWeekKey) as? Int else {
            return false
        }
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        return dismissedWeek == currentWeek
    }

    private func isDismissedUntilNextInactive(_ cardId: String) -> Bool {
        // Card reappears after user becomes inactive again (3+ days)
        // This is handled by the trigger condition, not dismissal state
        return false
    }

    private func setDismissedUntil(_ cardId: String, date: Date) {
        var dict = defaults.dictionary(forKey: dismissedUntilKey) as? [String: TimeInterval] ?? [:]
        dict[cardId] = date.timeIntervalSince1970
        defaults.set(dict, forKey: dismissedUntilKey)
    }

    private func getDismissedUntilDate(_ cardId: String) -> Date? {
        guard let dict = defaults.dictionary(forKey: dismissedUntilKey) as? [String: TimeInterval],
              let timestamp = dict[cardId] else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func setWeeklyDismissed(_ cardId: String) {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        defaults.set(currentWeek, forKey: weeklyDismissWeekKey)
    }

    private func setLastInactiveCheck() {
        defaults.set(Date().timeIntervalSince1970, forKey: lastInactiveCheckKey)
    }

    private func startOfTomorrow() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        return calendar.startOfDay(for: tomorrow)
    }

    // MARK: - Reset (for testing)

    func resetAllDismissals() {
        defaults.removeObject(forKey: foreverDismissedKey)
        defaults.removeObject(forKey: dismissedUntilKey)
        defaults.removeObject(forKey: seenMilestonesKey)
        defaults.removeObject(forKey: seenStreakMilestonesKey)
        defaults.removeObject(forKey: lastInactiveCheckKey)
        defaults.removeObject(forKey: weeklyDismissWeekKey)
    }
}
