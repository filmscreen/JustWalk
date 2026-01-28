//
//  ChallengesSectionView.swift
//  Just Walk
//
//  Section wrapper for Progress tab showing challenges
//

import SwiftUI

struct ChallengesSectionView: View {
    @ObservedObject private var challengeManager = ChallengeManager.shared

    let onSeeAll: () -> Void
    let onSelectChallenge: (Challenge) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Challenges")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "00C7BE")) // Teal
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Content area
            if let activeProgress = challengeManager.activeChallenges.first,
               let activeChallenge = challengeManager.getChallenge(byId: activeProgress.challengeId) {
                // Show active challenge card
                ActiveChallengeCard(
                    challenge: activeChallenge,
                    progress: activeProgress,
                    onTap: { onSelectChallenge(activeChallenge) }
                )
            } else {
                // Show up to 2 available challenges
                VStack(spacing: 8) {
                    ForEach(challengeManager.availableChallenges.prefix(2)) { challenge in
                        AvailableChallengeCard(
                            challenge: challenge,
                            onTap: { onSelectChallenge(challenge) }
                        )
                    }

                    // Show empty state if no challenges available
                    if challengeManager.availableChallenges.isEmpty {
                        emptyChallengesView
                    }
                }
            }
        }
    }

    private var emptyChallengesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text("No challenges available")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Check back soon for new challenges!")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ChallengesSectionView(
                onSeeAll: { print("See All tapped") },
                onSelectChallenge: { challenge in
                    print("Selected: \(challenge.title)")
                }
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
