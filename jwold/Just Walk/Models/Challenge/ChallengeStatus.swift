//
//  ChallengeStatus.swift
//  Just Walk
//
//  Status tracking for challenge progress.
//

import Foundation

/// Status of a challenge for the user
enum ChallengeStatus: String, Codable {
    /// Challenge is available but not yet started
    case available

    /// User has started the challenge and is actively working on it
    case active

    /// User has successfully completed the challenge
    case completed

    /// User failed to complete the challenge within the time limit
    case failed

    /// Challenge time window has passed without the user starting it
    case expired

    /// Whether this status represents an ended challenge
    var isEnded: Bool {
        switch self {
        case .completed, .failed, .expired:
            return true
        case .available, .active:
            return false
        }
    }

    /// Display text for the status
    var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .active:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .expired:
            return "Expired"
        }
    }
}
