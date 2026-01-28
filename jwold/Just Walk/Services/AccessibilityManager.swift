//
//  AccessibilityManager.swift
//  Just Walk
//
//  Centralized accessibility state management for reduce motion and other settings.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class AccessibilityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AccessibilityManager()

    // MARK: - Published Properties

    /// True when user has enabled Reduce Motion in iOS Settings
    @Published private(set) var reduceMotionEnabled: Bool = false

    // MARK: - Initialization

    private init() {
        // Read initial state
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled

        // Listen for changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Notification Handlers

    @objc private func reduceMotionChanged() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - Animation Helpers

    /// Returns the appropriate animation based on reduce motion setting
    /// - Parameter animation: The animation to use when reduce motion is disabled
    /// - Returns: nil if reduce motion is enabled, otherwise the provided animation
    func animation(_ animation: Animation) -> Animation? {
        reduceMotionEnabled ? nil : animation
    }

    /// Standard fade animation that respects reduce motion
    var fadeAnimation: Animation? {
        animation(.easeInOut(duration: 0.3))
    }

    /// Spring animation that respects reduce motion
    var springAnimation: Animation? {
        animation(.spring(response: 0.4, dampingFraction: 0.7))
    }
}
