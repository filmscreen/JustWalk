//
//  WatchSavedRoutesView.swift
//  Just Walk Watch App
//
//  List of saved routes with one-tap start.
//  Displays route name, distance, and estimated time.
//

import SwiftUI
import WatchKit

// MARK: - Saved Route Model

struct SavedRoute: Identifiable {
    let id: UUID
    let name: String
    let distanceMiles: Double
    let estimatedMinutes: Int
    let createdAt: Date

    var formattedDistance: String {
        let unit = WatchDistanceUnit.preferred
        let distanceInMeters = distanceMiles * 1609.34
        let convertedValue = distanceInMeters * unit.conversionFromMeters
        if convertedValue == floor(convertedValue) {
            return "\(Int(convertedValue)) \(unit.abbreviation)"
        }
        return String(format: "%.1f %@", convertedValue, unit.abbreviation)
    }

    var formattedTime: String {
        if estimatedMinutes < 60 {
            return "\(estimatedMinutes) min"
        }
        let hours = estimatedMinutes / 60
        let mins = estimatedMinutes % 60
        if mins == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(mins) min"
    }
}

// MARK: - Saved Routes View

struct WatchSavedRoutesView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    @State private var routes: [SavedRoute] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if routes.isEmpty {
                emptyState
            } else {
                routesList
            }
        }
        .navigationTitle("Saved Routes")
        .task {
            await loadRoutes()
        }
    }

    // MARK: - Routes List

    private var routesList: some View {
        List(routes) { route in
            Button {
                WKInterfaceDevice.current().play(.click)
                startWalkWithRoute(route)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(route.formattedDistance)
                        Text("~")
                        Text(route.formattedTime)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }
            .listRowBackground(Color.gray.opacity(0.15))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No Saved Routes")
                .font(.headline)

            Text("Save routes on iPhone\nto access them here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadRoutes() async {
        // Simulate loading delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        // In production, this would load from App Group or WatchConnectivity
        // For now, we'll show an empty state or sample data
        routes = []
        isLoading = false
    }

    private func startWalkWithRoute(_ route: SavedRoute) {
        // Create a distance goal from the route
        let goal = WalkGoal.distance(miles: route.distanceMiles)
        sessionManager.currentGoal = goal
        sessionManager.startSession(mode: .classic, goal: goal)
    }
}

// MARK: - Preview

#Preview("With Routes") {
    NavigationStack {
        WatchSavedRoutesView()
    }
}

#Preview("Empty") {
    NavigationStack {
        WatchSavedRoutesView()
    }
}
