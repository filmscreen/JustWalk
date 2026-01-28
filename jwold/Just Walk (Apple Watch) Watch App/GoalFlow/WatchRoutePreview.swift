//
//  WatchRoutePreview.swift
//  Just Walk Watch App
//
//  Simplified route preview (no map, just stats).
//  Shows estimated distance and time for a generated route.
//

import SwiftUI
import WatchKit

struct WatchRoutePreview: View {
    let goal: WalkGoal

    var onStart: () -> Void
    var onCancel: () -> Void

    @State private var isGenerating = true
    @State private var routeDistance: Double?
    @State private var routeTime: Double?
    @State private var triesRemaining = 3
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if isGenerating {
                generatingView
            } else if let distance = routeDistance {
                routeReadyView(distance: distance)
            } else if let error = errorMessage {
                errorView(message: error)
            }
        }
        .padding()
        .task {
            await generateRoute()
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Finding route...")
                .font(.headline)

            Text("This may take a moment")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Route Ready View

    private func routeReadyView(distance: Double) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)

            Text("Route Ready")
                .font(.headline)

            // Distance
            let unit = WatchDistanceUnit.preferred
            let distanceInMeters = distance * 1609.34
            let convertedValue = distanceInMeters * unit.conversionFromMeters
            Text("~\(String(format: "%.1f", convertedValue)) \(unit.abbreviation)")
                .font(.title2.bold())

            // Time estimate
            if let time = routeTime {
                Text("~\(Int(time)) min")
                    .foregroundStyle(.secondary)
            }

            Text("Estimates may vary")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            // Start Walk Button
            Button {
                WKInterfaceDevice.current().play(.click)
                onStart()
            } label: {
                Text("Start Walk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .buttonStyle(.plain)

            // Try Another (if tries remaining)
            if triesRemaining > 0 {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    regenerateRoute()
                } label: {
                    Text("Try Another")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)

                Text("\(triesRemaining) tries left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("Route Error")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                WKInterfaceDevice.current().play(.click)
                onCancel()
            } label: {
                Text("Go Back")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Route Generation

    private func generateRoute() async {
        isGenerating = true
        errorMessage = nil

        // Simulate route generation delay
        // In production, this would call a route generation service
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Calculate estimated route based on goal
        let estimatedDistance = WalkGoalPresets.estimatedDistance(for: goal)

        if estimatedDistance > 0 {
            routeDistance = estimatedDistance
            // Estimate time: average walking pace is ~3 mph
            routeTime = (estimatedDistance / 3.0) * 60 // minutes
        } else {
            // Default to 1 mile if we can't estimate
            routeDistance = 1.0
            routeTime = 20
        }

        isGenerating = false
    }

    private func regenerateRoute() {
        guard triesRemaining > 0 else { return }
        triesRemaining -= 1

        Task {
            await generateRoute()
        }
    }
}

// MARK: - Preview

#Preview("Generating") {
    WatchRoutePreview(
        goal: .time(minutes: 30.0),
        onStart: { print("Start") },
        onCancel: { print("Cancel") }
    )
}

#Preview("Ready") {
    WatchRoutePreview(
        goal: .distance(miles: 2.0),
        onStart: { print("Start") },
        onCancel: { print("Cancel") }
    )
}
