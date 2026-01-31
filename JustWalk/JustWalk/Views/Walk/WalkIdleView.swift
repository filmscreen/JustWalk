//
//  WalkIdleView.swift
//  JustWalk
//
//  Walk idle state with gradient background and interval preset cards
//

import SwiftUI
import CoreLocation

struct WalkIdleView: View {
    @StateObject private var walkSession = WalkSessionManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedInterval: IntervalProgram? = nil
    @State private var preFlightProgram: IntervalProgram? = nil
    @State private var showPaywall = false
    @State private var showUpgradeSheet = false
    @State private var showCustomBuilder = false
    @StateObject private var usageManager = WalkUsageManager.shared

    // Countdown state
    @State private var showCountdown = false
    @State private var pendingIntervalProgram: IntervalProgram? = nil
    @State private var pendingCustomConfig: CustomIntervalConfig? = nil
    @State private var pendingWalkId: UUID? = nil

    private let watchConnectivity = PhoneConnectivityManager.shared

    private var isWatchAvailable: Bool {
        watchConnectivity.canCommunicateWithWatch
    }

    private var freeIntervalsRemaining: Int? {
        subscriptionManager.isPro ? nil : usageManager.remainingFree(for: .interval)
    }

    var body: some View {
        ZStack {
            // Gradient background (replaces map)
            JW.Color.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable preset cards
                ScrollView(showsIndicators: false) {
                    BottomPanel(
                        selectedInterval: $selectedInterval,
                        isPro: subscriptionManager.isPro,
                        freeIntervalsRemaining: freeIntervalsRemaining,
                        onStartTap: handleStartTap,
                        onIntervalTap: handleIntervalTap,
                        onCustomTap: { showCustomBuilder = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(item: $preFlightProgram) { program in
            IntervalPreFlightSheet(program: program) {
                startIntervalWalk(program: program)
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProUpgradeView(onComplete: { showPaywall = false })
        }
        .sheet(isPresented: $showUpgradeSheet) {
            WalkUpgradeSheet.interval(onUpgrade: { showPaywall = true })
        }
        .sheet(isPresented: $showCustomBuilder) {
            CustomIntervalBuilderSheet { config in
                startCustomIntervalWalk(config: config)
            }
        }
        .fullScreenCover(isPresented: $showCountdown) {
            CountdownView {
                // Countdown complete — start the walk and notify Watch simultaneously
                if let program = pendingIntervalProgram {
                    let walkId = pendingWalkId
                    walkSession.startWalk(mode: .interval, intervalProgram: program, walkId: walkId)

                    // Notify Watch at the same time iPhone starts
                    if isWatchAvailable {
                        let transferData = buildTransferData(
                            name: program.displayName,
                            totalSeconds: program.duration * 60,
                            phases: program.phases
                        )
                        watchConnectivity.startWorkoutOnWatch(
                            walkId: walkId ?? UUID(),
                            startTime: walkSession.startTime,
                            intervalData: transferData,
                            modeRaw: "interval"
                        )
                    }

                    pendingIntervalProgram = nil
                    pendingWalkId = nil
                } else if let config = pendingCustomConfig {
                    let walkId = pendingWalkId
                    walkSession.startWalk(mode: .interval, customInterval: config, walkId: walkId)

                    // Notify Watch at the same time iPhone starts
                    if isWatchAvailable {
                        let transferData = buildTransferData(
                            name: config.displayName,
                            totalSeconds: config.totalMinutes * 60,
                            phases: config.phases
                        )
                        watchConnectivity.startWorkoutOnWatch(
                            walkId: walkId ?? UUID(),
                            startTime: walkSession.startTime,
                            intervalData: transferData,
                            modeRaw: "interval"
                        )
                    }

                    pendingCustomConfig = nil
                    pendingWalkId = nil
                }
            }
        }
        .onAppear {
            JustWalkHaptics.prepareForWalk()
            // Refresh usage data
            usageManager.refreshWeek()

            let status = walkSession.locationAuthorizationStatus
            if status == .notDetermined {
                walkSession.requestLocationAuthorization()
            }

        }
    }

    // MARK: - Actions

    private func hasSeenPreFlight(for program: IntervalProgram) -> Bool {
        UserDefaults.standard.bool(forKey: "hasSeenPreFlight_\(program.rawValue)")
    }

    private func markPreFlightSeen(for program: IntervalProgram) {
        UserDefaults.standard.set(true, forKey: "hasSeenPreFlight_\(program.rawValue)")
    }

    private func handleStartTap() {
        guard let interval = selectedInterval else { return }
        // Gating check
        if !subscriptionManager.isPro && !usageManager.canStart(.interval) {
            showUpgradeSheet = true
            return
        }

        if hasSeenPreFlight(for: interval) {
            // Repeat user — skip explainer, start directly
            startIntervalWalk(program: interval)
        } else {
            // First time — show explainer sheet
            preFlightProgram = interval
        }
    }

    private func handleIntervalTap(_ program: IntervalProgram) {
        JustWalkHaptics.selectionChanged()
        withAnimation(JustWalkAnimation.micro) {
            if selectedInterval == program {
                selectedInterval = nil
            } else {
                selectedInterval = program
            }
        }
    }

    private func startIntervalWalk(program: IntervalProgram) {
        // Mark pre-flight as seen so it's skipped next time
        markPreFlightSeen(for: program)

        // Note: Usage is recorded after walk completion (in WalkTabView) only if walk >= 5 minutes

        // Show countdown, then start walk + notify Watch when countdown completes
        let walkId = UUID()
        pendingIntervalProgram = program
        pendingWalkId = walkId
        showCountdown = true
        selectedInterval = nil
    }

    private func startCustomIntervalWalk(config: CustomIntervalConfig) {
        // Note: Usage is recorded after walk completion (in WalkTabView) only if walk >= 5 minutes

        // Show countdown, then start walk + notify Watch when countdown completes
        let walkId = UUID()
        pendingCustomConfig = config
        pendingWalkId = walkId
        showCountdown = true
    }

    private func buildTransferData(name: String, totalSeconds: Int, phases: [IntervalPhase]) -> IntervalTransferData {
        IntervalTransferData(
            programName: name,
            totalDurationSeconds: totalSeconds,
            phases: phases.map { phase in
                IntervalPhaseData(
                    type: phase.type.rawValue,
                    durationSeconds: phase.durationSeconds,
                    startOffset: phase.startOffset
                )
            }
        )
    }
}

#Preview {
    WalkIdleView()
}
