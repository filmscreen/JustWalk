//
//  BottomPanel.swift
//  JustWalk
//
//  Intervals panel with vertical preset cards and simplified controls
//

import SwiftUI

struct BottomPanel: View {
    @Binding var selectedInterval: IntervalProgram?
    let isPro: Bool
    let freeIntervalsRemaining: Int? // nil for Pro users
    let onStartTap: () -> Void
    let onIntervalTap: (IntervalProgram) -> Void
    let onCustomTap: () -> Void

    private var buttonLabel: String {
        if let interval = selectedInterval {
            return "Start \(interval.duration) min Interval"
        }
        return "Start Interval"
    }

    var body: some View {
        VStack(spacing: 20) {

            // === PRESET CARDS (vertical) ===
            VStack(spacing: 12) {
                ForEach(IntervalProgram.allCases) { program in
                    IntervalCardView(
                        program: program,
                        isSelected: selectedInterval == program,
                        onTap: { onIntervalTap(program) }
                    )
                }
            }

            // === CUSTOM INTERVAL LINK ===
            if isPro {
                Button(action: onCustomTap) {
                    HStack(spacing: 4) {
                        Text("Custom interval")
                            .font(JW.Font.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(JW.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // === FREE USER USAGE INDICATOR ===
            if let remaining = freeIntervalsRemaining {
                Text("\(remaining) of \(IntervalUsageData.freeWeeklyLimit) free intervals this week")
                    .font(JW.Font.caption)
                    .foregroundStyle(remaining > 0 ? JW.Color.textSecondary : JW.Color.danger)
            }

            // === CTA BUTTON ===
            Button(action: onStartTap) {
                Text(buttonLabel)
                    .font(JW.Font.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedInterval != nil ? JW.Color.accent : JW.Color.accent.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contentTransition(.interpolate)
            }
            .disabled(selectedInterval == nil)
            .buttonPressEffect()
        }
    }

}

#Preview {
    ZStack {
        JW.Color.heroGradient.ignoresSafeArea()
        ScrollView {
            BottomPanel(
                selectedInterval: .constant(.medium),
                isPro: true,
                freeIntervalsRemaining: nil,
                onStartTap: {},
                onIntervalTap: { _ in },
                onCustomTap: {}
            )
            .padding(20)
        }
    }
}
