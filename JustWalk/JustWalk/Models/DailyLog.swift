//
//  DailyLog.swift
//  JustWalk
//
//  Core data model for daily activity logs
//

import Foundation

struct DailyLog: Codable, Identifiable {
    let id: UUID
    let date: Date // Normalized to start of day
    let dayKey: String // Stable key for persistence
    var steps: Int
    var goalMet: Bool
    var shieldUsed: Bool
    var trackedWalkIDs: [UUID]
    var goalTarget: Int? = nil

    // "2026-01-25"
    var dateString: String { dayKey }

    init(
        id: UUID,
        date: Date,
        steps: Int,
        goalMet: Bool,
        shieldUsed: Bool,
        trackedWalkIDs: [UUID],
        goalTarget: Int? = nil,
        dayKey: String? = nil
    ) {
        self.id = id
        self.date = date
        self.dayKey = dayKey ?? Self.makeDayKey(for: date)
        self.steps = steps
        self.goalMet = goalMet
        self.shieldUsed = shieldUsed
        self.trackedWalkIDs = trackedWalkIDs
        self.goalTarget = goalTarget
    }

    enum CodingKeys: String, CodingKey {
        case id, date, dayKey, steps, goalMet, shieldUsed, trackedWalkIDs, goalTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        dayKey = try container.decodeIfPresent(String.self, forKey: .dayKey) ?? Self.makeDayKey(for: date)
        steps = try container.decode(Int.self, forKey: .steps)
        goalMet = try container.decode(Bool.self, forKey: .goalMet)
        shieldUsed = try container.decode(Bool.self, forKey: .shieldUsed)
        trackedWalkIDs = try container.decode([UUID].self, forKey: .trackedWalkIDs)
        goalTarget = try container.decodeIfPresent(Int.self, forKey: .goalTarget)
    }

    static func makeDayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 1970
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
