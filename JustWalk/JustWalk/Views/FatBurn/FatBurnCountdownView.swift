//
//  FatBurnCountdownView.swift
//  JustWalk
//
//  Countdown + transition to active Fat Burn walk.
//  Handles starting the walk session and HR tracking.
//

import SwiftUI

struct FatBurnCountdownView: View {
    var onFlowComplete: () -> Void

    @StateObject private var walkSession = WalkSessionManager.shared
    @StateObject private var zoneManager = FatBurnZoneManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager = WalkUsageManager.shared
    @State private var showCountdown = true
    @State private var showCompletion = false
    @State private var showUpgradeSheet = false

    var body: some View {
        ZStack {
            if showCountdown {
                CountdownView {
                    // Check gating before starting
                    if !subscriptionManager.isPro && !usageManager.canStart(.fatBurn) {
                        showUpgradeSheet = true
                        return
                    }
                    startFatBurnWalk()
                    showCountdown = false
                }
                .transition(.opacity)
            } else if showCompletion, let walk = walkSession.completedWalk {
                FatBurnCompletionView(walk: walk) {
                    onFlowComplete()
                }
                .id(walk.id) // Stable identity prevents view recreation during parent re-renders
                .transition(.scaleUp)
            } else {
                FatBurnActiveView()
                    .transition(.slideUp)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCountdown)
        .animation(.easeInOut(duration: 0.3), value: showCompletion)
        .navigationBarBackButtonHidden(true)
        .onChange(of: walkSession.completedWalk != nil) { _, hasWalk in
            if hasWalk && walkSession.completedWalk?.mode == .fatBurn {
                // Save walk to persistence
                if let walk = walkSession.completedWalk {
                    PersistenceManager.shared.saveTrackedWalk(walk)

                    // Record usage for free users (only for walks >= 5 minutes)
                    if walk.durationMinutes >= 5 && !subscriptionManager.isPro {
                        usageManager.recordUsage(for: .fatBurn)
                    }
                }
                showCompletion = true
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            WalkUpgradeSheet.fatBurn(onUpgrade: { showUpgradeSheet = false })
        }
    }

    private func startFatBurnWalk() {
        zoneManager.recalculateZone()
        zoneManager.startSession()
        walkSession.startWalk(mode: .fatBurn)

        // Ensure Watch starts the fat burn workout (HR source)
        let watchConnectivity = PhoneConnectivityManager.shared
        if watchConnectivity.canCommunicateWithWatch, let walkId = walkSession.currentWalkId {
            let zoneLow = zoneManager.zoneLow
            let zoneHigh = zoneManager.zoneHigh
            watchConnectivity.startWorkoutOnWatch(
                walkId: walkId,
                startTime: walkSession.startTime,
                modeRaw: "fatBurn",
                zoneLow: zoneLow,
                zoneHigh: zoneHigh
            )
        }
    }
}

#Preview {
    NavigationStack {
        FatBurnCountdownView(onFlowComplete: {})
    }
}
