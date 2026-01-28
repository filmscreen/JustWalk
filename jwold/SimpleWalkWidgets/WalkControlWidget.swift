//
//  WalkControlWidget.swift
//  SimpleWalkWidgets
//
//  iOS 18 Control Widget for quick access to Just Walk from lock screen.
//

#if os(iOS)
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct WalkControlWidget: ControlWidget {
    static let kind: String = "com.onworldtech.JustWalk.WalkControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenJustWalkIntent()) {
                Label("Walk", systemImage: "figure.walk")
            }
        }
        .displayName("Just Walk")
        .description("Quick access to step tracker")
    }
}
#endif
