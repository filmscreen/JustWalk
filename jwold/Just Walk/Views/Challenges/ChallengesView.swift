//
//  ChallengesView.swift
//  Just Walk
//
//  Main challenges list view showing active and available challenges.
//

import SwiftUI

struct ChallengesView: View {
    @ObservedObject private var challengeManager = ChallengeManager.shared

    @State private var selectedChallenge: Challenge?
    @State private var showCompletedSheet = false

    var body: some View {
        List {
            // Active challenges
            if !challengeManager.activeChallenges.isEmpty {
                activeChallengesSection
            }

            // Available challenges by type
            quickChallengesSection
            weeklyChallengesSection
            seasonalChallengesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Challenges")
        .refreshable {
            challengeManager.refreshAvailableChallenges()
            challengeManager.updateDailyProgress()
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailSheet(challenge: challenge) {
                selectedChallenge = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCompletedSheet) {
            if let challenge = challengeManager.recentlyCompletedChallenge {
                ChallengeCompletedSheet(challenge: challenge) {
                    challengeManager.recentlyCompletedChallenge = nil
                    showCompletedSheet = false
                }
                .presentationDetents([.medium])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .challengeCompleted)) { _ in
            showCompletedSheet = true
        }
    }

    // MARK: - Active Challenges Section

    private var activeChallengesSection: some View {
        Section {
            ForEach(challengeManager.activeChallenges) { progress in
                if let challenge = challengeManager.getChallenge(byId: progress.challengeId) {
                    ChallengeProgressRow(
                        challenge: challenge,
                        progress: progress
                    ) {
                        selectedChallenge = challenge
                    }
                }
            }
        } header: {
            Label("Active", systemImage: "flame.fill")
                .foregroundStyle(Color(hex: "FF9500"))
        }
    }

    // MARK: - Quick Challenges Section

    private var quickChallengesSection: some View {
        let quickChallenges = challengeManager.availableChallenges.filter { $0.type == .quick }

        return Group {
            if !quickChallenges.isEmpty {
                Section {
                    ForEach(quickChallenges) { challenge in
                        ChallengeProgressRow(
                            challenge: challenge,
                            progress: nil
                        ) {
                            selectedChallenge = challenge
                        }
                    }
                } header: {
                    Label("Quick Challenges", systemImage: "bolt.fill")
                        .foregroundStyle(Color(hex: "34C759"))
                } footer: {
                    Text("Start anytime, complete within a few hours")
                }
            }
        }
    }

    // MARK: - Weekly Challenges Section

    private var weeklyChallengesSection: some View {
        let weeklyChallenges = challengeManager.availableChallenges.filter { $0.type == .weekly }

        return Group {
            if !weeklyChallenges.isEmpty {
                Section {
                    ForEach(weeklyChallenges) { challenge in
                        ChallengeProgressRow(
                            challenge: challenge,
                            progress: nil
                        ) {
                            selectedChallenge = challenge
                        }
                    }
                } header: {
                    Label("Weekly Challenges", systemImage: "calendar.badge.clock")
                        .foregroundStyle(Color(hex: "00C7BE"))
                } footer: {
                    Text("Complete within the week to earn rewards")
                }
            }
        }
    }

    // MARK: - Seasonal Challenges Section

    private var seasonalChallengesSection: some View {
        let seasonalChallenges = challengeManager.availableChallenges.filter { $0.type == .seasonal }

        return Group {
            if !seasonalChallenges.isEmpty {
                Section {
                    ForEach(seasonalChallenges) { challenge in
                        ChallengeProgressRow(
                            challenge: challenge,
                            progress: nil
                        ) {
                            selectedChallenge = challenge
                        }
                    }
                } header: {
                    Label("Monthly Challenges", systemImage: "calendar")
                        .foregroundStyle(Color(hex: "FF9500"))
                } footer: {
                    Text("Bigger rewards for month-long dedication")
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
