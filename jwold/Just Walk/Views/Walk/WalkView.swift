//
//  WalkView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//  Refined with Minimal Cards & Workout History.
//

import SwiftUI

struct WalkView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeWalkMode: WalkMode?
    @State private var showPaywall = false
    @State private var showClassicInfo = false
    @State private var showIntervalInfo = false
    @State private var showGPSWorkout = false
    @State private var showGPSInfo = false
    @State private var showMagicRouteSheet = false
    @State private var showMagicRouteInfo = false
    @State private var pendingMagicRoute: RouteGenerator.GeneratedRoute?
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var workoutHistoryManager = WorkoutHistoryManager.shared

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Custom compact header
                    Text("Walk")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    ScrollView {
                        VStack(spacing: JWDesign.Spacing.md) {
                            // Just Walk Card
                            MinimalWorkoutCard(
                                title: "Just Walk",
                                subtitle: "Your Own Pace",
                                themeColor: JWDesign.Colors.success,
                                icon: "figure.walk",
                                isLocked: false,
                                onStart: {
                                    HapticService.shared.playSelection()
                                    activeWalkMode = .classic
                                },
                                onInfo: {
                                    showClassicInfo = true
                                }
                            )

                            // Interval Walk Card
                            MinimalWorkoutCard(
                                title: "Interval Walk",
                                subtitle: "Burn More Calories",
                                themeColor: JWDesign.Colors.brandPrimary,
                                icon: "figure.run",
                                isLocked: !subscriptionManager.isPro,
                                onStart: {
                                    HapticService.shared.playSelection()
                                    if subscriptionManager.isPro {
                                        activeWalkMode = .interval
                                    } else {
                                        showPaywall = true
                                    }
                                },
                                onInfo: {
                                    showIntervalInfo = true
                                }
                            )

                            // Just Walk Card (iPhone workout with route recording)
                            MinimalWorkoutCard(
                                title: "Just Walk",
                                subtitle: "Track Your Route",
                                themeColor: .purple,
                                icon: "location.fill",
                                isLocked: false,
                                onStart: {
                                    HapticService.shared.playSelection()
                                    showGPSWorkout = true
                                },
                                onInfo: {
                                    showGPSInfo = true
                                }
                            )

                            // Magic Route Card
                            MinimalWorkoutCard(
                                title: "Magic Route",
                                subtitle: "Guided Circular Walk",
                                themeColor: JWDesign.Colors.brandSecondary,
                                icon: "wand.and.stars",
                                isLocked: false,
                                onStart: {
                                    HapticService.shared.playSelection()
                                    showMagicRouteSheet = true
                                },
                                onInfo: {
                                    showMagicRouteInfo = true
                                }
                            )

                            // MARK: - Workout History Section
                            workoutHistorySection
                        }
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                        .padding(.bottom, JWDesign.Spacing.xxxl)
                        .id("top")
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
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
                    if let tab = notification.object as? AppTab, tab == .walk {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .background(JWDesign.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $activeWalkMode) { mode in
                IWTSessionView(mode: mode)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView {
                    showPaywall = false
                    activeWalkMode = .interval
                }
            }
            .sheet(isPresented: $showClassicInfo) {
                WorkoutInfoSheet(
                    title: "Just Walk",
                    subtitle: "Your Own Pace",
                    description: "Go at your own pace. Your walk is saved to Apple Health and synced with your daily step goal.",
                    themeColor: JWDesign.Colors.success,
                    icon: "figure.walk"
                )
            }
            .sheet(isPresented: $showIntervalInfo) {
                WorkoutInfoSheet(
                    title: "Interval Walk",
                    subtitle: "Burn More Calories",
                    description: "Based on the Japanese Interval Walking Technique. Switch between 3 minutes of fast walking and 3 minutes of slow walking to burn more calories in less time. Studies show this technique can improve fitness and metabolism more effectively than steady-paced walking.",
                    themeColor: JWDesign.Colors.brandPrimary,
                    icon: "figure.run",
                    isPro: true
                )
            }
            .fullScreenCover(isPresented: $showGPSWorkout) {
                // If we have a pending magic route, use RouteWalkSessionView
                // Otherwise use the regular PhoneWorkoutSessionView
                if let route = pendingMagicRoute {
                    RouteWalkSessionView(route: route)
                        .onDisappear {
                            pendingMagicRoute = nil
                        }
                } else {
                    PhoneWorkoutSessionView()
                }
            }
            .sheet(isPresented: $showGPSInfo) {
                WorkoutInfoSheet(
                    title: "Just Walk",
                    subtitle: "Track Your Route",
                    description: "Record your walking route with GPS tracking. See exactly where you walked on a map when you finish. Your route is saved to Apple Health and appears in the Fitness app.",
                    themeColor: .purple,
                    icon: "location.fill"
                )
            }
            .sheet(isPresented: $showMagicRouteSheet) {
                MagicRouteSheet { route in
                    // Store the route and start the walk
                    pendingMagicRoute = route
                    showGPSWorkout = true
                }
            }
            .sheet(isPresented: $showMagicRouteInfo) {
                WorkoutInfoSheet(
                    title: "Magic Route",
                    subtitle: "Guided Circular Walk",
                    description: "Generate a unique circular walking route that starts and ends at your current location. Choose your target distance or time, and we'll create a route just for you. Free users get 2 re-rolls per session and 1 walk per day.",
                    themeColor: JWDesign.Colors.brandSecondary,
                    icon: "wand.and.stars"
                )
            }
            .onChange(of: subscriptionManager.isPro) { _, isPro in
                if isPro && showPaywall {
                    showPaywall = false
                    activeWalkMode = .interval
                }
            }
            .onChange(of: activeWalkMode) { oldValue, newValue in
                // Refresh workouts when session ends (fullScreenCover dismissed)
                if oldValue != nil && newValue == nil {
                    Task {
                        await workoutHistoryManager.fetchWorkouts()
                    }
                }
            }
            .onChange(of: showGPSWorkout) { oldValue, newValue in
                // Refresh workouts when GPS session ends
                if oldValue && !newValue {
                    Task {
                        await workoutHistoryManager.fetchWorkouts()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoteSessionStarted)) { notification in
                if let mode = notification.userInfo?["mode"] as? WalkMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        activeWalkMode = mode
                    }
                }
            }
        }
    }

    // MARK: - Workout History Section

    @ViewBuilder
    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Section Header
            Text("Recent Walks")
                .font(JWDesign.Typography.headline)
                .foregroundStyle(.primary)
                .padding(.top, JWDesign.Spacing.lg)

            if workoutHistoryManager.isLoading {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if workoutHistoryManager.workouts.isEmpty {
                // Empty state
                emptyHistoryView
            } else {
                // Grouped workouts by month
                let groupedWorkouts = workoutHistoryManager.groupedWorkouts(isPro: subscriptionManager.isPro)

                ForEach(groupedWorkouts, id: \.key) { monthGroup in
                    VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
                        // Month header
                        Text(monthGroup.key)
                            .font(JWDesign.Typography.captionBold)
                            .foregroundStyle(.secondary)
                            .padding(.top, JWDesign.Spacing.sm)

                        // Workouts in this month (List for swipe-to-delete)
                        VStack(spacing: 0) {
                            List {
                                ForEach(Array(monthGroup.workouts.enumerated()), id: \.element.id) { index, workout in
                                    WorkoutHistoryRow(workout: workout)
                                        .listRowInsets(EdgeInsets(
                                            top: index == 0 ? 20 : 0,
                                            leading: JWDesign.Spacing.md,
                                            bottom: 0,
                                            trailing: JWDesign.Spacing.md
                                        ))
                                        .listRowSeparator(.automatic)
                                        .listRowBackground(JWDesign.Colors.secondaryBackground)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteWorkout(workout)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .scrollContentBackground(.hidden)
                            .environment(\.defaultMinListHeaderHeight, 0)
                            .frame(height: CGFloat(monthGroup.workouts.count * 85 + 20))
                        }
                        .padding(.top, -16)
                        .clipped()
                        .background(JWDesign.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
                    }
                }

                // Locked history upsell for free users
                if !subscriptionManager.isPro && workoutHistoryManager.hasHiddenWorkouts(isPro: false) {
                    lockedHistoryRow
                }
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

            Text("Start a walk above to see your history here.")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JWDesign.Spacing.xxxl)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    private var lockedHistoryRow: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: JWDesign.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(JWDesign.Colors.brandPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .foregroundStyle(JWDesign.Colors.brandPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Full History")
                        .font(JWDesign.Typography.headlineBold)
                        .foregroundStyle(.primary)

                    Text("See all your past walks")
                        .font(JWDesign.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(JWDesign.Spacing.md)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        }
        .buttonStyle(.plain)
        .padding(.top, JWDesign.Spacing.sm)
    }

    // MARK: - Actions

    private func deleteWorkout(_ workout: WorkoutHistoryItem) {
        Task {
            await workoutHistoryManager.deleteWorkout(id: workout.id)
        }
    }
}

// MARK: - Minimal Workout Card

struct MinimalWorkoutCard: View {
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
                    .fill(themeColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(themeColor)
            }

            // Title + Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(JWDesign.Typography.headline)

                    if isLocked {
                        Text("PRO")
                            .font(.caption2.bold())
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(JWDesign.Typography.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Info button
            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Start button
            Button(action: onStart) {
                Text("Start")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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

// MARK: - Workout Info Sheet

struct WorkoutInfoSheet: View {
    let title: String
    let subtitle: String
    let description: String
    let themeColor: Color
    let icon: String
    var isPro: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundStyle(themeColor)
                }
                .padding(.top, 24)

                // Title
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.title2.bold())

                        if isPro {
                            Text("PRO")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Description
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    WalkView()
}
