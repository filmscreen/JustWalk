//
//  ShownInsightsStore.swift
//  Just Walk
//
//  Tracks insight cooldowns using UserDefaults.
//

import Foundation

class ShownInsightsStore {
    private let defaults = UserDefaults.standard
    private let key = "shown_insights"

    func isOnCooldown(_ insightId: String, cooldownHours: Int) -> Bool {
        guard let shownDict = getShownDict(),
              let lastShown = shownDict[insightId] else {
            print("   🕐 \(insightId): never shown before")
            return false
        }
        let cooldownEnd = lastShown.addingTimeInterval(TimeInterval(cooldownHours * 3600))
        let isOnCooldown = Date() < cooldownEnd
        if isOnCooldown {
            let remaining = cooldownEnd.timeIntervalSince(Date()) / 3600
            print("   🕐 \(insightId): on cooldown for \(String(format: "%.1f", remaining)) more hours")
        }
        return isOnCooldown
    }

    func markAsShown(_ insightId: String) {
        var shownDict = getShownDict() ?? [:]
        shownDict[insightId] = Date()
        saveShownDict(shownDict)
        print("   📝 ShownInsightsStore: marked \(insightId) as shown at \(Date())")
    }

    // MARK: - Private Helpers

    private func getShownDict() -> [String: Date]? {
        guard let data = defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return nil
        }
        return dict
    }

    private func saveShownDict(_ dict: [String: Date]) {
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: key)
        }
    }

    /// Clean up old entries (older than 7 days) to prevent unbounded growth
    func cleanupOldEntries() {
        guard var shownDict = getShownDict() else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        shownDict = shownDict.filter { $0.value > cutoff }
        saveShownDict(shownDict)
    }
}
