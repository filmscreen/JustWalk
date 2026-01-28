//
//  WatchCustomGoalInput.swift
//  Just Walk Watch App
//
//  Digital Crown input for custom goal values.
//  Supports time (5-120 min), distance (0.5-10 mi), steps (1000-20000).
//

import SwiftUI
import WatchKit

struct WatchCustomGoalInput: View {
    let goalType: WalkGoalType

    var onSelect: (WalkGoal) -> Void
    var onCancel: () -> Void

    @State private var value: Double

    init(goalType: WalkGoalType, onSelect: @escaping (WalkGoal) -> Void, onCancel: @escaping () -> Void) {
        self.goalType = goalType
        self.onSelect = onSelect
        self.onCancel = onCancel

        // Set default values
        let defaultValue: Double
        switch goalType {
        case .time: defaultValue = 30
        case .distance: defaultValue = 1.0
        case .steps: defaultValue = 5000
        case .none: defaultValue = 0
        }
        _value = State(initialValue: defaultValue)
    }

    private var range: ClosedRange<Double> {
        switch goalType {
        case .time: return 5...120
        case .distance: return 0.5...10.0
        case .steps: return 1000...20000
        case .none: return 0...100
        }
    }

    private var step: Double {
        switch goalType {
        case .time: return 5
        case .distance: return 0.5
        case .steps: return 500
        case .none: return 1
        }
    }

    private var formattedValue: String {
        switch goalType {
        case .time:
            return "\(Int(value))"
        case .distance:
            let unit = WatchDistanceUnit.preferred
            let distanceInMeters = value * 1609.34
            let convertedValue = distanceInMeters * unit.conversionFromMeters
            if convertedValue == floor(convertedValue) {
                return "\(Int(convertedValue))"
            }
            return String(format: "%.1f", convertedValue)
        case .steps:
            return "\(Int(value).formatted())"
        case .none:
            return ""
        }
    }

    private var unitLabel: String {
        switch goalType {
        case .time: return "minutes"
        case .distance: return WatchDistanceUnit.preferred.abbreviation
        case .steps: return "steps"
        case .none: return ""
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Custom \(goalType.label)")
                .font(.headline)

            Spacer()

            Text(formattedValue)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .focusable()
                .digitalCrownRotation(
                    $value,
                    from: range.lowerBound,
                    through: range.upperBound,
                    by: step,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            Text(unitLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    let goal = buildGoal()
                    onSelect(goal)
                } label: {
                    Text("Start")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func buildGoal() -> WalkGoal {
        switch goalType {
        case .time:
            return WalkGoal.time(minutes: value, isCustom: true)
        case .distance:
            return WalkGoal.distance(miles: value, isCustom: true)
        case .steps:
            return WalkGoal.steps(count: value, isCustom: true)
        case .none:
            return .none
        }
    }
}

// MARK: - Preview

#Preview("Time") {
    WatchCustomGoalInput(
        goalType: .time,
        onSelect: { print("Selected: \($0)") },
        onCancel: { print("Cancelled") }
    )
}

#Preview("Steps") {
    WatchCustomGoalInput(
        goalType: .steps,
        onSelect: { print("Selected: \($0)") },
        onCancel: { print("Cancelled") }
    )
}
