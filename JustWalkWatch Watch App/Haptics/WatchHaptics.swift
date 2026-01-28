//
//  WatchHaptics.swift
//  JustWalkWatch Watch App
//
//  Centralized haptic feedback for watchOS, mirroring the iPhone
//  JustWalkHaptics pattern using WKInterfaceDevice.
//

import WatchKit

enum WatchHaptics {
    private static let device = WKInterfaceDevice.current()

    // MARK: - Walk Lifecycle

    /// Walk paused
    static func walkPaused() {
        device.play(.stop)
    }

    /// Walk resumed
    static func walkResumed() {
        device.play(.start)
    }

    /// Walk completed successfully
    static func walkCompleted() {
        device.play(.success)
    }

    // MARK: - Countdown

    /// Countdown tick (3, 2, 1)
    static func countdownTick() {
        device.play(.click)
    }

    /// Countdown GO
    static func countdownGo() {
        device.play(.start)
    }

    // MARK: - Fat Burn Zones

    /// Entered the fat burn zone
    static func enteredZone() {
        device.play(.success)
    }

    /// Left the fat burn zone
    static func leftZone() {
        device.play(.directionUp)
    }

    /// Speed up (below zone)
    static func speedUp() {
        device.play(.directionUp)
    }

    /// Slow down (above zone)
    static func slowDown() {
        device.play(.directionDown)
    }

    // MARK: - Phase Transitions

    /// Phase change — strong 3-tap notification burst
    static func phaseChange() {
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            device.play(.notification)
        }
    }
}
