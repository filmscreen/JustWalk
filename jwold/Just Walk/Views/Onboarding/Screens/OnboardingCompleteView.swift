//
//  OnboardingCompleteView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var showCheckmark = false
    @State private var showConfetti = false
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Checkmark icon
            if #available(iOS 18.0, *) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }

            Text("You're all set!")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 10)

            // Summary Card
            VStack(spacing: 12) {
                // Daily Goal
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Your goal: \(coordinator.selectedDailyGoal.formatted()) steps/day")
                        .font(.body)
                        .foregroundStyle(.white)
                    Spacer()
                }

                // Streak Commitment (if selected)
                if let streakDays = coordinator.selectedStreakCommitment {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Your target: \(streakDays)-day streak")
                            .font(.body)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 15)

            Spacer()

            Button(action: { coordinator.complete() }) {
                Text("Let's Go!")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // 1. Checkmark scales in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showCheckmark = true
            }

            // 2. Confetti triggers after 0.3s delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }

            // 3. Content fades in with slight offset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        OnboardingCompleteView()
            .environmentObject(OnboardingCoordinator())
    }
}
