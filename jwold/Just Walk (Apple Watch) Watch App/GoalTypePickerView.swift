//
//  GoalTypePickerView.swift
//  Just Walk (Apple Watch) Watch App
//
//  Segmented picker for selecting goal type (Time, Distance, Steps).
//

import SwiftUI
import WatchKit

struct GoalTypePickerView: View {
    @Binding var selectedType: WalkGoalType
    var isEnabled: Bool = true

    // Filter out .none from display - user selects "Open Walk" separately
    private var displayTypes: [WalkGoalType] {
        WalkGoalType.allCases.filter { $0 != .none }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(displayTypes, id: \.self) { type in
                Button {
                    if isEnabled {
                        WKInterfaceDevice.current().play(.click)
                        selectedType = type
                    }
                } label: {
                    Text(type.label)
                        .font(.caption2.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(buttonBackground(for: type))
                        .foregroundStyle(buttonForeground(for: type))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    private func buttonBackground(for type: WalkGoalType) -> Color {
        if !isEnabled {
            return Color.gray.opacity(0.2)
        }
        return selectedType == type ? Color(hex: "00C7BE") : Color.gray.opacity(0.3)
    }

    private func buttonForeground(for type: WalkGoalType) -> Color {
        if !isEnabled {
            return .secondary
        }
        return selectedType == type ? .white : .primary
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GoalTypePickerView(selectedType: .constant(.time), isEnabled: true)
        GoalTypePickerView(selectedType: .constant(.time), isEnabled: false)
    }
}
