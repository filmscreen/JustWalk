//
//  MagicRouteSheet.swift
//  Just Walk
//
//  Main sheet for Magic Route generation with re-roll limits.
//  Free users get 2 re-rolls (3 total routes) per session.
//

import SwiftUI
import CoreLocation
import MapKit

struct MagicRouteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var locationTracker = UserLocationTracker()
    @ObservedObject private var freeTierManager = FreeTierManager.shared

    /// Callback when user starts a walk with a route
    var onStartWalk: (RouteGenerator.GeneratedRoute) -> Void = { _ in }

    // MARK: - Selection State

    @State private var selectedDistanceMiles: Double?
    @State private var selectedTimeMinutes: Int?
    @State private var showPaywall = false

    // MARK: - Options

    let distanceOptions: [Double] = [1, 2, 3, 5]
    let timeOptions: [Int] = [15, 30, 45, 60]

    // MARK: - Computed

    private var hasSelection: Bool {
        selectedDistanceMiles != nil || selectedTimeMinutes != nil
    }

    private var isPro: Bool {
        routeManager.isPro
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                VStack(spacing: 24) {
                    if routeManager.currentRoute == nil {
                        selectionView
                    } else {
                        routePreviewView
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Loading overlay
                if routeManager.isGenerating {
                    GeneratingRouteOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        routeManager.resetSessionOnDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { routeManager.errorMessage != nil },
                set: { if !$0 { routeManager.errorMessage = nil } }
            )) {
                Button("OK") {
                    routeManager.errorMessage = nil
                }
            } message: {
                if let error = routeManager.errorMessage {
                    Text(error)
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
        .onAppear {
            locationTracker.startTracking()
        }
        .onDisappear {
            // Session cleanup handled by dismiss button
        }
    }

    // MARK: - Selection View

    @ViewBuilder
    private var selectionView: some View {
        // Header
        headerSection

        // Distance section
        distanceSection

        // Divider with "or by time"
        timeDivider

        // Time section
        timeSection

        Spacer()

        // Generate button
        generateButton
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Dice icon
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(JWDesign.Colors.brandSecondary)

            // Title
            Text("Magic Route")
                .font(.title2)
                .fontWeight(.bold)

            // Subtitle
            Text("We'll generate a circular route that starts and ends at your current location")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Distance Section

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISTANCE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(distanceOptions, id: \.self) { miles in
                    OptionChip(
                        label: "\(Int(miles)) mi",
                        isSelected: selectedDistanceMiles == miles
                    ) {
                        selectedDistanceMiles = miles
                        selectedTimeMinutes = nil
                    }
                }
            }
        }
    }

    // MARK: - Time Divider

    private var timeDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            Text("or by time")
                .font(.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(timeOptions, id: \.self) { minutes in
                    OptionChip(
                        label: "\(minutes) min",
                        isSelected: selectedTimeMinutes == minutes
                    ) {
                        selectedTimeMinutes = minutes
                        selectedDistanceMiles = nil
                    }
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            HapticService.shared.playSelection()
            generateRoute()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                Text("Generate Route")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                hasSelection
                    ? JWDesign.Colors.brandSecondary
                    : Color.gray.opacity(0.3)
            )
            .cornerRadius(JWDesign.Radius.button)
        }
        .buttonStyle(.plain)
        .disabled(!hasSelection)
    }

    // MARK: - Route Preview View

    @ViewBuilder
    private var routePreviewView: some View {
        if let route = routeManager.currentRoute {
            VStack(spacing: 0) {
                // Map with route
                MagicRouteMapView(route: route)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Stats and buttons
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

                    // Re-roll status for free users
                    if !isPro {
                        rerollStatusView
                    }

                    // Buttons
                    VStack(spacing: JWDesign.Spacing.sm) {
                        // Primary: Walk This Route
                        Button {
                            startWalk(route)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.walk")
                                Text("Walk This Route")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canStartWalk ? JWDesign.Colors.brandSecondary : Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canStartWalk)

                        // Show daily limit message if can't start
                        if !canStartWalk {
                            dailyLimitMessage
                        }

                        // Secondary: Try Another Route
                        Button {
                            tryAnotherRoute()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(tryAnotherButtonText)
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(routeManager.canRegenerate ? JWDesign.Colors.brandSecondary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                    .padding(.bottom, JWDesign.Spacing.lg)
                }
                .background(JWDesign.Colors.secondaryBackground)
            }
        }
    }

    // MARK: - Re-roll Status View

    private var rerollStatusView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(JWDesign.Colors.brandSecondary)

            Text(routeManager.remainingRerollsText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(JWDesign.Colors.brandSecondary.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Daily Limit Message

    private var dailyLimitMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.orange)

            Text("You've used your free magic route for today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var canStartWalk: Bool {
        freeTierManager.canStartMagicRouteToday
    }

    private var tryAnotherButtonText: String {
        if routeManager.canRegenerate {
            return "Try Another Route"
        } else {
            return "Unlock More Re-rolls"
        }
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(JWDesign.Colors.brandSecondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func generateRoute() {
        guard let location = locationTracker.currentLocation?.coordinate else {
            routeManager.errorMessage = "Unable to get your current location. Please ensure location services are enabled."
            return
        }

        Task {
            if let distanceMiles = selectedDistanceMiles {
                _ = await routeManager.generateRoute(distanceMiles: distanceMiles, from: location)
            } else if let timeMinutes = selectedTimeMinutes {
                _ = await routeManager.generateRoute(timeMinutes: timeMinutes, from: location)
            }
        }
    }

    private func tryAnotherRoute() {
        HapticService.shared.playSelection()

        if routeManager.canRegenerate {
            generateRoute()
        } else {
            // Show paywall for unlimited re-rolls
            showPaywall = true
        }
    }

    private func startWalk(_ route: RouteGenerator.GeneratedRoute) {
        guard freeTierManager.canStartMagicRouteToday else {
            // Shouldn't happen due to disabled button, but safety check
            return
        }

        HapticService.shared.playIncrementMilestone()

        // Record the walk start for daily limit tracking
        freeTierManager.recordMagicRouteWalkStarted()

        // Reset session state
        routeManager.resetSessionOnWalkStart()

        // Dismiss and start walk
        dismiss()
        onStartWalk(route)
    }

    // MARK: - Formatters

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

// MARK: - Magic Route Map View

struct MagicRouteMapView: UIViewRepresentable {
    let route: RouteGenerator.GeneratedRoute

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Calculate region
        let region = calculateRegion()
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

    private func calculateRegion() -> MKCoordinateRegion {
        guard !route.coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

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
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.teal)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "MagicRouteMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }

            view?.markerTintColor = UIColor(Color.teal)
            view?.glyphImage = UIImage(systemName: "flag.fill")

            return view
        }
    }
}

// Note: OptionChip and GeneratingRouteOverlay are defined in
// Views/Walk/Components/ and reused here

#Preview {
    MagicRouteSheet()
}
