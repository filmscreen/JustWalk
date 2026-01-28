//
//  OpenAppIntent.swift
//  SimpleWalkWidgets
//
//  AppIntent for opening the Just Walk app from Control Widget.
//

#if os(iOS)
import AppIntents
import SwiftUI

@available(iOS 18.0, *)
struct OpenJustWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Just Walk"
    static var description = IntentDescription("Opens the Just Walk app")

    // This allows the intent to open the app
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
#endif
