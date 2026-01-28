//
//  GoalValuePickerView.swift
//  Just Walk (Apple Watch) Watch App
//
//  Value picker with Digital Crown support for selecting goal values.
//

import SwiftUI

struct GoalValuePickerView: View {
    let goalType: WalkGoalType
    @Binding var timeIndex: Int
    @Binding var distanceIndex: Int
    @Binding var stepsIndex: Int
    var onValueChanged: () -> Void
    var isEnabled: Bool = true

    @State private var crownValue: Double = 0

    let timeValues = [15, 30, 45, 60]
    let distanceValues = [1.0, 2.0, 3.0, 5.0]
    let stepsValues = [2000, 3000, 5000, 10000]

    var body: some View {
        VStack(spacing: 4) {
            // Value display
            Text(displayValue)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(isEnabled ? .primary : .secondary)

            Text(unitLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(isEnabled ? 0.2 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isEnabled ? 1.0 : 0.4)
        .focusable(isEnabled)
        .digitalCrownRotation(
            isEnabled ? $crownValue : .constant(0),
            from: 0,
            through: Double(currentValuesCount - 1),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: isEnabled
        )
        .onChange(of: crownValue) { _, newValue in
            guard isEnabled else { return }
            let index = Int(newValue.rounded())
            updateIndex(to: index)
            onValueChanged()
        }
        .onChange(of: goalType) { _, _ in
            // Reset crown position when type changes
            crownValue = Double(currentIndex)
        }
        .onAppear {
            crownValue = Double(currentIndex)
        }
    }

    private var currentValuesCount: Int {
        switch goalType {
        case .none: return 0
        case .time: return timeValues.count
        case .distance: return distanceValues.count
        case .steps: return stepsValues.count
        }
    }

    private var currentIndex: Int {
        switch goalType {
        case .none: return 0
        case .time: return timeIndex
        case .distance: return distanceIndex
        case .steps: return stepsIndex
        }
    }

    private func updateIndex(to index: Int) {
        let clampedIndex = max(0, min(index, currentValuesCount - 1))
        switch goalType {
        case .none: break
        case .time: timeIndex = clampedIndex
        case .distance: distanceIndex = clampedIndex
        case .steps: stepsIndex = clampedIndex
        }
    }

    private var displayValue: String {
        switch goalType {
        case .none:
            return "Open"
        case .time:
            return "\(timeValues[timeIndex])"
        case .distance:
            // Convert miles to user's preferred unit
            let milesValue = distanceValues[distanceIndex]
            let unit = WatchDistanceUnit.preferred
            let distanceInMeters = milesValue * 1609.34
            let convertedValue = distanceInMeters * unit.conversionFromMeters
            return String(format: "%.0f", convertedValue)
        case .steps:
            return stepsValues[stepsIndex].formatted()
        }
    }

    private var unitLabel: String {
        switch goalType {
        case .none: return "walk"
        case .time: return "minutes"
        case .distance: return WatchDistanceUnit.preferred.rawValue.lowercased()
        case .steps: return "steps"
        }
    }
}

// MARK: - Preview

#Preview("Enabled") {
    GoalValuePickerView(
        goalType: .time,
        timeIndex: .constant(1),
        distanceIndex: .constant(1),
        stepsIndex: .constant(2),
        onValueChanged: {},
        isEnabled: true
    )
}

#Preview("Disabled") {
    GoalValuePickerView(
        goalType: .time,
        timeIndex: .constant(1),
        distanceIndex: .constant(1),
        stepsIndex: .constant(2),
        onValueChanged: {},
        isEnabled: false
    )
}
