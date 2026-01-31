//
//  WalksWatchView.swift
//  JustWalkWatch Watch App
//
//  Walk type selection: Intervals, Fat Burn, Post-Meal
//

import SwiftUI

struct WalksWatchView: View {
    @EnvironmentObject var appState: WatchAppState
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Walks")
                        .font(.headline)

                    Spacer()
                }

                // Intervals
                NavigationLink {
                    WatchWalkStartView(
                        session: appState.walkSession,
                        onWalkStarted: {
                            appState.currentScreen = .activeWalk
                        }
                    )
                } label: {
                    WalkTypeCard(
                        icon: "bolt.fill",
                        title: "Intervals",
                        subtitle: "18 or 30 min",
                        color: .green
                    )
                }
                .buttonStyle(.plain)

                // Fat Burn Zone
                NavigationLink {
                    FatBurnWatchSetupView()
                } label: {
                    WalkTypeCard(
                        icon: "heart.fill",
                        title: "Fat Burn",
                        subtitle: "HR zone guided",
                        color: .red
                    )
                }
                .buttonStyle(.plain)

                // Post-Meal
                NavigationLink {
                    PostMealWatchSetupView()
                } label: {
                    WalkTypeCard(
                        icon: "fork.knife",
                        title: "Post-Meal",
                        subtitle: "10 min",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Walk Type Card

struct WalkTypeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        WalksWatchView()
            .environmentObject(WatchAppState())
    }
}
