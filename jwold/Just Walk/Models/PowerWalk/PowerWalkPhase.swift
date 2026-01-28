//
//  PowerWalkPhase.swift
//  Just Walk
//
//  Phase types for Power Walk interval training.
//  Simplified to two main phases: Easy and Brisk.
//

import SwiftUI

/// Power Walk phase types - simplified from original IWT
/// Only two active phases (Easy/Brisk) to keep the experience simple and approachable.
enum PowerWalkPhase: String, CaseIterable, Codable, Sendable {
    case easy = "Easy Walk"
    case brisk = "Brisk Walk"
    case completed = "Completed"

    // MARK: - Display Properties

    var icon: String {
        switch self {
        case .easy: return "figure.walk"
        case .brisk: return "figure.walk.motion"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: return Color(hex: "00C7BE")      // Brand teal
        case .brisk: return Color(hex: "FF9500")     // Orange/energy
        case .completed: return Color(hex: "34C759") // Green/success
        }
    }

    var colorHex: String {
        switch self {
        case .easy: return "00C7BE"
        case .brisk: return "FF9500"
        case .completed: return "34C759"
        }
    }

    var instruction: String {
        switch self {
        case .easy: return "Comfortable pace, catch your breath"
        case .brisk: return "Pick up the pace, push yourself"
        case .completed: return "Great work!"
        }
    }

    /// Short label for compact UI
    var shortLabel: String {
        switch self {
        case .easy: return "Easy"
        case .brisk: return "Brisk"
        case .completed: return "Done"
        }
    }

    // MARK: - Pace Properties

    /// Target pace for each phase in miles per hour
    var targetMPH: Double {
        switch self {
        case .easy: return 2.5    // ~24 min/mile
        case .brisk: return 4.0   // ~15 min/mile
        case .completed: return 0
        }
    }

    /// Target pace in meters per second
    var targetMPS: Double {
        targetMPH * 0.44704
    }

    /// Expected steps per minute at target pace
    var stepsPerMinute: Int {
        switch self {
        case .easy: return 90     // Relaxed walking
        case .brisk: return 130   // Energetic walking
        case .completed: return 0
        }
    }

    /// Human-readable pace description
    var paceDescription: String {
        switch self {
        case .easy: return "~2.5 mph"
        case .brisk: return "~4.0 mph"
        case .completed: return ""
        }
    }

    // MARK: - Audio Cue Properties

    /// Audio cue text for TTS
    var audioCue: String {
        switch self {
        case .easy: return "Easy pace. Catch your breath."
        case .brisk: return "Brisk pace. Pick it up!"
        case .completed: return "Workout complete. Great job!"
        }
    }

    /// Haptic pattern identifier
    var hapticPattern: String {
        switch self {
        case .easy: return "easy_phase"
        case .brisk: return "brisk_phase"
        case .completed: return "completion"
        }
    }

    // MARK: - Utility

    /// Returns true if this is an active walking phase (not completed)
    var isActivePhase: Bool {
        self != .completed
    }
}
