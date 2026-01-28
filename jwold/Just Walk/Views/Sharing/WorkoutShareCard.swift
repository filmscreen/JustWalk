//
//  WorkoutShareCard.swift
//  Just Walk
//
//  Share card for past walks with map route and stats.
//  Designed for Instagram stories (1080x1920).
//

import SwiftUI

struct WorkoutShareCard: View {
    let data: WorkoutShareData

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.3, blue: 0.5),
                    Color(red: 0.05, green: 0.15, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Map section (top 55% of card)
                if let routeImage = data.routeImage {
                    Image(uiImage: routeImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 1056)  // ~55% of 1920
                        .clipped()
                        .overlay(
                            // Gradient fade at bottom for smooth transition
                            LinearGradient(
                                colors: [.clear, .clear, Color(red: 0.05, green: 0.15, blue: 0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Fallback if no map image
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 1056)
                        .overlay(
                            VStack {
                                Image(systemName: "map")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Route")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        )
                }

                Spacer()

                // Stats section
                VStack(spacing: 32) {
                    // Headline
                    Text(data.headline)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))

                    // Distance hero stat
                    Text(data.formattedDistance)
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // Secondary stats row
                    HStack(spacing: 48) {
                        statItem(
                            icon: "clock.fill",
                            value: data.formattedDuration,
                            label: "Duration"
                        )

                        if let steps = data.steps {
                            statItem(
                                icon: "figure.walk",
                                value: steps.formatted(),
                                label: "Steps"
                            )
                        }
                    }

                    // Date
                    Text(data.formattedDate)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)

                // Branding footer
                ShareCardBranding(style: .light)
                    .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                Text(value)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Previews

#Preview("With Map") {
    WorkoutShareCard(data: WorkoutShareData(
        date: Date(),
        duration: 2700,  // 45 minutes
        distanceMeters: 4023,  // ~2.5 miles
        steps: 5280,
        routeImage: nil
    ))
    .scaleEffect(0.3)
}

#Preview("Without Steps") {
    WorkoutShareCard(data: WorkoutShareData(
        date: Date(),
        duration: 1800,
        distanceMeters: 2414,
        steps: nil,
        routeImage: nil
    ))
    .scaleEffect(0.3)
}
