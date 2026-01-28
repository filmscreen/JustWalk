//
//  JustWalkAnimation.swift
//  JustWalk
//
//  Centralized animation tokens for consistent motion design
//

import SwiftUI

enum JustWalkAnimation {
    // MARK: - Micro Animations (UI feedback)

    /// Quick feedback for button taps, toggles
    static let micro = Animation.easeOut(duration: 0.15)

    /// Subtle bounce for selection feedback
    static let microBounce = Animation.spring(response: 0.2, dampingFraction: 0.6)

    // MARK: - Standard Animations (transitions, reveals)

    /// Default animation for most UI transitions
    static let standard = Animation.easeInOut(duration: 0.3)

    /// Smooth spring for natural movement
    static let standardSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    /// For sheet presentations and modal transitions
    static let presentation = Animation.spring(response: 0.4, dampingFraction: 0.8)

    // MARK: - Emphasis Animations (celebrations, achievements)

    /// Bouncy animation for achievements and milestones
    static let emphasis = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// Extra bouncy for major celebrations
    static let celebration = Animation.spring(response: 0.6, dampingFraction: 0.5)

    /// Dramatic entrance for celebration animations
    static let dramatic = Animation.spring(response: 0.7, dampingFraction: 0.55)

    // MARK: - Morph Animations (shape/number changes)

    /// For numeric counters and progress changes
    static let morph = Animation.interpolatingSpring(stiffness: 200, damping: 20)

    /// Slower morph for larger value changes
    static let morphSlow = Animation.interpolatingSpring(stiffness: 100, damping: 15)

    // MARK: - Ring/Progress Animations

    /// For circular progress rings
    static let ringFill = Animation.easeOut(duration: 0.8)

    /// For progress bars
    static let progressFill = Animation.easeOut(duration: 0.5)

    /// Pulsing animation for active states
    static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)

    // MARK: - Stagger Animations

    /// Base delay for staggered list items
    static let staggerDelay: Double = 0.05

    /// Animation for staggered list items
    static let staggerItem = Animation.spring(response: 0.4, dampingFraction: 0.75)

    /// Calculate stagger delay for item at index
    static func stagger(for index: Int, baseDelay: Double = staggerDelay) -> Animation {
        staggerItem.delay(Double(index) * baseDelay)
    }

    // MARK: - Shake Animation

    /// For error states or invalid input
    static let shake = Animation.spring(response: 0.2, dampingFraction: 0.2)

    // MARK: - Duration Presets

    enum Duration {
        static let instant: Double = 0.1
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5
        static let emphasis: Double = 0.7
    }

    // MARK: - Timing Curves

    enum Curve {
        static let easeOut = Animation.easeOut(duration: Duration.normal)
        static let easeIn = Animation.easeIn(duration: Duration.normal)
        static let easeInOut = Animation.easeInOut(duration: Duration.normal)
        static let linear = Animation.linear(duration: Duration.normal)
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// Convenience for staggered appearance
    func staggered(index: Int, delay: Double = 0.05) -> Animation {
        self.delay(Double(index) * delay)
    }
}

// MARK: - Button Styles

/// Press-scale button style for tactile tap feedback on interactive elements
struct ScalePressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - View Transition Presets

extension AnyTransition {
    /// Slide up with fade
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    /// Scale with fade
    static var scaleUp: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }

    /// Pop in from center
    static var pop: AnyTransition {
        .scale(scale: 0.5).combined(with: .opacity)
    }

    /// Blur transition
    static var blur: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.95))
    }

    /// Horizontal slide for onboarding flow
    static var onboardingSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
