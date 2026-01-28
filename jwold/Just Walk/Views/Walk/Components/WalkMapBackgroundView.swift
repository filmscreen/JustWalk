//
//  WalkMapBackgroundView.swift
//  Just Walk
//
//  Map background component for Walk tab.
//  Shows live map when authorized, gradient fallback when denied.
//

import SwiftUI
import MapKit

struct WalkMapBackgroundView: View {
    @ObservedObject var viewModel: WalkMapViewModel

    var body: some View {
        if viewModel.isLocationAuthorized {
            mapView
        } else {
            fallbackView
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(position: $viewModel.cameraPosition) {
            if let coordinate = viewModel.userCoordinate {
                Annotation("", coordinate: coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00C7BE").opacity(0.3))
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(Color(hex: "00C7BE"))
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls { }  // Hide default controls
        .overlay(alignment: .bottomTrailing) {
            recenterButton
        }
        .overlay(alignment: .bottom) {
            // Gradient fade at bottom edge for smooth transition to sheet
            LinearGradient(
                colors: [.clear, Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
        }
    }

    // MARK: - Recenter Button

    private var recenterButton: some View {
        Button {
            HapticService.shared.playSelection()
            viewModel.recenterOnUser()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "00C7BE"))
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 80) // Above the bottom sheet
    }

    // MARK: - Fallback View

    private var fallbackView: some View {
        LinearGradient(
            colors: [
                Color(hex: "00C7BE").opacity(0.3),
                Color(hex: "00C7BE").opacity(0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Enable location for map")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Location Authorized") {
    WalkMapBackgroundView(viewModel: WalkMapViewModel())
}
