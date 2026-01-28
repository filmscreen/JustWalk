//
//  ControlSheet.swift
//  Just Walk
//
//  Bottom control sheet for the map-forward Walk Tab.
//  Contains workout start buttons and past walks history.
//

import SwiftUI

struct ControlSheet: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var workoutHistoryManager = WorkoutHistoryManager.shared

    @State private var showPaywall = false
    @State private var showClassicInfo = false
    @State private var showIntervalInfo = false
    @State private var selectedWorkout: WorkoutHistoryItem?
    @State private var pendingWorkoutType: WalkMode?

    @Binding var isExpanded: Bool

    let onStartClassic: () -> Void
    let onStartInterval: () -> Void

    var body: some View {
        VStack(spacing: JWDesign.Spacing.sectionSpacing) {
            // Workout buttons - FIXED at top
            workoutButtonsSection
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Tappable "Past Walks" header row
            pastWalksHeader
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Past walks - SCROLLABLE (only when expanded)
            if isExpanded {
                ScrollView {
                    pastWalksContent
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                        .padding(.bottom, JWDesign.Spacing.xxxl)
                }
            }
        }
        .task {
            workoutHistoryManager.setModelContext(modelContext)
            await workoutHistoryManager.fetchWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutSaved)) { _ in
            Task {
                await workoutHistoryManager.fetchWorkouts()
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView {
                showPaywall = false
                if pendingWorkoutType == .classic {
                    onStartClassic()
                } else {
                    onStartInterval()
                }
                pendingWorkoutType = nil
            }
        }
        .sheet(isPresented: $showClassicInfo) {
            WorkoutInfoSheet(
                title: "Just Walk",
                subtitle: "Your Own Pace",
                description: "Go at your own pace. Your walk is saved to Apple Health and synced with your daily step goal.",
                themeColor: JWDesign.Colors.success,
                icon: "figure.walk",
                isPro: true
            )
        }
        .sheet(isPresented: $showIntervalInfo) {
            WorkoutInfoSheet(
                title: "Interval Walk",
                subtitle: "Burn More Calories",
                description: "Based on the Japanese Interval Walking Technique. Switch between 3 minutes of fast walking and 3 minutes of slow walking to burn more calories in less time.",
                themeColor: JWDesign.Colors.brandPrimary,
                icon: "figure.run",
                isPro: true
            )
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workoutItem: workout)
                .presentationDetents([.fraction(0.6)])
        }
    }

    // MARK: - Workout Buttons Section

    private var workoutButtonsSection: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            // Just Walk Button
            WorkoutStartButton(
                title: "Just Walk",
                subtitle: "Your Own Pace",
                themeColor: JWDesign.Colors.success,
                icon: "figure.walk",
                isLocked: false,
                onStart: {
                    HapticService.shared.playSelection()
                    if subscriptionManager.isPro {
                        onStartClassic()
                    } else {
                        pendingWorkoutType = .classic
                        showPaywall = true
                    }
                },
                onInfo: {
                    showClassicInfo = true
                }
            )

            // Interval Walk Button
            WorkoutStartButton(
                title: "Interval Walk",
                subtitle: "Burn More Calories",
                themeColor: JWDesign.Colors.brandPrimary,
                icon: "figure.run",
                isLocked: false,
                onStart: {
                    HapticService.shared.playSelection()
                    if subscriptionManager.isPro {
                        onStartInterval()
                    } else {
                        pendingWorkoutType = .interval
                        showPaywall = true
                    }
                },
                onInfo: {
                    showIntervalInfo = true
                }
            )
        }
    }

    // MARK: - Past Walks Header (Tappable)

    private var pastWalksHeader: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text("Past Walks")
                    .font(JWDesign.Typography.headline)
                    .foregroundStyle(.primary)

                if !workoutHistoryManager.workouts.isEmpty {
                    Text("(\(workoutHistoryManager.workouts.count))")
                        .font(JWDesign.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Past Walks Content

    @ViewBuilder
    private var pastWalksContent: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            if workoutHistoryManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if workoutHistoryManager.workouts.isEmpty {
                emptyHistoryView
            } else {
                let recentWorkouts = Array(workoutHistoryManager.workouts.prefix(5))

                VStack(spacing: 0) {
                    ForEach(recentWorkouts) { workout in
                        Button {
                            selectedWorkout = workout
                        } label: {
                            WorkoutHistoryRow(workout: workout)
                                .padding(.horizontal, JWDesign.Spacing.md)
                                .padding(.vertical, JWDesign.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task {
                                    await workoutHistoryManager.deleteWorkout(id: workout.id)
                                }
                            }
                        }

                        if workout.id != recentWorkouts.last?.id {
                            Divider()
                                .padding(.leading, JWDesign.Spacing.md)
                        }
                    }
                }
                .background(JWDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            Image(systemName: "figure.walk")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No walks yet")
                .font(JWDesign.Typography.headline)
                .foregroundStyle(.primary)

            Text("Start a walk to see your history here.")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JWDesign.Spacing.xxxl)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
}

// MARK: - Workout Start Button

struct WorkoutStartButton: View {
    let title: String
    let subtitle: String
    let themeColor: Color
    let icon: String
    let isLocked: Bool
    let onStart: () -> Void
    let onInfo: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(themeColor)
            }

            // Title + Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(JWDesign.Typography.headlineBold)

                    if isLocked {
                        Text("PRO")
                            .font(.caption2.bold())
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeColor.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    // Info button - next to title (subtle)
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text(subtitle)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Start button - prominent CTA
            Button(action: onStart) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("Start")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(themeColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        .shadow(
            color: JWDesign.Shadows.card(colorScheme: colorScheme).color,
            radius: JWDesign.Shadows.card(colorScheme: colorScheme).radius,
            y: JWDesign.Shadows.card(colorScheme: colorScheme).y
        )
    }
}

#Preview {
    ControlSheet(
        isExpanded: .constant(false),
        onStartClassic: {},
        onStartInterval: {}
    )
}
