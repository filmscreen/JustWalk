//
//  WatchConnectivityConstants.swift
//  JustWalk
//
//  Constants for iPhone ↔ Watch communication
//

import Foundation

enum WatchConnectivityConstants {
    /// Timeout for interactive messages
    static let messageTimeout: TimeInterval = 5.0

    /// How often to send stats updates during workout
    static let statsUpdateInterval: TimeInterval = 3.0

    /// App group identifier for shared storage
    static let appGroupIdentifier = "group.com.justwalk.shared"

    /// User defaults key for last known state
    static let lastKnownStateKey = "lastKnownWorkoutState"
}
