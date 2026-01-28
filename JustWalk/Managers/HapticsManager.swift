//
//  HapticsManager.swift
//  JustWalk
//
//  Haptic feedback management
//

import Foundation
import UIKit

@Observable
class HapticsManager {
    static let shared = HapticsManager()

    // MARK: - Persisted Preferences

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "haptics_isEnabled") }
    }

    var goalReachedHaptic: Bool {
        didSet { UserDefaults.standard.set(goalReachedHaptic, forKey: "haptics_goalReached") }
    }

    var stepMilestoneHaptic: Bool {
        didSet { UserDefaults.standard.set(stepMilestoneHaptic, forKey: "haptics_stepMilestone") }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "haptics_isEnabled": true,
            "haptics_goalReached": true,
            "haptics_stepMilestone": true
        ])

        self.isEnabled = defaults.bool(forKey: "haptics_isEnabled")
        self.goalReachedHaptic = defaults.bool(forKey: "haptics_goalReached")
        self.stepMilestoneHaptic = defaults.bool(forKey: "haptics_stepMilestone")
    }

    // MARK: - Feedback Generators

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    // MARK: - Prepare (call before expected feedback)

    func prepare() {
        impactMedium.prepare()
        notification.prepare()
    }

    // MARK: - Walk Events

    func walkStarted() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func walkPaused() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func walkResumed() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func walkCompleted() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    // MARK: - Goal Events

    func goalAchieved() {
        guard isEnabled, goalReachedHaptic else { return }
        notification.notificationOccurred(.success)
    }

    func goalProgress() {
        guard isEnabled, stepMilestoneHaptic else { return }
        impactLight.impactOccurred()
    }

    // MARK: - Streak Events

    func streakMilestone() {
        guard isEnabled, stepMilestoneHaptic else { return }
        notification.notificationOccurred(.success)
    }

    func streakAtRisk() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    func streakBroken() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    // MARK: - Shield Events

    func shieldAutoDeploy() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func shieldRepair() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    // MARK: - Interval Events

    func intervalPhaseChange() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func intervalSpeedUp() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    func intervalSlowDown() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    // MARK: - UI Feedback

    func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }
}
