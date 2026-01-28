//
//  WatchWalkRecord.swift
//  JustWalkWatch Watch App
//
//  Simplified walk record for watchOS
//

import Foundation

struct WatchWalkRecord: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let steps: Int
    let distanceMeters: Double
    let intervalProgram: String?
    let intervalCompleted: Bool?
    let averageHeartRate: Int?
    let activeCalories: Double?

    // Fat burn zone data
    let isFatBurnWalk: Bool
    let fatBurnZoneLow: Int?
    let fatBurnZoneHigh: Int?
    let timeInZone: TimeInterval?
    let percentageInZone: Double?

    var isIntervalWalk: Bool {
        intervalProgram != nil
    }

    init(
        id: UUID,
        startTime: Date,
        endTime: Date,
        durationMinutes: Int,
        steps: Int,
        distanceMeters: Double,
        intervalProgram: String? = nil,
        intervalCompleted: Bool? = nil,
        averageHeartRate: Int? = nil,
        activeCalories: Double? = nil,
        isFatBurnWalk: Bool = false,
        fatBurnZoneLow: Int? = nil,
        fatBurnZoneHigh: Int? = nil,
        timeInZone: TimeInterval? = nil,
        percentageInZone: Double? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.intervalProgram = intervalProgram
        self.intervalCompleted = intervalCompleted
        self.averageHeartRate = averageHeartRate
        self.activeCalories = activeCalories
        self.isFatBurnWalk = isFatBurnWalk
        self.fatBurnZoneLow = fatBurnZoneLow
        self.fatBurnZoneHigh = fatBurnZoneHigh
        self.timeInZone = timeInZone
        self.percentageInZone = percentageInZone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        steps = try container.decode(Int.self, forKey: .steps)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        intervalProgram = try container.decodeIfPresent(String.self, forKey: .intervalProgram)
        intervalCompleted = try container.decodeIfPresent(Bool.self, forKey: .intervalCompleted)
        averageHeartRate = try container.decodeIfPresent(Int.self, forKey: .averageHeartRate)
        activeCalories = try container.decodeIfPresent(Double.self, forKey: .activeCalories)
        isFatBurnWalk = try container.decodeIfPresent(Bool.self, forKey: .isFatBurnWalk) ?? false
        fatBurnZoneLow = try container.decodeIfPresent(Int.self, forKey: .fatBurnZoneLow)
        fatBurnZoneHigh = try container.decodeIfPresent(Int.self, forKey: .fatBurnZoneHigh)
        timeInZone = try container.decodeIfPresent(TimeInterval.self, forKey: .timeInZone)
        percentageInZone = try container.decodeIfPresent(Double.self, forKey: .percentageInZone)
    }
}
