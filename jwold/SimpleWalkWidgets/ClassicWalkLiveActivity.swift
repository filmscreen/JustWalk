//
//  ClassicWalkLiveActivity.swift
//  SimpleWalkWidgets
//
//  Live Activity for Classic "Just Walk" mode - provides persistent background execution
//  and visual feedback during simple walks (non-interval).
//
//  Note: Live Activities are only available on iOS, not watchOS.
//  Note: WalkActivityAttributes is defined in WalkActivityAttributes.swift (shared file)
//

#if os(iOS)
import ActivityKit
import AppIntents
#endif
import WidgetKit
import SwiftUI

// MARK: - Live Activity View

#if os(iOS)
struct ClassicWalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Lock Screen / Banner view
            ClassicWalkLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island regions
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Steps hero
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(Color(hex: "00C7BE"))
                            Text("\(context.state.sessionSteps.formatted())")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }

                        Text("steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        // Duration
                        if context.state.isPaused {
                            Text("PAUSED")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        } else {
                            Text(context.attributes.sessionStartTime, style: .timer)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                        }

                        Text("duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        // Goal progress bar
                        GoalProgressBar(
                            progress: context.state.goalProgress,
                            label: "\(context.state.currentDailySteps.formatted())/\(context.state.dailyGoal.formatted())"
                        )

                        // End Walk button
                        EndWalkButton()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                // Compact leading - walking icon + step count
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "00C7BE"))
                    Text("\(context.state.sessionSteps.formatted())")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            } compactTrailing: {
                // Compact trailing - duration timer
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(context.attributes.sessionStartTime, style: .timer)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                }
            } minimal: {
                // Minimal view - just walking icon
                Image(systemName: "figure.walk")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "00C7BE"))
            }
        }
    }
}
#endif

// MARK: - Lock Screen View

#if os(iOS)
struct ClassicWalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(Color(hex: "00C7BE"))
                Text("Just Walk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()

                if context.state.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Main content row
            HStack(spacing: 20) {
                // Steps (hero)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.state.sessionSteps.formatted())")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "00C7BE"))

                    Text("steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    } else {
                        Text(context.attributes.sessionStartTime, style: .timer)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }

                    Text("duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Goal progress bar
            GoalProgressBar(
                progress: context.state.goalProgress,
                label: "\(context.state.goalProgressPercent)%"
            )

            // Footer row
            HStack {
                Text(context.state.formattedDistance)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text("\(context.state.currentDailySteps.formatted())/\(context.state.dailyGoal.formatted()) daily")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
#endif

// MARK: - Goal Progress Bar

#if os(iOS)
struct GoalProgressBar: View {
    let progress: Double
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "00C7BE").opacity(0.2))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: geometry.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 8)

            HStack {
                Spacer()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

// MARK: - End Walk Button

#if os(iOS)
struct EndWalkButton: View {
    var body: some View {
        Button(intent: EndWalkIntent()) {
            Text("End Walk")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(hex: "FF3B30"))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif

// MARK: - Color Helper

#if os(iOS)
fileprivate extension Color {
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
#endif

// MARK: - Preview

#if os(iOS)
#Preview("Lock Screen", as: .content, using: WalkActivityAttributes(sessionStartTime: Date())) {
    ClassicWalkLiveActivity()
} contentStates: {
    // Active walk
    WalkActivityAttributes.ContentState(
        sessionSteps: 3421,
        sessionDistance: 2896,  // ~1.8 mi
        elapsedSeconds: 1425,   // ~23:45
        dailyGoal: 10_000,
        stepsAtStart: 4000,
        isPaused: false
    )
    // Goal almost complete
    WalkActivityAttributes.ContentState(
        sessionSteps: 1250,
        sessionDistance: 1609,  // ~1 mi
        elapsedSeconds: 900,    // 15:00
        dailyGoal: 10_000,
        stepsAtStart: 8500,
        isPaused: false
    )
    // Paused state
    WalkActivityAttributes.ContentState(
        sessionSteps: 2100,
        sessionDistance: 1800,
        elapsedSeconds: 1200,
        dailyGoal: 10_000,
        stepsAtStart: 5000,
        isPaused: true
    )
}
#endif
