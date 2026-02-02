//
//  WalkTabView.swift
//  JustWalk
//
//  Main walk tab container switching between idle and active states
//

import SwiftUI
import WidgetKit

struct WalkTabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @StateObject private var walkSession = WalkSessionManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager = WalkUsageManager.shared

    @State private var postWalkData: TrackedWalk?
    @State private var showCompletion = false
    @State private var showTooShortToast = false

    var body: some View {
        ZStack {
            if showCompletion, let walk = postWalkData {
                PostWalkSummaryView(walk: walk) {
                    showCompletion = false
                    postWalkData = nil
                    walkSession.completedWalk = nil
                    dismiss()
                }
                .id(walk.id) // Stable identity prevents view recreation during parent re-renders
                .transition(.scaleUp)
            } else if walkSession.isWalking {
                WalkActiveView()
            } else {
                WalkIdleView()
            }
        }
        .animation(JustWalkAnimation.morph, value: walkSession.isWalking)
        .animation(.easeInOut(duration: 0.3), value: showCompletion)
        .onChange(of: walkSession.isWalking) { wasWalking, isWalking in
            // When walk ends (was walking, now idle), process the completed walk
            if wasWalking && !isWalking, let walk = walkSession.completedWalk {
                processCompletedWalk(walk)
            }
        }
        .overlay {
            if showTooShortToast {
                TooShortToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(showCompletion ? "" : "Intervals")
        .navigationBarTitleDisplayMode(showCompletion ? .inline : .large)
        .navigationBarBackButtonHidden(walkSession.isWalking)
        .onAppear {
            // Track that user is viewing the walk screen (for active walk banner visibility)
            if walkSession.isWalking {
                appState.isViewingActiveWalk = true
            }
        }
        .onDisappear {
            appState.isViewingActiveWalk = false
        }
        .onChange(of: walkSession.isWalking) { _, isWalking in
            // Update viewing state when walk starts
            appState.isViewingActiveWalk = isWalking
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func processCompletedWalk(_ walk: TrackedWalk) {
        let persistence = PersistenceManager.shared

        // Check if walk meets minimum duration (5 minutes) for guided walks
        let meetsMinimumDuration = walk.durationMinutes >= 5
        let isGuidedWalk = walk.mode == .interval || walk.mode == .fatBurn
        let isTooShortGuided = isGuidedWalk && !meetsMinimumDuration

        // For guided walks under 5 minutes: still save for history, but don't count usage.
        if isTooShortGuided {
            showTooShortToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showTooShortToast = false
            }
        }

        // 1. Save walk to persistence (always do this first)
        persistence.saveTrackedWalk(walk)

        // 2. Record usage for free users (only for guided walks that meet minimum)
        if isGuidedWalk && meetsMinimumDuration && !subscriptionManager.isPro {
            usageManager.recordUsage(for: walk.mode)
        }

        // 3. Update today's daily log
        let today = Calendar.current.startOfDay(for: Date())
        let goal = persistence.loadProfile().dailyStepGoal
        var todayLog = persistence.loadDailyLog(for: today) ?? DailyLog(
            id: UUID(),
            date: today,
            steps: 0,
            goalMet: false,
            shieldUsed: false,
            trackedWalkIDs: [],
            goalTarget: goal
        )
        if todayLog.goalTarget == nil {
            todayLog.goalTarget = goal
        }
        todayLog.trackedWalkIDs.append(walk.id)
        let healthKitManager = HealthKitManager.shared
        if healthKitManager.isAuthorized {
            // Avoid double-counting; prefer HealthKit total for the day.
            let hkSteps = healthKitManager.todaySteps
            todayLog.steps = max(todayLog.steps, hkSteps, walk.steps)
            todayLog.goalMet = todayLog.steps >= (todayLog.goalTarget ?? goal)
        } else {
            // HealthKit unavailable: fall back to walk-based steps.
            todayLog.steps += walk.steps
            todayLog.goalMet = todayLog.steps >= (todayLog.goalTarget ?? goal)
        }
        persistence.saveDailyLog(todayLog)

        // 4. Check for interval walk milestone
        if walk.mode == .interval && !isTooShortGuided {
            let allWalks = persistence.loadAllTrackedWalks()
            let intervalCount = allWalks.filter { $0.mode == .interval }.count
            if intervalCount >= 10 {
                MilestoneManager.shared.trigger("walks_interval_10")
            }
        }

        // 5. Record walk for review prompt
        if !isTooShortGuided {
            ReviewManager.shared.recordWalk()
            ReviewManager.shared.requestReviewIfEligible()
        }

        // 6. Push updated data to widgets
        pushWidgetData()

        // 7. Handle completion UI for guided walks
        if isGuidedWalk {
            let hasCompletedFirstWalk = UserDefaults.standard.bool(forKey: "hasCompletedFirstWalk")
            if !hasCompletedFirstWalk {
                // First guided walk: Show the celebration moment (not PostWalkSummaryView)
                // The moment provides a special "Your first walk. That's Day 1." experience
                UserDefaults.standard.set(true, forKey: "hasCompletedFirstWalk")
                EmotionalMomentTrigger.shared.post(.firstWalk)
                return
            }
        }

        // 8. Show post-walk summary (for non-first guided walks and all other walks)
        postWalkData = walk
        showCompletion = true
    }

    private func pushWidgetData() {
        Task {
            let steps = await HealthKitManager.shared.fetchTodaySteps()
            let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
            let streak = StreakManager.shared.streakData.currentStreak
            let calendar = Calendar.current
            let weekSteps = (-6...0).map { offset -> Int in
                guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return 0 }
                return PersistenceManager.shared.loadDailyLog(for: date)?.steps ?? 0
            }
            JustWalkWidgetData.updateWidgetData(
                todaySteps: steps,
                stepGoal: goal,
                currentStreak: streak,
                weekSteps: weekSteps
            )
        }
    }
}

// MARK: - Too Short Toast

private struct TooShortToast: View {
    var body: some View {
        VStack {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(JW.Color.accentBlue)
                Text("Walk too short to count. Try again!")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textPrimary)
            }
            .padding(.vertical, JW.Spacing.md)
            .padding(.horizontal, JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .fill(JW.Color.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: JW.Radius.lg)
                            .stroke(JW.Color.accentBlue.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

            Spacer()
        }
        .padding(.top, JW.Spacing.lg)
        .padding(.horizontal, JW.Spacing.lg)
    }
}

#Preview {
    WalkTabView()
}
