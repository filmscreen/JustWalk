//
//  GoalValueSelector.swift
//  Just Walk
//
//  Preset value chips and custom option based on selected goal type.
//

import SwiftUI

struct GoalValueSelector: View {
    let goalType: WalkGoalType
    let selectedValue: Double?
    var onSelectPreset: (Double) -> Void = { _ in }
    var onSelectCustom: () -> Void = {}

    // Design constants
    private let chipHeight: CGFloat = 48
    private let chipRadius: CGFloat = 10
    private let chipMinWidth: CGFloat = 72
    private let tealAccent = Color(hex: "00C7BE")

    private var promptText: String {
        switch goalType {
        case .time: return "How long?"
        case .distance: return "How far?"
        case .steps: return "How many steps?"
        case .none: return "Choose a target"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(promptText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Preset chips
            presetChips

            // Custom option
            customRow

            // Steps disclaimer
            if goalType == .steps {
                stepsDisclaimer
            }
        }
    }

    // MARK: - Preset Chips

    private var presetChips: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { value in
                presetChip(value: value)
            }
        }
    }

    private func presetChip(value: Double) -> some View {
        let isSelected = selectedValue == value

        return Button {
            HapticService.shared.playSelection()
            onSelectPreset(value)
        } label: {
            Text(formatPreset(value))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(minWidth: chipMinWidth)
                .frame(height: chipHeight)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: chipRadius)
                        .fill(isSelected ? tealAccent : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Row

    private var customRow: some View {
        Button {
            HapticService.shared.playSelection()
            onSelectCustom()
        } label: {
            HStack {
                Text("Custom")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(height: chipHeight)
            .background(
                RoundedRectangle(cornerRadius: chipRadius)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Steps Disclaimer

    private var stepsDisclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
            Text("Step count is estimated from distance")
                .font(.system(size: 13))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var presets: [Double] {
        switch goalType {
        case .time: return WalkGoalPresets.time
        case .distance: return WalkGoalPresets.distance
        case .steps: return WalkGoalPresets.steps
        case .none: return []
        }
    }

    private func formatPreset(_ value: Double) -> String {
        switch goalType {
        case .time:
            return "\(Int(value)) min"
        case .distance:
            if value == floor(value) {
                return "\(Int(value)) mi"
            }
            return String(format: "%.1f mi", value)
        case .steps:
            if value >= 1000 {
                let k = value / 1000
                if k == floor(k) {
                    return "\(Int(k))K"
                }
                return String(format: "%.1fK", k)
            }
            return "\(Int(value))"
        case .none:
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        GoalValueSelector(
            goalType: .time,
            selectedValue: 30,
            onSelectPreset: { print("Time: \($0)") },
            onSelectCustom: { print("Custom time") }
        )

        GoalValueSelector(
            goalType: .distance,
            selectedValue: nil,
            onSelectPreset: { print("Distance: \($0)") },
            onSelectCustom: { print("Custom distance") }
        )

        GoalValueSelector(
            goalType: .steps,
            selectedValue: 5000,
            onSelectPreset: { print("Steps: \($0)") },
            onSelectCustom: { print("Custom steps") }
        )
    }
    .padding()
}
