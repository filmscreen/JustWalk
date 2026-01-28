//
//  CustomGoalInputSheet.swift
//  Just Walk
//
//  Full custom value entry with slider and stepper buttons.
//  Pattern follows WalkModePicker customInputView.
//

import SwiftUI

struct CustomGoalInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalType: WalkGoalType
    var onSelect: (Double) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    // State for each goal type
    @State private var customMinutes: Double = 30
    @State private var customMiles: Double = 2.0
    @State private var customSteps: Double = 5000

    private let tealAccent = Color(hex: "00C7BE")

    // Range configurations
    private var timeRange: ClosedRange<Double> { 5...120 }
    private var timeStep: Double { 5 }

    private var distanceRange: ClosedRange<Double> { 0.5...10 }
    private var distanceStep: Double { 0.5 }

    private var stepsRange: ClosedRange<Double> { 1000...20000 }
    private var stepsStep: Double { 500 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Large centered value display
                valueDisplay

                // +/- buttons with slider
                sliderControls

                // Range hint
                rangeHint

                Spacer()

                // Confirm button
                confirmButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Custom \(goalType.label)")
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadLastValues()
        }
    }

    // MARK: - Value Display

    private var valueDisplay: some View {
        VStack(spacing: 4) {
            Text(formattedValue)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(tealAccent)

            Text(unitLabel)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
    }

    private var formattedValue: String {
        switch goalType {
        case .time:
            return "\(Int(customMinutes))"
        case .distance:
            if customMiles == floor(customMiles) {
                return "\(Int(customMiles))"
            }
            return String(format: "%.1f", customMiles)
        case .steps:
            return Int(customSteps).formatted()
        case .none:
            return ""
        }
    }

    private var unitLabel: String {
        switch goalType {
        case .time: return "minutes"
        case .distance: return "miles"
        case .steps: return "steps"
        case .none: return ""
        }
    }

    // MARK: - Slider Controls

    private var sliderControls: some View {
        HStack(spacing: 16) {
            // Decrement button
            Button {
                HapticService.shared.playSelection()
                decrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(canDecrement ? tealAccent : Color(.systemGray4))
            }
            .disabled(!canDecrement)
            .buttonStyle(.plain)

            // Slider
            Slider(
                value: currentBinding,
                in: currentRange,
                step: currentStep
            )
            .tint(tealAccent)

            // Increment button
            Button {
                HapticService.shared.playSelection()
                increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(canIncrement ? tealAccent : Color(.systemGray4))
            }
            .disabled(!canIncrement)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Range Hint

    private var rangeHint: some View {
        Text(rangeText)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }

    private var rangeText: String {
        switch goalType {
        case .time:
            return "5 – 120 minutes"
        case .distance:
            return "0.5 – 10 miles"
        case .steps:
            return "1,000 – 20,000 steps"
        case .none:
            return ""
        }
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            HapticService.shared.playIncrementMilestone()
            saveLastValue()
            dismiss()
            onSelect(currentValue)
        } label: {
            Text("Set Goal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tealAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var currentValue: Double {
        switch goalType {
        case .time: return customMinutes
        case .distance: return customMiles
        case .steps: return customSteps
        case .none: return 0
        }
    }

    private var currentBinding: Binding<Double> {
        switch goalType {
        case .time: return $customMinutes
        case .distance: return $customMiles
        case .steps: return $customSteps
        case .none: return .constant(0)
        }
    }

    private var currentRange: ClosedRange<Double> {
        switch goalType {
        case .time: return timeRange
        case .distance: return distanceRange
        case .steps: return stepsRange
        case .none: return 0...0
        }
    }

    private var currentStep: Double {
        switch goalType {
        case .time: return timeStep
        case .distance: return distanceStep
        case .steps: return stepsStep
        case .none: return 1
        }
    }

    private var canDecrement: Bool {
        currentValue > currentRange.lowerBound
    }

    private var canIncrement: Bool {
        currentValue < currentRange.upperBound
    }

    private func decrement() {
        switch goalType {
        case .time:
            customMinutes = max(timeRange.lowerBound, customMinutes - timeStep)
        case .distance:
            customMiles = max(distanceRange.lowerBound, customMiles - distanceStep)
        case .steps:
            customSteps = max(stepsRange.lowerBound, customSteps - stepsStep)
        case .none:
            break
        }
    }

    private func increment() {
        switch goalType {
        case .time:
            customMinutes = min(timeRange.upperBound, customMinutes + timeStep)
        case .distance:
            customMiles = min(distanceRange.upperBound, customMiles + distanceStep)
        case .steps:
            customSteps = min(stepsRange.upperBound, customSteps + stepsStep)
        case .none:
            break
        }
    }

    private func loadLastValues() {
        customMinutes = UserDefaults.standard.lastTimeGoal
        customMiles = UserDefaults.standard.lastDistanceGoal
        customSteps = UserDefaults.standard.lastStepsGoal
    }

    private func saveLastValue() {
        switch goalType {
        case .time:
            UserDefaults.standard.lastTimeGoal = customMinutes
        case .distance:
            UserDefaults.standard.lastDistanceGoal = customMiles
        case .steps:
            UserDefaults.standard.lastStepsGoal = customSteps
        case .none:
            break
        }
    }
}

// MARK: - Preview

#Preview("Time") {
    CustomGoalInputSheet(goalType: .time)
}

#Preview("Distance") {
    CustomGoalInputSheet(goalType: .distance)
}

#Preview("Steps") {
    CustomGoalInputSheet(goalType: .steps)
}
