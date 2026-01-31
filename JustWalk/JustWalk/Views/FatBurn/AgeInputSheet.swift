//
//  AgeInputSheet.swift
//  JustWalk
//
//  Collects user age to calculate fat burn heart rate zone.
//  Shows live zone calculation as age changes.
//

import SwiftUI

struct AgeInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userAge") private var storedAge: Int?
    @State private var age: Int = 35
    @State private var showWhySheet = false

    let onContinue: () -> Void

    private var zone: (low: Int, high: Int, maxHR: Int) {
        FatBurnZoneManager.calculateZone(for: age)
    }

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(JW.Color.streak.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "heart.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(JW.Color.streak)
            }

            // Title + description
            VStack(spacing: JW.Spacing.md) {
                Text("Set Up Fat Burn Zone")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We need your age to calculate your optimal heart rate zone.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, JW.Spacing.xl)

            // Age picker
            VStack(spacing: JW.Spacing.lg) {
                Text("Your age")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)

                HStack(spacing: JW.Spacing.xxl) {
                    Button(action: {
                        if age > 10 { age -= 1 }
                        JustWalkHaptics.selectionChanged()
                    }) {
                        Image(systemName: "minus")
                            .font(JW.Font.title2)
                            .foregroundStyle(JW.Color.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(JW.Color.backgroundTertiary)
                            .clipShape(Circle())
                    }
                    .buttonPressEffect()

                    Text("\(age)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(minWidth: 80)
                        .contentTransition(.numericText())
                        .animation(.default, value: age)

                    Button(action: {
                        if age < 100 { age += 1 }
                        JustWalkHaptics.selectionChanged()
                    }) {
                        Image(systemName: "plus")
                            .font(JW.Font.title2)
                            .foregroundStyle(JW.Color.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(JW.Color.backgroundTertiary)
                            .clipShape(Circle())
                    }
                    .buttonPressEffect()
                }

                // Live zone display
                Text("Your fat burn zone: \(zone.low)–\(zone.high) bpm")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.accent)
                    .contentTransition(.numericText())
                    .animation(.default, value: age)
            }

            Spacer()

            // Continue + Why
            VStack(spacing: JW.Spacing.lg) {
                Button(action: {
                    JustWalkHaptics.buttonTap()
                    storedAge = age
                    FatBurnZoneManager.shared.recalculateZone()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                Button(action: {
                    showWhySheet = true
                }) {
                    HStack(spacing: 4) {
                        Text("Why do we need this?")
                            .font(JW.Font.footnote)
                        Image(systemName: "info.circle")
                            .font(JW.Font.footnote)
                    }
                    .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
        }
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.large])
        .onAppear {
            if let stored = storedAge {
                age = stored
            }
        }
        .sheet(isPresented: $showWhySheet) {
            AgeExplainerSheet()
        }
    }
}

// MARK: - Why We Need This

struct AgeExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            VStack(spacing: JW.Spacing.lg) {
                Text("Why Your Age?")
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("Your maximum heart rate is estimated as 220 minus your age. Fat Burn Zone keeps you at 60–70% of that max, which is where your body burns fat most efficiently.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Your age is stored only on your device.")
                    .font(JW.Font.footnote)
                    .foregroundStyle(JW.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            Button(action: {
                JustWalkHaptics.buttonTap()
                dismiss()
            }) {
                Text("Got It")
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
        }
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.medium])
    }
}

#Preview {
    AgeInputSheet(onContinue: {})
}
