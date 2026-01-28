//
//  WalkerCardView.swift
//  Just Walk
//
//  Shareable 1080x1080 Walker Card template.
//  Displays user's rank, name, and walking stats.
//

import SwiftUI

struct WalkerCardView: View {
    let data: WalkerCardData

    // Card dimensions (square format)
    private let cardSize: CGFloat = 1080

    var body: some View {
        ZStack {
            // Background
            data.background.backgroundView(
                rankColor: data.rank.color,
                customColor: data.customColor
            )

            // Content overlay
            VStack(spacing: 0) {
                Spacer().frame(height: 120)

                // Rank icon with glow
                rankIconSection

                Spacer().frame(height: 40)

                // Rank title
                rankTitleSection

                // Divider
                dividerLine
                    .padding(.vertical, 40)

                // Display name
                nameSection

                Spacer().frame(height: 30)

                // Stats
                statsSection

                // Just Walker special: identity statement
                if data.rank == .justWalker {
                    justWalkerSpecialSection
                }

                Spacer()

                // Branding footer
                brandingFooter
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 80)
        }
        .frame(width: cardSize, height: cardSize)
    }

    // MARK: - Rank Icon Section

    private var rankIconSection: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(data.rank.color.opacity(0.2))
                .frame(width: 180, height: 180)
                .blur(radius: 30)

            // Icon
            Image(systemName: data.rank.icon)
                .font(.system(size: 100, weight: .medium))
                .foregroundStyle(data.rank.color)
        }
    }

    // MARK: - Rank Title Section

    private var rankTitleSection: some View {
        VStack(spacing: 16) {
            // Just Walker special: star decorations
            if data.rank == .justWalker {
                HStack(spacing: 20) {
                    ForEach(0..<5, id: \.self) { _ in
                        Text("\u{2726}")  // Four-pointed star
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "FFD700"))
                    }
                }
            }

            Text(data.rank.title.uppercased())
                .font(.system(size: 48, weight: .bold))
                .tracking(4)
                .foregroundStyle(data.rank.color)
        }
    }

    // MARK: - Divider

    private var dividerLine: some View {
        Rectangle()
            .fill(.white.opacity(0.3))
            .frame(width: 200, height: 2)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Text(data.displayName.isEmpty ? "Walker" : data.displayName)
            .font(.system(size: 36, weight: .medium))
            .foregroundStyle(.white)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 8) {
            Text("\(data.daysAsWalker) days")
                .font(.system(size: 24, weight: .medium))

            Text("\u{2022}")  // Bullet
                .font(.system(size: 24))

            Text(formattedMiles)
                .font(.system(size: 24, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.8))
    }

    private var formattedMiles: String {
        if data.totalMiles >= 1000 {
            return String(format: "%.0fk miles", data.totalMiles / 1000)
        } else if data.totalMiles >= 100 {
            return String(format: "%.0f miles", data.totalMiles)
        } else {
            return String(format: "%.1f miles", data.totalMiles)
        }
    }

    // MARK: - Just Walker Special Section

    private var justWalkerSpecialSection: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)

            Text("I just walk.")
                .font(.system(size: 28, weight: .medium))
                .italic()
                .foregroundStyle(Color(hex: "FFD700").opacity(0.9))
        }
    }

    // MARK: - Branding Footer

    private var brandingFooter: some View {
        ShareCardBranding(style: .light)
    }
}

// MARK: - Preview

#Preview("Walker Card - Walker Rank") {
    WalkerCardView(
        data: WalkerCardData(
            rank: .walker,
            displayName: "Randy",
            daysAsWalker: 14,
            totalMiles: 42.5,
            background: .solidDark,
            customColor: nil
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1080 * 0.3)
}

#Preview("Walker Card - Just Walker") {
    WalkerCardView(
        data: WalkerCardData(
            rank: .justWalker,
            displayName: "Sarah",
            daysAsWalker: 400,
            totalMiles: 1250,
            background: .gradientRank,
            customColor: nil
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1080 * 0.3)
}

#Preview("Walker Card - Centurion") {
    WalkerCardView(
        data: WalkerCardData(
            rank: .centurion,
            displayName: "Mike",
            daysAsWalker: 120,
            totalMiles: 520,
            background: .solidNavy,
            customColor: nil
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1080 * 0.3)
}
