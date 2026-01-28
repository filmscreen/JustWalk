//
//  JustWalkSecondaryStatsView.swift
//  Just Walk Watch App
//
//  Secondary stats view accessible via Digital Crown scroll.
//

import SwiftUI

struct JustWalkSecondaryStatsView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("Details")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    statItem(
                        icon: "map.fill",
                        value: formattedSessionDistance,
                        unit: WatchDistanceUnit.preferred.abbreviation,
                        color: .teal
                    )

                    statItem(
                        icon: "heart.fill",
                        value: "\(Int(sessionManager.currentHeartRate))",
                        unit: "BPM",
                        color: .red
                    )

                    statItem(
                        icon: "flame.fill",
                        value: "\(Int(sessionManager.activeCalories))",
                        unit: "cal",
                        color: .orange
                    )

                    statItem(
                        icon: "speedometer",
                        value: formattedPace,
                        unit: paceUnit,
                        color: .cyan
                    )
                }

                // Dismiss hint
                Text("Scroll down to close")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func statItem(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Format session distance (sessionManager.distance is in miles)
    private var formattedSessionDistance: String {
        let unit = WatchDistanceUnit.preferred
        let distanceInMeters = sessionManager.distance * 1609.34  // Convert miles to meters
        let value = distanceInMeters * unit.conversionFromMeters
        return String(format: "%.2f", value)
    }

    /// Get the pace unit label based on preferred distance unit
    private var paceUnit: String {
        "min/\(WatchDistanceUnit.preferred.abbreviation)"
    }

    private var formattedPace: String {
        guard sessionManager.distance > 0 else { return "--" }
        guard let startTime = sessionManager.sessionStartTime else { return "--" }

        let elapsedMinutes = Date().timeIntervalSince(startTime) / 60
        let unit = WatchDistanceUnit.preferred

        // Convert session distance (in miles) to preferred unit
        let distanceInMeters = sessionManager.distance * 1609.34
        let distanceInPreferredUnit = distanceInMeters * unit.conversionFromMeters

        let paceMinPerUnit = elapsedMinutes / distanceInPreferredUnit

        guard paceMinPerUnit.isFinite && paceMinPerUnit < 60 else { return "--" }

        let minutes = Int(paceMinPerUnit)
        let seconds = Int((paceMinPerUnit - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    JustWalkSecondaryStatsView()
}
