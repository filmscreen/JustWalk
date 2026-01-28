//
//  WalkTabHeader.swift
//  Just Walk
//
//  Header component for Walk tab that directly observes StepRepository.
//  Fixes the "10,000 steps to go" bug by eliminating intermediate caching.
//

import SwiftUI

struct WalkTabHeader: View {
    @ObservedObject private var stepRepo = StepRepository.shared
    @ObservedObject private var streakService = StreakService.shared

    // Computed directly from StepRepository (no caching)
    private var stepsRemaining: Int { stepRepo.stepsRemaining }
    private var goalReached: Bool { stepRepo.goalReached }
    private var progress: Double { stepRepo.goalProgress }
    private var bonusSteps: Int { max(0, stepRepo.todaySteps - stepRepo.stepGoal) }

    private var titleText: String {
        goalReached ? "Goal reached!" : "\(formatNumber(stepsRemaining)) steps to go"
    }

    private var subtitleText: String {
        // Goal reached states
        if goalReached {
            return bonusSteps > 0 ? "+\(formatNumber(bonusSteps)) bonus" : "Keep going for bonus steps"
        }
        // Streak messaging (if active)
        if streakService.currentStreak > 0 {
            return streakSubtitle
        }
        // Progress-based messaging
        return progressSubtitle
    }

    private var streakSubtitle: String {
        let day = streakService.currentStreak + 1
        switch progress {
        case 0: return "Day \(day) — Keep your streak alive"
        case 0..<0.25: return "Day \(day) — You're on your way"
        case 0.25..<0.50: return "Day \(day) — Keep it going"
        case 0.50..<0.75: return "Day \(day) — Halfway there!"
        default: return "Day \(day) — Almost there!"
        }
    }

    private var progressSubtitle: String {
        switch progress {
        case 0: return timeBasedSubtitle
        case 0..<0.25: return "You're on your way"
        case 0.25..<0.50: return "Keep it going"
        case 0.50..<0.75: return "Halfway there!"
        default: return "Almost there!"
        }
    }

    private var timeBasedSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Start your day strong"
        case 12..<17: return "Let's get moving"
        case 17..<21: return "There's still time"
        default: return "Every step counts"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleText)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(goalReached ? Color(hex: "34C759") : .primary)
                .contentTransition(.numericText())

            Text(subtitleText)
                .font(.system(size: 17))
                .foregroundStyle(goalReached && bonusSteps > 0 ? Color(hex: "34C759") : .secondary)
        }
        .animation(.easeInOut(duration: 0.3), value: stepsRemaining)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Preview

#Preview("Steps to Go") {
    WalkTabHeader()
        .padding()
}

#Preview("Goal Reached") {
    WalkTabHeader()
        .padding()
}
