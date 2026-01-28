//
//  WatchGoalConfirmation.swift
//  Just Walk Watch App
//
//  Confirmation screen before starting a walk with a goal.
//  Shows the goal summary and offers Start or With Route options.
//

import SwiftUI
import WatchKit

struct WatchGoalConfirmation: View {
    let goal: WalkGoal

    var onStart: () -> Void
    var onStartWithRoute: () -> Void = {}
    var onCancel: () -> Void

    @State private var showRouteGeneration = false

    var body: some View {
        VStack(spacing: 16) {
            // Goal Summary
            VStack(spacing: 4) {
                Image(systemName: goal.type.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.teal)

                Text(goal.displayString)
                    .font(.headline)
            }
            .padding(.top, 8)

            Spacer()

            // Start Button
            Button {
                WKInterfaceDevice.current().play(.click)
                onStart()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                    Text("Start")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color.teal)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // With Route Button (optional - for future route generation)
            Button {
                WKInterfaceDevice.current().play(.click)
                showRouteGeneration = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.body)
                    Text("With Route")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.gray.opacity(0.2))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Disclaimer
            Text("~1 free route/day")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .sheet(isPresented: $showRouteGeneration) {
            WatchRoutePreview(
                goal: goal,
                onStart: {
                    showRouteGeneration = false
                    onStartWithRoute()
                },
                onCancel: {
                    showRouteGeneration = false
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WatchGoalConfirmation(
            goal: .time(minutes: 30.0),
            onStart: { print("Start") },
            onCancel: { print("Cancel") }
        )
    }
}
