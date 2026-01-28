//
//  HapticModifier.swift
//  Just Walk
//
//  SwiftUI view modifier for convenient haptic feedback on tap gestures.
//

import SwiftUI

// MARK: - Haptic Style Enum

enum HapticStyle {
    case buttonTap   // Primary actions
    case softTap     // Secondary actions
    case selection   // Tab switches, pickers
    case success     // Goal hit, completions
    case milestone   // Rank up, streaks
    case warning     // Streak at risk
    case error       // Failed actions
}

// MARK: - View Extension

extension View {
    /// Adds haptic feedback when the view is tapped
    func hapticOnTap(_ style: HapticStyle = .buttonTap) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                switch style {
                case .buttonTap:
                    HapticService.shared.playButtonTap()
                case .softTap:
                    HapticService.shared.playSoftTap()
                case .selection:
                    HapticService.shared.playSelection()
                case .success:
                    HapticService.shared.playSuccess()
                case .milestone:
                    HapticService.shared.playMilestone()
                case .warning:
                    HapticService.shared.playWarning()
                case .error:
                    HapticService.shared.playError()
                }
            }
        )
    }
}
