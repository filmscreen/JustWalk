//
//  WatchTodayView.swift
//  JustWalkWatch Watch App
//
//  Main dashboard showing today's stats
//

import SwiftUI

struct WatchTodayView: View {
    @State private var todaySteps: Int = 0
    @State private var streakInfo: WatchStreakInfo = .empty
    @State private var isAnimating = false
    @State private var showDebugSheet = false
    @State private var debugProfile: WatchDebugProfile?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var displaySteps: Int {
        debugProfile?.steps ?? todaySteps
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

    private var goalMet: Bool {
        displaySteps >= dailyGoal
    }

    private var progressPercent: Int {
        guard dailyGoal > 0 else { return 0 }
        return min(Int(Double(displaySteps) / Double(dailyGoal) * 100), 100)
    }

    private var stepsRemaining: Int {
        max(dailyGoal - displaySteps, 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // HealthKit authorization message
                if WatchHealthKitManager.shared.authorizationDenied {
                    VStack(spacing: 6) {
                        Image(systemName: "heart.slash")
                            .font(.title3)
                            .foregroundStyle(.red)
                        Text("Step Tracking Off")
                            .font(.caption.bold())
                        Text("Open Health on your iPhone to allow JustWalk access.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 8)
                } else if WatchHealthKitManager.shared.healthDataUnavailable {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text("Health data not available on this device.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 8)
                }

                // Debug mode indicator
                if debugProfile != nil {
                    Text("DEBUG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                }

                // Step progress ring
                WatchStepRingView(steps: displaySteps, goal: dailyGoal, size: 120)
                    .onTapGesture(count: 3) {
                        showDebugSheet = true
                    }
                    .padding(.bottom, 8)

                // Streak badge
                HStack(spacing: 4) {
                    Image(systemName: displayStreak > 0 ? "flame.fill" : "flame")
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeating, value: displayStreak > 0 && isAnimating && !reduceMotion)
                    Text("\(displayStreak)")
                        .fontWeight(.semibold)
                }
                .font(.system(.body, weight: .medium))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Streak: \(displayStreak) days")

                // Phone connection status
                PhoneConnectionIndicator()
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            .opacity(isLuminanceReduced ? 0.6 : 1.0)
        }
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
    }

    private func refreshData() async {
        todaySteps = await WatchHealthKitManager.shared.fetchTodaySteps()
        streakInfo = WatchPersistenceManager.shared.loadStreakInfo()
    }
}

#Preview {
    NavigationStack {
        WatchTodayView()
    }
}
