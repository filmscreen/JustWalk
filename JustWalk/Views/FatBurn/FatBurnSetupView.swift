//
//  FatBurnSetupView.swift
//  JustWalk
//
//  Shared components for Fat Burn Zone: explainer (first-time),
//  zone scale visualization, and education sheet.
//

import SwiftUI

// MARK: - Combined First-Time Explainer

struct FatBurnExplainerView: View {
    let onStart: () -> Void

    @AppStorage("userAge") private var storedAge: Int?

    @State private var age: Int = 35
    @State private var showWhySheet = false
    @StateObject private var zoneManager = FatBurnZoneManager.shared

    private var needsAge: Bool { storedAge == nil }

    private var displayZone: (low: Int, high: Int) {
        if needsAge {
            let z = FatBurnZoneManager.calculateZone(for: age)
            return (low: z.low, high: z.high)
        }
        return (low: zoneManager.zoneLow, high: zoneManager.zoneHigh)
    }

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: JW.Spacing.xl) {
                    // Heart icon
                    ZStack {
                        Circle()
                            .fill(JW.Color.streak.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "heart.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(JW.Color.streak)
                    }
                    .padding(.top, JW.Spacing.xxl)

                    // Title + what it does
                    VStack(spacing: JW.Spacing.md) {
                        Text("Fat Burn Zone")
                            .font(JW.Font.largeTitle)
                            .foregroundStyle(JW.Color.textPrimary)

                        Text("We'll guide you to stay in Zone 2\nfor maximum fat burning.")
                            .font(JW.Font.body)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Age picker (only when no stored age)
                    if needsAge {
                        agePickerSection
                    }

                    // Zone display
                    Text("Your zone: \(displayZone.low)–\(displayZone.high) bpm")
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.accent)
                        .contentTransition(.numericText())
                        .animation(.default, value: age)

                    // How it works + requirement
                    VStack(spacing: JW.Spacing.md) {
                        infoRow(
                            icon: "waveform.path.ecg",
                            text: "Walk as long as you want. We'll let you know if you need to speed up or slow down."
                        )

                        infoRow(
                            icon: "applewatch",
                            text: "Requires Apple Watch for heart rate monitoring."
                        )
                    }
                    .padding(.horizontal, JW.Spacing.lg)

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, JW.Spacing.xl)
            }

            // Bottom: Start Walk button
            VStack {
                Spacer()

                Button(action: handleStartTap) {
                    Text("Start Walk")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showWhySheet) {
            AgeExplainerSheet()
        }
        .onAppear {
            zoneManager.recalculateZone()
            if let stored = storedAge {
                age = stored
            }
        }
    }

    // MARK: - Components

    private var agePickerSection: some View {
        VStack(spacing: JW.Spacing.sm) {
            Text("Your age")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)

            HStack(spacing: JW.Spacing.xxl) {
                Button(action: {
                    if age > 10 { age -= 1 }
                    JustWalkHaptics.selectionChanged()
                }) {
                    Image(systemName: "minus")
                        .font(JW.Font.title2)
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(JW.Color.backgroundTertiary)
                        .clipShape(Circle())
                }
                .buttonPressEffect()

                Text("\(age)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(JW.Color.textPrimary)
                    .frame(minWidth: 72)
                    .contentTransition(.numericText())
                    .animation(.default, value: age)

                Button(action: {
                    if age < 100 { age += 1 }
                    JustWalkHaptics.selectionChanged()
                }) {
                    Image(systemName: "plus")
                        .font(JW.Font.title2)
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(JW.Color.backgroundTertiary)
                        .clipShape(Circle())
                }
                .buttonPressEffect()
            }

            Button(action: { showWhySheet = true }) {
                HStack(spacing: 4) {
                    Text("Why do we need this?")
                        .font(JW.Font.footnote)
                    Image(systemName: "info.circle")
                        .font(JW.Font.footnote)
                }
                .foregroundStyle(JW.Color.textTertiary)
            }
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: JW.Spacing.sm) {
            Image(systemName: icon)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textTertiary)
                .frame(width: 20)

            Text(text)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    // MARK: - Actions

    private func handleStartTap() {
        JustWalkHaptics.buttonTap()

        // Save age if we collected it
        if storedAge == nil {
            storedAge = age
            zoneManager.recalculateZone()
        }

        onStart()
    }
}

// MARK: - Zone Scale View

struct ZoneScaleView: View {
    let zoneLow: Int
    let zoneHigh: Int
    var currentHR: Int?

    private var scaleMin: Int { zoneLow - 20 }
    private var scaleMax: Int { zoneHigh + 20 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                // Full scale background
                RoundedRectangle(cornerRadius: 4)
                    .fill(JW.Color.backgroundTertiary)
                    .frame(height: 8)

                // Zone highlight
                let zoneStart = position(for: zoneLow, in: width)
                let zoneEnd = position(for: zoneHigh, in: width)
                RoundedRectangle(cornerRadius: 4)
                    .fill(JW.Color.accent)
                    .frame(width: zoneEnd - zoneStart, height: 8)
                    .offset(x: zoneStart)

                // Current HR indicator
                if let hr = currentHR, hr > 0 {
                    let hrPos = position(for: hr, in: width)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: hrPos - 7) // center the circle
                        .animation(JustWalkAnimation.standardSpring, value: currentHR)
                }
            }

            // Labels
            HStack {
                Text("\(scaleMin)")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textTertiary)

                Spacer()

                Text("\(zoneLow)")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.accent)

                Spacer()

                Text("\(zoneHigh)")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.accent)

                Spacer()

                Text("\(scaleMax)")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .offset(y: 16)
        }
        .frame(height: 32)
    }

    private func position(for value: Int, in width: CGFloat) -> CGFloat {
        let range = CGFloat(scaleMax - scaleMin)
        let offset = CGFloat(value - scaleMin)
        return (offset / range) * width
    }
}

// MARK: - First Time Education Sheet

struct FatBurnFirstTimeEducationSheet: View {
    let onDismiss: () -> Void

    @State private var zoneManager = FatBurnZoneManager.shared

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(JW.Color.streak.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "heart.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(JW.Color.streak)
            }

            VStack(spacing: JW.Spacing.lg) {
                Text("How Fat Burn Zone Works")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We monitor your heart rate and guide you to stay in the optimal fat-burning zone.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Zone 2 (60–70% of max HR) is where your body burns fat instead of carbs.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Your zone: \(zoneManager.zoneLow)–\(zoneManager.zoneHigh) bpm")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.accent)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            Button(action: {
                JustWalkHaptics.buttonTap()
                onDismiss()
            }) {
                Text("Got It")
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
        }
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.large])
    }
}
