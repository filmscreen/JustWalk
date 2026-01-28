//
//  WalkActivityAttributes.swift
//  JustWalk Widgets
//
//  Live Activity attributes for walk tracking (shared with main app)
//

import ActivityKit

struct WalkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var steps: Int
        var distance: Double
        var isPaused: Bool
    }

    var mode: String // "free", "interval", "fatBurn", "postMeal"
    var intervalProgram: String? // For interval mode
    var intervalDuration: Int? // Total minutes
}
