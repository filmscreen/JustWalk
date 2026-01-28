//
//  RankSystemExplainerSheet.swift
//  Just Walk
//
//  Educational sheet explaining the rank system.
//  Shows all ranks with their identity statements and requirements.
//

import SwiftUI

struct RankSystemExplainerSheet: View {
    @ObservedObject private var rankManager = RankManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Intro text
                    Text("As you walk, you'll grow:")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    // Rank list
                    VStack(spacing: 12) {
                        ForEach(WalkerRank.allCases, id: \.rawValue) { rank in
                            RankExplainerRow(
                                rank: rank,
                                isCurrentRank: rank == rankManager.profile.currentRank
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    // Footer tip
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Multiple paths to each rank.")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Walk your way — there's no wrong path.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(JWDesign.Colors.background)
            .navigationTitle("Your Walker Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Rank Row Component

private struct RankExplainerRow: View {
    let rank: WalkerRank
    let isCurrentRank: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle (32pt)
            ZStack {
                Circle()
                    .fill(rank.color.opacity(0.10))
                    .frame(width: 32, height: 32)

                Image(systemName: rank.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(rank.color)
            }

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                // Rank title + identity statement
                HStack(spacing: 6) {
                    Text(rank.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\"\(rank.identityStatement)\"")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                // Requirements text
                Text(requirementsText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Current rank indicator
            if isCurrentRank {
                Text("You")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rank.color)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(isCurrentRank ? rank.color.opacity(0.08) : JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var requirementsText: String {
        switch rank {
        case .walker:
            return "Where everyone starts"
        case .strider:
            return "7-day streak or 14 walks"
        case .wayfarer:
            return "30-day streak, 100 walks, or 200 mi"
        case .centurion:
            return "100-day streak, 500 walks, or 500 mi"
        case .justWalker:
            return "365-day streak, 1000 walks, or 1000 mi"
        }
    }
}

// MARK: - Previews

#Preview("Explainer Sheet") {
    RankSystemExplainerSheet()
}
