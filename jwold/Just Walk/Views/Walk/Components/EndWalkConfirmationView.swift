//
//  EndWalkConfirmationView.swift
//  Just Walk
//
//  Confirmation dialog shown when ending a meaningful walk.
//

import SwiftUI

struct EndWalkConfirmationView: View {
    let steps: Int
    let durationSeconds: TimeInterval
    let distanceMeters: Double

    var onKeepWalking: () -> Void
    var onEndWalk: () -> Void

    private let tealColor = Color(hex: "00C7BE")
    private let redColor = Color(hex: "FF3B30")

    var body: some View {
        ZStack {
            // Dimmed background - tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onKeepWalking() }

            // Modal
            VStack(spacing: 24) {
                Text("End this walk?")
                    .font(.system(size: 22, weight: .bold))

                // Stats
                VStack(spacing: 8) {
                    Text(primaryStatText)
                        .font(.system(size: 20, weight: .semibold))
                    Text(secondaryStatsText)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                // Buttons
                VStack(spacing: 12) {
                    // Keep Walking - PRIMARY (teal filled)
                    Button {
                        HapticService.shared.playSelection()
                        onKeepWalking()
                    } label: {
                        Text("Keep Walking")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(tealColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // End Walk - SECONDARY (red outline)
                    Button {
                        HapticService.shared.playIncrementMilestone()
                        onEndWalk()
                    } label: {
                        Text("End Walk")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(redColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(redColor, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Primary Stat Logic

    private var primaryStatText: String {
        if steps >= 1000 {
            return "You've walked \(steps.formatted()) steps"
        } else if distanceMiles >= 0.5 {
            return "You've walked \(String(format: "%.1f", distanceMiles)) miles"
        } else {
            return "You've been walking for \(durationMinutes) min"
        }
    }

    private var secondaryStatsText: String {
        var parts: [String] = []

        // Add stats that weren't primary
        if steps < 1000 {
            parts.append("\(steps.formatted()) steps")
        }
        if distanceMiles < 0.5 {
            parts.append(String(format: "%.1f mi", distanceMiles))
        }
        if steps >= 1000 || distanceMiles >= 0.5 {
            parts.append("\(durationMinutes) min")
        }

        return "(" + parts.prefix(2).joined(separator: " • ") + ")"
    }

    private var distanceMiles: Double { distanceMeters * 0.000621371 }
    private var durationMinutes: Int { Int(durationSeconds / 60) }
}

#Preview("1500 steps") {
    EndWalkConfirmationView(
        steps: 1500,
        durationSeconds: 720,
        distanceMeters: 644,
        onKeepWalking: {},
        onEndWalk: {}
    )
}

#Preview("0.8 miles") {
    EndWalkConfirmationView(
        steps: 400,
        durationSeconds: 480,
        distanceMeters: 1287,
        onKeepWalking: {},
        onEndWalk: {}
    )
}

#Preview("10 min") {
    EndWalkConfirmationView(
        steps: 300,
        durationSeconds: 600,
        distanceMeters: 322,
        onKeepWalking: {},
        onEndWalk: {}
    )
}
