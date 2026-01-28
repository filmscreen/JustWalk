//
//  RankHeroCard.swift
//  Just Walk
//
//  Compact hero card displaying the user's Walker Rank, identity statement,
//  and progress toward the next rank via the closest path.
//

import SwiftUI

struct RankHeroCard: View {
    @ObservedObject private var rankManager = RankManager.shared
    @State private var showPathsSheet = false
    var onShare: () -> Void = {}

    private var rank: WalkerRank {
        rankManager.profile.currentRank
    }

    private var profile: WalkerProfile {
        rankManager.profile
    }

    private var nextRank: WalkerRank? {
        switch rank {
        case .walker: return .strider
        case .strider: return .wayfarer
        case .wayfarer: return .centurion
        case .centurion: return .justWalker
        case .justWalker: return nil
        }
    }

    var body: some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            // Icon and identity section
            VStack(spacing: JWDesign.Spacing.md) {
                // Rank icon in colored circle (60pt, down from 80pt)
                Circle()
                    .fill(rank.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: rank.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(rank.color)
                    }

                // Rank title
                Text(rank.title.uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(rank.color)

                // Identity statement
                Text("\"\(rank.identityStatement)\"")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                // Days as a walker
                if profile.daysAsWalker > 0 {
                    Text("\(profile.daysAsWalker) days as a Walker")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }

            // Progress section or max-rank state
            if rank == .justWalker {
                maxRankSection
            } else if let closest = rankManager.closestPathToNextRank() {
                compactProgressSection(closest)
            }

            // Share button (inside card, centered, subtle)
            shareButton
        }
        .padding(20)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showPathsSheet) {
            RankPathsSheet(onDismiss: { showPathsSheet = false })
                .presentationDetents([.medium])
        }
    }

    // MARK: - Max Rank Section (Just Walker)

    private var maxRankSection: some View {
        VStack(spacing: 12) {
            Text("You've arrived.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("No more ranks. No more goals.\nYou just walk.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Label("\(profile.daysAsWalker) days", systemImage: "trophy.fill")
                Text("\u{2022}")
                    .foregroundStyle(Color(hex: "FFD700"))
                Label(String(format: "%.0f miles", profile.totalMiles), systemImage: "figure.walk")
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: "FFD700"))
        }
        .padding(.top, JWDesign.Spacing.sm)
    }

    // MARK: - Compact Progress Section

    @ViewBuilder
    private func compactProgressSection(_ closest: (metric: String, current: Double, required: Double, progress: Double)) -> some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            // Single progress bar
            RankProgressBar(
                current: closest.current,
                required: closest.required,
                label: closest.metric
            )

            // "X days to Wayfarer" + "See paths >"
            HStack {
                if let nextRank = nextRank {
                    let remaining = Int(closest.required - closest.current)
                    Text("\(remaining) \(closest.metric) to \(nextRank.title)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    HapticService.shared.playSelection()
                    showPathsSheet = true
                }) {
                    HStack(spacing: 4) {
                        Text("See paths")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "00C7BE"))
                }
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button(action: {
            HapticService.shared.playSelection()
            onShare()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                Text("Share Walker Card")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Progress Bar Component

struct RankProgressBar: View {
    let current: Double
    let required: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: geo.size.width * min(current / required, 1.0), height: 6)
                }
            }
            .frame(height: 6)

            // Label: "47/100 days"
            Text("\(Int(current))/\(Int(required)) \(label)")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
    }
}

// MARK: - Preview

#Preview("Rank Hero Card - Walker") {
    ScrollView {
        RankHeroCard()
            .padding()
    }
    .background(JWDesign.Colors.background)
}
