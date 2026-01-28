//
//  DailyGoalOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI

struct GoalOption: Identifiable {
    let id = UUID()
    let value: Int
    let emoji: String
    let title: String
    let subtitle: String
    let isSuggested: Bool
}

struct DailyGoalOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var selectedGoal: Int = 4000
    @State private var showCustomSheet = false
    @State private var customGoalValue: Int = 5000

    private let goalOptions: [GoalOption] = [
        GoalOption(value: 4000, emoji: "🌱", title: "4,000 steps", subtitle: "Perfect for getting started", isSuggested: true),
        GoalOption(value: 6000, emoji: "🌿", title: "6,000 steps", subtitle: "A solid daily habit", isSuggested: false),
        GoalOption(value: 8000, emoji: "🌳", title: "8,000 steps", subtitle: "Above average activity", isSuggested: false),
        GoalOption(value: 10000, emoji: "🏆", title: "10,000 steps", subtitle: "The classic benchmark", isSuggested: false)
    ]

    // Track if custom value is selected (not a preset)
    private var isCustomSelected: Bool {
        !goalOptions.contains { $0.value == selectedGoal }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("What's your daily goal?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Start with what feels achievable.\nYou can change this anytime.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            // Goal cards
            VStack(spacing: 12) {
                ForEach(goalOptions) { option in
                    GoalOptionCard(
                        emoji: option.emoji,
                        title: option.title,
                        subtitle: option.subtitle,
                        isSuggested: option.isSuggested,
                        isSelected: selectedGoal == option.value
                    ) {
                        HapticService.shared.playSelection()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedGoal = option.value
                        }
                    }
                }

                // Custom option (show as card if custom is selected)
                if isCustomSelected {
                    GoalOptionCard(
                        emoji: "✨",
                        title: "\(selectedGoal.formatted()) steps",
                        subtitle: "Your custom goal",
                        isSuggested: false,
                        isSelected: true
                    ) {
                        showCustomSheet = true
                    }
                }
            }
            .padding(.horizontal, 24)

            // Custom goal link (only if not already custom)
            if !isCustomSelected {
                Button {
                    showCustomSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Custom goal")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 8)
            }

            Spacer()

            // Continue button
            Button {
                coordinator.selectedDailyGoal = selectedGoal
                coordinator.next()
            } label: {
                Text("Continue")
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
        }
        .sheet(isPresented: $showCustomSheet) {
            CustomGoalSheet(customGoal: $customGoalValue) { newGoal in
                selectedGoal = newGoal
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

        DailyGoalOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
