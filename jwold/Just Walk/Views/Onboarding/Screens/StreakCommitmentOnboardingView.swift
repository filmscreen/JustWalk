//
//  StreakCommitmentOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI

struct CommitmentOption: Identifiable {
    let id = UUID()
    let days: Int?
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let identityStatement: String?
}

struct StreakCommitmentOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var selectedCommitment: Int? = 7

    private let commitmentOptions: [CommitmentOption] = [
        CommitmentOption(
            days: 7,
            icon: "flame.fill",
            iconColor: Color(hex: "FF9500"),
            title: "7-Day Streak",
            subtitle: "Earn the title \"Strider\"",
            identityStatement: "I've found my rhythm."
        ),
        CommitmentOption(
            days: 30,
            icon: "flame.fill",
            iconColor: Color(hex: "FF9500"),
            title: "30-Day Streak",
            subtitle: "Earn the title \"Wayfarer\"",
            identityStatement: "I'm on a path."
        ),
        CommitmentOption(
            days: nil,
            icon: "rocket.fill",
            iconColor: Color(hex: "00C7BE"),
            title: "Just get started",
            subtitle: "No pressure — I'll explore",
            identityStatement: nil
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Set your first goal")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Having a target keeps you motivated.\nYou can always change it later.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            // Commitment cards
            VStack(spacing: 12) {
                ForEach(commitmentOptions) { option in
                    CommitmentOptionCard(
                        icon: option.icon,
                        iconColor: option.iconColor,
                        title: option.title,
                        subtitle: option.subtitle,
                        identityStatement: option.identityStatement,
                        isSelected: selectedCommitment == option.days
                    ) {
                        HapticService.shared.playSelection()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedCommitment = option.days
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button {
                coordinator.selectedStreakCommitment = selectedCommitment
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

        StreakCommitmentOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
