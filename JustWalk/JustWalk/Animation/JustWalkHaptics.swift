//
//  JustWalkHaptics.swift
//  JustWalk
//
//  Static haptic feedback utilities for consistent tactile feedback
//

import UIKit
import CoreHaptics

enum JustWalkHaptics {
    // MARK: - Feedback Generators (lazy initialized)

    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    // MARK: - Core Haptics Engine (for ultra-strong patterns)

    private static var hapticEngine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            try engine.start()
            return engine
        } catch {
            return nil
        }
    }()

    /// Restart the haptic engine if it stopped (called before playing patterns)
    private static func ensureEngineRunning() {
        guard let engine = hapticEngine else { return }
        do {
            try engine.start()
        } catch {
            // Engine may already be running, ignore
        }
    }

    /// Respects the user's haptic preference from Settings
    private static var isEnabled: Bool {
        HapticsManager.shared.isEnabled
    }

    // MARK: - UI Interactions

    /// Light tap for buttons and toggles
    static func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Selection changed in pickers, segments
    static func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    /// Medium impact for important actions
    static func impact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Heavy impact for major state changes
    static func heavyImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    // MARK: - Goal & Achievement Haptics

    /// Daily goal completed
    static func goalComplete() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Progress milestone (25%, 50%, 75%)
    static func progressMilestone() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    // MARK: - Streak Haptics

    /// Streak milestone (7, 30, 100 days, etc.)
    static func streakMilestone() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            notification.notificationOccurred(.success)
        }
    }

    /// Milestone celebration — double-tap feel
    static func milestone() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactMedium.impactOccurred()
        }
    }

    /// Streak at risk warning
    static func streakAtRisk() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Streak broken
    static func streakBroken() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    // MARK: - Walk Session Haptics

    /// Walk started
    static func walkStart() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Walk paused
    static func walkPause() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Walk resumed
    static func walkResume() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Walk completed
    static func walkComplete() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    // MARK: - Interval Training Haptics

    /// Phase change (fast to slow, slow to fast) - ULTRA-STRONG attention-grabbing pattern
    /// Uses Core Haptics for sustained vibration + sharp impacts that are impossible to miss
    static func intervalPhaseChange() {
        guard isEnabled else { return }

        // Try Core Haptics first for maximum intensity
        if playCoreHapticsIntervalPhaseChange() {
            return
        }

        // Fallback: Enhanced UIKit pattern - "Attention Burst"
        // Wave 1: Warning notification + rapid heavy impacts
        notification.notificationOccurred(.warning)
        impactHeavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { impactHeavy.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { impactHeavy.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { impactHeavy.impactOccurred(intensity: 1.0) }

        // Wave 2: Brief pause, then escalating rigid impacts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { impactRigid.impactOccurred(intensity: 0.8) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { impactRigid.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { impactRigid.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) { impactRigid.impactOccurred(intensity: 1.0) }

        // Wave 3: Final "boom" - error notification (strongest type)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { notification.notificationOccurred(.error) }
    }

    /// Core Haptics pattern for interval phase change - sustained vibration + sharp taps
    private static func playCoreHapticsIntervalPhaseChange() -> Bool {
        guard let engine = hapticEngine else { return false }
        ensureEngineRunning()

        do {
            // Create a pattern with sustained vibration + sharp transient taps
            var events: [CHHapticEvent] = []

            // Initial attention-grabbing burst: sustained vibration (0-0.3s)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0,
                duration: 0.3
            ))

            // Sharp transient taps overlaid (creates "machine gun" feel)
            for i in 0..<6 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: Double(i) * 0.05
                ))
            }

            // Brief pause (0.3-0.4s)

            // Second wave: rising intensity (0.4-0.7s)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.4,
                duration: 0.15
            ))
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.55,
                duration: 0.15
            ))

            // Final punctuation: maximum intensity sharp taps (0.7-0.9s)
            for i in 0..<4 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.75 + Double(i) * 0.06
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    /// Speed up signal
    static func intervalSpeedUp() {
        guard isEnabled else { return }
        impactRigid.impactOccurred()
    }

    /// Slow down signal
    static func intervalSlowDown() {
        guard isEnabled else { return }
        impactSoft.impactOccurred()
    }

    /// 10-second warning before phase change
    static func intervalCountdownWarning() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Interval complete
    static func intervalComplete() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    // MARK: - Fat Burn Zone Haptics

    /// Entered the fat burn zone — success feedback
    static func fatBurnEnteredZone() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Left the fat burn zone — gentle nudge
    static func fatBurnLeftZone() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Need to speed up (below zone)
    static func fatBurnSpeedUp() {
        guard isEnabled else { return }
        impactRigid.impactOccurred()
    }

    /// Need to slow down (above zone)
    static func fatBurnSlowDown() {
        guard isEnabled else { return }
        impactSoft.impactOccurred()
    }

    /// Out-of-range alert (too low — need to speed up) — ULTRA-STRONG rising urgency pattern
    /// Creates a "wake up and move!" feeling with escalating intensity
    static func fatBurnOutOfRangeLow() {
        guard isEnabled else { return }

        // Try Core Haptics first
        if playCoreHapticsFatBurnLow() {
            return
        }

        // Fallback: Enhanced UIKit pattern - "Rising Alarm"
        // Start with error notification (strongest)
        notification.notificationOccurred(.error)

        // Rising intensity heavy impacts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { impactHeavy.impactOccurred(intensity: 0.6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { impactHeavy.impactOccurred(intensity: 0.8) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { impactHeavy.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { impactHeavy.impactOccurred(intensity: 1.0) }

        // Second burst after brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { notification.notificationOccurred(.warning) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { impactRigid.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.73) { impactRigid.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.81) { impactRigid.impactOccurred(intensity: 1.0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.89) { impactRigid.impactOccurred(intensity: 1.0) }

        // Final punctuation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { notification.notificationOccurred(.error) }
    }

    /// Core Haptics pattern for fat burn low - sustained rumble with rising intensity
    private static func playCoreHapticsFatBurnLow() -> Bool {
        guard let engine = hapticEngine else { return false }
        ensureEngineRunning()

        do {
            var events: [CHHapticEvent] = []

            // Initial rumble (low sharpness = thuddy/rumbly feel)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: 0,
                duration: 0.2
            ))

            // Rising intensity (0.2-0.6s)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.2,
                duration: 0.2
            ))
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.4,
                duration: 0.2
            ))

            // Sharp taps overlaid at peak (0.4-0.6s)
            for i in 0..<4 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.4 + Double(i) * 0.05
                ))
            }

            // Second wave after brief pause (0.7-1.0s)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0.7,
                duration: 0.3
            ))

            // Rapid transients overlaid (0.7-1.0s)
            for i in 0..<6 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.7 + Double(i) * 0.05
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    /// Out-of-range alert (too high — need to slow down) — ULTRA-STRONG urgent buzzing pattern
    /// Creates a "calm down!" feeling with sharp, insistent feedback
    static func fatBurnOutOfRangeHigh() {
        guard isEnabled else { return }

        // Try Core Haptics first
        if playCoreHapticsFatBurnHigh() {
            return
        }

        // Fallback: Enhanced UIKit pattern - "Urgent Staccato"
        // Error notification (strongest)
        notification.notificationOccurred(.error)

        // Rapid-fire rigid impacts (machine gun pattern)
        for i in 0..<10 {
            let delay = 0.05 + Double(i) * 0.04
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                impactRigid.impactOccurred(intensity: 1.0)
            }
        }

        // Second burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { notification.notificationOccurred(.warning) }
        for i in 0..<8 {
            let delay = 0.60 + Double(i) * 0.04
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                impactHeavy.impactOccurred(intensity: 1.0)
            }
        }

        // Final error notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { notification.notificationOccurred(.error) }
    }

    /// Core Haptics pattern for fat burn high - sharp staccato with sustained buzz
    private static func playCoreHapticsFatBurnHigh() -> Bool {
        guard let engine = hapticEngine else { return false }
        ensureEngineRunning()

        do {
            var events: [CHHapticEvent] = []

            // Immediate sharp buzz (high sharpness = crisp/sharp feel)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0,
                duration: 0.15
            ))

            // Rapid staccato taps (0-0.4s)
            for i in 0..<10 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: Double(i) * 0.04
                ))
            }

            // Brief pause (0.4-0.5s)

            // Second wave: sustained intense buzz (0.5-0.8s)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.5,
                duration: 0.3
            ))

            // Sharp taps overlaid (0.5-0.8s)
            for i in 0..<8 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.5 + Double(i) * 0.04
                ))
            }

            // Final punctuation (0.9-1.0s)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0.9,
                duration: 0.1
            ))
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 1.0
            ))

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    /// Pre-warm generators for fat burn session
    static func prepareForFatBurn() {
        impactMedium.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    // MARK: - Shield Haptics

    /// Shield auto-deployed
    static func shieldDeployed() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Shield repair used
    static func shieldRepair() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// No shields available
    static func shieldUnavailable() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    // MARK: - Feedback States

    /// Success feedback
    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Warning feedback
    static func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Error feedback
    static func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    // MARK: - Preparation

    /// Prepare generators before expected haptic (call ~0.5s before)
    static func prepare() {
        impactMedium.prepare()
        notification.prepare()
    }

    /// Prepare for walk session haptics
    static func prepareForWalk() {
        impactLight.prepare()
        impactMedium.prepare()
        notification.prepare()
    }

    /// Prepare for interval training
    static func prepareForInterval() {
        impactSoft.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactRigid.prepare()
        notification.prepare()
    }
}
