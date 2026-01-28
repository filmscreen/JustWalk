//
//  ActiveRouteMapView.swift
//  Just Walk
//
//  UIViewRepresentable showing the route polyline with user location tracking.
//  Used during active route walks to display the planned route and user progress.
//

import SwiftUI
import MapKit
import CoreLocation

struct ActiveRouteMapView: UIViewRepresentable {
    let route: RouteGenerator.GeneratedRoute
    let userLocation: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true

        // Add route polyline
        mapView.addOverlay(route.polyline)

        // Add start/end marker
        if let startCoord = route.coordinates.first {
            let annotation = MKPointAnnotation()
            annotation.coordinate = startCoord
            annotation.title = "Start/End"
            mapView.addAnnotation(annotation)
        }

        // Set initial visible region with padding for bottom overlay
        let edgePadding = UIEdgeInsets(top: 100, left: 50, bottom: 280, right: 50)
        mapView.setVisibleMapRect(
            route.polyline.boundingMapRect,
            edgePadding: edgePadding,
            animated: false
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update user location tracking if needed
        // The map automatically updates user location via showsUserLocation
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
            // Don't customize user location
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
    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

    let mockRoute = RouteGenerator.GeneratedRoute(
        polyline: polyline,
        totalDistance: 1609.34,
        estimatedTime: 1200,
        waypoints: Array(coordinates.dropFirst().dropLast()),
        coordinates: coordinates
    )

    return ActiveRouteMapView(
        route: mockRoute,
        userLocation: coordinates.first
    )
}
