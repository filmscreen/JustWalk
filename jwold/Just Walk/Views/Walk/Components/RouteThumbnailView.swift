//
//  RouteThumbnailView.swift
//  Just Walk
//
//  Generates a static map thumbnail with route polyline overlay.
//  Uses MKMapSnapshotter for async image generation.
//

import SwiftUI
import MapKit

struct RouteThumbnailView: View {
    let route: SavedRoute
    let size: CGSize

    @State private var snapshotImage: UIImage?
    @State private var isLoading = true

    private let tealColor = UIColor(red: 0, green: 199/255, blue: 190/255, alpha: 1)

    var body: some View {
        ZStack {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder while loading
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "map")
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            await generateSnapshot()
        }
    }

    private func generateSnapshot() async {
        isLoading = true

        let coordinates = route.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        guard !coordinates.isEmpty else {
            isLoading = false
            return
        }

        // Calculate region that fits all coordinates with padding
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        var region = MKCoordinateRegion(polyline.boundingMapRect)

        // Add padding (20%)
        region.span.latitudeDelta *= 1.4
        region.span.longitudeDelta *= 1.4

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: size.width * 2, height: size.height * 2) // 2x for retina
        options.mapType = .standard
        options.showsBuildings = false

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = drawRouteOnSnapshot(snapshot: snapshot, coordinates: coordinates)
            await MainActor.run {
                self.snapshotImage = image
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func drawRouteOnSnapshot(snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D]) -> UIImage {
        let image = snapshot.image

        UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
        image.draw(at: .zero)

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }

        // Draw route polyline
        context.setStrokeColor(tealColor.cgColor)
        context.setLineWidth(4.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        var isFirstPoint = true
        for coordinate in coordinates {
            let point = snapshot.point(for: coordinate)
            if isFirstPoint {
                context.move(to: point)
                isFirstPoint = false
            } else {
                context.addLine(to: point)
            }
        }

        context.strokePath()

        // Draw start/end marker
        if let firstCoord = coordinates.first {
            let startPoint = snapshot.point(for: firstCoord)
            context.setFillColor(tealColor.cgColor)
            context.fillEllipse(in: CGRect(x: startPoint.x - 6, y: startPoint.y - 6, width: 12, height: 12))
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: startPoint.x - 3, y: startPoint.y - 3, width: 6, height: 6))
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return finalImage
    }
}

// MARK: - Convenience initializer for GeneratedRoute

extension RouteThumbnailView {
    init(generatedRoute: RouteGenerator.GeneratedRoute, size: CGSize) {
        let manager = SavedRouteManager.shared
        let coordinates = manager.extractCoordinates(from: generatedRoute.polyline)
        let center = coordinates.isEmpty ? CoordinatePair(latitude: 0, longitude: 0) :
            CoordinatePair(
                latitude: coordinates.reduce(0) { $0 + $1.latitude } / Double(coordinates.count),
                longitude: coordinates.reduce(0) { $0 + $1.longitude } / Double(coordinates.count)
            )

        self.init(
            route: SavedRoute(
                name: "",
                distance: generatedRoute.totalDistance,
                estimatedTime: generatedRoute.estimatedTime,
                polylineCoordinates: coordinates,
                centerLatitude: center.latitude,
                centerLongitude: center.longitude
            ),
            size: size
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RouteThumbnailView(
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
                centerLongitude: -122.4184
            ),
            size: CGSize(width: 60, height: 60)
        )

        RouteThumbnailView(
            route: SavedRoute(
                name: "Evening Walk",
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
            size: CGSize(width: 120, height: 120)
        )
    }
    .padding()
}
