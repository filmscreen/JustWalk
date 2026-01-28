//
//  AllSavedRoutesView.swift
//  Just Walk
//
//  Full list of all saved routes with swipe-to-delete.
//

import SwiftUI

struct AllSavedRoutesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var savedRouteManager = SavedRouteManager.shared

    var onStartWalk: (RouteGenerator.GeneratedRoute) -> Void = { _ in }

    @State private var selectedRoute: SavedRoute?

    var body: some View {
        NavigationStack {
            Group {
                if savedRouteManager.savedRoutes.isEmpty {
                    emptyState
                } else {
                    routesList
                }
            }
            .navigationTitle("Saved Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedRoute) { route in
                SavedRouteDetailView(route: route) { generatedRoute in
                    selectedRoute = nil
                    dismiss()
                    onStartWalk(generatedRoute)
                }
            }
        }
    }

    // MARK: - Routes List

    private var routesList: some View {
        List {
            ForEach(savedRouteManager.savedRoutes) { route in
                Button {
                    selectedRoute = route
                } label: {
                    routeRow(route)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteRoutes)
        }
        .listStyle(.plain)
    }

    private func routeRow(_ route: SavedRoute) -> some View {
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Saved Routes")
                .font(.headline)

            Text("After walking a Magic Route, you can save it to walk again later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            let route = savedRouteManager.savedRoutes[index]
            savedRouteManager.deleteRoute(route)
        }
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
    AllSavedRoutesView(
        onStartWalk: { _ in print("Start walk") }
    )
}
