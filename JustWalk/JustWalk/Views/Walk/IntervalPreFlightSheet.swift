//
//  IntervalPreFlightSheet.swift
//  JustWalk
//
//  Pre-flight confirmation sheet before starting an interval walk
//

import SwiftUI

struct IntervalPreFlightSheet: View {
    let program: IntervalProgram
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: JW.Spacing.xl) {
            // Bolt icon (matches card)
            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
                .foregroundStyle(JW.Color.accent)

            VStack(spacing: JW.Spacing.sm) {
                Text("Ready for \(program.displayName)?")
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("\(program.duration) minutes · \(program.intervalCount) cycles")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)

                Text(program.structureLabel)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }

            // Positive contract — glassmorphism card
            VStack(alignment: .leading, spacing: JW.Spacing.md) {
                ContractRow(icon: "checkmark.circle.fill", text: "Complete the full \(program.duration) min")
                ContractRow(icon: "checkmark.circle.fill", text: "End early if needed — progress still counts")
            }
            .padding(JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            Spacer()

            // Actions
            VStack(spacing: JW.Spacing.md) {
                Button(action: {
                    dismiss()
                    onConfirm()
                }) {
                    Text("Let's Go")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                Button("Cancel") {
                    dismiss()
                }
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
            }
        }
        .padding(JW.Spacing.xl)
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Contract Row

struct ContractRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: JW.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(JW.Color.success)
            Text(text)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textPrimary)
        }
    }
}

#Preview {
    IntervalPreFlightSheet(program: .short, onConfirm: {})
}
