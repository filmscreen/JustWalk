//
//  IntervalPickerSheet.swift
//  JustWalk
//
//  Sheet for selecting interval walking programs
//

import SwiftUI

struct IntervalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walkSession = WalkSessionManager.shared

    @State private var selectedProgram: IntervalProgram?
    @State private var showPreFlight = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: JW.Spacing.sm) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 32))
                    .foregroundStyle(JW.Color.accent)

                Text("Interval Programs")
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("Choose a program to boost your walk")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }
            .padding(.top, JW.Spacing.xl)
            .padding(.bottom, JW.Spacing.lg)

            // Program list
            ScrollView {
                VStack(spacing: JW.Spacing.md) {
                    ForEach(IntervalProgram.allCases) { program in
                        IntervalProgramCard(
                            program: program,
                            isSelected: selectedProgram == program,
                            onSelect: { selectedProgram = program }
                        )
                    }
                }
                .padding(.horizontal, JW.Spacing.lg)
            }

            // Bottom actions
            VStack(spacing: JW.Spacing.md) {
                Button(action: {
                    if selectedProgram != nil {
                        showPreFlight = true
                    }
                }) {
                    Text("Select")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedProgram != nil ? JW.Color.accent : JW.Color.accent.opacity(0.3))
                        .foregroundStyle(selectedProgram != nil ? .white : JW.Color.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .disabled(selectedProgram == nil)
                .buttonPressEffect()

                Button("Cancel") {
                    dismiss()
                }
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
            }
            .padding(.horizontal, JW.Spacing.lg)
            .padding(.bottom, JW.Spacing.xl)
            .padding(.top, JW.Spacing.md)
        }
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPreFlight) {
            if let program = selectedProgram {
                IntervalPreFlightSheet(program: program) {
                    dismiss()
                    walkSession.startWalk(mode: .interval, intervalProgram: program)
                }
            }
        }
    }
}

// MARK: - Interval Program Card

struct IntervalProgramCard: View {
    let program: IntervalProgram
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            JustWalkHaptics.selectionChanged()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: JW.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                        Text(program.displayName)
                            .font(JW.Font.headline)
                            .foregroundStyle(JW.Color.textPrimary)
                        Text(program.description)
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? JW.Color.accent : JW.Color.textTertiary)
                        .font(.title2)
                }

                HStack(spacing: JW.Spacing.lg) {
                    StatBadge(icon: "clock", value: "\(program.duration) min")
                }
            }
            .padding(JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .fill(isSelected ? JW.Color.accent.opacity(0.1) : JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .stroke(isSelected ? JW.Color.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: JW.Spacing.xs) {
            Image(systemName: icon)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
            Text(value)
                .font(JW.Font.caption.bold())
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(.horizontal, JW.Spacing.sm)
        .padding(.vertical, JW.Spacing.xs)
        .background(
            Capsule()
                .fill(JW.Color.backgroundTertiary)
        )
    }
}

#Preview {
    IntervalPickerSheet()
}
