//
//  CircleTheme.swift
//  Just Walk
//
//  Stub for CircleTheme - Circles feature removed, keeping for auth views to compile.
//

import SwiftUI

/// Minimal stub - Circles feature was removed
enum CircleTheme {
    // MARK: - Colors
    static let midnightBlue = Color(red: 0.1, green: 0.1, blue: 0.2)
    static let accentCyan = Color.cyan
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    
    // MARK: - Gradients
    static let accentGradient = LinearGradient(
        colors: [.teal, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Typography
    static let partnerHeader = Font.system(size: 24, weight: .bold, design: .rounded)
}
