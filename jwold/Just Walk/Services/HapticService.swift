//
//  HapticService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftUI
import CoreHaptics
import Combine
import UIKit

/// Service for managing haptic feedback throughout the app
@MainActor
final class HapticService: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    static let shared = HapticService()

    // MARK: - Settings

    @Published var hapticsEnabled: Bool = true {
        didSet { saveSettings() }
    }

    @Published var intervalHapticsEnabled: Bool = true {
        didSet { saveSettings() }
    }

    @Published var milestoneHapticsEnabled: Bool = true {
        didSet { saveSettings() }
    }

    @Published var goalReachedHapticsEnabled: Bool = true {
        didSet { saveSettings() }
    }

    @Published var achievementHapticsEnabled: Bool = true {
        didSet { saveSettings() }
    }

    // MARK: - Private Properties

    private var engine: CHHapticEngine?

    private init() {
        loadSettings()
        prepareHapticEngine()
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.ensureEngineRunning()
            }
        }
    }
    
    private func ensureEngineRunning() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        if engine == nil {
            prepareHapticEngine()
        }
        
        do {
            try engine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
            // If start fails, maybe recreation helps
            prepareHapticEngine()
        }
    }
    
    private func prepareHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            // Auto-restart if stopped
            engine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                Task { @MainActor in
                    self?.ensureEngineRunning()
                }
            }
            
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                Task { @MainActor in
                    self?.ensureEngineRunning()
                }
            }
        } catch {
            print("Haptic engine creation failed: \(error)")
        }
    }

    // MARK: - Milestone Feedback

    /// Play haptic feedback when user completes a 500-step increment
    func playIncrementMilestone() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    /// Play haptic feedback when user reaches the 10,000 step goal
    func playGoalReached() {
        guard hapticsEnabled, goalReachedHapticsEnabled else { return }

        // Triple burst pattern for goal achievement
        let impact = UIImpactFeedbackGenerator(style: .heavy)

        impact.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impact.impactOccurred(intensity: 1.0)
        }
    }

    /// Play haptic feedback for achievements
    func playAchievement() {
        guard hapticsEnabled, achievementHapticsEnabled else { return }

        // Success notification for achievements
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    /// Play haptic feedback when user is close to goal (within 500 steps)
    func playNearGoal() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    // MARK: - UI Interactions

    /// Play light feedback for button taps
    func playSelection() {
        guard hapticsEnabled else { return }
        let selection = UISelectionFeedbackGenerator()
        selection.selectionChanged()
    }

    /// Primary button tap - medium impact
    func playButtonTap() {
        guard hapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    /// Secondary button tap - soft impact
    func playSoftTap() {
        guard hapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }

    /// Rank up / streak milestone - success + delayed light taps
    func playMilestone() {
        guard hapticsEnabled, milestoneHapticsEnabled else { return }
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        let light = UIImpactFeedbackGenerator(style: .light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            light.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            light.impactOccurred()
        }
    }

    /// Subtle progress tick during walks (every 1000 steps)
    func playProgressTick() {
        guard hapticsEnabled, milestoneHapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred(intensity: 0.5)
    }

    /// Play success feedback
    func playSuccess() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    /// Play warning feedback
    func playWarning() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }

    /// Play error feedback
    func playError() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
    }

    // MARK: - Countdown Haptics

    /// Medium impact for countdown numbers (3, 2, 1)
    func playCountdownTick() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Success notification for "Go!"
    func playCountdownGo() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Play strong interval alert (3 heavy buzzes) - legacy
    func playIntervalAlert() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        
        // Burst 1
        impact.impactOccurred(intensity: 1.0)
        
        // Burst 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            impact.impactOccurred(intensity: 1.0)
        }
        
        // Burst 3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            impact.impactOccurred(intensity: 1.0)
        }
    }
    
    // MARK: - Symphony Haptic (Core Haptics)
    
    /// Play a rich "Symphony" haptic pattern for walk start and interval transitions
    /// This is a strong, multi-layered pattern using Core Haptics
    func playSymphony() {
        // Ensure engine is ready
        if engine == nil {
             ensureEngineRunning()
        }
        
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            // Fallback to legacy strong pattern
            playIntervalAlert()
            return
        }
        
        // Try to start if stopped
        try? engine.start()
        
        do {
            // Create a rich symphony pattern with transients and continuous haptics
            var events: [CHHapticEvent] = []
            
            // Opening burst - sharp transient
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            ))
            
            // Rising continuous wave
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.05,
                duration: 0.15
            ))
            
            // Second transient - mid accent
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.25
            ))
            
            // Sustained rumble
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.3,
                duration: 0.2
            ))
            
            // Final powerful burst
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0.55
            ))
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            
        } catch {
            print("Symphony haptic failed: \(error), falling back")
            playIntervalAlert()
        }
    }

    // MARK: - Power Walk Haptics

    /// Brisk phase starting - 3 quick strong pulses (•••)
    /// Energetic, attention-grabbing pattern
    func playBriskStart() {
        guard hapticsEnabled, intervalHapticsEnabled else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()

        // Pulse 1
        impact.impactOccurred(intensity: 1.0)

        // Pulse 2 - 100ms later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact.impactOccurred(intensity: 1.0)
        }

        // Pulse 3 - 200ms later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impact.impactOccurred(intensity: 1.0)
        }
    }

    /// Easy phase starting - 2 slow gentle pulses (— —)
    /// Calm, relaxing pattern
    func playEasyStart() {
        guard hapticsEnabled, intervalHapticsEnabled else { return }

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()

        // Pulse 1
        impact.impactOccurred(intensity: 0.6)

        // Pulse 2 - 300ms later (slower spacing = calmer feel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            impact.impactOccurred(intensity: 0.6)
        }
    }

    /// Phase halfway marker - 1 soft tap (•)
    func playPhaseHalfway() {
        guard hapticsEnabled, intervalHapticsEnabled else { return }

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred(intensity: 0.4)
    }

    /// Pre-warning 10 seconds before transition - 1 medium tap (•)
    func playPreWarning() {
        guard hapticsEnabled, intervalHapticsEnabled else { return }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred(intensity: 0.7)
    }

    /// Workout complete - Long buzz + 3 celebration pulses (———•••)
    /// Uses Core Haptics for rich continuous + transient pattern
    func playWorkoutComplete() {
        guard hapticsEnabled else { return }

        // Try Core Haptics first for rich pattern
        if playCoreHapticsWorkoutComplete() {
            return
        }

        // Fallback: UIKit pattern
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            impact.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            impact.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            impact.impactOccurred(intensity: 1.0)
        }
    }

    /// Step milestone (1k, 2k, etc) - 2 quick light taps (••)
    func playStepMilestone() {
        guard hapticsEnabled, milestoneHapticsEnabled else { return }

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()

        // Pulse 1
        impact.impactOccurred(intensity: 0.5)

        // Pulse 2 - 80ms later (quick double-tap feel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            impact.impactOccurred(intensity: 0.5)
        }
    }

    // MARK: - Route Navigation Haptics

    /// Haptic for upcoming turn announcement (~200ft)
    func playTurnAhead() {
        guard hapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred(intensity: 0.7)
    }

    /// Haptic for "turn now" - more prominent double pulse
    func playTurnNow() {
        guard hapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact.impactOccurred(intensity: 0.8)
        }
    }

    /// Haptic for off-route warning
    func playOffRouteWarning() {
        guard hapticsEnabled else { return }
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }

    /// Haptic for returning to route
    func playBackOnRoute() {
        guard hapticsEnabled else { return }
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    /// Haptic for arriving at destination
    func playArrival() {
        guard hapticsEnabled else { return }
        // Success notification followed by celebration pattern
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: .medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impact.impactOccurred(intensity: 0.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            impact.impactOccurred(intensity: 0.6)
        }
    }

    // MARK: - Core Haptics Patterns

    /// Core Haptics rich pattern for workout complete
    /// Long sustained buzz followed by celebration pulses
    private func playCoreHapticsWorkoutComplete() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            return false
        }

        ensureEngineRunning()

        do {
            var events: [CHHapticEvent] = []

            // Long continuous buzz (400ms)
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0,
                duration: 0.4
            ))

            // Celebration pulse 1
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.5
            ))

            // Celebration pulse 2
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.6
            ))

            // Celebration pulse 3
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0.7
            ))

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true

        } catch {
            print("Core Haptics workout complete failed: \(error)")
            return false
        }
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        hapticsEnabled = UserDefaults.standard.object(forKey: "haptics_enabled") as? Bool ?? true
        intervalHapticsEnabled = UserDefaults.standard.object(forKey: "haptics_intervals") as? Bool ?? true
        milestoneHapticsEnabled = UserDefaults.standard.object(forKey: "haptics_milestones") as? Bool ?? true
        goalReachedHapticsEnabled = UserDefaults.standard.object(forKey: "haptics_goalReached") as? Bool ?? true
        achievementHapticsEnabled = UserDefaults.standard.object(forKey: "haptics_achievements") as? Bool ?? true
    }

    private func saveSettings() {
        UserDefaults.standard.set(hapticsEnabled, forKey: "haptics_enabled")
        UserDefaults.standard.set(intervalHapticsEnabled, forKey: "haptics_intervals")
        UserDefaults.standard.set(milestoneHapticsEnabled, forKey: "haptics_milestones")
        UserDefaults.standard.set(goalReachedHapticsEnabled, forKey: "haptics_goalReached")
        UserDefaults.standard.set(achievementHapticsEnabled, forKey: "haptics_achievements")
    }
}

