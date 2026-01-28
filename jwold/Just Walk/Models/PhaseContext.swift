//
//  PhaseContext.swift
//  Just Walk
//
//  Context for phase transitions in Power Walk.
//  Helps audio cues select the appropriate message.
//

import Foundation

/// Context for phase transitions
enum PhaseContext {
    /// Workout is starting (first phase)
    case workoutStart

    /// Warmup phase is starting
    case warmupStart

    /// Warmup has completed, transitioning to intervals
    case warmupComplete

    /// First brisk interval of the workout
    case firstBrisk

    /// Last brisk interval (final push)
    case lastBrisk

    /// Last easy interval before cooldown/end
    case lastEasy

    /// Cooldown phase is starting
    case cooldownStart

    /// Normal transition (not first or last)
    case normal
}
