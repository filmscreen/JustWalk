//
//  RankPathsSheet.swift
//  Just Walk
//
//  Sheet displaying all paths to the next rank with progress bars.
//

import SwiftUI

struct RankPathsSheet: View {
    @ObservedObject private var rankManager = RankManager.shared
    var onDismiss: () -> Void = {}

    private var rank: WalkerRank {
        rankManager.profile.currentRank
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

    private var closestMetric: String? {
        rankManager.closestPathToNextRank()?.metric
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JWDesign.Spacing.lg) {
                    // Header explanation
                    Text("Rank up when you reach ANY of these:")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, JWDesign.Spacing.sm)

                    // Path cards
                    if let progressItems = rankManager.progressToNextRank() {
                        VStack(spacing: JWDesign.Spacing.md) {
                            ForEach(Array(progressItems.enumerated()), id: \.offset) { _, item in
                                pathCard(item)
                            }
                        }
                    }

                    // Tip banner
                    if let hint = rankManager.fastestPathHint() {
                        tipBanner(hint)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Paths to \(nextRank?.title ?? "Next Rank")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Path Card

    @ViewBuilder
    private func pathCard(_ item: (current: Double, required: Double, metric: String)) -> some View {
        let progress = item.required > 0 ? min(item.current / item.required, 1.0) : 0
        let isClosest = item.metric == closestMetric

        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            // Header with icon and closest badge
            HStack {
                HStack(spacing: 8) {
                    Text(iconForMetric(item.metric))
                        .font(.system(size: 20))
                    Text(displayNameForMetric(item.metric))
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer()

                if isClosest {
                    Text("Closest")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "00C7BE"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "00C7BE").opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            // Label: "14 of 30 days"
            Text("\(Int(item.current)) of \(Int(item.required)) \(item.metric)")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tip Banner

    private func tipBanner(_ hint: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "FFD60A"))

            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFD60A").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func iconForMetric(_ metric: String) -> String {
        switch metric {
        case "day streak": return "\u{1F525}" // Fire emoji
        case "walks": return "\u{1F6B6}" // Walking person emoji
        case "miles": return "\u{1F4CD}" // Pin emoji
        default: return "\u{2B50}" // Star emoji
        }
    }

    private func displayNameForMetric(_ metric: String) -> String {
        switch metric {
        case "day streak": return "Day Streak"
        case "walks": return "Total Walks"
        case "miles": return "Distance"
        default: return metric.capitalized
        }
    }
}

// MARK: - Preview

#Preview {
    RankPathsSheet()
}
