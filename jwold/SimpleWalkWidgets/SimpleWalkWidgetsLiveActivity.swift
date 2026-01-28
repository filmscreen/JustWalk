//
//  SimpleWalkWidgetsLiveActivity.swift
//  SimpleWalkWidgets
//
//  Live Activity for Interval Walk sessions - provides persistent background execution
//  and visual feedback during walks.
//
//  Note: Live Activities are only available on iOS, not watchOS.
//

#if os(iOS)
import ActivityKit
#endif
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes

#if os(iOS)
/// Attributes for the IWT Live Activity
/// Static attributes are set when the activity starts and don't change
/// Dynamic content is updated via ContentState
public struct IWTActivityAttributes: ActivityAttributes {

    /// Dynamic content that updates during the activity
    public struct ContentState: Codable, Hashable {
        /// Current phase name (e.g., "Brisk", "Easy")
        public var phaseName: String

        /// Phase color hex for visual distinction
        public var phaseColorHex: String

        /// Current interval number (1-based)
        public var currentInterval: Int

        /// Total intervals in session
        public var totalIntervals: Int

        /// Simple status message for broad display
        public var statusMessage: String

        /// Whether the session is paused
        public var isPaused: Bool

        /// Phase icon SF Symbol name
        public var phaseIcon: String

        /// Total elapsed time in seconds (legacy, kept for compatibility)
        public var elapsedSeconds: Int

        // MARK: - New Fields for Enhanced Display

        /// Absolute end time for current phase (for ActivityKit countdown timer)
        public var phaseEndTime: Date

        /// Total duration of current phase in seconds (for progress calculation)
        public var phaseDuration: TimeInterval

        /// Current step count during session
        public var sessionSteps: Int

        /// Name of next phase (nil if last phase)
        public var nextPhaseName: String?

        /// Duration of next phase in seconds (nil if last phase)
        public var nextPhaseDuration: TimeInterval?

        public init(
            phaseName: String,
            phaseColorHex: String,
            currentInterval: Int,
            totalIntervals: Int,
            statusMessage: String,
            isPaused: Bool,
            phaseIcon: String,
            elapsedSeconds: Int = 0,
            phaseEndTime: Date = Date(),
            phaseDuration: TimeInterval = 180,
            sessionSteps: Int = 0,
            nextPhaseName: String? = nil,
            nextPhaseDuration: TimeInterval? = nil
        ) {
            self.phaseName = phaseName
            self.phaseColorHex = phaseColorHex
            self.currentInterval = currentInterval
            self.totalIntervals = totalIntervals
            self.statusMessage = statusMessage
            self.isPaused = isPaused
            self.phaseIcon = phaseIcon
            self.elapsedSeconds = elapsedSeconds
            self.phaseEndTime = phaseEndTime
            self.phaseDuration = phaseDuration
            self.sessionSteps = sessionSteps
            self.nextPhaseName = nextPhaseName
            self.nextPhaseDuration = nextPhaseDuration
        }
    }

    /// Session start time (static, set once)
    public var sessionStartTime: Date

    /// Walk mode identifier
    public var walkMode: String

    public init(sessionStartTime: Date, walkMode: String) {
        self.sessionStartTime = sessionStartTime
        self.walkMode = walkMode
    }
}
#endif

// MARK: - Live Activity View

#if os(iOS)
struct SimpleWalkWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IWTActivityAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island regions
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Phase name with icon
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                            Text(context.state.phaseName.uppercased())
                                .font(.headline.bold())
                                .foregroundColor(colorFromHex(context.state.phaseColorHex))
                        }

                        // Timer countdown
                        HStack(spacing: 4) {
                            if context.state.isPaused {
                                Text("PAUSED")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            } else {
                                Text(timerInterval: Date()...context.state.phaseEndTime, countsDown: true)
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .monospacedDigit()
                            }
                            Text("remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        // Next phase preview
                        if let nextPhase = context.state.nextPhaseName,
                           let nextDuration = context.state.nextPhaseDuration {
                            Text("Next: \(nextPhase)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("(\(formatDuration(nextDuration)))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Final phase")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        PhaseProgressBar(
                            progress: calculateProgress(
                                endTime: context.state.phaseEndTime,
                                duration: context.state.phaseDuration,
                                isPaused: context.state.isPaused
                            ),
                            color: colorFromHex(context.state.phaseColorHex)
                        )

                        // Footer with phase count and steps
                        HStack {
                            Text("Phase \(context.state.currentInterval) of \(context.state.totalIntervals)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(context.state.sessionSteps.formatted()) steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                // Compact leading - bolt icon + phase name
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(context.state.phaseName.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(colorFromHex(context.state.phaseColorHex))
                        .lineLimit(1)
                }
            } compactTrailing: {
                // Compact trailing - timer + interval count
                HStack(spacing: 6) {
                    if context.state.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text(timerInterval: Date()...context.state.phaseEndTime, countsDown: true)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    }

                    Text("\(context.state.currentInterval)/\(context.state.totalIntervals)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                // Minimal view - bolt icon + timer
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)

                    if context.state.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text(timerInterval: Date()...context.state.phaseEndTime, countsDown: true)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
#endif

// MARK: - Lock Screen View

#if os(iOS)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<IWTActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Just Walk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Main content row
            HStack(spacing: 20) {
                // Phase name (large)
                Text(context.state.phaseName.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(colorFromHex(context.state.phaseColorHex))

                Spacer()

                // Timer with ActivityKit countdown
                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    } else {
                        Text(timerInterval: Date()...context.state.phaseEndTime, countsDown: true)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }

                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            PhaseProgressBar(
                progress: calculateProgress(
                    endTime: context.state.phaseEndTime,
                    duration: context.state.phaseDuration,
                    isPaused: context.state.isPaused
                ),
                color: colorFromHex(context.state.phaseColorHex)
            )

            // Footer row
            HStack {
                Text("Phase \(context.state.currentInterval) of \(context.state.totalIntervals)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text("\(context.state.sessionSteps.formatted()) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if context.state.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
#endif

// MARK: - Progress Bar Components

#if os(iOS)
struct PhaseProgressBar: View {
    let progress: Double  // 0.0 to 1.0
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))

                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 8)
    }
}

struct MiniProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.3))

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 4)
    }
}

/// Calculate progress based on remaining time
fileprivate func calculateProgress(endTime: Date, duration: TimeInterval, isPaused: Bool = false) -> Double {
    guard duration > 0 else { return 0 }
    if isPaused { return 0.5 } // Show half progress when paused

    let remaining = endTime.timeIntervalSinceNow
    let elapsed = duration - remaining
    return max(0, min(1, elapsed / duration))
}

/// Format duration as M:SS
fileprivate func formatDuration(_ seconds: TimeInterval) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return "\(mins):\(String(format: "%02d", secs))"
}
#endif

// MARK: - Color Helper

/// Helper function to create Color from hex string (avoids redeclaration with main app)
fileprivate func colorFromHex(_ hexString: String) -> Color {
    let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
        (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
        (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
        (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
        (a, r, g, b) = (1, 1, 1, 0)
    }
    return Color(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue: Double(b) / 255,
        opacity: Double(a) / 255
    )
}

// MARK: - Preview

#if os(iOS)
#Preview("Lock Screen", as: .content, using: IWTActivityAttributes(sessionStartTime: Date(), walkMode: "interval")) {
    SimpleWalkWidgetsLiveActivity()
} contentStates: {
    // Brisk phase - active
    IWTActivityAttributes.ContentState(
        phaseName: "Brisk",
        phaseColorHex: "#FF9500",
        currentInterval: 4,
        totalIntervals: 10,
        statusMessage: "In Progress",
        isPaused: false,
        phaseIcon: "hare.fill",
        elapsedSeconds: 0,
        phaseEndTime: Date().addingTimeInterval(107), // 1:47 remaining
        phaseDuration: 180,
        sessionSteps: 2847,
        nextPhaseName: "Easy",
        nextPhaseDuration: 180
    )
    // Easy phase - active
    IWTActivityAttributes.ContentState(
        phaseName: "Easy",
        phaseColorHex: "#30D5C8",
        currentInterval: 5,
        totalIntervals: 10,
        statusMessage: "In Progress",
        isPaused: false,
        phaseIcon: "tortoise.fill",
        elapsedSeconds: 0,
        phaseEndTime: Date().addingTimeInterval(145), // 2:25 remaining
        phaseDuration: 180,
        sessionSteps: 3250,
        nextPhaseName: "Brisk",
        nextPhaseDuration: 180
    )
    // Paused state
    IWTActivityAttributes.ContentState(
        phaseName: "Brisk",
        phaseColorHex: "#FF9500",
        currentInterval: 4,
        totalIntervals: 10,
        statusMessage: "Paused",
        isPaused: true,
        phaseIcon: "hare.fill",
        elapsedSeconds: 0,
        phaseEndTime: Date().addingTimeInterval(107),
        phaseDuration: 180,
        sessionSteps: 2847,
        nextPhaseName: "Easy",
        nextPhaseDuration: 180
    )
    // Final phase
    IWTActivityAttributes.ContentState(
        phaseName: "Easy",
        phaseColorHex: "#30D5C8",
        currentInterval: 10,
        totalIntervals: 10,
        statusMessage: "Final Cooldown",
        isPaused: false,
        phaseIcon: "tortoise.fill",
        elapsedSeconds: 0,
        phaseEndTime: Date().addingTimeInterval(60),
        phaseDuration: 120,
        sessionSteps: 5120,
        nextPhaseName: nil,
        nextPhaseDuration: nil
    )
}
#endif
