//
//  MilestoneManager.swift
//  JustWalk
//
//  Manages milestone detection, queueing, rate-limiting, and persistence
//

import Foundation
import Combine

@Observable
class MilestoneManager: ObservableObject {
    static let shared = MilestoneManager()

    private let persistence = PersistenceManager.shared

    // MARK: - Persisted State

    /// Map of milestone ID → date triggered (never re-triggers)
    private(set) var triggeredMilestones: [String: Date] = [:]

    // MARK: - Queued Events

    /// Queued Tier 1 event for next app open
    var pendingFullscreen: MilestoneEvent?

    /// Queued Tier 2 events for dynamic card system
    var pendingTier2: [MilestoneEvent] = []

    /// Queued Tier 3 events for immediate toast display
    var pendingToasts: [MilestoneEvent] = []

    // MARK: - Daily Limits

    /// Daily limit tracking: tier rawValue → count shown today
    private var dailyCounts: [Int: Int] = [:]
    private var dailyCountsDate: String = ""

    /// Max per tier per calendar day
    private static let dailyLimits: [MilestoneTier: Int] = [
        .tier1: 1,
        .tier2: 1,
        .tier3: 3,
    ]

    // MARK: - Persistence Keys

    private enum Keys {
        static let triggeredMilestones = "milestone_triggered"
        static let pendingFullscreen = "milestone_pending_fullscreen"
        static let pendingTier2 = "milestone_pending_tier2"
        static let pendingToasts = "milestone_pending_toasts"
        static let dailyCounts = "milestone_daily_counts"
        static let dailyCountsDate = "milestone_daily_counts_date"
    }

    private init() {}

    // MARK: - Trigger

    /// Attempt to trigger a milestone by ID. Looks up registry, checks fire-once + daily limits, queues to correct tier.
    func trigger(_ id: String) {
        // Already fired?
        guard !hasFired(id) else { return }

        // Look up in registry (or handle dynamic personal best keys)
        guard let event = resolveEvent(for: id) else { return }

        // Check daily limit for this tier
        resetDailyCountsIfNeeded()
        let tier = event.tier
        let currentCount = dailyCounts[tier.rawValue] ?? 0
        let limit = Self.dailyLimits[tier] ?? 1
        guard currentCount < limit else { return }

        // Mark as triggered
        var triggered = event
        triggered.triggeredDate = Date()
        triggeredMilestones[id] = Date()
        dailyCounts[tier.rawValue] = currentCount + 1

        // Queue to correct tier
        switch tier {
        case .tier1:
            pendingFullscreen = triggered
        case .tier2:
            pendingTier2.append(triggered)
        case .tier3:
            pendingToasts.append(triggered)
        }

        save()
    }

    // MARK: - Consumption

    /// Returns and clears the pending Tier 1 event (called on app foreground).
    func checkPendingFullscreen() -> MilestoneEvent? {
        guard let event = pendingFullscreen else { return nil }
        pendingFullscreen = nil
        save()
        return event
    }

    /// Returns and removes the first pending toast.
    func popNextToast() -> MilestoneEvent? {
        guard !pendingToasts.isEmpty else { return nil }
        let event = pendingToasts.removeFirst()
        save()
        return event
    }

    /// Returns and removes the first pending Tier 2 event (for dynamic card engine).
    func popNextTier2() -> MilestoneEvent? {
        guard !pendingTier2.isEmpty else { return nil }
        let event = pendingTier2.removeFirst()
        save()
        return event
    }

    // MARK: - Queries

    func hasFired(_ id: String) -> Bool {
        triggeredMilestones[id] != nil
    }

    // MARK: - Resolution

    private func resolveEvent(for id: String) -> MilestoneEvent? {
        // Direct registry lookup
        if let event = MilestoneRegistry.event(for: id) {
            return event
        }
        // Dynamic personal best key: "steps_personal_best_2026-01-27"
        if id.hasPrefix("steps_personal_best_") {
            let dateString = String(id.dropFirst("steps_personal_best_".count))
            return MilestoneRegistry.personalBestEvent(dateString: dateString)
        }
        return nil
    }

    // MARK: - Daily Limit Reset

    private func resetDailyCountsIfNeeded() {
        let today = todayString()
        if dailyCountsDate != today {
            dailyCounts.removeAll()
            dailyCountsDate = today
        }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Persistence

    func load() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        if let data = defaults.data(forKey: Keys.triggeredMilestones),
           let decoded = try? decoder.decode([String: Date].self, from: data) {
            triggeredMilestones = decoded
        }

        if let data = defaults.data(forKey: Keys.pendingFullscreen),
           let decoded = try? decoder.decode(MilestoneEvent.self, from: data) {
            pendingFullscreen = decoded
        }

        if let data = defaults.data(forKey: Keys.pendingTier2),
           let decoded = try? decoder.decode([MilestoneEvent].self, from: data) {
            pendingTier2 = decoded
        }

        if let data = defaults.data(forKey: Keys.pendingToasts),
           let decoded = try? decoder.decode([MilestoneEvent].self, from: data) {
            pendingToasts = decoded
        }

        if let counts = defaults.dictionary(forKey: Keys.dailyCounts) as? [String: Int] {
            dailyCounts = Dictionary(uniqueKeysWithValues: counts.compactMap { key, value in
                guard let intKey = Int(key) else { return nil }
                return (intKey, value)
            })
        }
        dailyCountsDate = defaults.string(forKey: Keys.dailyCountsDate) ?? ""

        resetDailyCountsIfNeeded()
    }

    func save() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(triggeredMilestones) {
            defaults.set(data, forKey: Keys.triggeredMilestones)
        }

        if let fullscreen = pendingFullscreen,
           let data = try? encoder.encode(fullscreen) {
            defaults.set(data, forKey: Keys.pendingFullscreen)
        } else {
            defaults.removeObject(forKey: Keys.pendingFullscreen)
        }

        if let data = try? encoder.encode(pendingTier2) {
            defaults.set(data, forKey: Keys.pendingTier2)
        }

        if let data = try? encoder.encode(pendingToasts) {
            defaults.set(data, forKey: Keys.pendingToasts)
        }

        let stringCounts = Dictionary(uniqueKeysWithValues: dailyCounts.map { ("\($0.key)", $0.value) })
        defaults.set(stringCounts, forKey: Keys.dailyCounts)
        defaults.set(dailyCountsDate, forKey: Keys.dailyCountsDate)
    }

    // MARK: - Cloud Sync

    struct MilestoneState: Codable {
        var triggeredMilestones: [String: Date]
        var pendingFullscreen: MilestoneEvent?
        var pendingTier2: [MilestoneEvent]
        var pendingToasts: [MilestoneEvent]
        var dailyCounts: [Int: Int]
        var dailyCountsDate: String
    }

    func exportState() -> MilestoneState {
        MilestoneState(
            triggeredMilestones: triggeredMilestones,
            pendingFullscreen: pendingFullscreen,
            pendingTier2: pendingTier2,
            pendingToasts: pendingToasts,
            dailyCounts: dailyCounts,
            dailyCountsDate: dailyCountsDate
        )
    }

    func mergeFromCloud(_ remote: MilestoneState, isFreshInstall: Bool) {
        if isFreshInstall {
            triggeredMilestones = remote.triggeredMilestones
            pendingFullscreen = remote.pendingFullscreen
            pendingTier2 = remote.pendingTier2
            pendingToasts = remote.pendingToasts
            dailyCounts = remote.dailyCounts
            dailyCountsDate = remote.dailyCountsDate
            save()
            return
        }

        // Merge triggered milestones: keep the most recent date per key
        for (id, date) in remote.triggeredMilestones {
            let localDate = triggeredMilestones[id] ?? .distantPast
            if date > localDate {
                triggeredMilestones[id] = date
            }
        }

        // Merge pending queues by unique id
        if let remoteFullscreen = remote.pendingFullscreen {
            if pendingFullscreen == nil {
                pendingFullscreen = remoteFullscreen
            }
        }

        let localTier2IDs = Set(pendingTier2.map(\.id))
        let newTier2 = remote.pendingTier2.filter { !localTier2IDs.contains($0.id) }
        if !newTier2.isEmpty {
            pendingTier2.append(contentsOf: newTier2)
        }

        let localToastIDs = Set(pendingToasts.map(\.id))
        let newToasts = remote.pendingToasts.filter { !localToastIDs.contains($0.id) }
        if !newToasts.isEmpty {
            pendingToasts.append(contentsOf: newToasts)
        }

        // Daily counts: take the newer date, or max counts if same date
        if remote.dailyCountsDate > dailyCountsDate {
            dailyCountsDate = remote.dailyCountsDate
            dailyCounts = remote.dailyCounts
        } else if remote.dailyCountsDate == dailyCountsDate {
            for (key, value) in remote.dailyCounts {
                let localValue = dailyCounts[key] ?? 0
                dailyCounts[key] = max(localValue, value)
            }
        }

        save()
    }

    // MARK: - Debug / Reset

    #if DEBUG
    func resetAllMilestones() {
        triggeredMilestones.removeAll()
        pendingFullscreen = nil
        pendingTier2.removeAll()
        pendingToasts.removeAll()
        dailyCounts.removeAll()
        dailyCountsDate = ""
        save()
    }

    func debugTrigger(tier: MilestoneTier) {
        let testEvents: [MilestoneTier: MilestoneEvent] = [
            .tier1: MilestoneEvent(
                id: "debug_tier1_\(Date().timeIntervalSince1970)",
                tier: .tier1,
                category: .streak,
                headline: "Debug Tier 1",
                subtitle: "Testing fullscreen milestone.",
                sfSymbol: "flame.circle.fill",
                triggeredDate: Date()
            ),
            .tier2: MilestoneEvent(
                id: "debug_tier2_\(Date().timeIntervalSince1970)",
                tier: .tier2,
                category: .steps,
                headline: "Debug Tier 2",
                subtitle: "Testing dynamic card milestone.",
                sfSymbol: "figure.walk.circle.fill",
                triggeredDate: Date()
            ),
            .tier3: MilestoneEvent(
                id: "debug_tier3_\(Date().timeIntervalSince1970)",
                tier: .tier3,
                category: .walks,
                headline: "Debug Tier 3",
                subtitle: "Testing toast milestone.",
                sfSymbol: "stopwatch.fill",
                triggeredDate: Date()
            ),
        ]

        guard let event = testEvents[tier] else { return }

        switch tier {
        case .tier1:
            pendingFullscreen = event
        case .tier2:
            pendingTier2.append(event)
        case .tier3:
            pendingToasts.append(event)
        }
        save()
    }
    #endif
}
