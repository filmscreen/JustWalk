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

    /// 10-second countdown warning for interval phase change
    /// Quick attention-grab to prepare user for upcoming phase transition
    static func countdownWarning() {
        // Quick double-tap pattern: "heads up!"
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { device.play(.directionUp) }
    }

    /// Progress milestone (e.g., 5-minute halfway point)
    /// Celebratory pattern to acknowledge progress
    static func progressMilestone() {
        device.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { device.play(.click) }
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

    /// Ultra-strong out-of-range alert for fat burn zone (too low — SPEED UP!)
    /// Rising intensity pattern: slow beats accelerating to urgent rapid fire
    static func fatBurnOutOfRangeLow() {
        // Wave 1: Slow attention-grabbing beats (wake up!)
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { device.play(.directionUp) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { device.play(.directionUp) }

        // Wave 2: Accelerating - getting urgent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { device.play(.directionUp) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) { device.play(.directionUp) }

        // Wave 3: Rapid fire crescendo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { device.play(.directionUp) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) { device.play(.directionUp) }

        // Final punctuation: unmistakable "GO FASTER!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { device.play(.start) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) { device.play(.success) }
    }

    /// Ultra-strong out-of-range alert for fat burn zone (too high — SLOW DOWN!)
    /// Urgent staccato pattern: rapid fire bursts demanding immediate attention
    static func fatBurnOutOfRangeHigh() {
        // Wave 1: Urgent rapid-fire burst (ALARM!)
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { device.play(.directionDown) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { device.play(.notification) }

        // Brief pause to let it sink in
        // Wave 2: Second burst with downward emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { device.play(.directionDown) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) { device.play(.directionDown) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { device.play(.notification) }

        // Wave 3: Final demanding burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.74) { device.play(.directionDown) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) { device.play(.directionDown) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.86) { device.play(.notification) }

        // Final punctuation: unmistakable "SLOW DOWN!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) { device.play(.stop) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) { device.play(.retry) }
    }

    // MARK: - Phase Transitions

    /// Ultra-strong interval phase change — unmissable multi-wave pattern
    /// Creates a "heartbeat alarm" that demands attention during workout
    static func phaseChange() {
        // Wave 1: Opening attention grab - sustained rumble effect
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) { device.play(.notification) }

        // Wave 2: Sharp staccato taps (machine gun effect)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { device.play(.start) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.39) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.51) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.57) { device.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { device.play(.click) }

        // Wave 3: Second rumble with varied haptics
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.73) { device.play(.directionUp) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.76) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.79) { device.play(.directionDown) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { device.play(.notification) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) { device.play(.notification) }

        // Final punctuation: unmistakable "PHASE CHANGED!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) { device.play(.success) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) { device.play(.start) }
    }
}
