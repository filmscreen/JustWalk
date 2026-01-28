//
//  RoutePreviewSheet.swift
//  Just Walk
//
//  Created by Claude on 2026-01-22.
//

import SwiftUI
import MapKit
import CoreLocation

struct RoutePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let route: RouteGenerator.GeneratedRoute
    var goal: WalkGoal? = nil
    var onStartWalk: () -> Void = {}
    var onTryAnother: () -> Void = {}

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map with route
                TealRoutePreviewMap(
                    route: route,
                    region: $mapRegion
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Stats and buttons overlay
                VStack(spacing: JWDesign.Spacing.md) {
                    // Stats row
                    HStack(spacing: JWDesign.Spacing.xl) {
                        statItem(
                            icon: "point.topleft.down.to.point.bottomright.curvepath",
                            value: formatDistance(route.totalDistance),
                            label: "Distance"
                        )

                        Divider()
                            .frame(height: 40)

                        statItem(
                            icon: "clock",
                            value: formatTime(route.estimatedTime),
                            label: "Est. Time"
                        )
                    }
                    .padding(.horizontal, JWDesign.Spacing.lg)
                    .padding(.top, JWDesign.Spacing.md)

                    // Goal badge (if goal-based route)
                    if let goal = goal, goal.type != .none {
                        goalBadge(for: goal)
                    }

                    // Route disclaimer (always show for goal routes)
                    if goal != nil {
                        routeDisclaimer
                    }

                    // Buttons
                    VStack(spacing: JWDesign.Spacing.sm) {
                        // Primary: Walk This Route
                        Button {
                            HapticService.shared.playIncrementMilestone()
                            dismiss()
                            onStartWalk()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.walk")
                                Text("Walk This Route")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "00C7BE"))
                            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
                        }
                        .buttonStyle(.plain)

                        // Secondary: Try Another Route
                        Button {
                            HapticService.shared.playSelection()
                            dismiss()
                            onTryAnother()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Try Another Route")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "00C7BE"))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                    .padding(.bottom, JWDesign.Spacing.lg)
                }
                .background(JWDesign.Colors.secondaryBackground)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Route")
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            updateMapRegion()
        }
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "00C7BE"))
                Text(value)
                    .font(.system(size: 20, weight: .bold))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Goal Badge

    private func goalBadge(for goal: WalkGoal) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "target")
                .font(.system(size: 12))
            Text(goal.displayString + " goal")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(Color(hex: "00C7BE"))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "00C7BE").opacity(0.15))
        )
    }

    // MARK: - Route Disclaimer

    private var routeDisclaimer: some View {
        Text("Route times and distances are estimates based on a 2.5 mph walking pace.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, JWDesign.Spacing.lg)
    }

    // MARK: - Helpers

    private func updateMapRegion() {
        // Calculate bounding box for the route
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for coord in route.coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,  // Add padding
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        mapRegion = MKCoordinateRegion(center: center, span: span)
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles < 1 {
            return String(format: "%.2f mi", miles)
        }
        return String(format: "%.1f mi", miles)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMins = minutes % 60
        if remainingMins == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainingMins) min"
    }
}

// MARK: - Teal Route Preview Map

struct TealRoutePreviewMap: UIViewRepresentable {
    let route: RouteGenerator.GeneratedRoute
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)

        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        // Add route polyline
        mapView.addOverlay(route.polyline)

        // Add start/end annotation
        if let startCoord = route.coordinates.first {
            let annotation = MKPointAnnotation()
            annotation.coordinate = startCoord
            annotation.title = "Start/End"
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color(hex: "00C7BE"))  // Teal
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "StartEndMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }

            view?.markerTintColor = UIColor(Color(hex: "00C7BE"))  // Teal
            view?.glyphImage = UIImage(systemName: "flag.fill")

            return view
        }
    }
}

#Preview {
    // Create a mock route for preview
    let coordinates = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4174),
        CLLocationCoordinate2D(latitude: 37.7769, longitude: -122.4184),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    ]
    _ = MKPolyline(coordinates: coordinates, count: coordinates.count)

    return Text("RoutePreviewSheet Preview")
}
