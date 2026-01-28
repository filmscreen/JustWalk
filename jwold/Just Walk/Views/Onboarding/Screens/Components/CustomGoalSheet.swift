//
//  CustomGoalSheet.swift
//  Just Walk
//
//  Created by Claude on 1/22/26.
//

import SwiftUI

struct CustomGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var customGoal: Int
    let onSave: (Int) -> Void

    @State private var tempGoal: Int

    private let minGoal = 1000
    private let maxGoal = 25000
    private let stepSize = 500

    init(customGoal: Binding<Int>, onSave: @escaping (Int) -> Void) {
        self._customGoal = customGoal
        self.onSave = onSave
        self._tempGoal = State(initialValue: customGoal.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header
            HStack {
                Spacer()
                Text("Custom Goal")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Large number display
            VStack(spacing: 4) {
                Text("\(tempGoal.formatted())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("steps")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // +/- Controls with slider
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    // Minus button
                    Button {
                        adjustGoal(by: -stepSize)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(tempGoal <= minGoal ? .gray : .blue)
                    }
                    .disabled(tempGoal <= minGoal)

                    // Slider
                    Slider(
                        value: Binding(
                            get: { Double(tempGoal) },
                            set: { tempGoal = Int($0) }
                        ),
                        in: Double(minGoal)...Double(maxGoal),
                        step: Double(stepSize)
                    )
                    .tint(.blue)

                    // Plus button
                    Button {
                        adjustGoal(by: stepSize)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(tempGoal >= maxGoal ? .gray : .blue)
                    }
                    .disabled(tempGoal >= maxGoal)
                }

                // Range labels
                HStack {
                    Text("1,000")
                    Spacer()
                    Text("25,000")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Set Goal button
            Button {
                HapticService.shared.playSelection()
                onSave(tempGoal)
                dismiss()
            } label: {
                Text("Set Goal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func adjustGoal(by amount: Int) {
        let newValue = tempGoal + amount
        if newValue >= minGoal && newValue <= maxGoal {
            HapticService.shared.playSelection()
            withAnimation(.snappy) {
                tempGoal = newValue
            }
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CustomGoalSheet(customGoal: .constant(5000)) { _ in }
        }
}
