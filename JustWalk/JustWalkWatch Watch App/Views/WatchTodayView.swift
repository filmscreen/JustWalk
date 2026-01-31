//
//  WatchTodayView.swift
//  JustWalkWatch Watch App
//
//  Main dashboard showing today's stats
//

import SwiftUI
import HealthKit

struct WatchTodayView: View {
    @State private var streakInfo: WatchStreakInfo = .empty
    @State private var isAnimating = false
    @State private var showDebugSheet = false
    @State private var debugProfile: WatchDebugProfile?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase

    private var healthKitManager: WatchHealthKitManager {
        WatchHealthKitManager.shared
    }

    private var displaySteps: Int {
        if let debugSteps = debugProfile?.steps {
            return debugSteps
        }
        switch healthKitManager.stepDataState {
        case .available(let steps):
            return steps
        case .loading, .unavailable:
            return 0
        }
    }

    private var displayGoal: Int {
        debugProfile?.goal ?? streakInfo.dailyStepGoal
    }

    private var displayStreak: Int {
        debugProfile?.streak ?? streakInfo.currentStreak
    }

    private var dailyGoal: Int {
        displayGoal
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                contentView(size: side, fullSize: proxy.size)

                if debugProfile != nil {
                    VStack {
                        Text("DEBUG")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                        Spacer()
                    }
                    .padding(.top, 6)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
        .onAppear { isAnimating = true }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showDebugSheet) {
            WatchDebugView(
                onSelect: { profile in
                    debugProfile = profile
                },
                onReset: {
                    debugProfile = nil
                }
            )
        }
        .task {
            await refreshData()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Refresh on foreground (wrist raise, tap complication, etc.)
                Task {
                    await WatchHealthKitManager.shared.refreshIfDayChanged()
                    streakInfo = WatchPersistenceManager.shared.loadStreakInfo()
                }
            }
        }
    }

    @ViewBuilder
    private func contentView(size: CGFloat, fullSize: CGSize) -> some View {
        // Debug mode overrides state machine
        if debugProfile != nil {
            WatchStepRingView(
                steps: displaySteps,
                goal: dailyGoal,
                streak: displayStreak,
                size: size * 0.9
            )
            .frame(width: fullSize.width, height: fullSize.height, alignment: .center)
            .onTapGesture(count: 3) {
                showDebugSheet = true
            }
        } else {
            // Use state machine for rendering
            switch healthKitManager.stepDataState {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)

            case .available(let steps):
                WatchStepRingView(
                    steps: steps,
                    goal: dailyGoal,
                    streak: displayStreak,
                    size: size * 0.9
                )
                .frame(width: fullSize.width, height: fullSize.height, alignment: .center)
                .onTapGesture(count: 3) {
                    showDebugSheet = true
                }

            case .unavailable(let reason):
                unavailableView(reason: reason)
            }
        }
    }

    @ViewBuilder
    private func unavailableView(reason: UnavailableReason) -> some View {
        VStack(spacing: 8) {
            switch reason {
            case .noHealthData:
                Image(systemName: "heart.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Health data not available on this device")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

            case .notAuthorized:
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Step tracking unavailable")
                    .font(.caption)
                    .foregroundStyle(.primary)
                Text("Open Settings → Privacy → Health to enable.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 12)
    }

    private func refreshData() async {
        _ = await WatchHealthKitManager.shared.fetchTodaySteps()
        streakInfo = WatchPersistenceManager.shared.loadStreakInfo()
    }
}

#Preview {
    NavigationStack {
        WatchTodayView()
    }
}
