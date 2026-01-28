//
//  PreWalkCountdownView.swift
//  Just Walk
//
//  Fullscreen countdown overlay (3... 2... 1... Go!) before walks begin.
//

import SwiftUI

struct PreWalkCountdownView: View {
    let walkMode: WalkMode
    var walkGoal: WalkGoal = .none  // Optional goal for display
    var durationMinutes: Int? = nil  // Legacy: Optional duration for display
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var currentNumber: Int = 3
    @State private var showGo: Bool = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            // Background gradient matching walk type
            backgroundGradient
                .ignoresSafeArea()

            // Walk type label + countdown number or "Go!"
            VStack(spacing: 16) {
                Spacer()

                // Walk type label above countdown
                walkTypeLabel

                if showGo {
                    goText
                } else if currentNumber > 0 {
                    numberText
                }

                Spacer()
            }

            // Cancel button at bottom
            VStack {
                Spacer()
                cancelButton
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    // MARK: - Walk Type Label

    private var walkTypeLabel: some View {
        Text(walkTypeLabelText)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
    }

    private var walkTypeLabelText: String {
        let walkName: String
        switch walkMode {
        case .classic: walkName = "Just Walk"
        case .interval: walkName = "Power Walk"
        case .postMeal: walkName = "Post-Meal Walk"
        }

        // Check for walkGoal first
        switch walkGoal.type {
        case .none:
            // Fall back to legacy durationMinutes if set
            if let minutes = durationMinutes {
                return "\(walkName) · \(minutes) min"
            }
            return walkName
        case .time:
            return "\(walkName) · \(Int(walkGoal.target)) min"
        case .distance:
            let miles = walkGoal.target
            if miles == floor(miles) {
                return "\(walkName) · \(Int(miles)) mi"
            }
            return "\(walkName) · \(String(format: "%.1f", miles)) mi"
        case .steps:
            return "\(walkName) · \(Int(walkGoal.target).formatted()) steps"
        }
    }

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        Group {
            switch walkMode {
            case .classic:
                LinearGradient(
                    colors: [Color(hex: "32D4DE"), Color(hex: "00C7BE")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .interval:
                LinearGradient(
                    colors: [Color(hex: "FF9500"), Color(hex: "FF6B00")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .postMeal:
                LinearGradient(
                    colors: [Color(hex: "34C759"), Color(hex: "30D158")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Number Text

    private var numberText: some View {
        Text("\(currentNumber)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .scaleEffect(scale)
            .opacity(opacity)
            .accessibilityLabel("\(currentNumber)")
    }

    // MARK: - Go Text

    private var goText: some View {
        Text("Go!")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .scaleEffect(scale)
            .opacity(opacity)
            .accessibilityLabel("Go")
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .frame(minWidth: 100, minHeight: 44)
        }
        .accessibilityLabel("Cancel countdown")
    }

    // MARK: - Countdown Logic

    private func startCountdown() {
        guard !isAnimating else { return }
        isAnimating = true

        // Start with number 3
        animateNumber(3) {
            // Then 2
            animateNumber(2) {
                // Then 1
                animateNumber(1) {
                    // Then Go!
                    animateGo()
                }
            }
        }
    }

    private func animateNumber(_ number: Int, completion: @escaping () -> Void) {
        currentNumber = number
        showGo = false

        // Reset animation state
        scale = 0.5
        opacity = 0

        // Play haptic
        HapticService.shared.playCountdownTick()

        // Animate in: scale up + fade in (0.2s)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }

        // Hold for 0.5s, then fade out (0.2s), then call completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
                scale = 0.8
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }

    private func animateGo() {
        showGo = true
        currentNumber = 0

        // Reset animation state
        scale = 0.5
        opacity = 0

        // Play success haptic
        HapticService.shared.playCountdownGo()

        // Animate in with bounce: scale up to 1.2, then settle to 1.0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale = 1.1
            opacity = 1.0
        }

        // Brief hold, then complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.15)) {
                opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onComplete()
            }
        }
    }
}

// MARK: - Preview

#Preview("Classic Walk Countdown") {
    PreWalkCountdownView(
        walkMode: .classic,
        onComplete: { print("Countdown complete!") },
        onCancel: { print("Cancelled") }
    )
}

#Preview("Interval Walk Countdown") {
    PreWalkCountdownView(
        walkMode: .interval,
        onComplete: { print("Countdown complete!") },
        onCancel: { print("Cancelled") }
    )
}
