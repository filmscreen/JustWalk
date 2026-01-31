//
//  WalkActivityAttributes.swift
//  JustWalk Widgets
//
//  Live Activity attributes for walk tracking (shared with main app)
//

import Foundation
import ActivityKit

struct WalkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var elapsedSeconds: Int
        var steps: Int
        var distance: Double
        var isPaused: Bool
        var intervalPhaseRemaining: Int?
        var intervalPhaseEndDate: Date?
        var intervalPhaseType: String?
    }

    var mode: String // "free", "interval", "fatBurn", "postMeal"
    var intervalProgram: String? // For interval mode
    var intervalDuration: Int? // Total minutes
}
