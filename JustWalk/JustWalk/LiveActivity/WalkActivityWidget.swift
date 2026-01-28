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
                    Text(formatDuration(context.state.elapsedSeconds))
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
                    .foregroundStyle(Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255))
            } compactTrailing: {
                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255))
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Walking")
                    .font(.headline)

                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.largeTitle.bold().monospacedDigit())
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
