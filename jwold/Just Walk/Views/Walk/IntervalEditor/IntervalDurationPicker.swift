//
//  IntervalDurationPicker.swift
//  Just Walk
//
//  Horizontal scrolling pill picker for interval durations.
//  Supports 30-second increments from 1:00 to 5:00.
//

import SwiftUI

/// Horizontal scrolling duration picker with pill-style buttons
struct IntervalDurationPicker: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let selectedDuration: TimeInterval
    let options: [TimeInterval]
    let onChange: (TimeInterval) -> Void

    @Namespace private var pillAnimation

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            // Header row
            headerRow

            // Pill options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JWDesign.Spacing.xs) {
                    ForEach(options, id: \.self) { duration in
                        DurationPill(
                            duration: duration,
                            isSelected: duration == selectedDuration,
                            accentColor: iconColor,
                            namespace: pillAnimation
                        ) {
                            onChange(duration)
                        }
                    }
                }
                .padding(.horizontal, JWDesign.Spacing.md)
            }
            .padding(.horizontal, -JWDesign.Spacing.md) // Compensate for card padding
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }

    private var headerRow: some View {
        HStack(spacing: JWDesign.Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.small))

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JWDesign.Typography.bodyBold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            // Current value badge
            Text(formatDuration(selectedDuration))
                .font(JWDesign.Typography.bodyBold)
                .foregroundStyle(iconColor)
                .padding(.horizontal, JWDesign.Spacing.sm)
                .padding(.vertical, JWDesign.Spacing.xs)
                .background(iconColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Duration Pill

/// Individual duration option pill button
struct DurationPill: View {
    let duration: TimeInterval
    let isSelected: Bool
    let accentColor: Color
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(formatDuration(duration))
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, JWDesign.Spacing.md)
                .padding(.vertical, JWDesign.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(accentColor)
                            .matchedGeometryEffect(id: "selectedPill", in: namespace)
                    } else {
                        Capsule()
                            .fill(JWDesign.Colors.secondaryBackground)
                    }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(JWDesign.Animation.spring, value: isSelected)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview("Duration Picker") {
    VStack(spacing: 20) {
        IntervalDurationPicker(
            title: "Easy Duration",
            subtitle: "Recovery walking pace",
            icon: "tortoise.fill",
            iconColor: JWDesign.Colors.success,
            selectedDuration: 180,
            options: stride(from: 60, through: 300, by: 30).map { TimeInterval($0) }
        ) { duration in
            print("Selected: \(duration)")
        }

        IntervalDurationPicker(
            title: "Brisk Duration",
            subtitle: "Faster power walking pace",
            icon: "hare.fill",
            iconColor: JWDesign.Colors.brandSecondary,
            selectedDuration: 180,
            options: stride(from: 60, through: 300, by: 30).map { TimeInterval($0) }
        ) { duration in
            print("Selected: \(duration)")
        }
    }
    .padding()
    .background(JWDesign.Colors.background)
}
