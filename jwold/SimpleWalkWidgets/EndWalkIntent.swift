//
//  EndWalkIntent.swift
//  SimpleWalkWidgets
//
//  AppIntent for ending a Classic Walk from the Dynamic Island.
//  Posts a notification that the main app listens to.
//

import AppIntents
import Foundation

#if os(iOS)
/// Intent to end a walk from the Live Activity
struct EndWalkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Walk"
    static var description = IntentDescription("End the current walk session")

    func perform() async throws -> some IntentResult {
        // Post notification for the main app to handle
        await MainActor.run {
            NotificationCenter.default.post(name: .endWalkFromLiveActivity, object: nil)
        }
        return .result()
    }
}
#endif

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when user taps "End Walk" on the Live Activity
    static let endWalkFromLiveActivity = Notification.Name("endWalkFromLiveActivity")
}
