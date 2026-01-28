//
//  TimeSelectionView.swift
//  Just Walk
//
//  Screen 1: Time selection for walk duration.
//  "How long do you want to walk?" with quick select buttons.
//

import SwiftUI
import MapKit

struct TimeSelectionView: View {
    @StateObject private var locationManager = LocationPermissionManager()
    @StateObject private var userLocationTracker = UserLocationTracker()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showPastWalks = false
    @State private var showCustomPicker = false
    @State private var customMinutes = 30
    @State private var selectedDuration: Int? = nil
    @State private var navigateToWalkType = false

    private let presetDurations = [15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                // Map background (dimmed)
                mapBackground

                // Content overlay
                VStack(spacing: 0) {
                    Spacer()

                    // Main content card
                    contentCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPastWalks) {
                PastWalksSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCustomPicker) {
                customDurationPicker
                    .presentationDetents([.height(280)])
            }
            .navigationDestination(isPresented: $navigateToWalkType) {
                if let duration = selectedDuration {
                    WalkTypeSelectionView(durationMinutes: duration)
                }
            }
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Map Background

    private var mapBackground: some View {
        ZStack {
            if locationManager.isAuthorized {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea()
                .onChange(of: userLocationTracker.currentLocation) { _, newLocation in
                    guard let location = newLocation?.coordinate else { return }
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            } else {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }

            // Dimming overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            Text("How long do you want to walk?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Duration grid
            durationGrid

            // Past walks link
            pastWalksLink
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Duration Grid

    private var durationGrid: some View {
        VStack(spacing: 12) {
            // Row 1: 15, 30, 45
            HStack(spacing: 12) {
                ForEach(presetDurations.prefix(3), id: \.self) { minutes in
                    durationButton(minutes: minutes)
                }
            }

            // Row 2: 60, Custom
            HStack(spacing: 12) {
                durationButton(minutes: 60)
                customButton
            }
        }
    }

    private func durationButton(minutes: Int) -> some View {
        Button {
            HapticService.shared.playSelection()
            selectedDuration = minutes
            navigateToWalkType = true
        } label: {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                Text("min")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var customButton: some View {
        Button {
            HapticService.shared.playSelection()
            showCustomPicker = true
        } label: {
            Text("Custom")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Past Walks Link

    private var pastWalksLink: some View {
        Button {
            HapticService.shared.playSelection()
            showPastWalks = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15))
                Text("View past walks")
                    .font(.system(size: 15, weight: .regular))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Duration Picker

    private var customDurationPicker: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select duration")
                    .font(.headline)
                    .padding(.top, 8)

                Picker("Duration", selection: $customMinutes) {
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)

                Button {
                    HapticService.shared.playSelection()
                    selectedDuration = customMinutes
                    showCustomPicker = false
                    navigateToWalkType = true
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "00C7BE"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showCustomPicker = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TimeSelectionView()
}
