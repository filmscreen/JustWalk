//
//  IntervalTimelinePreview.swift
//  Just Walk
//
//  Visual timeline showing the workout structure with colored blocks
//  representing warmup, easy, brisk, and cooldown phases.
//

import SwiftUI

/// Visual timeline showing workout phase structure
struct IntervalTimelinePreview: View {
    let easyDuration: TimeInterval
    let briskDuration: TimeInterval
    let numberOfIntervals: Int
    let includeWarmup: Bool
    let includeCooldown: Bool

    private let warmupDuration: TimeInterval = 120
    private let cooldownDuration: TimeInterval = 120

    // Colors for each phase type
    private let warmupColor = Color.gray.opacity(0.6)
    private let easyColor = JWDesign.Colors.success
    private let briskColor = JWDesign.Colors.brandSecondary
    private let cooldownColor = Color.gray.opacity(0.6)

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Header
            Text("WALK STRUCTURE")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(1)

            // Timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    // Warmup block
                    if includeWarmup {
                        TimelineBlock(
                            label: "Warmup",
                            duration: warmupDuration,
                            color: warmupColor,
                            showLabel: true,
                            totalDuration: totalDuration
                        )
                    }

                    // Interval cycles
                    ForEach(0..<numberOfIntervals, id: \.self) { index in
                        // Easy phase
                        TimelineBlock(
                            label: "Easy",
                            duration: easyDuration,
                            color: easyColor,
                            showLabel: index == 0,
                            totalDuration: totalDuration
                        )

                        // Brisk phase
                        TimelineBlock(
                            label: "Brisk",
                            duration: briskDuration,
                            color: briskColor,
                            showLabel: index == 0,
                            totalDuration: totalDuration
                        )
                    }

                    // Cooldown block
                    if includeCooldown {
                        TimelineBlock(
                            label: "Cooldown",
                            duration: cooldownDuration,
                            color: cooldownColor,
                            showLabel: true,
                            totalDuration: totalDuration
                        )
                    }
                }
                .padding(.vertical, JWDesign.Spacing.xs)
            }

            // Legend
            HStack(spacing: JWDesign.Spacing.md) {
                if includeWarmup {
                    LegendItem(color: warmupColor, label: "Warmup")
                }
                LegendItem(color: easyColor, label: "Easy")
                LegendItem(color: briskColor, label: "Brisk")
                if includeCooldown {
                    LegendItem(color: cooldownColor, label: "Cooldown")
                }
            }
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }

    private var totalDuration: TimeInterval {
        let warmup = includeWarmup ? warmupDuration : 0
        let cooldown = includeCooldown ? cooldownDuration : 0
        let intervals = Double(numberOfIntervals) * (easyDuration + briskDuration)
        return warmup + intervals + cooldown
    }
}

// MARK: - Timeline Block

/// Individual phase block in the timeline
private struct TimelineBlock: View {
    let label: String
    let duration: TimeInterval
    let color: Color
    let showLabel: Bool
    let totalDuration: TimeInterval

    // Minimum width for visibility, scaled by duration proportion
    private var blockWidth: CGFloat {
        let minWidth: CGFloat = 20
        let maxWidth: CGFloat = 80
        let proportion = duration / totalDuration
        return max(minWidth, min(maxWidth, proportion * 400))
    }

    var body: some View {
        VStack(spacing: 4) {
            // Label (only shown on first occurrence)
            if showLabel {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            } else {
                Text(" ")
                    .font(.system(size: 10))
            }

            // Block
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: blockWidth, height: 32)

            // Duration label
            if showLabel {
                Text(formatDuration(duration))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(.tertiaryLabel))
            } else {
                Text(" ")
                    .font(.system(size: 9))
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Legend Item

/// Legend item showing color and label
private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(JWDesign.Typography.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }
}

// MARK: - Preview

#Preview("Timeline Preview") {
    VStack(spacing: 20) {
        IntervalTimelinePreview(
            easyDuration: 180,
            briskDuration: 180,
            numberOfIntervals: 5,
            includeWarmup: true,
            includeCooldown: true
        )

        IntervalTimelinePreview(
            easyDuration: 120,
            briskDuration: 240,
            numberOfIntervals: 3,
            includeWarmup: false,
            includeCooldown: false
        )

        IntervalTimelinePreview(
            easyDuration: 90,
            briskDuration: 150,
            numberOfIntervals: 8,
            includeWarmup: true,
            includeCooldown: true
        )
    }
    .padding()
    .background(JWDesign.Colors.background)
}
