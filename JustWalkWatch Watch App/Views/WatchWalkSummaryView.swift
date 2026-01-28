//
//  WatchWalkSummaryView.swift
//  JustWalkWatch Watch App
//
//  Post-walk summary showing walk results
//

import SwiftUI

struct WatchWalkSummaryView: View {
    let record: WatchWalkRecord
    let onDone: () -> Void

    // Animated stat values
    @State private var animatedDuration = 0
    @State private var animatedSteps = 0
    @State private var animatedDistance = 0.0

    private var formattedDuration: String {
        if animatedDuration >= 60 {
            let hours = animatedDuration / 60
            let minutes = animatedDuration % 60
            return "\(hours)h \(minutes)m"
        }
        return "\(animatedDuration) min"
    }

    private var useMetric: Bool {
        WatchPersistenceManager.shared.loadUseMetricUnits()
    }

    private var formattedDistance: String {
        if useMetric {
            let km = animatedDistance / 1000
            if km >= 1 {
                return String(format: "%.2f km", km)
            } else {
                return "\(Int(animatedDistance)) m"
            }
        } else {
            let miles = animatedDistance / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }

    private var headerTitle: String {
        if record.isFatBurnWalk, let pct = record.percentageInZone {
            if pct >= 0.70 { return "Zone Master!" }
            if pct >= 0.40 { return "Great Burn!" }
            return "Keep Trying!"
        }
        if record.isIntervalWalk {
            return "Interval Complete"
        }
        return "Walk Complete"
    }

    private var headerIcon: String {
        if record.isFatBurnWalk {
            return "heart.circle.fill"
        }
        return "checkmark.circle.fill"
    }

    private var headerColor: Color {
        if record.isFatBurnWalk, let pct = record.percentageInZone {
            if pct >= 0.70 { return .green }
            if pct >= 0.40 { return .yellow }
            return .orange
        }
        return .green
    }

    private var formattedZoneTime: String? {
        guard let seconds = record.timeInZone else { return nil }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: headerIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(headerColor)
                    .accessibilityHidden(true)

                Text(headerTitle)
                    .font(.headline)

                // Stats grid
                VStack(spacing: 8) {
                    statRow(label: "Duration", value: formattedDuration)
                    statRow(label: "Steps", value: "\(animatedSteps.formatted())")
                    statRow(label: "Distance", value: formattedDistance)

                    if let avgHR = record.averageHeartRate {
                        statRow(label: "Avg BPM", value: "\(avgHR)")
                    }
                    if let cal = record.activeCalories, cal > 0 {
                        statRow(label: "Calories", value: "\(Int(cal))")
                    }
                }

                // Fat burn zone stats
                if record.isFatBurnWalk {
                    Divider()
                    VStack(spacing: 8) {
                        if let pct = record.percentageInZone {
                            statRow(label: "In Zone", value: "\(Int(pct * 100))%")
                        }
                        if let zoneTime = formattedZoneTime {
                            statRow(label: "Zone Time", value: zoneTime)
                        }
                        if let low = record.fatBurnZoneLow, let high = record.fatBurnZoneHigh {
                            statRow(label: "Zone", value: "\(low)–\(high) bpm")
                        }
                    }
                }

                if record.isIntervalWalk {
                    Divider()
                    if record.intervalCompleted == true {
                        Label("Interval Complete", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Label("Interval Incomplete", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            WatchHaptics.walkCompleted()
            startCountingAnimation()
        }
    }

    // MARK: - Counting Animation

    private func startCountingAnimation() {
        let totalFrames = 15 // 0.75s at 20fps — faster for Watch
        var frame = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            frame += 1
            let progress = Double(frame) / Double(totalFrames)
            let eased = easeOutCubic(progress)

            animatedDuration = Int(Double(record.durationMinutes) * eased)
            animatedSteps = Int(Double(record.steps) * eased)
            animatedDistance = record.distanceMeters * eased

            if frame >= totalFrames {
                timer.invalidate()
                animatedDuration = record.durationMinutes
                animatedSteps = record.steps
                animatedDistance = record.distanceMeters
            }
        }
    }

    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    WatchWalkSummaryView(
        record: WatchWalkRecord(
            id: UUID(),
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            durationMinutes: 30,
            steps: 3200,
            distanceMeters: 2400
        ),
        onDone: {}
    )
}
