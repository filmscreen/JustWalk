//
//  WatchAppState.swift
//  JustWalkWatch Watch App
//
//  Manages the overall Watch app state and navigation
//

import SwiftUI
import Combine
import os

@MainActor
final class WatchAppState: ObservableObject {

    enum Screen {
        case idle
        case activeWalk
        case walkSummary(WatchWalkRecord)
    }

    private nonisolated static let logger = Logger(subsystem: "com.justwalk.watch", category: "AppState")

    @Published var currentScreen: Screen = .idle

    let walkSession = WatchWalkSessionManager()

    private let connectivity = WatchConnectivityManager.shared

    init() {
        setupConnectivityCallbacks()
    }

    private func setupConnectivityCallbacks() {
        // iPhone says: Start workout (now with optional interval data)
        connectivity.onStartWorkoutCommand = { [weak self] walkId, intervalData in
            Task { @MainActor in
                self?.startWalk(transferData: intervalData)
            }
        }

        // iPhone says: Pause
        connectivity.onPauseWorkoutCommand = { [weak self] in
            self?.walkSession.pauseWalk()
        }

        // iPhone says: Resume
        connectivity.onResumeWorkoutCommand = { [weak self] in
            self?.walkSession.resumeWalk()
        }

        // iPhone says: End workout
        connectivity.onEndWorkoutCommand = { [weak self] in
            Task { @MainActor in
                await self?.endWalk()
            }
        }
    }

    // MARK: - Public Methods

    /// Start walk from Watch (user initiated)
    func startWalk(interval: WatchIntervalProgram? = nil, transferData: IntervalTransferData? = nil, mode: WalkMode = .standard) {
        walkSession.startWalk(interval: interval, transferData: transferData, mode: mode)
        currentScreen = .activeWalk
    }

    /// Start a fat burn zone walk
    func startFatBurnWalk() {
        walkSession.startWalk(mode: .fatBurn)
        currentScreen = .activeWalk
    }

    /// End walk and show summary
    func endWalk() async {
        // Prevent re-entry while ending is in progress
        guard !walkSession.isEnding else { return }

        if let record = await walkSession.endWalk() {
            currentScreen = .walkSummary(record)
        } else {
            currentScreen = .idle
        }
    }

    /// Dismiss summary and return to idle
    func dismissSummary() {
        currentScreen = .idle
    }
}
