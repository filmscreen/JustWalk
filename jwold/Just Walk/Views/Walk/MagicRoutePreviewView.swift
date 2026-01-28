//
//  MagicRoutePreviewView.swift
//  Just Walk
//
//  Sheet view showing the generated route preview with map,
//  stats overlay, and start/regenerate buttons.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MagicRoutePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let targetDistance: Double  // miles
    var onStartWalk: (RouteGenerator.GeneratedRoute) -> Void

    @State private var generatedRoute: RouteGenerator.GeneratedRoute?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    @StateObject private var locationTracker = LocationTracker()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                JWDesign.Colors.background
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let route = generatedRoute {
                    routePreviewContent(route)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "AF52DE"))
                        Text("Magic Route")
                            .font(.headline)
                    }
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
        .task {
            await generateRoute()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "AF52DE"))

            Text("Generating your route...")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Finding the best \(String(format: "%.1f", targetDistance)) mile loop near you")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Route Generation Failed")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await generateRoute()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "AF52DE"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, JWDesign.Spacing.sm)
        }
        .padding()
    }

    // MARK: - Route Preview Content

    private func routePreviewContent(_ route: RouteGenerator.GeneratedRoute) -> some View {
        VStack(spacing: 0) {
            // Map with route
            RoutePreviewMap(
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

                // Buttons
                HStack(spacing: JWDesign.Spacing.md) {
                    // Regenerate button
                    Button {
                        HapticService.shared.playSelection()
                        Task {
                            await generateRoute()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("New Route")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "AF52DE"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "AF52DE").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
                    }
                    .buttonStyle(.plain)

                    // Start button
                    Button {
                        HapticService.shared.playIncrementMilestone()
                        dismiss()
                        onStartWalk(route)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text("Start Walk")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "AF52DE"))
                        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                .padding(.bottom, JWDesign.Spacing.lg)
            }
            .background(JWDesign.Colors.secondaryBackground)
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "AF52DE"))
                Text(value)
                    .font(.system(size: 20, weight: .bold))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func generateRoute() async {
        isLoading = true
        errorMessage = nil

        // Get current location
        guard let location = getCurrentLocation() else {
            await MainActor.run {
                errorMessage = "Unable to get your current location. Please ensure location services are enabled."
                isLoading = false
            }
            return
        }

        // Update map region to center on user
        await MainActor.run {
            mapRegion = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        // Generate route
        await withCheckedContinuation { continuation in
            RouteGenerator.shared.generateRoute(
                from: location,
                targetDistance: targetDistance
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let route):
                        self.generatedRoute = route
                        self.updateMapRegion(for: route)
                        self.isLoading = false
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        return locationTracker.currentLocation
    }

    private func updateMapRegion(for route: RouteGenerator.GeneratedRoute) {
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

// MARK: - Route Preview Map

struct RoutePreviewMap: UIViewRepresentable {
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
                renderer.strokeColor = UIColor(Color(hex: "AF52DE"))
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

            view?.markerTintColor = UIColor(Color(hex: "AF52DE"))
            view?.glyphImage = UIImage(systemName: "flag.fill")

            return view
        }
    }
}

// MARK: - Location Tracker Helper

@MainActor
private class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location.coordinate
        }
    }
}

// MARK: - Preview

#Preview {
    MagicRoutePreviewView(
        targetDistance: 1.0,
        onStartWalk: { route in
            print("Start walk with route: \(route.totalDistance)m")
        }
    )
}
