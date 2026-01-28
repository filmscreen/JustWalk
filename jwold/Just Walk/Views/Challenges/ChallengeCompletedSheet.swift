//
//  ChallengeCompletedSheet.swift
//  Just Walk
//
//  Celebration overlay shown when a challenge is completed.
//

import SwiftUI

struct ChallengeCompletedSheet: View {
    let challenge: Challenge
    var onDismiss: () -> Void = {}

    @State private var showConfetti = false
    @State private var scaleEffect: CGFloat = 0.5
    @State private var opacityEffect: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration icon
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color(hex: "34C759").opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                Circle()
                    .fill(Color(hex: "34C759").opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(Color(hex: "34C759"))
            }
            .scaleEffect(scaleEffect)
            .opacity(opacityEffect)

            VStack(spacing: 8) {
                Text("Challenge Complete!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text(challenge.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .opacity(opacityEffect)

            Spacer()

            // Dismiss button
            Button {
                HapticService.shared.playSuccess()
                onDismiss()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "34C759"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .opacity(opacityEffect)
        }
        .background(Color(.systemBackground))
        .task {
            await animateIn()
        }
    }

    private func animateIn() async {
        // Play haptic
        HapticService.shared.playSuccess()

        // Animate in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            scaleEffect = 1.0
            opacityEffect = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    ChallengeCompletedSheet(
        challenge: Challenge(
            id: "speed_demon",
            type: .quick,
            title: "Speed Demon",
            description: "5,000 steps in 3 hours",
            iconName: "bolt.fill",
            dailyStepTarget: 5000,
            targetDays: 1,
            requiredDaysPattern: .allDays,
            startDate: Date(),
            endDate: Date(),
            durationHours: 3,
            badgeId: nil,
            difficultyLevel: 2
        )
    )
}
