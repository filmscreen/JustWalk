//
//  IntervalPickerSheet.swift
//  Just Walk
//
//  Sheet for selecting interval walk duration.
//  Quick (3 intervals), Classic (5 intervals), Intense (7 intervals).
//

import SwiftUI

struct IntervalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var intervalPrefs = PowerWalkPreferencesManager.shared

    @State private var selectedDuration: String? = nil

    var onStartInterval: (IWTConfiguration) -> Void
    var onDismiss: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(hex: "FF9500"))

                    Text("Interval Mode")
                        .font(.title2.bold())

                    Text("Proven Japanese method for 20% more calorie burn")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Duration options
                VStack(spacing: 12) {
                    intervalOption("quick", cycles: 3, label: "Quick")
                    intervalOption("standard", cycles: 5, label: "Classic")
                    intervalOption("extended", cycles: 7, label: "Intense")
                }
                .padding(.horizontal)

                Spacer()

                // Start button
                Button {
                    startIntervalWalk()
                } label: {
                    Text("Start Interval Walk")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedDuration != nil ? Color(hex: "FF9500") : Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedDuration == nil)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                        dismiss()
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
    }

    private func intervalOption(_ id: String, cycles: Int, label: String) -> some View {
        let style = intervalPrefs.intervalStyle
        let minutes = Int(style.totalDuration(cycles: cycles) / 60)
        let isSelected = selectedDuration == id

        return Button {
            HapticService.shared.playSelection()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDuration = isSelected ? nil : id
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(minutes) min • \(cycles) intervals")
                        .font(.system(size: 14))
                        .opacity(0.8)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "FF9500"))
                }
            }
            .foregroundStyle(isSelected ? Color(hex: "FF9500") : .primary)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "FF9500") : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func startIntervalWalk() {
        guard let duration = selectedDuration else { return }

        HapticService.shared.playIncrementMilestone()

        let cycles: Int
        switch duration {
        case "quick": cycles = 3
        case "extended": cycles = 7
        default: cycles = 5
        }

        // Save preference
        intervalPrefs.setSelectedDurationId(duration)

        // Build config and start
        let config = intervalPrefs.intervalStyle.configuration(cycles: cycles)
        onStartInterval(config)
    }
}

// MARK: - Preview

#Preview {
    IntervalPickerSheet(
        onStartInterval: { config in
            print("Start interval with config: \(config)")
        }
    )
}
