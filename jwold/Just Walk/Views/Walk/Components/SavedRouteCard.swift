//
//  SavedRouteCard.swift
//  Just Walk
//
//  Compact card showing a saved route with thumbnail and stats.
//  Tappable to open route detail view.
//

import SwiftUI

struct SavedRouteCard: View {
    let route: SavedRoute
    var onTap: () -> Void = {}

    var body: some View {
        Button {
            HapticService.shared.playSelection()
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Route thumbnail
                RouteThumbnailView(route: route, size: CGSize(width: 60, height: 60))

                // Route info
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label(formatDistance(route.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        Label(formatTime(route.estimatedTime), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Times walked indicator
                    if route.timesWalked > 0 {
                        Text("Walked \(route.timesWalked) time\(route.timesWalked == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
    VStack(spacing: 12) {
        SavedRouteCard(
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
                timesWalked: 3
            ),
            onTap: { print("Tapped") }
        )

        SavedRouteCard(
            route: SavedRoute(
                name: "Evening Walk Around the Park",
                distance: 3218.68,
                estimatedTime: 2400,
                polylineCoordinates: [
                    CoordinatePair(latitude: 37.7749, longitude: -122.4194),
                    CoordinatePair(latitude: 37.7759, longitude: -122.4174),
                    CoordinatePair(latitude: 37.7769, longitude: -122.4184),
                    CoordinatePair(latitude: 37.7749, longitude: -122.4194)
                ],
                centerLatitude: 37.7759,
                centerLongitude: -122.4184
            ),
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
