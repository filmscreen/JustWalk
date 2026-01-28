//
//  WatchGoalPickerSheet.swift
//  Just Walk Watch App
//
//  Goal type selection sheet (Time/Distance/Steps).
//  Uses NavigationStack for smooth navigation to value picker.
//

import SwiftUI
import WatchKit

struct WatchGoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onSelectGoal: (WalkGoal) -> Void
    var onCancel: () -> Void

    @State private var selectedType: WalkGoalType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    GoalTypeRow(
                        icon: "timer",
                        title: "Time",
                        isSelected: selectedType == .time
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        selectedType = .time
                    }

                    GoalTypeRow(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        title: "Distance",
                        isSelected: selectedType == .distance
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        selectedType = .distance
                    }

                    GoalTypeRow(
                        icon: "shoeprints.fill",
                        title: "Steps",
                        isSelected: selectedType == .steps
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        selectedType = .steps
                    }
                }
                .padding()
            }
            .navigationTitle("Pick a Goal")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedType) { type in
                WatchGoalValuePickerView(
                    goalType: type,
                    onSelectGoal: onSelectGoal,
                    onCancel: { selectedType = nil }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Goal Type Row

struct GoalTypeRow: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.teal)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
            .background(isSelected ? Color.teal.opacity(0.2) : Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    WatchGoalPickerSheet(
        onSelectGoal: { print("Selected: \($0)") },
        onCancel: { print("Cancelled") }
    )
}
