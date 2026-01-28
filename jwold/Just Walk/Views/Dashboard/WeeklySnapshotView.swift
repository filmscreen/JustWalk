//
//  WeeklySnapshotView.swift
//  Just Walk
//
//  A feel-good "story card" for the weekly recap.
//  Designed for a 6th grader. 10 seconds max. High five, not report card.
//

import SwiftUI

struct WeeklySnapshotView: View {
    let snapshot: WeeklySnapshot
    let onDismiss: () -> Void

    @State private var animateIn = false

    /// Natural language comparison for the weekly distance
    private var distanceComparisonText: String {
        DistanceContextManager.shared.getApproximateComparison(for: Double(snapshot.totalMiles))
    }

    var body: some View {
        ZStack {
            // Clean gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .opacity(animateIn ? 1 : 0)

                // Week label
                Text("Last Week")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(2)

                // THE HEADLINE (Volume)
                VStack(spacing: 8) {
                    Text("You walked")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("\(snapshot.formattedSteps)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("steps!")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)

                // THE 3 METRICS
                VStack(alignment: .leading, spacing: 16) {
                    // Total Distance with real-world comparison
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.cyan)
                            .frame(width: 24)
                        Text(distanceComparisonText)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.body)

                    // Daily Average
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("Your daily average was \(snapshot.formattedDailyAverage) steps.")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.body)

                    // Best Day
                    if let bestDay = snapshot.bestDayName, let bestSteps = snapshot.bestDaySteps {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .frame(width: 24)
                            Text("\(bestDay) was your best day with \(bestSteps.formatted()) steps.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .font(.body)
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)

                Spacer()

                // Ready for a fresh week?
                Text("Ready for a fresh week?")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                    .opacity(animateIn ? 1 : 0)

                // Awesome button
                Button {
                    HapticService.shared.playSuccess()
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .fixedSize()
                        .padding(.horizontal, 48)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
                .scaleEffect(animateIn ? 1 : 0.9)
                .opacity(animateIn ? 1 : 0)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
    }

}

// MARK: - Preview

#Preview("Weekly Snapshot - Up") {
    WeeklySnapshotView(
        snapshot: WeeklySnapshot(
            weekStartDate: Date(),
            weekEndDate: Date(),
            totalSteps: 54320,
            percentageChange: 12,
            bestDayName: "Saturday",
            bestDaySteps: 14000,
            totalMiles: 27
        ),
        onDismiss: {}
    )
}

#Preview("Weekly Snapshot - Down") {
    WeeklySnapshotView(
        snapshot: WeeklySnapshot(
            weekStartDate: Date(),
            weekEndDate: Date(),
            totalSteps: 38500,
            percentageChange: -15,
            bestDayName: "Wednesday",
            bestDaySteps: 9000,
            totalMiles: 19
        ),
        onDismiss: {}
    )
}

#Preview("Weekly Snapshot - No Previous Data") {
    WeeklySnapshotView(
        snapshot: WeeklySnapshot(
            weekStartDate: Date(),
            weekEndDate: Date(),
            totalSteps: 62000,
            percentageChange: nil,
            bestDayName: "Sunday",
            bestDaySteps: 15000,
            totalMiles: 31
        ),
        onDismiss: {}
    )
}
