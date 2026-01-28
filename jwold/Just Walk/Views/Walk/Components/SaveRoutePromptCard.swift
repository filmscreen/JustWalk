//
//  SaveRoutePromptCard.swift
//  Just Walk
//
//  Prompt card shown after completing a route walk.
//  Allows user to save the route with a custom name.
//

import SwiftUI
import MapKit
import CoreLocation

struct SaveRoutePromptCard: View {
    let route: RouteGenerator.GeneratedRoute
    var onSave: (String) -> Void
    var onSkip: () -> Void = {}
    var onShowPaywall: () -> Void = {}

    @ObservedObject private var savedRouteManager = SavedRouteManager.shared
    @State private var routeName: String
    @State private var isSaved = false

    init(
        route: RouteGenerator.GeneratedRoute,
        onSave: @escaping (String) -> Void,
        onSkip: @escaping () -> Void = {},
        onShowPaywall: @escaping () -> Void = {}
    ) {
        self.route = route
        self.onSave = onSave
        self.onSkip = onSkip
        self.onShowPaywall = onShowPaywall
        self._routeName = State(initialValue: SavedRouteManager.defaultRouteName())
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color(hex: "00C7BE"))
                Text("Save This Route?")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }

            if isSaved {
                // Success state
                savedConfirmation
            } else if savedRouteManager.isAtFreeLimit {
                // Free limit reached
                freeLimitReached
            } else {
                // Save form
                saveForm
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Save Form

    private var saveForm: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Route thumbnail
                RouteThumbnailView(generatedRoute: route, size: CGSize(width: 60, height: 60))

                // Route info + name field
                VStack(alignment: .leading, spacing: 8) {
                    // Route stats
                    HStack(spacing: 12) {
                        Label(formatDistance(route.totalDistance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        Label(formatTime(route.estimatedTime), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Editable name
                    TextField("Route name", text: $routeName)
                        .font(.system(size: 15, weight: .medium))
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    saveRoute()
                } label: {
                    Text("Save Route")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "00C7BE"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Saved Confirmation

    private var savedConfirmation: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Route Saved!")
                    .font(.system(size: 15, weight: .semibold))
                Text("Find it in your Walk tab anytime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Free Limit Reached

    private var freeLimitReached: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Route Limit Reached")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Free users can save up to 3 routes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                onShowPaywall()
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Pro")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "00C7BE"), Color(hex: "00A89D")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func saveRoute() {
        let name = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? SavedRouteManager.defaultRouteName() : name

        onSave(finalName)

        withAnimation(.easeInOut(duration: 0.3)) {
            isSaved = true
        }

        HapticService.shared.playSuccess()
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

#Preview("Can Save") {
    SaveRoutePromptCard(
        route: RouteGenerator.GeneratedRoute(
            polyline: MKPolyline(
                coordinates: [
                    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4174),
                    CLLocationCoordinate2D(latitude: 37.7769, longitude: -122.4184),
                    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ],
                count: 4
            ),
            totalDistance: 1609.34,
            estimatedTime: 1200,
            waypoints: [],
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4174),
                CLLocationCoordinate2D(latitude: 37.7769, longitude: -122.4184),
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ]
        ),
        onSave: { _ in },
        onSkip: { },
        onShowPaywall: { }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
