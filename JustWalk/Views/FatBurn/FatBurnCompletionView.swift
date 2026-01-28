//
//  FatBurnCompletionView.swift
//  JustWalk
//
//  Post-walk summary for Fat Burn Zone walks, showing zone stats,
//  time in zone, and performance insight.
//

import SwiftUI
import MapKit

struct FatBurnCompletionView: View {
    let walk: TrackedWalk
    let onDone: () -> Void

    @State private var showConfetti = false

    // Animated stat values
    @State private var animatedDuration = 0
    @State private var animatedSteps = 0
    @State private var animatedDistance = 0.0
    @State private var animatedZonePercent = 0.0
    @State private var statsAnimationComplete = false

    private var timeInZone: Int { walk.fatBurnTimeInZoneSeconds ?? 0 }
    private var zonePercent: Double { walk.fatBurnZonePercentage ?? 0 }
    private var avgHR: Int { walk.heartRateAvg ?? 0 }
    private var isSubstantialWalk: Bool { walk.durationMinutes >= 5 }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: JW.Spacing.xxl) {
                    // Header
                    VStack(spacing: JW.Spacing.md) {
                        AnimatedCheckmark()
                            .padding(.bottom, JW.Spacing.xs)

                        Text("Fat Burn Zone Complete")
                            .font(.title.bold())
                            .foregroundStyle(JW.Color.textPrimary)
                    }
                    .padding(.top, 40)

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

                    // Time in zone card (hero stat)
                    timeInZoneCard
                        .padding(.horizontal, JW.Spacing.lg)

                    // Route map
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

                    Spacer(minLength: 120)
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
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 40)
            }

            // Confetti
            ConfettiView(isActive: $showConfetti)
        }
        .background(JW.Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startCountingAnimation()

            if isSubstantialWalk {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                    JustWalkHaptics.goalComplete()
                }
            }
        }
    }

    // MARK: - Time In Zone Card

    private var timeInZoneCard: some View {
        VStack(spacing: JW.Spacing.lg) {
            Text("Time in Zone")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            // Progress bar
            HStack(spacing: JW.Spacing.md) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(JW.Color.backgroundTertiary)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(JW.Color.accent)
                            .frame(width: geometry.size.width * min(animatedZonePercent / 100, 1.0), height: 12)
                            .animation(.easeOut(duration: 1.2), value: animatedZonePercent)
                    }
                }
                .frame(height: 12)

                Text("\(Int(animatedZonePercent))%")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.accent)
                    .frame(width: 50, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.default, value: Int(animatedZonePercent))
            }

            // Time breakdown
            let totalFormatted = formatTime(walk.durationMinutes * 60)
            let zoneFormatted = formatTime(timeInZone)
            Text("\(zoneFormatted) of \(totalFormatted)")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            // Avg HR
            if avgHR > 0 {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "heart.fill")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.streak)
                    Text("Avg HR: \(avgHR) bpm")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        HStack(spacing: JW.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(JW.Font.title3)
                .foregroundStyle(.yellow)

            Text(FatBurnZoneManager.shared.completionInsight(zonePercent: zonePercent))
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
            animatedZonePercent = zonePercent * eased

            if frame >= totalFrames {
                timer.invalidate()
                animatedDuration = walk.durationMinutes
                animatedSteps = walk.steps
                animatedDistance = walk.distanceMeters
                animatedZonePercent = zonePercent
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

    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    FatBurnCompletionView(
        walk: TrackedWalk(
            id: UUID(),
            startTime: Date().addingTimeInterval(-1440),
            endTime: Date(),
            durationMinutes: 24,
            steps: 3201,
            distanceMeters: 2253,
            mode: .fatBurn,
            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: [],
            fatBurnTimeInZoneSeconds: 1122,
            fatBurnZonePercentage: 78,
            fatBurnZoneLow: 111,
            fatBurnZoneHigh: 130
        ),
        onDone: {}
    )
}
