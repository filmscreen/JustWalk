//
//  RouteMapView.swift
//  Just Walk
//
//  Displays workout routes on a map with start/end markers.
//  Uses iOS 17+ SwiftUI Map with MapPolyline.
//

import SwiftUI
import MapKit
import HealthKit
import CoreLocation

// MARK: - Route Map View

struct RouteMapView: View {
    let workout: HKWorkout

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RouteMapViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.routeCoordinates.isEmpty {
                emptyStateView
            } else {
                mapContent
            }
        }
        .background(Color(uiColor: .systemBackground))
        .task {
            await viewModel.loadRoute(for: workout)
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $viewModel.cameraPosition) {
            // Route polyline (blue - brand primary)
            MapPolyline(coordinates: viewModel.routeCoordinates)
                .stroke(.blue, lineWidth: 4)

            // Start marker (green)
            if let startCoordinate = viewModel.routeCoordinates.first {
                Annotation("Start", coordinate: startCoordinate) {
                    RouteMarker(type: .start)
                }
            }

            // End marker (red)
            if let endCoordinate = viewModel.routeCoordinates.last,
               viewModel.routeCoordinates.count > 1 {
                Annotation("End", coordinate: endCoordinate) {
                    RouteMarker(type: .end)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Route Stats Overlay

    private var routeStatsOverlay: some View {
        HStack(spacing: 24) {
            routeStatItem(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                value: viewModel.formattedDistance,
                label: "Distance"
            )

            Divider()
                .frame(height: 40)

            routeStatItem(
                icon: "clock.fill",
                value: viewModel.formattedDuration,
                label: "Duration"
            )

            if let pace = viewModel.formattedPace {
                Divider()
                    .frame(height: 40)

                routeStatItem(
                    icon: "speedometer",
                    value: pace,
                    label: "Pace"
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func routeStatItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading route...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Route Available")
                .font(.headline)

            Text("This workout doesn't have GPS data recorded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Route Marker View

struct RouteMarker: View {
    enum MarkerType {
        case start
        case end

        var color: Color {
            switch self {
            case .start: return .green
            case .end: return .red
            }
        }

        var icon: String {
            switch self {
            case .start: return "flag.fill"
            case .end: return "flag.checkered"
            }
        }
    }

    let type: MarkerType

    var body: some View {
        ZStack {
            Circle()
                .fill(type.color)
                .frame(width: 32, height: 32)
                .shadow(color: type.color.opacity(0.4), radius: 4, y: 2)

            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Navigation Wrapper

struct RouteMapNavigationView: View {
    let workout: HKWorkout
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RouteMapViewModel()

    // Sharing state
    @State private var showSharePreview = false
    @State private var showPaywall = false
    @State private var capturedMapImage: UIImage?
    @State private var isCapturingSnapshot = false

    var body: some View {
        NavigationStack {
            RouteMapViewWithViewModel(workout: workout, viewModel: viewModel)
                .navigationTitle("Route")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            HapticService.shared.playSelection()
                            if FreeTierManager.shared.isPro {
                                captureMapAndShare()
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            if isCapturingSnapshot {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(viewModel.routeCoordinates.isEmpty || isCapturingSnapshot)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .sheet(isPresented: $showSharePreview) {
                    SharePreviewSheet(cardType: .workout(workoutShareData))
                        .presentationDetents([.large])
                }
                .fullScreenCover(isPresented: $showPaywall) {
                    ProPaywallView()
                }
        }
    }

    /// Share data for the workout card
    private var workoutShareData: WorkoutShareData {
        WorkoutShareData(
            date: workout.startDate,
            duration: workout.duration,
            distanceMeters: viewModel.totalDistance,
            steps: nil,  // Steps not available in workout route
            routeImage: capturedMapImage
        )
    }

    /// Capture map snapshot and trigger share preview
    private func captureMapAndShare() {
        guard !viewModel.routeCoordinates.isEmpty else { return }

        isCapturingSnapshot = true

        // Create snapshot options
        let options = MKMapSnapshotter.Options()

        // Calculate region from coordinates
        let coordinates = viewModel.routeCoordinates
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.4  // Add padding
        let spanLon = (maxLon - minLon) * 1.4

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: max(spanLat, 0.01), longitudeDelta: max(spanLon, 0.01))
        options.region = MKCoordinateRegion(center: center, span: span)

        // Set snapshot size (match share card map section)
        options.size = CGSize(width: 1080, height: 1056)
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)

        snapshotter.start { snapshot, error in
            DispatchQueue.main.async {
                isCapturingSnapshot = false

                guard let snapshot = snapshot else {
                    print("Failed to capture map snapshot: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                // Draw route on snapshot
                let image = UIGraphicsImageRenderer(size: snapshot.image.size).image { context in
                    // Draw the map
                    snapshot.image.draw(at: .zero)

                    // Draw route polyline
                    let path = UIBezierPath()
                    for (index, coord) in coordinates.enumerated() {
                        let point = snapshot.point(for: coord)
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }

                    UIColor.systemBlue.setStroke()
                    path.lineWidth = 6
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()

                    // Draw start marker
                    if let startCoord = coordinates.first {
                        let startPoint = snapshot.point(for: startCoord)
                        drawMarker(at: startPoint, color: .systemGreen, in: context.cgContext)
                    }

                    // Draw end marker
                    if let endCoord = coordinates.last, coordinates.count > 1 {
                        let endPoint = snapshot.point(for: endCoord)
                        drawMarker(at: endPoint, color: .systemRed, in: context.cgContext)
                    }
                }

                capturedMapImage = image
                showSharePreview = true
            }
        }
    }

    /// Draw a circular marker at the given point
    private func drawMarker(at point: CGPoint, color: UIColor, in context: CGContext) {
        let markerSize: CGFloat = 24
        let rect = CGRect(
            x: point.x - markerSize / 2,
            y: point.y - markerSize / 2,
            width: markerSize,
            height: markerSize
        )

        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)

        // White border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: rect)
    }
}

// MARK: - Route Map View with ViewModel (internal use)

private struct RouteMapViewWithViewModel: View {
    let workout: HKWorkout
    @ObservedObject var viewModel: RouteMapViewModel

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.routeCoordinates.isEmpty {
                emptyStateView
            } else {
                mapContent
            }
        }
        .background(Color(uiColor: .systemBackground))
        .task {
            await viewModel.loadRoute(for: workout)
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $viewModel.cameraPosition) {
            // Route polyline (blue - brand primary)
            MapPolyline(coordinates: viewModel.routeCoordinates)
                .stroke(.blue, lineWidth: 4)

            // Start marker (green)
            if let startCoordinate = viewModel.routeCoordinates.first {
                Annotation("Start", coordinate: startCoordinate) {
                    RouteMarker(type: .start)
                }
            }

            // End marker (red)
            if let endCoordinate = viewModel.routeCoordinates.last,
               viewModel.routeCoordinates.count > 1 {
                Annotation("End", coordinate: endCoordinate) {
                    RouteMarker(type: .end)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading route...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Route Available")
                .font(.headline)

            Text("This workout doesn't have GPS data recorded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
// Note: Preview requires a real HKWorkout from HealthKit, disabled to avoid deprecation warning
// #Preview {
//     RouteMapView(workout: HKWorkout(activityType: .walking, start: Date(), end: Date()))
// }
