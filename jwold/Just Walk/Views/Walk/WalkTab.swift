//
//  WalkTab.swift
//  Just Walk
//
//  Walk tab with goal-connected landing screen.
//  Landing → Countdown → Session
//

import SwiftUI

struct WalkTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showActiveWorkout = false
    @State private var activeMode: WalkMode = .classic
    @State private var activeGoal: WalkGoal = .none

    var body: some View {
        WalkLandingViewV2()
            .fullScreenCover(isPresented: $showActiveWorkout) {
                switch activeMode {
                case .classic:
                    PhoneWorkoutSessionView(walkGoal: activeGoal)
                case .interval:
                    IWTSessionView(mode: activeMode)
                case .postMeal:
                    PostMealActiveView()
                }
            }
            .onChange(of: showActiveWorkout) { oldValue, newValue in
                // Refresh workouts when session ends (fullScreenCover dismissed)
                if oldValue == true && newValue == false {
                    Task {
                        await WorkoutHistoryManager.shared.fetchWorkouts()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoteSessionStarted)) { notification in
                if let mode = notification.userInfo?["mode"] as? WalkMode {
                    let goal = notification.userInfo?["walkGoal"] as? WalkGoal ?? .none
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        activeMode = mode
                        activeGoal = goal
                        showActiveWorkout = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startWalkFromDashboard)) { _ in
                // Quick start from Dashboard - launch Just Walk immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    activeMode = .classic
                    activeGoal = .none
                    showActiveWorkout = true
                }
            }
    }
}

#Preview {
    WalkTab()
}
