//
//  JustWalkHaptics.swift
//  JustWalk
//
//  Static haptic feedback utilities for consistent tactile feedback
//

import UIKit

enum JustWalkHaptics {
    // MARK: - Feedback Generators (lazy initialized)

    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

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

    /// Phase change (fast to slow, slow to fast) - Strong 3-tap burst for maximum feel during workout
    static func intervalPhaseChange() {
        guard isEnabled else { return }
        // First strong tap immediately
        impactHeavy.impactOccurred()
        
        // Second strong tap after 150ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            impactHeavy.impactOccurred()
        }
        
        // Third strong tap after 300ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            impactHeavy.impactOccurred()
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

    /// Pre-warm generators for fat burn session
    static func prepareForFatBurn() {
        impactMedium.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
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
