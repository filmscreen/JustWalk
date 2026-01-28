//
//  GoalTypeSelector.swift
//  Just Walk
//
//  Three equal-width tabs for goal type selection (Time, Distance, Steps).
//

import SwiftUI

struct GoalTypeSelector: View {
    @Binding var selectedType: WalkGoalType
    var onSelect: (WalkGoalType) -> Void = { _ in }

    // Design constants
    private let tabHeight: CGFloat = 70
    private let tabRadius: CGFloat = 12
    private let tealAccent = Color(hex: "00C7BE")

    private let goalTypes: [WalkGoalType] = [.time, .distance, .steps]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(goalTypes, id: \.self) { type in
                goalTab(for: type)
            }
        }
    }

    private func goalTab(for type: WalkGoalType) -> some View {
        let isSelected = selectedType == type

        return Button {
            HapticService.shared.playSelection()
            selectedType = type
            onSelect(type)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .medium))
                Text(type.label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: tabHeight)
            .background(
                RoundedRectangle(cornerRadius: tabRadius)
                    .fill(isSelected ? tealAccent : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selected: WalkGoalType = .time

        var body: some View {
            VStack(spacing: 24) {
                GoalTypeSelector(selectedType: $selected) { type in
                    print("Selected: \(type)")
                }

                Text("Selected: \(selected.label)")
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
