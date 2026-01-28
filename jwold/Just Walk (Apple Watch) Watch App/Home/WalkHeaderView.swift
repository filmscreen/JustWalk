//
//  WalkHeaderView.swift
//  Just Walk Watch App
//
//  Compact header showing steps remaining to goal.
//  Optionally shows streak days if available.
//

import SwiftUI

struct WalkHeaderView: View {
    let stepsToGo: Int
    var streakDays: Int = 0

    private var displayText: String {
        if stepsToGo <= 0 {
            return "Goal reached!"
        }
        return "\(stepsToGo.formatted()) to go"
    }

    var body: some View {
        VStack(spacing: 2) {
            if stepsToGo <= 0 {
                // Goal reached state
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 14))
                    Text("Goal reached!")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.teal)
                }
            } else {
                Text(displayText)
                    .font(.system(size: 15, weight: .medium))
            }

            if streakDays > 0 {
                Label("Day \(streakDays)", systemImage: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview("Steps to go") {
    WalkHeaderView(stepsToGo: 3500, streakDays: 7)
}

#Preview("Goal reached") {
    WalkHeaderView(stepsToGo: 0, streakDays: 12)
}
