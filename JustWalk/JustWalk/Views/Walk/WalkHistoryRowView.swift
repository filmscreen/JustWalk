//
//  WalkHistoryRowView.swift
//  JustWalk
//
//  Individual walk history card display
//

import SwiftUI

struct WalkHistoryRowView: View {
    let walk: TrackedWalk
    let useMetric: Bool

    // MARK: - Cached Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    // MARK: - Computed Properties

    private var walkTypeLabel: String {
        switch walk.mode {
        case .interval:
            return walk.intervalProgram?.displayName ?? "Interval Walk"
        case .fatBurn:
            return "Fat Burn Zone"
        case .postMeal, .free:
            return "Post-Meal"
        }
    }

    private var modeIcon: String {
        switch walk.mode {
        case .interval: return "bolt.fill"
        case .fatBurn: return "heart.fill"
        case .postMeal, .free: return "fork.knife"
        }
    }

    private var modeIconColor: Color {
        switch walk.mode {
        case .interval: return JW.Color.accent
        case .fatBurn: return JW.Color.streak
        case .postMeal, .free: return JW.Color.streak
        }
    }

    private var formattedDuration: String {
        let mins = walk.durationMinutes
        if mins < 1 {
            return "<1 min"
        } else if mins < 60 {
            return "\(mins) min"
        } else {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
    }

    private var formattedSteps: String {
        walk.steps.formatted()
    }

    private var formattedDistance: String {
        if useMetric {
            if walk.distanceMeters < 1000 {
                return "\(Int(walk.distanceMeters)) m"
            }
            return String(format: "%.1f km", walk.distanceMeters / 1000)
        } else {
            return String(format: "%.2f mi", walk.distanceMeters / 1609.344)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.md) {
            // Top: icon + walk type + date
            HStack(spacing: JW.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(modeIconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: modeIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(modeIconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(walkTypeLabel)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textPrimary)

                    Text(Self.dateFormatter.string(from: walk.startTime))
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }

            // Bottom: stat row
            HStack(spacing: JW.Spacing.lg) {
                Label(formattedDuration, systemImage: "clock")
                Label(formattedSteps, systemImage: "figure.walk")
                Label(formattedDistance, systemImage: "map")
            }
            .font(JW.Font.caption)
            .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(JW.Spacing.lg)
        .jwCard()
    }
}
