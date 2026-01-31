//
//  MilestoneEvent.swift
//  JustWalk
//
//  Data model and registry for milestone celebrations
//

import Foundation

// MARK: - Milestone Tier

enum MilestoneTier: Int, Codable, Comparable {
    case tier1 = 1  // Fullscreen overlay
    case tier2 = 2  // Dynamic card
    case tier3 = 3  // Toast banner

    static func < (lhs: MilestoneTier, rhs: MilestoneTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Milestone Category

enum MilestoneCategory: String, Codable {
    case streak
    case steps
    case walks
}

// MARK: - Milestone Event

struct MilestoneEvent: Codable, Identifiable, Equatable {
    let id: String              // e.g. "streak_30"
    let tier: MilestoneTier
    let category: MilestoneCategory
    let headline: String        // "One Month."
    let subtitle: String        // "30 days. That's not luck."
    let sfSymbol: String        // "flame.circle.fill"
    var triggeredDate: Date?
    var shown: Bool = false
}

// MARK: - Milestone Registry

/// Static catalog mapping known milestones to their metadata.
enum MilestoneRegistry {

    static func event(for id: String) -> MilestoneEvent? {
        catalog[id]
    }

    private static let catalog: [String: MilestoneEvent] = {
        var map: [String: MilestoneEvent] = [:]
        for event in allEvents {
            map[event.id] = event
        }
        return map
    }()

    // MARK: - Streak Milestones

    private static let streakEvents: [MilestoneEvent] = [
        // Tier 1 — Fullscreen
        MilestoneEvent(
            id: "streak_7",
            tier: .tier1,
            category: .streak,
            headline: "One Week.",
            subtitle: "7 days in a row. You're building something.",
            sfSymbol: "flame.circle.fill"
        ),
        MilestoneEvent(
            id: "streak_30",
            tier: .tier1,
            category: .streak,
            headline: "One Month.",
            subtitle: "30 days. That's not luck.",
            sfSymbol: "flame.circle.fill"
        ),
        MilestoneEvent(
            id: "streak_100",
            tier: .tier1,
            category: .streak,
            headline: "Triple Digits.",
            subtitle: "100 days. You're unstoppable.",
            sfSymbol: "flame.circle.fill"
        ),
        MilestoneEvent(
            id: "streak_365",
            tier: .tier1,
            category: .streak,
            headline: "One Year.",
            subtitle: "365 days. Legendary.",
            sfSymbol: "flame.circle.fill"
        ),

        // Tier 2 — Dynamic Card
        MilestoneEvent(
            id: "streak_14",
            tier: .tier2,
            category: .streak,
            headline: "Two Weeks Strong.",
            subtitle: "14 days — the habit is forming.",
            sfSymbol: "flame.fill"
        ),
        MilestoneEvent(
            id: "streak_60",
            tier: .tier2,
            category: .streak,
            headline: "Two Months.",
            subtitle: "60 days of consistency.",
            sfSymbol: "flame.fill"
        ),
        MilestoneEvent(
            id: "streak_90",
            tier: .tier2,
            category: .streak,
            headline: "Quarter Year.",
            subtitle: "90 days. This is who you are now.",
            sfSymbol: "flame.fill"
        ),
        MilestoneEvent(
            id: "streak_180",
            tier: .tier2,
            category: .streak,
            headline: "Half Year.",
            subtitle: "180 days of walking. Incredible.",
            sfSymbol: "flame.fill"
        ),

        // Tier 3 — Toast
        MilestoneEvent(
            id: "streak_restart_3",
            tier: .tier3,
            category: .streak,
            headline: "Back at it.",
            subtitle: "3-day streak after a break.",
            sfSymbol: "arrow.counterclockwise.circle.fill"
        ),
    ]

    // MARK: - Step Milestones

    private static let stepEvents: [MilestoneEvent] = [
        // Tier 2 — Dynamic Card
        MilestoneEvent(
            id: "steps_first_10k",
            tier: .tier2,
            category: .steps,
            headline: "First 10K Day.",
            subtitle: "You just hit 10,000 steps in a day.",
            sfSymbol: "figure.walk.circle.fill"
        ),

        // Tier 3 — Toast (personal best uses dynamic key)
        MilestoneEvent(
            id: "steps_personal_best",
            tier: .tier3,
            category: .steps,
            headline: "New Personal Best!",
            subtitle: "Your highest step count ever.",
            sfSymbol: "trophy.circle.fill"
        ),
    ]

    // MARK: - Walk Milestones

    private static let walkEvents: [MilestoneEvent] = [
        MilestoneEvent(
            id: "walks_interval_10",
            tier: .tier2,
            category: .walks,
            headline: "10 Interval Walks.",
            subtitle: "A real training habit.",
            sfSymbol: "stopwatch.fill"
        ),
    ]

    // MARK: - All Events

    static let allEvents: [MilestoneEvent] = streakEvents + stepEvents + walkEvents

    /// Look up a personal best milestone, returning a copy with the date-keyed ID.
    static func personalBestEvent(dateString: String) -> MilestoneEvent {
        guard let template = stepEvents.first(where: { $0.id == "steps_personal_best" }) else {
            return MilestoneEvent(
                id: "steps_personal_best_\(dateString)",
                tier: .tier3,
                category: .steps,
                headline: "Personal Best",
                subtitle: "Your highest step count ever.",
                sfSymbol: "trophy.circle.fill"
            )
        }
        // Use a date-keyed ID so it can fire once per day but across multiple days
        return MilestoneEvent(
            id: "steps_personal_best_\(dateString)",
            tier: template.tier,
            category: template.category,
            headline: template.headline,
            subtitle: template.subtitle,
            sfSymbol: template.sfSymbol
        )
    }
}
