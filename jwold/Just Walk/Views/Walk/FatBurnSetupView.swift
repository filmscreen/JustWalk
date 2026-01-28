//
//  FatBurnSetupView.swift
//  Just Walk
//
//  Fat Burn setup screen - simplified "one decision, then go" experience.
//  Choose duration, tap Start, and begin walking.
//

import SwiftUI

struct FatBurnSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @ObservedObject private var prefsManager = PowerWalkPreferencesManager.shared

    @State private var selectedDurationId: String = "standard"
    @State private var showCountdown = false
    @State private var showCustomSettings = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Duration options (3 radio cards)
                        durationSection

                        // Structure preview
                        structureSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 100) // Space for button
                }

                // Fixed bottom button
                VStack {
                    Spacer()
                    startButton
                }
            }
            .navigationTitle("Interval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.shared.playSelection()
                        if storeManager.isPro {
                            showCustomSettings = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color(hex: "FF9500"))
                    }
                }
            }
            .fullScreenCover(isPresented: $showCountdown) {
                PreWalkCountdownView(
                    walkMode: .interval,
                    onComplete: startFatBurn,
                    onCancel: { showCountdown = false }
                )
            }
            .sheet(isPresented: $showCustomSettings) {
                CustomIntervalSettingsSheet()
                    .environmentObject(storeManager)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
            .onAppear {
                // Load saved preference
                selectedDurationId = prefsManager.selectedDurationId
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "FF9500").opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "FF9500"))
            }

            // Title
            Text("Proven Japanese method for 20% more calorie burn")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            // Subtitle - shows current interval style
            Text("Alternate easy and brisk every \(prefsManager.intervalStyle.easyMinutes) min")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Duration Section

    private var durationSection: some View {
        VStack(spacing: 12) {
            ForEach(durationOptions) { option in
                durationCard(option)
            }
        }
    }

    private var durationOptions: [DurationOption] {
        let style = prefsManager.intervalStyle

        return [
            DurationOption(
                id: "quick",
                durationLabel: "\(Int(style.totalDuration(cycles: 3) / 60)) min",
                subtitle: "3 intervals · \(formatSteps(style.estimatedSteps(cycles: 3))) steps"
            ),
            DurationOption(
                id: "standard",
                durationLabel: "\(Int(style.totalDuration(cycles: 5) / 60)) min",
                subtitle: "5 intervals · \(formatSteps(style.estimatedSteps(cycles: 5))) steps"
            ),
            DurationOption(
                id: "extended",
                durationLabel: "\(Int(style.totalDuration(cycles: 7) / 60)) min",
                subtitle: "7 intervals · \(formatSteps(style.estimatedSteps(cycles: 7))) steps"
            )
        ]
    }

    private func durationCard(_ option: DurationOption) -> some View {
        let isSelected = selectedDurationId == option.id

        return Button {
            HapticService.shared.playSelection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedDurationId = option.id
                prefsManager.setSelectedDurationId(option.id)
            }
        } label: {
            HStack {
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "FF9500") : Color(.tertiaryLabel), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color(hex: "FF9500"))
                            .frame(width: 12, height: 12)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.durationLabel)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(option.subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "FF9500") : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Structure Section

    private var structureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT TO EXPECT")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(structurePreviewText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var structurePreviewText: String {
        let style = prefsManager.intervalStyle
        return "You'll alternate between easy (\(style.easyFormatted)) and brisk (\(style.briskFormatted)). We'll tell you when to switch pace."
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                HapticService.shared.playSelection()
                showCountdown = true
            } label: {
                Text("Start Walk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "FF9500"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func startFatBurn() {
        showCountdown = false
        dismiss()

        // Get cycle count based on selection
        let cycles: Int
        switch selectedDurationId {
        case "quick": cycles = 3
        case "extended": cycles = 7
        default: cycles = 5
        }

        // Build configuration from interval style
        let config = prefsManager.intervalStyle.configuration(cycles: cycles)

        // Configure IWTService for interval mode
        let service = IWTService.shared
        service.sessionMode = .interval
        service.configuration = config
        service.currentPhase = .slow  // Start with Easy phase

        // Post notification to trigger session view
        NotificationCenter.default.post(
            name: .remoteSessionStarted,
            object: nil,
            userInfo: ["mode": WalkMode.interval, "config": config]
        )
    }

    // MARK: - Helpers

    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "~\(formatter.string(from: NSNumber(value: steps)) ?? "\(steps)")"
    }
}

// MARK: - Duration Option Model

private struct DurationOption: Identifiable {
    let id: String
    let durationLabel: String
    let subtitle: String
}

// MARK: - Preview

#Preview {
    FatBurnSetupView()
        .environmentObject(StoreManager.shared)
}
