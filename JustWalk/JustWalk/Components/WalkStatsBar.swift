//
//  WalkStatsBar.swift
//  JustWalk
//
//  Shared stats bar showing time, steps, and distance for all walk types
//

import SwiftUI

struct WalkStatsBar: View {
    let elapsedSeconds: Int
    let steps: Int
    let distanceMeters: Double

    var body: some View {
        HStack(spacing: 24) {
            StatPill(value: formatDuration(elapsedSeconds), label: "Time")
                .contentTransition(.numericText())
            StatPill(value: "\(steps.formatted())", label: "Steps")
                .contentTransition(.numericText())
            StatPill(value: formatDistance(distanceMeters), label: "Distance")
                .contentTransition(.numericText())
        }
        .padding()
        .jwGlassEffect()
        .animation(.default, value: elapsedSeconds)
    }

    // MARK: - Formatters

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var useMetric: Bool {
        PersistenceManager.shared.cachedUseMetric
    }

    private func formatDistance(_ meters: Double) -> String {
        if useMetric {
            if meters < 1000 {
                return "\(Int(meters))m"
            } else {
                return String(format: "%.1f km", meters / 1000)
            }
        } else {
            let miles = meters / 1609.344
            return String(format: "%.1f mi", miles)
        }
    }
}

#Preview {
    WalkStatsBar(elapsedSeconds: 754, steps: 1200, distanceMeters: 950)
        .padding()
        .background(Color.black)
}
