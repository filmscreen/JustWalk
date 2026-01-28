//
//  FatBurnLandingView.swift
//  JustWalk
//
//  Landing page for Fat Burn Zone. Shows the user's target heart rate
//  zone and allows changing age. First-time users see the age picker
//  sheet automatically.
//

import SwiftUI
import WatchConnectivity

struct FatBurnLandingView: View {
    var onFlowComplete: () -> Void

    @AppStorage("userAge") private var storedAge: Int?
    @StateObject private var zoneManager = FatBurnZoneManager.shared
    @StateObject private var connectivityManager = PhoneConnectivityManager.shared
    @State private var showAgeSheet = false
    @State private var navigateToCountdown = false
    @State private var showWatchRequiredAlert = false

    private var zone: (low: Int, high: Int) {
        (low: zoneManager.zoneLow, high: zoneManager.zoneHigh)
    }

    var body: some View {
        if navigateToCountdown {
            FatBurnCountdownView(onFlowComplete: onFlowComplete)
        } else {
            landingContent
        }
    }

    private var landingContent: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: JW.Spacing.xl) {
                    // Header icon
                    ZStack {
                        Circle()
                            .fill(JW.Color.streak.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "heart.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(JW.Color.streak)
                    }
                    .padding(.top, JW.Spacing.xl)

                    // Title + description
                    VStack(spacing: JW.Spacing.md) {
                        Text("Fat Burn Zone")
                            .font(JW.Font.largeTitle)
                            .foregroundStyle(JW.Color.textPrimary)

                        Text("Stay in your optimal heart rate zone to maximize fat burning.")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, JW.Spacing.xl)
                    }

                    // Target zone card
                    targetZoneCard

                    // Apple Watch note
                    HStack(spacing: JW.Spacing.sm) {
                        Image(systemName: "applewatch")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textTertiary)
                        Text("Requires Apple Watch")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }

                    Spacer(minLength: 120)
                }
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
        .navigationBarBackButtonHidden(false)
        .onAppear {
            zoneManager.recalculateZone()
            if storedAge == nil {
                showAgeSheet = true
            }
        }
        .sheet(isPresented: $showAgeSheet) {
            AgeInputSheet(onContinue: {
                showAgeSheet = false
                zoneManager.recalculateZone()
            })
        }
        .alert("Apple Watch Required", isPresented: $showWatchRequiredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Fat Burn Zone requires an Apple Watch to monitor your heart rate in real-time.")
        }
    }

    // MARK: - Target Zone Card

    private var targetZoneCard: some View {
        VStack(spacing: JW.Spacing.md) {
            Text("Your Target Zone")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Text("\(zone.low) - \(zone.high) BPM")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(JW.Color.textPrimary)
                .contentTransition(.numericText())
                .animation(.default, value: storedAge)

            if let age = storedAge {
                Button(action: { showAgeSheet = true }) {
                    HStack(spacing: 4) {
                        Text("Based on age: \(age)")
                            .font(JW.Font.footnote)
                            .foregroundStyle(JW.Color.textTertiary)
                        Text("Change \u{203A}")
                            .font(JW.Font.footnote)
                            .foregroundStyle(JW.Color.accent)
                    }
                }
            }
        }
        .padding(JW.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, JW.Spacing.xl)
    }

    // MARK: - Actions

    private func handleStartTap() {
        JustWalkHaptics.buttonTap()

        // Check if Apple Watch is available for heart rate monitoring
        guard canStartFatBurnZone() else {
            showWatchRequiredAlert = true
            return
        }

        navigateToCountdown = true
    }

    /// Checks if Fat Burn Zone can start (requires paired Apple Watch with app installed)
    private func canStartFatBurnZone() -> Bool {
        guard WCSession.isSupported() else {
            print("🔴 WatchConnectivity not supported")
            return false
        }

        guard WCSession.default.isPaired else {
            print("🔴 No Apple Watch paired")
            return false
        }

        guard WCSession.default.isWatchAppInstalled else {
            print("🔴 Watch app not installed")
            return false
        }

        return true
    }
}

#Preview {
    NavigationStack {
        FatBurnLandingView(onFlowComplete: {})
    }
}
