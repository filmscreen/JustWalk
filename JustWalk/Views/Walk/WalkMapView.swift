//
//  WalkMapView.swift
//  JustWalk
//
//  Map view displaying walk route with polyline
//

import SwiftUI
import MapKit

// MARK: - Equatable Extension for CLLocationCoordinate2D

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct WalkMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    let currentLocation: CLLocationCoordinate2D?

    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $mapPosition) {
            // Route polyline
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(JW.Color.accent, lineWidth: 4)
            }

            // Start marker
            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                }
            }

            // Current location marker
            if let current = currentLocation {
                Annotation("You", coordinate: current) {
                    ZStack {
                        Circle()
                            .stroke(.red.opacity(0.4), lineWidth: 3)
                            .frame(width: 40, height: 40)
                        Circle()
                            .fill(JW.Color.accent)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .preferredColorScheme(.dark)
        .mapControls {
            MapCompass()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: {
                if let location = currentLocation {
                    withAnimation(JustWalkAnimation.standard) {
                        mapPosition = .camera(
                            MapCamera(
                                centerCoordinate: location,
                                distance: 500,
                                heading: 0,
                                pitch: 45
                            )
                        )
                    }
                }
            }) {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .padding(12)
            }
            .jwGlassEffect()
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
        .onChange(of: currentLocation) { _, newLocation in
            if let location = newLocation {
                withAnimation(JustWalkAnimation.standard) {
                    mapPosition = .camera(
                        MapCamera(
                            centerCoordinate: location,
                            distance: 500,
                            heading: 0,
                            pitch: 45
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Preview Helpers

extension CLLocationCoordinate2D {
    static let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
}

#Preview {
    WalkMapView(
        coordinates: [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4190),
            CLLocationCoordinate2D(latitude: 37.7755, longitude: -122.4185)
        ],
        currentLocation: CLLocationCoordinate2D(latitude: 37.7755, longitude: -122.4185)
    )
}
