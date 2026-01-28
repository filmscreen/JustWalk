//
//  RouteGeneratorSheet.swift
//  Just Walk
//
//  Created by Claude on 2026-01-22.
//

import SwiftUI
import CoreLocation

struct RouteGeneratorSheet: View {
    @StateObject private var viewModel = RouteGeneratorViewModel()
    @StateObject private var locationTracker = UserLocationTracker()
    @Environment(\.dismiss) private var dismiss

    var onStartWalk: (RouteGenerator.GeneratedRoute) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Distance section
                    distanceSection

                    // Divider with "or by time"
                    timeDivider

                    // Time section
                    timeSection

                    Spacer()

                    // Free tier limit message
                    if !viewModel.isPro && viewModel.routesRemainingToday == 0 {
                        limitReachedMessage
                    }

                    // Generate button
                    generateButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Loading overlay
                if viewModel.isGenerating {
                    GeneratingRouteOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                }
            }
            .sheet(item: $viewModel.generatedRoute) { route in
                RoutePreviewSheet(
                    route: route,
                    onStartWalk: {
                        dismiss()
                        onStartWalk(route)
                    },
                    onTryAnother: {
                        if let location = locationTracker.currentLocation?.coordinate {
                            viewModel.regenerateRoute(from: location)
                        }
                    }
                )
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
        }
        .onAppear {
            locationTracker.startTracking()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Dice icon
            Image(systemName: "dice")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "00C7BE"))

            // Title
            Text("Generate a Route")
                .font(.title2)
                .fontWeight(.bold)

            // Subtitle
            Text("We'll create a loop that starts and ends at your current location")
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
                ForEach(viewModel.distanceOptions, id: \.self) { miles in
                    OptionChip(
                        label: "\(Int(miles)) mi",
                        isSelected: viewModel.selectedDistanceMiles == miles
                    ) {
                        viewModel.selectDistance(miles)
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
                ForEach(viewModel.timeOptions, id: \.self) { minutes in
                    OptionChip(
                        label: "\(minutes) min",
                        isSelected: viewModel.selectedTimeMinutes == minutes
                    ) {
                        viewModel.selectTime(minutes)
                    }
                }
            }
        }
    }

    // MARK: - Limit Reached Message

    private var limitReachedMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.orange)

            Text("You've used your free route for today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            HapticService.shared.playSelection()
            if let location = locationTracker.currentLocation?.coordinate {
                viewModel.generateRoute(from: location)
            } else {
                viewModel.error = "Unable to get your current location. Please ensure location services are enabled."
            }
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
                viewModel.hasSelection && viewModel.canGenerateRoute
                    ? Color(hex: "00C7BE")
                    : Color.gray.opacity(0.3)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasSelection || !viewModel.canGenerateRoute)
    }
}

// MARK: - Make GeneratedRoute Identifiable for sheet presentation

extension RouteGenerator.GeneratedRoute: Identifiable {
    public var id: Int {
        // Use distance and coordinate count as a simple hash
        Int(totalDistance) ^ coordinates.count
    }
}

#Preview {
    RouteGeneratorSheet()
}
