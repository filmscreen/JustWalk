//
//  IntervalCardView.swift
//  JustWalk
//
//  Rich vertical interval program card with phase structure bar
//

import SwiftUI

struct IntervalCardView: View {
    let program: IntervalProgram
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: name + recommended badge
                HStack {
                    Text(program.displayName)
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    if program.isRecommended {
                        Text("Recommended")
                            .font(JW.Font.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(JW.Color.accent)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                // Duration + cycles row
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(program.duration)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(JW.Color.textPrimary)

                    Text("min")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)

                    Spacer()

                    Text("\(program.intervalCount) cycles")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                // Phase structure bar
                PhaseStructureBar(phases: program.phases)
                    .frame(height: 8)

                // Structure label + description
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.structureLabel)
                        .font(JW.Font.caption.bold())
                        .foregroundStyle(JW.Color.textSecondary)

                    Text(program.description)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? JW.Color.backgroundCard.opacity(1.2) : JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? JW.Color.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Phase Structure Bar

private struct PhaseStructureBar: View {
    let phases: [IntervalPhase]

    private var totalDuration: Int {
        phases.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(phases) { phase in
                    let fraction = CGFloat(phase.durationSeconds) / CGFloat(max(1, totalDuration))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(phaseColor(for: phase.type))
                        .frame(width: max(2, fraction * geo.size.width))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func phaseColor(for type: IntervalPhase.PhaseType) -> Color {
        switch type {
        case .warmup:   return JW.Color.phaseWarmup
        case .fast:     return JW.Color.phaseFast
        case .slow:     return JW.Color.phaseSlow
        case .cooldown: return JW.Color.phaseCooldown
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        IntervalCardView(program: .short, isSelected: false, onTap: {})
        IntervalCardView(program: .medium, isSelected: true, onTap: {})
    }
    .padding()
    .background(JW.Color.backgroundPrimary)
}
