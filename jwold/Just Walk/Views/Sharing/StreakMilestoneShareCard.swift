//
//  StreakMilestoneShareCard.swift
//  Just Walk
//
//  Premium share card for streak milestone achievements.
//  Rendered at 1080x1920 (9:16 story format).
//

import SwiftUI

struct StreakMilestoneShareCard: View {
    let data: StreakMilestoneShareData

    // Card dimensions (story format)
    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920

    var body: some View {
        ZStack {
            // Premium gradient background (warm orange to deep red)
            backgroundGradient

            // Animated flame particles (static for image)
            flameParticles

            // Content
            VStack(spacing: 0) {
                Spacer().frame(height: 200)

                // Flame icon
                flameIcon

                Spacer().frame(height: 60)

                // Streak count (hero)
                streakCountSection

                Spacer().frame(height: 60)

                // Motivational text
                motivationalSection

                Spacer().frame(height: 60)

                // Start date info
                if let startDate = data.formattedStartDate {
                    startDateSection(startDate: startDate)
                }

                Spacer()

                // Shield badge (if applicable)
                if data.hasShield {
                    shieldBadge
                    Spacer().frame(height: 40)
                }

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
                Color(red: 1.0, green: 0.5, blue: 0.2),   // Warm orange
                Color(red: 0.8, green: 0.2, blue: 0.1)    // Deep red-orange
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Flame Particles (Decorative)

    private var flameParticles: some View {
        GeometryReader { geometry in
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: "flame.fill")
                    .font(.system(size: CGFloat.random(in: 30...60)))
                    .foregroundStyle(.white.opacity(0.1))
                    .position(
                        x: CGFloat.random(in: 100...(geometry.size.width - 100)),
                        y: CGFloat.random(in: 300...(geometry.size.height - 300))
                    )
                    .rotationEffect(.degrees(Double.random(in: -30...30)))
            }
        }
    }

    // MARK: - Flame Icon

    private var flameIcon: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 200, height: 200)
                .blur(radius: 30)

            // Main flame
            Image(systemName: "flame.fill")
                .font(.system(size: 120))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.5), radius: 20, y: 10)
        }
    }

    // MARK: - Streak Count Section

    private var streakCountSection: some View {
        VStack(spacing: 16) {
            Text(data.milestoneEmoji)
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

            Text("DAYS")
                .font(.system(size: 40, weight: .bold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Motivational Section

    private var motivationalSection: some View {
        Text(data.motivationalText)
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .lineSpacing(8)
    }

    // MARK: - Start Date Section

    private func startDateSection(startDate: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 24))

            Text("Started: \(startDate)")
                .font(.system(size: 22))

            Text("•")

            Text("Still going strong")
                .font(.system(size: 22))
        }
        .foregroundStyle(.white.opacity(0.8))
    }

    // MARK: - Shield Badge

    private var shieldBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.system(size: 24))
                .foregroundStyle(.yellow)

            Text("Protected by Streak Shield")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Branding Footer

    private var brandingFooter: some View {
        ShareCardBranding(style: .light)
    }
}

// MARK: - Preview

#Preview("7 Day Streak") {
    StreakMilestoneShareCard(
        data: StreakMilestoneShareData(
            streakCount: 7,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            motivationalText: "One week strong! You're building a habit.",
            hasShield: false
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1920 * 0.3)
}

#Preview("30 Day Streak") {
    StreakMilestoneShareCard(
        data: StreakMilestoneShareData(
            streakCount: 30,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            motivationalText: "A full month of daily walks!",
            hasShield: true
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1920 * 0.3)
}

#Preview("100 Day Streak") {
    StreakMilestoneShareCard(
        data: StreakMilestoneShareData(
            streakCount: 100,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -100, to: Date()),
            motivationalText: "Triple digits! Incredible commitment.",
            hasShield: true
        )
    )
    .scaleEffect(0.3)
    .frame(width: 1080 * 0.3, height: 1920 * 0.3)
}
