//
//  PhaseProgressDots.swift
//  Just Walk Watch App
//
//  Progress indicator showing completed/remaining intervals as dots.
//

import SwiftUI

struct PhaseProgressDots: View {
    let currentInterval: Int
    let totalIntervals: Int
    let currentPhase: WatchIWTPhase

    var body: some View {
        VStack(spacing: 4) {
            // Dots row - show only interval dots (brisk+slow pairs)
            HStack(spacing: 4) {
                ForEach(0..<min(totalIntervals * 2, 10), id: \.self) { index in
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 8, height: 8)
                }

                // Show ellipsis if too many dots
                if totalIntervals * 2 > 10 {
                    Text("...")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Phase counter text
            Text("Phase \(currentPhaseNumber) of \(totalPhases)")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func dotColor(for index: Int) -> Color {
        let completedPhases = completedPhaseCount
        if index < completedPhases {
            return .white // Completed
        } else if index == completedPhases {
            return .white.opacity(0.9) // Current
        } else {
            return .white.opacity(0.3) // Remaining
        }
    }

    private var completedPhaseCount: Int {
        // Dots represent just the interval phases (brisk + slow)
        // warmup and cooldown are not shown as dots
        switch currentPhase {
        case .warmup:
            return 0
        case .brisk:
            // First brisk = 0, second brisk = 2, etc.
            return (currentInterval - 1) * 2
        case .slow:
            // After brisk completes, slow is current
            return (currentInterval - 1) * 2 + 1
        case .cooldown, .completed:
            return totalIntervals * 2
        default:
            return 0
        }
    }

    private var currentPhaseNumber: Int {
        // Human-readable phase number including warmup
        switch currentPhase {
        case .warmup:
            return 1
        case .brisk:
            return 2 + (currentInterval - 1) * 2
        case .slow:
            return 2 + (currentInterval - 1) * 2 + 1
        case .cooldown:
            return 2 + totalIntervals * 2
        case .completed:
            return totalPhases
        default:
            return 1
        }
    }

    private var totalPhases: Int {
        // warmup + (brisk + slow) * intervals + cooldown
        return 1 + totalIntervals * 2 + 1
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.orange
            .ignoresSafeArea()

        PhaseProgressDots(
            currentInterval: 2,
            totalIntervals: 5,
            currentPhase: .brisk
        )
    }
}
