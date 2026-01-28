//
//  LocationPermissionOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI
import CoreLocation

struct LocationPermissionOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @ObservedObject private var locationManager = LocationPermissionManager.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 70))
                .foregroundStyle(.white)

            Text("Track Your Routes")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Enable location to see where you walk and map your favorite routes.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Privacy note
            Text("Location is only used while walking.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            VStack(spacing: 16) {
                Button(action: requestLocation) {
                    Text("Enable Location")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }

                Button(action: { coordinator.next() }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onChange(of: locationManager.authorizationStatus) { oldValue, newValue in
            // Advance when user responds to permission dialog
            if oldValue == .notDetermined && newValue != .notDetermined {
                coordinator.next()
            }
        }
    }

    private func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        // Delegate callback will trigger navigation via onChange
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        LocationPermissionOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
