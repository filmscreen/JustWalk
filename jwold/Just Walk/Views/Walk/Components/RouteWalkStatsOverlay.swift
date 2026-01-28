//
//  RouteWalkStatsOverlay.swift
//  Just Walk
//
//  Bottom overlay showing stats and controls during route walk.
//  Displays steps, distance, time, and pause/end buttons.
//

import SwiftUI

struct RouteWalkStatsOverlay: View {
    let steps: Int
    let distance: Double  // meters
    let duration: TimeInterval
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Stats row
            HStack(spacing: 0) {
                statItem(
                    value: "\(steps.formatted())",
                    label: "steps",
                    icon: "shoeprints.fill"
                )

                Divider()
                    .frame(height: 40)

                statItem(
                    value: formatDistance(distance),
                    label: "miles",
                    icon: "point.topleft.down.to.point.bottomright.curvepath"
                )

                Divider()
                    .frame(height: 40)

                statItem(
                    value: formatDuration(duration),
                    label: "time",
                    icon: "clock"
                )
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Control buttons
            HStack(spacing: 24) {
                // Pause/Resume button (orange)
                Button(action: isPaused ? onResume : onPause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 64, height: 64)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // End button (red)
                Button(action: onEnd) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 64, height: 64)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Stat Item

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "00C7BE"))
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            return String(format: "%.2f", miles)
        }
        return String(format: "%.1f", miles)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack {
            Spacer()
            RouteWalkStatsOverlay(
                steps: 2345,
                distance: 1609.34,
                duration: 1234,
                isPaused: false,
                onPause: { print("Pause") },
                onResume: { print("Resume") },
                onEnd: { print("End") }
            )
        }
    }
}
