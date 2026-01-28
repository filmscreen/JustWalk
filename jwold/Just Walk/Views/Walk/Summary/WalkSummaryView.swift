//
//  WalkSummaryView.swift
//  Just Walk
//
//  Post-walk summary screen for Just Walk and Power Walk.
//  Celebrates effort, shows goal progress, and handles conversion moments.
//

import SwiftUI
import CoreLocation

struct WalkSummaryView: View {
    let summaryData: WalkSummaryData
    let onDismiss: () -> Void
    let onShowPaywall: () -> Void

    @StateObject private var viewModel: WalkSummaryViewModel
    @State private var showExpandedMap: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showConfetti: Bool = false

    init(
        summaryData: WalkSummaryData,
        onDismiss: @escaping () -> Void,
        onShowPaywall: @escaping () -> Void
    ) {
        self.summaryData = summaryData
        self.onDismiss = onDismiss
        self.onShowPaywall = onShowPaywall
        self._viewModel = StateObject(wrappedValue: WalkSummaryViewModel(summaryData: summaryData))
    }

    var body: some View {
        ZStack {
            // Always show full summary (consistent with classic walk)
            ScrollView {
                VStack(spacing: JWDesign.Spacing.lg) {
                    // Drag indicator
                    dragIndicator

                    // Header with celebration
                    headerSection

                    // Only show step contribution and progress if steps > 0
                    if summaryData.stepsAdded > 0 {
                        // Primary stat: Steps contribution
                        StepsContributionCard(stepsAdded: summaryData.stepsAdded)

                        // Progress bar showing before → after
                        WalkProgressBar(
                            stepsBeforeWalk: summaryData.stepsBeforeWalk,
                            stepsAfterWalk: summaryData.stepsAfterWalk,
                            dailyGoal: summaryData.dailyGoal
                        )
                    }

                    // Power Walk efficiency stat (if applicable)
                    if viewModel.showEfficiencyStat {
                        PowerWalkEfficiencyCard(minutesSaved: viewModel.estimatedTimeSaved)

                        // Weekly pattern
                        if viewModel.showWeeklyPattern {
                            Text(viewModel.weeklyPatternText)
                                .font(JWDesign.Typography.subheadline)
                                .foregroundStyle(Color(hex: "00C7BE"))
                        }
                    }

                    // Efficiency callout for completed Power Walks
                    if let efficiencyText = viewModel.efficiencyCalloutText {
                        Text(efficiencyText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, JWDesign.Spacing.md)
                    }

                    // Ended early card (if applicable)
                    if viewModel.showEndedEarlyCard {
                        EndedEarlyCard(
                            completedIntervals: summaryData.completedIntervals,
                            totalIntervals: summaryData.totalIntervals,
                            encouragementMessage: viewModel.encouragementMessage
                        )
                    }

                    // Route map (if available)
                    if viewModel.showRouteMap {
                        mapSection
                    }

                    // Secondary stats row (always show - time/distance are meaningful even with 0 steps)
                    secondaryStatsRow

                    // Conversion card (for free users after triggers)
                    if viewModel.shouldShowConversionCard && !viewModel.conversionCardDismissed {
                        PowerWalkConversionCard(
                            bodyText: viewModel.conversionCardBodyText,
                            ctaText: viewModel.conversionCardCTAText,
                            onTryPowerWalk: onShowPaywall,
                            onDismiss: { viewModel.dismissConversionCard() }
                        )
                    }

                    // Action buttons
                    actionButtons

                    Spacer(minLength: JWDesign.Spacing.xxxl)
                }
                .padding(.horizontal, JWDesign.Spacing.xl)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .onAppear {
            triggerGoalCelebrationIfNeeded()
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
    }

    // MARK: - Components

    private var dragIndicator: some View {
        Capsule()
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
    }

    private var headerSection: some View {
        VStack(spacing: JWDesign.Spacing.xs) {
            HStack(spacing: 12) {
                Image(systemName: summaryData.didReachGoalDuringWalk ? "trophy.fill" : "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(summaryData.didReachGoalDuringWalk ? .yellow : Color(hex: "00C7BE"))
                    .symbolEffect(.bounce, value: showConfetti)

                Text(viewModel.headerText)
                    .font(.title3.bold())
            }

            if let subtext = viewModel.headerSubtext {
                Text(subtext)
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mapSection: some View {
        Button {
            withAnimation(JWDesign.Animation.spring) {
                showExpandedMap.toggle()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                CompactRouteMap(coordinates: summaryData.routeCoordinates)
                    .frame(height: showExpandedMap ? 360 : 180)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.large))

                if !showExpandedMap {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var secondaryStatsRow: some View {
        HStack(spacing: 0) {
            statItem(
                title: "Time",
                value: viewModel.formattedDuration,
                icon: "clock.fill"
            )

            Divider().frame(height: 50)

            statItem(
                title: "Distance",
                value: viewModel.formattedDistance,
                icon: "map.fill"
            )

            // Intervals (Power Walk only)
            if summaryData.walkMode == .interval {
                Divider().frame(height: 50)

                statItem(
                    title: "Intervals",
                    value: viewModel.intervalsText,
                    icon: "bolt.fill"
                )
            }
        }
        .padding()
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.large))
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(JWDesign.Colors.brandSecondary)

            Text(value)
                .font(.headline.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: JWDesign.Spacing.md) {
            // Done button (primary)
            Button {
                HapticService.shared.playSelection()
                onDismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(JWPrimaryButtonStyle())

            // Share button (secondary)
            Button {
                HapticService.shared.playSelection()
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
            }
            .buttonStyle(JWSecondaryButtonStyle())
            .frame(width: 56)
        }
    }

    private var shareSheet: some View {
        // Use existing share preview infrastructure
        SharePreviewSheet(
            cardType: .workout(
                WorkoutShareData(
                    date: summaryData.sessionSummary.startTime,
                    duration: summaryData.sessionSummary.totalDuration,
                    distanceMeters: summaryData.sessionSummary.distance,
                    steps: summaryData.stepsAdded,
                    routeImage: nil // Will be captured by ShareService
                )
            )
        )
    }

    // MARK: - Actions

    private func triggerGoalCelebrationIfNeeded() {
        guard summaryData.didReachGoalDuringWalk else { return }

        // Delay to sync with progress bar animation
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            withAnimation {
                showConfetti = true
            }
            HapticService.shared.playSuccess()
        }
    }
}

// MARK: - Walk Progress Bar

/// Horizontal progress bar showing before → after step progress
struct WalkProgressBar: View {
    let stepsBeforeWalk: Int
    let stepsAfterWalk: Int
    let dailyGoal: Int

    private var beforeProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(stepsBeforeWalk) / Double(dailyGoal))
    }

    private var afterProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(stepsAfterWalk) / Double(dailyGoal))
    }

    private var stepsAdded: Int {
        stepsAfterWalk - stepsBeforeWalk
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))

                    // "Before" fill (lighter teal)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "00C7BE").opacity(0.3))
                        .frame(width: geometry.size.width * beforeProgress)

                    // "After" fill (bright teal, overlays the before)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: geometry.size.width * afterProgress)

                    // Goal marker at 100% (if not already reached)
                    if afterProgress < 1.0 {
                        Rectangle()
                            .fill(Color(.systemGray3))
                            .frame(width: 2)
                            .offset(x: geometry.size.width - 1)
                    }
                }
            }
            .frame(height: 12)

            // Labels row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(stepsBeforeWalk.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("After")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(stepsAfterWalk.formatted())
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "00C7BE"))
                }
            }

            // Goal label
            HStack {
                Spacer()
                Text("Goal: \(dailyGoal.formatted())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }
}

// MARK: - Preview

#Preview("Just Walk Summary") {
    Text("Summary Preview")
        .sheet(isPresented: .constant(true)) {
            WalkSummaryView(
                summaryData: WalkSummaryData(
                    sessionSummary: IWTSessionSummary(
                        startTime: Date(),
                        endTime: Date(),
                        totalDuration: 2827,
                        briskIntervals: 0,
                        slowIntervals: 0,
                        configuration: .standard,
                        completedSuccessfully: true,
                        steps: 4847,
                        distance: 2000,
                        averageHeartRate: 0,
                        activeCalories: 0
                    ),
                    stepsBeforeWalk: 4200,
                    dailyGoal: 10000,
                    walkMode: .classic,
                    routeCoordinates: []
                ),
                onDismiss: {},
                onShowPaywall: {}
            )
        }
}
