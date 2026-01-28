//
//  WalkActiveView.swift
//  JustWalk
//
//  Active walk state — dispatches to IntervalActiveView or free walk layout
//

import SwiftUI

struct WalkActiveView: View {
    @StateObject private var walkSession = WalkSessionManager.shared
    @State private var showEndConfirmation = false

    var body: some View {
        switch walkSession.currentMode {
        case .interval:
            IntervalActiveView()
        case .free, .fatBurn, .postMeal:
            freeWalkBody
        }
    }

    // MARK: - Free Walk Layout

    private var freeWalkBody: some View {
        ZStack {
            WalkMapView(
                coordinates: walkSession.routeCoordinates,
                currentLocation: walkSession.currentLocation
            )
            .ignoresSafeArea()

            VStack {
                WalkStatsBar(
                    elapsedSeconds: walkSession.elapsedSeconds,
                    steps: walkSession.currentSteps,
                    distanceMeters: walkSession.currentDistance
                )

                Spacer()

                WalkControlBar(
                    isPaused: walkSession.isPaused,
                    onTogglePause: {
                        if walkSession.isPaused {
                            walkSession.resumeWalk()
                        } else {
                            walkSession.pauseWalk()
                        }
                    },
                    onEnd: {
                        showEndConfirmation = true
                    }
                )
            }
        }
        .alert("End this walk?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                Task { await walkSession.endWalk() }
            }
            Button("Keep Going", role: .cancel) {}
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(JW.Font.title3.bold().monospacedDigit())
            Text(label)
                .font(JW.Font.caption2)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }
}

#Preview {
    WalkActiveView()
}
