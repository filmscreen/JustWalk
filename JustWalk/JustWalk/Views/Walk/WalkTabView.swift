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
    @StateObject private var walkSession = WalkSessionManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager = WalkUsageManager.shared

    @State private var postWalkData: TrackedWalk?
    @State private var showTooShortToast = false

    var body: some View {
        ZStack {
            if walkSession.isWalking {
                WalkActiveView()
            } else {
                WalkIdleView()
            }
        }
        .animation(JustWalkAnimation.morph, value: walkSession.isWalking)
        .onChange(of: walkSession.isWalking) { wasWalking, isWalking in
            // When walk ends (was walking, now idle), process the completed walk
            if wasWalking && !isWalking, let walk = walkSession.completedWalk {
                processCompletedWalk(walk)
            }
        }
        .sheet(item: $postWalkData, onDismiss: {
            walkSession.completedWalk = nil
            dismiss()
        }) { walk in
            PostWalkSummaryView(walk: walk)
        }
        .overlay {
            if showTooShortToast {
                TooShortToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle("Intervals")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(walkSession.isWalking)
    }

    private func processCompletedWalk(_ walk: TrackedWalk) {
        let persistence = PersistenceManager.shared

        // Check if walk meets minimum duration (5 minutes) for guided walks
        let meetsMinimumDuration = walk.durationMinutes >= 5
        let isGuidedWalk = walk.mode == .interval || walk.mode == .fatBurn

        // For guided walks under 5 minutes: discard and show toast
        if isGuidedWalk && !meetsMinimumDuration {
            showTooShortToast = true
            // Don't save the walk or record usage
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showTooShortToast = false
            }
            pushWidgetData()
            return
        }

        // 1. Save walk to persistence
        persistence.saveTrackedWalk(walk)

        // 2. Record usage for free users (only for guided walks that meet minimum)
        if isGuidedWalk && meetsMinimumDuration && !subscriptionManager.isPro {
            usageManager.recordUsage(for: walk.mode)
        }

        // 3. Update today's daily log
        let today = Calendar.current.startOfDay(for: Date())
        var todayLog = persistence.loadDailyLog(for: today) ?? DailyLog(
            id: UUID(),
            date: today,
            steps: 0,
            goalMet: false,
            shieldUsed: false,
            trackedWalkIDs: []
        )
        todayLog.trackedWalkIDs.append(walk.id)
        todayLog.steps += walk.steps
        persistence.saveDailyLog(todayLog)

        // 4. Check for interval walk milestone
        if walk.mode == .interval {
            let allWalks = persistence.loadAllTrackedWalks()
            let intervalCount = allWalks.filter { $0.mode == .interval }.count
            if intervalCount >= 10 {
                MilestoneManager.shared.trigger("walks_interval_10")
            }
        }

        // 5. Record walk for review prompt
        ReviewManager.shared.recordWalk()
        ReviewManager.shared.requestReviewIfEligible()

        // 6. Show post-walk summary
        postWalkData = walk

        // 7. Push updated data to widgets
        pushWidgetData()
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
