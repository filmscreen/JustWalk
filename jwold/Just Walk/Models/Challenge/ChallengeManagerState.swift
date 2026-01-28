//
//  ChallengeManagerState.swift
//  Just Walk
//
//  Codable wrapper for persisting ChallengeManager state to UserDefaults.
//

import Foundation

/// Persistent state for ChallengeManager
struct ChallengeManagerState: Codable {
    /// Active challenge progress entries
    var activeProgress: [ChallengeProgress]

    /// IDs of challenges that have been completed
    var completedChallengeIds: Set<String>

    /// When the state was last updated
    var lastUpdated: Date

    /// IDs of challenges that the user has abandoned
    var abandonedChallengeIds: Set<String>

    // MARK: - Initialization

    init(
        activeProgress: [ChallengeProgress] = [],
        completedChallengeIds: Set<String> = [],
        lastUpdated: Date = Date(),
        abandonedChallengeIds: Set<String> = []
    ) {
        self.activeProgress = activeProgress
        self.completedChallengeIds = completedChallengeIds
        self.lastUpdated = lastUpdated
        self.abandonedChallengeIds = abandonedChallengeIds
    }

    // MARK: - Default State

    static var empty: ChallengeManagerState {
        ChallengeManagerState()
    }
}
