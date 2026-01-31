//
//  WalkActivityWidget.swift
//  JustWalk
//
//  Widget for Live Activity on lock screen and Dynamic Island
//
//  NOTE: This file should be added to a Widget Extension target
//  for full functionality. Create a new Widget Extension target
//  in Xcode and move this file there.
//

import WidgetKit
import SwiftUI

struct WalkActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Lock Screen / Banner
            WalkLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.steps)", systemImage: "figure.walk")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailingTimeView(context)
                        .font(.headline.monospacedDigit())
                }
            DynamicIslandExpandedRegion(.bottom) {
                HStack {
                    Text(formatDistance(context.state.distance))
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255))
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                compactTimeView(context)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255))
                    .frame(minWidth: 32, maxWidth: 44)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255))
                    .frame(width: 16, height: 16)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @ViewBuilder
    private func trailingTimeView(_ context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        let isCountdownMode = context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
        if isCountdownMode {
            if context.state.isPaused {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            } else if let endDate = context.state.intervalPhaseEndDate {
                if endDate > Date() {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                } else {
                    Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
                }
            } else {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            }
        } else {
            Text(formatDuration(context.state.elapsedSeconds))
        }
    }

    @ViewBuilder
    private func compactTimeView(_ context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        let isCountdownMode = context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
        if isCountdownMode {
            if context.state.isPaused {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            } else if let endDate = context.state.intervalPhaseEndDate {
                if endDate > Date() {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                } else {
                    Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
                }
            } else {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            }
        } else {
            let minutes = max(0, context.state.elapsedSeconds / 60)
            Text("\(minutes)m")
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}

// MARK: - Lock Screen View

struct WalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    private var modeTitle: String {
        switch context.attributes.mode {
        case "interval": return "Intervals"
        case "postMeal": return "Post-Meal Walk"
        case "fatBurn": return "Fat Burn Zone"
        default: return "Walking"
        }
    }

    private var isCountdownMode: Bool {
        context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(modeTitle)
                    .font(.headline)

                if isCountdownMode {
                    if context.state.isPaused {
                        Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
                            .font(.largeTitle.bold().monospacedDigit())
                    } else if let endDate = context.state.intervalPhaseEndDate, endDate > Date() {
                        // Use timerInterval with countsDown: true for countdown display
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.largeTitle.bold().monospacedDigit())
                    } else {
                        Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
                            .font(.largeTitle.bold().monospacedDigit())
                    }
                } else if context.state.isPaused {
                    Text(formatDuration(context.state.elapsedSeconds))
                        .font(.largeTitle.bold().monospacedDigit())
                } else {
                    Text(context.state.startDate, style: .timer)
                        .font(.largeTitle.bold().monospacedDigit())
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(context.state.steps) steps")
            }
        }
        .padding()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
