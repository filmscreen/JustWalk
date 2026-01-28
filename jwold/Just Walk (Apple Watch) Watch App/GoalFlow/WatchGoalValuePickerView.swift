//
//  WatchGoalValuePickerView.swift
//  Just Walk Watch App
//
//  Value picker with presets and custom option.
//  Shows 4 preset values based on goal type, plus Custom button.
//

import SwiftUI
import WatchKit

struct WatchGoalValuePickerView: View {
    let goalType: WalkGoalType

    var onSelectGoal: (WalkGoal) -> Void
    var onCancel: () -> Void

    @State private var showCustomInput = false

    private var presets: [Double] {
        switch goalType {
        case .time: return [15, 30, 45, 60]  // minutes
        case .distance: return [0.5, 1.0, 1.5, 2.0]  // miles
        case .steps: return [2000, 3000, 5000, 7500]
        case .none: return []
        }
    }

    private var titleForType: String {
        switch goalType {
        case .time: return "Time Goal"
        case .distance: return "Distance Goal"
        case .steps: return "Steps Goal"
        case .none: return "Goal"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(presets, id: \.self) { value in
                    PresetButton(
                        value: value,
                        goalType: goalType
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        let goal = buildGoal(from: value)
                        onSelectGoal(goal)
                    }
                }

                Button {
                    WKInterfaceDevice.current().play(.click)
                    showCustomInput = true
                } label: {
                    Text("Custom")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle(titleForType)
        .sheet(isPresented: $showCustomInput) {
            WatchCustomGoalInput(
                goalType: goalType,
                onSelect: { goal in
                    showCustomInput = false
                    onSelectGoal(goal)
                },
                onCancel: {
                    showCustomInput = false
                }
            )
        }
    }

    private func buildGoal(from value: Double) -> WalkGoal {
        switch goalType {
        case .time:
            return WalkGoal.time(minutes: value)
        case .distance:
            return WalkGoal.distance(miles: value)
        case .steps:
            return WalkGoal.steps(count: value)
        case .none:
            return .none
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let value: Double
    let goalType: WalkGoalType
    let action: () -> Void

    private var displayText: String {
        switch goalType {
        case .time:
            let minutes = Int(value)
            if minutes < 60 {
                return "\(minutes) min"
            }
            return "1 hour"
        case .distance:
            let unit = WatchDistanceUnit.preferred
            let distanceInMeters = value * 1609.34
            let convertedValue = distanceInMeters * unit.conversionFromMeters
            if convertedValue == floor(convertedValue) {
                return "\(Int(convertedValue)) \(unit.abbreviation)"
            }
            return String(format: "%.1f %@", convertedValue, unit.abbreviation)
        case .steps:
            return "\(Int(value).formatted()) steps"
        case .none:
            return ""
        }
    }

    var body: some View {
        Button(action: action) {
            Text(displayText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.teal)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Time") {
    NavigationStack {
        WatchGoalValuePickerView(
            goalType: .time,
            onSelectGoal: { print("Selected: \($0)") },
            onCancel: { print("Cancelled") }
        )
    }
}

#Preview("Steps") {
    NavigationStack {
        WatchGoalValuePickerView(
            goalType: .steps,
            onSelectGoal: { print("Selected: \($0)") },
            onCancel: { print("Cancelled") }
        )
    }
}
