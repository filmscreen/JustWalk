//
//  DailyGoalShareCard.swift
//  Just Walk
//
//  Premium share card for daily goal achievements.
//  Rendered at 1080x1920 (9:16 story format).
//

import SwiftUI

struct DailyGoalShareCard: View {
    let data: DailyGoalShareData

    // Card dimensions (story format)
    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920

    var body: some View {
        ZStack {
            // Premium gradient background (teal to dark teal)
            backgroundGradient

            // Content
            VStack(spacing: 0) {
                Spacer().frame(height: 200)

                // Trophy icon
                trophyIcon

                Spacer().frame(height: 60)

                // Header text
                headerSection

                Spacer().frame(height: 80)

                // Hero stat (steps)
                heroStatSection

                Spacer().frame(height: 60)

                // Supporting stats
                supportingStatsSection

                Spacer().frame(height: 80)

                // Motivational text
                motivationalSection

                Spacer()

                // Branding footer
                brandingFooter

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 80)
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.65, blue: 0.65),  // Teal
                Color(red: 0.0, green: 0.35, blue: 0.45)   // Dark teal
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Trophy Icon

    private var trophyIcon: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 180, height: 180)
                .blur(radius: 20)

            // Trophy
            Image(systemName: "trophy.fill")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("GOAL CRUSHED")
                .font(.system(size: 36, weight: .bold))
                .tracking(4)
                .foregroundStyle(.white)

            Text(data.formattedDate)
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Hero Stat Section

    private var heroStatSection: some View {
        VStack(spacing: 16) {
            Text(data.steps.formatted())
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

            Text("steps")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .tracking(2)
        }
    }

    // MARK: - Supporting Stats

    private var supportingStatsSection: some View {
        HStack(spacing: 40) {
            // Distance
            VStack(spacing: 8) {
                Image(systemName: "ruler")
                    .font(.system(size: 28))
                Text(data.formattedDistance)
                    .font(.system(size: 24, weight: .semibold))
            }

            // Divider
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 2, height: 60)

            // Goal
            VStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 28))
                Text("Goal: \(data.goal.formatted())")
                    .font(.system(size: 24, weight: .semibold))
            }
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Motivational Section

    private var motivationalSection: some View {
        Text("\"\(data.celebrationPhrase)\"")
            .font(.system(size: 28, weight: .medium))
            .italic()
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
    }

    // MARK: - Branding Footer

    private var brandingFooter: some View {
        ShareCardBranding(style: .light)
    }
}

// MARK: - Preview

#Preview("Daily Goal Card") {
    DailyGoalShareCard(
        data: DailyGoalShareData(
            date: Date(),
            steps: 12450,
            goal: 10000,
            distanceMiles: 5.2,
            celebrationPhrase: "Another day, another win!"
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1920 * 0.3)
}
