//
//  WalkStatsCard.swift
//  Just Walk
//
//  Frosted stats row showing secondary metrics during a walk.
//  Configurable to show different combinations based on walk goal type.
//

import SwiftUI

// MARK: - Stats Configuration

struct WalkStatsConfiguration {
    var showDuration: Bool = true
    var showDistance: Bool = true
    var showSteps: Bool = false

    static let durationDistance = WalkStatsConfiguration()
    static let stepsDistance = WalkStatsConfiguration(showDuration: false, showSteps: true)
    static let stepsDuration = WalkStatsConfiguration(showDistance: false, showSteps: true)
}

// MARK: - Walk Stats Card

struct WalkStatsCard: View {
    let duration: TimeInterval
    let distance: Double  // in meters
    let steps: Int
    let calories: Int?
    let configuration: WalkStatsConfiguration

    init(
        duration: TimeInterval,
        distance: Double,
        steps: Int = 0,
        calories: Int? = nil,
        configuration: WalkStatsConfiguration = .durationDistance
    ) {
        self.duration = duration
        self.distance = distance
        self.steps = steps
        self.calories = calories
        self.configuration = configuration
    }

    var body: some View {
        HStack(spacing: 0) {
            let items = buildStatItems()
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    divider
                }
                statItem(icon: item.icon, value: item.value, label: item.label)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    private func buildStatItems() -> [(icon: String, value: String, label: String)] {
        var items: [(icon: String, value: String, label: String)] = []
        if configuration.showSteps {
            items.append(("shoeprints.fill", steps.formatted(), "Steps"))
        }
        if configuration.showDuration {
            items.append(("clock.fill", formattedDuration, "Time"))
        }
        if configuration.showDistance {
            items.append(("point.topleft.down.to.point.bottomright.curvepath", formattedDistance, "Distance"))
        }
        if let cal = calories {
            items.append(("flame.fill", "\(cal)", "Calories"))
        }
        return items
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.8))

            // Value
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            // Label
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 50)
    }

    // MARK: - Formatters

    private var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private var formattedDistance: String {
        let miles = distance * 0.000621371
        if miles >= 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }
}

// MARK: - Preview

#Preview("Duration & Distance") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkStatsCard(
            duration: 1935,  // 32:15
            distance: 2896,  // ~1.8 mi
            steps: 3847,
            calories: 142,
            configuration: .durationDistance
        )
        .padding(.horizontal, 24)
    }
}

#Preview("Steps & Distance (Time Goal)") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkStatsCard(
            duration: 1935,
            distance: 2896,
            steps: 3847,
            calories: nil,
            configuration: .stepsDistance
        )
        .padding(.horizontal, 24)
    }
}

#Preview("Steps & Duration (Distance Goal)") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkStatsCard(
            duration: 1935,
            distance: 2896,
            steps: 3847,
            calories: 142,
            configuration: .stepsDuration
        )
        .padding(.horizontal, 24)
    }
}
