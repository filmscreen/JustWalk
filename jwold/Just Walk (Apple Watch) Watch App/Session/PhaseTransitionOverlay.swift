//
//  PhaseTransitionOverlay.swift
//  Just Walk Watch App
//
//  3-2-1 countdown overlay before phase transitions.
//

import SwiftUI
import WatchKit

struct PhaseTransitionOverlay: View {
    let countdownNumber: Int?
    let nextPhase: WatchIWTPhase?

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Countdown number
                if let number = countdownNumber {
                    Text("\(number)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }

                // Next phase hint
                if let next = nextPhase {
                    Text("Get ready for \(nextPhaseName(next))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .onChange(of: countdownNumber) { _, newValue in
            if newValue != nil {
                animateIn()
            }
        }
        .onAppear {
            animateIn()
        }
    }

    private func nextPhaseName(_ phase: WatchIWTPhase) -> String {
        switch phase {
        case .brisk: return "BRISK"
        case .slow: return "EASY"
        case .cooldown: return "COOLDOWN"
        case .completed: return "FINISH"
        default: return phase.title
        }
    }

    private func animateIn() {
        scale = 0.5
        opacity = 0

        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    PhaseTransitionOverlay(
        countdownNumber: 3,
        nextPhase: .brisk
    )
}
