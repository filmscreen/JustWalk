//
//  PostMealCompletionView.swift
//  JustWalk
//
//  Post-walk summary for post-meal walks showing stats,
//  optional route map, and a contextual insight.
//

import SwiftUI
import MapKit

struct PostMealCompletionView: View {
    let walk: TrackedWalk
    let onDone: () -> Void

    @State private var showConfetti = false

    // Animated stat values
    @State private var animatedDuration = 0
    @State private var animatedSteps = 0
    @State private var animatedDistance = 0.0
    @State private var statsAnimationComplete = false

    private let totalDuration: Int = 10 // 10-minute walk
    private var isFullCompletion: Bool { walk.durationMinutes >= totalDuration }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: JW.Spacing.lg) {
                    // Header
                    VStack(spacing: JW.Spacing.md) {
                        AnimatedCheckmark()
                            .padding(.bottom, JW.Spacing.xs)

                        Text("Post-Meal Walk Complete")
                            .font(.title.bold())
                            .foregroundStyle(JW.Color.textPrimary)
                    }
                    .padding(.top, 8)

                    // Stats row
                    HStack(spacing: 8) {
                        StatCard(
                            icon: "clock",
                            value: formatDuration(animatedDuration),
                            label: "Duration"
                        )
                        .staggeredAppearance(index: 0, delay: 0.08)
                        StatCard(
                            icon: "figure.walk",
                            value: animatedSteps.formatted(),
                            label: "Steps"
                        )
                        .staggeredAppearance(index: 1, delay: 0.08)
                        StatCard(
                            icon: "map",
                            value: formatDistance(animatedDistance),
                            label: "Distance"
                        )
                        .staggeredAppearance(index: 2, delay: 0.08)
                    }
                    .padding(.horizontal, JW.Spacing.lg)

                    // Route map (optional for short walks)
                    if walk.routeCoordinates.count >= 2 {
                        AnimatedPostWalkMapView(coordinates: walk.routeCoordinates)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                            .padding(.horizontal, JW.Spacing.lg)
                    } else {
                        RouteNotAvailablePlaceholder()
                            .padding(.horizontal, JW.Spacing.lg)
                    }

                    // Insight card
                    insightCard
                        .padding(.horizontal, JW.Spacing.lg)

                    Spacer(minLength: 80)
                }
            }

            // Done button
            VStack {
                Spacer()

                Button(action: onDone) {
                    Text("Done")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 24)
            }

            // Confetti
            ConfettiView(isActive: $showConfetti)
        }
        .background(JW.Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startCountingAnimation()

            if isFullCompletion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                    JustWalkHaptics.goalComplete()
                }
            }
        }
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        HStack(spacing: JW.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(JW.Font.title3)
                .foregroundStyle(.yellow)

            Text(insightMessage)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(JW.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var insightMessage: String {
        if isFullCompletion {
            return "That 10 minutes can reduce your blood sugar response by up to 30%. Well done."
        } else {
            return "Every minute counts. Even a short walk helps with digestion."
        }
    }

    // MARK: - Animation

    private func startCountingAnimation() {
        let totalFrames = 30
        var frame = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            frame += 1
            let progress = Double(frame) / Double(totalFrames)
            let eased = easeOutCubic(progress)

            animatedDuration = Int(Double(walk.durationMinutes) * eased)
            animatedSteps = Int(Double(walk.steps) * eased)
            animatedDistance = walk.distanceMeters * eased

            if frame >= totalFrames {
                timer.invalidate()
                animatedDuration = walk.durationMinutes
                animatedSteps = walk.steps
                animatedDistance = walk.distanceMeters
                statsAnimationComplete = true
            }
        }
    }

    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }

    // MARK: - Formatters

    private var useMetric: Bool {
        PersistenceManager.shared.cachedUseMetric
    }

    private func formatDuration(_ minutes: Int) -> String {
        minutes < 1 ? "<1 min" : "\(minutes) min"
    }

    private func formatDistance(_ meters: Double) -> String {
        if useMetric {
            if meters < 1000 {
                return "\(Int(meters))m"
            } else {
                return String(format: "%.1f km", meters / 1000)
            }
        } else {
            let miles = meters / 1609.344
            return String(format: "%.1f mi", miles)
        }
    }
}

#Preview {
    PostMealCompletionView(
        walk: TrackedWalk(
            id: UUID(),
            startTime: Date().addingTimeInterval(-600),
            endTime: Date(),
            durationMinutes: 10,
            steps: 1847,
            distanceMeters: 1287,
            mode: .postMeal,
            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: []
        ),
        onDone: {}
    )
}
