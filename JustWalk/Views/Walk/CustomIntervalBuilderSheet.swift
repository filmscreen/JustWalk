//
//  CustomIntervalBuilderSheet.swift
//  JustWalk
//
//  Pro custom interval builder with configurable phases
//

import SwiftUI

struct CustomIntervalBuilderSheet: View {
    let onStart: (CustomIntervalConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var fastMinutes: Int = 3
    @State private var slowMinutes: Int = 3
    @State private var warmupMinutes: Int = 1
    @State private var cooldownMinutes: Int = 1
    @State private var intervalCount: Int = 3

    private var config: CustomIntervalConfig {
        CustomIntervalConfig(
            fastMinutes: fastMinutes,
            slowMinutes: slowMinutes,
            warmupMinutes: warmupMinutes,
            cooldownMinutes: cooldownMinutes,
            intervalCount: intervalCount
        )
    }

    private var totalMinutes: Int {
        config.totalMinutes
    }

    private var cycleDescription: String {
        "\(intervalCount) cycles of \(fastMinutes) min fast / \(slowMinutes) min slow"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: JW.Spacing.lg) {
                // Header
                VStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 36))
                        .foregroundStyle(JW.Color.accent)

                    Text("Custom Interval")
                        .font(JW.Font.title2)
                        .foregroundStyle(JW.Color.textPrimary)
                }

                // Inputs
                VStack(spacing: 16) {
                    // Intervals count
                    stepperRow(label: "# of Intervals", value: $intervalCount, range: 1...10, unit: "")
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)

                    // Fast pace
                    stepperRow(label: "Fast pace", value: $fastMinutes, range: 1...10, unit: "min")
                    
                    // Slow pace
                    stepperRow(label: "Slow pace", value: $slowMinutes, range: 1...10, unit: "min")

                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)

                    // Warm up
                    stepperRow(label: "Warm up", value: $warmupMinutes, range: 0...5, unit: "min")
                    
                    // Cool down
                    stepperRow(label: "Cool down", value: $cooldownMinutes, range: 0...5, unit: "min")

                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)

                    // Total time (read-only)
                    HStack {
                        Text("Total time")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textPrimary)

                        Spacer()

                        Text("\(totalMinutes) min")
                            .font(JW.Font.headline.monospacedDigit())
                            .foregroundStyle(JW.Color.accent)
                    }
                }
                .padding(JW.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: JW.Radius.xl)
                        .fill(JW.Color.backgroundCard)
                )

                // Preview
                Text(cycleDescription)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)

                Spacer()

                // Start button
                Button(action: {
                    dismiss()
                    onStart(config)
                }) {
                    Text("Start \(totalMinutes) min Interval")
                        .font(JW.Font.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(JW.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonPressEffect()
            }
            .padding(JW.Spacing.xl)
            .background(JW.Color.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Stepper Row

    @ViewBuilder
    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            HStack(spacing: 12) {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? JW.Color.accent : JW.Color.textSecondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)

                if unit.isEmpty {
                    Text("\(value.wrappedValue)")
                        .font(JW.Font.headline.monospacedDigit())
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(width: 60)
                } else {
                    Text("\(value.wrappedValue) \(unit)")
                        .font(JW.Font.headline.monospacedDigit())
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(width: 60)
                }

                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value.wrappedValue < range.upperBound ? JW.Color.accent : JW.Color.textSecondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }
}

#Preview {
    CustomIntervalBuilderSheet(onStart: { _ in })
}
