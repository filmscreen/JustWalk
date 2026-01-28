//
//  SoundEffect.swift
//  Just Walk
//
//  Sound effect types for Power Walk audio cues.
//

import Foundation

/// Sound effect types for Power Walk
enum SoundEffect: String, CaseIterable {
    case briskStart = "brisk_start"      // Ascending energetic chime
    case easyStart = "easy_start"        // Descending calming tone
    case workoutComplete = "complete"    // Celebration sound
    case countdown = "tick"              // Countdown tick
    case milestone = "milestone"         // Step milestone ding
    case goalReached = "goal_reached"    // Goal celebration

    /// Human-readable description
    var description: String {
        switch self {
        case .briskStart: return "Brisk start chime"
        case .easyStart: return "Easy start tone"
        case .workoutComplete: return "Workout complete celebration"
        case .countdown: return "Countdown tick"
        case .milestone: return "Step milestone ding"
        case .goalReached: return "Goal reached celebration"
        }
    }

    /// File extension for the sound file
    var fileExtension: String {
        "mp3"
    }

    /// Full filename with extension
    var filename: String {
        "\(rawValue).\(fileExtension)"
    }
}
