//
//  SavedRouteDetailView.swift
//  Just Walk
//
//  Full detail view for a saved route.
//  Shows large map, stats, and "Walk This Route" button.
//

import SwiftUI
import MapKit

struct SavedRouteDetailView: View {
    let route: SavedRoute
    var onStartWalk: (RouteGenerator.GeneratedRoute) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var savedRouteManager = SavedRouteManager.shared
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large route map
                    routeMapView
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Route name
                    Text(route.name)
                        .font(.system(size: 24, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Stats row
                    statsRow

                    // Walk history (if walked before)
                    if route.timesWalked > 0 {
                        walkHistorySection
                    }

                    // Walk this route button
                    walkButton
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            newName = route.name
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                    }
                }
            }
            .alert("Rename Route", isPresented: $showingRenameAlert) {
                TextField("Route name", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        savedRouteManager.renameRoute(route, to: newName)
                    }
                }
            } message: {
                Text("Enter a new name for this route")
            }
            .alert("Delete Route?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    savedRouteManager.deleteRoute(route)
                    dismiss()
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Route Map

    private var routeMapView: some View {
        Map {
            // Route polyline
            MapPolyline(coordinates: route.polylineCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            })
            .stroke(Color(hex: "00C7BE"), lineWidth: 4)

            // Start/End marker
            if let first = route.polylineCoordinates.first {
                Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                    Circle()
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                }
            }
        }
        .mapStyle(.standard)
        .mapControlVisibility(.hidden)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                title: "Distance",
                value: formatDistance(route.distance),
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                color: .teal
            )

            Divider()
                .frame(height: 50)

            statItem(
                title: "Est. Time",
                value: formatTime(route.estimatedTime),
                icon: "clock",
                color: .blue
            )

            Divider()
                .frame(height: 50)

            statItem(
                title: "Walked",
                value: "\(route.timesWalked)",
                icon: "figure.walk",
                color: .green
            )
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Walk History

    private var walkHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Walk History")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)

                if let lastWalked = route.lastWalkedAt {
                    Text("Last walked \(lastWalked, style: .relative) ago")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Walk Button

    private var walkButton: some View {
        Button {
            HapticService.shared.playSelection()
            let generatedRoute = savedRouteManager.toGeneratedRoute(route)
            savedRouteManager.recordWalk(for: route)
            onStartWalk(generatedRoute)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 20, weight: .semibold))
                Text("Walk This Route")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "00C7BE"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "%.1f mi", miles)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Preview

#Preview {
    SavedRouteDetailView(
        route: SavedRoute(
            name: "Morning Loop",
            distance: 1609.34,
            estimatedTime: 1200,
            polylineCoordinates: [
                CoordinatePair(latitude: 37.7749, longitude: -122.4194),
                CoordinatePair(latitude: 37.7759, longitude: -122.4174),
                CoordinatePair(latitude: 37.7769, longitude: -122.4184),
                CoordinatePair(latitude: 37.7749, longitude: -122.4194)
            ],
            centerLatitude: 37.7759,
            centerLongitude: -122.4184,
            timesWalked: 5,
            lastWalkedAt: Date().addingTimeInterval(-86400)
        ),
        onStartWalk: { route in print("Starting walk") }
    )
}
