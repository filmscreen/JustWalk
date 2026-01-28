//
//  TrackedWalk.swift
//  JustWalk
//
//  Core data model for tracked walks
//

import Foundation

struct TrackedWalk: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let steps: Int
    let distanceMeters: Double
    let mode: WalkMode
    let intervalProgram: IntervalProgram?
    let intervalCompleted: Bool?
    let routeCoordinates: [CodableCoordinate]
    let customIntervalConfig: CustomIntervalConfig?

    // Watch-provided data (enhanced after walk ends)
    var heartRateAvg: Int?
    var heartRateMax: Int?
    var activeCalories: Double?

    // Fat Burn Zone data
    var fatBurnTimeInZoneSeconds: Int?
    var fatBurnZonePercentage: Double?
    var fatBurnZoneLow: Int?
    var fatBurnZoneHigh: Int?

    /// Whether this walk should appear in user-facing lists.
    /// Shows any walk with recorded activity; only filters truly empty recordings.
    var isDisplayable: Bool {
        steps > 0 || durationMinutes > 0
    }

    // Backward-compatible decoding for records saved before new fields existed
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        steps = try container.decode(Int.self, forKey: .steps)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        mode = try container.decode(WalkMode.self, forKey: .mode)
        intervalProgram = try container.decodeIfPresent(IntervalProgram.self, forKey: .intervalProgram)
        intervalCompleted = try container.decodeIfPresent(Bool.self, forKey: .intervalCompleted)
        routeCoordinates = try container.decode([CodableCoordinate].self, forKey: .routeCoordinates)
        customIntervalConfig = try container.decodeIfPresent(CustomIntervalConfig.self, forKey: .customIntervalConfig)
        heartRateAvg = try container.decodeIfPresent(Int.self, forKey: .heartRateAvg)
        heartRateMax = try container.decodeIfPresent(Int.self, forKey: .heartRateMax)
        activeCalories = try container.decodeIfPresent(Double.self, forKey: .activeCalories)
        fatBurnTimeInZoneSeconds = try container.decodeIfPresent(Int.self, forKey: .fatBurnTimeInZoneSeconds)
        fatBurnZonePercentage = try container.decodeIfPresent(Double.self, forKey: .fatBurnZonePercentage)
        fatBurnZoneLow = try container.decodeIfPresent(Int.self, forKey: .fatBurnZoneLow)
        fatBurnZoneHigh = try container.decodeIfPresent(Int.self, forKey: .fatBurnZoneHigh)
    }

    init(
        id: UUID,
        startTime: Date,
        endTime: Date,
        durationMinutes: Int,
        steps: Int,
        distanceMeters: Double,
        mode: WalkMode,
        intervalProgram: IntervalProgram?,
        intervalCompleted: Bool?,
        routeCoordinates: [CodableCoordinate],
        customIntervalConfig: CustomIntervalConfig? = nil,
        heartRateAvg: Int? = nil,
        heartRateMax: Int? = nil,
        activeCalories: Double? = nil,
        fatBurnTimeInZoneSeconds: Int? = nil,
        fatBurnZonePercentage: Double? = nil,
        fatBurnZoneLow: Int? = nil,
        fatBurnZoneHigh: Int? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.mode = mode
        self.intervalProgram = intervalProgram
        self.intervalCompleted = intervalCompleted
        self.routeCoordinates = routeCoordinates
        self.customIntervalConfig = customIntervalConfig
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.activeCalories = activeCalories
        self.fatBurnTimeInZoneSeconds = fatBurnTimeInZoneSeconds
        self.fatBurnZonePercentage = fatBurnZonePercentage
        self.fatBurnZoneLow = fatBurnZoneLow
        self.fatBurnZoneHigh = fatBurnZoneHigh
    }

    private enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, durationMinutes, steps, distanceMeters
        case mode, intervalProgram, intervalCompleted, routeCoordinates
        case customIntervalConfig
        case heartRateAvg, heartRateMax, activeCalories
        case fatBurnTimeInZoneSeconds, fatBurnZonePercentage, fatBurnZoneLow, fatBurnZoneHigh
    }
}
