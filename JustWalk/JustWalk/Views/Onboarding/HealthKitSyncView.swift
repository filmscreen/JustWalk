//
//  HealthKitSyncView.swift
//  JustWalk
//
//  Onboarding step to sync step history from HealthKit
//

import SwiftUI

struct HealthKitSyncView: View {
    let onComplete: () -> Void

    @State private var syncState: SyncState = .ready
    @State private var syncPhase: SyncPhase = .connecting
    @State private var ringProgress: Double = 0

    private var healthKitManager: HealthKitManager { HealthKitManager.shared }

    enum SyncState {
        case ready
        case syncing
        case skipped
    }

    enum SyncPhase: CaseIterable {
        case connecting
        case scanning
        case importing
        case finishing

        var message: String {
            switch self {
            case .connecting: return "Connecting to Apple Health..."
            case .scanning: return "Scanning your step history..."
            case .importing: return "Importing your data..."
            case .finishing: return "Almost there..."
            }
        }

        var progress: Double {
            switch self {
            case .connecting: return 0.15
            case .scanning: return 0.45
            case .importing: return 0.75
            case .finishing: return 0.95
            }
        }
    }

    var body: some View {
        VStack(spacing: JW.Spacing.xl) {
            Spacer()

            // Icon with progress ring
            ZStack {
                // Background circle
                Circle()
                    .fill(JW.Color.accent.opacity(0.1))
                    .frame(width: 140, height: 140)

                // Progress ring (only during syncing)
                if syncState == .syncing {
                    // Track
                    Circle()
                        .stroke(JW.Color.accent.opacity(0.2), lineWidth: 6)
                        .frame(width: 130, height: 130)

                    // Progress
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            JW.Color.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-90))

                    // Pulsing inner glow
                    Circle()
                        .fill(JW.Color.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringProgress > 0.5 ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: ringProgress)
                }

                // Icon
                if syncState == .syncing {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(JW.Color.accent)
                        .symbolEffect(.pulse, options: .repeating)
                } else {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(JW.Color.accent)
                }
            }
            .frame(height: 140)

            // Title & Description
            VStack(spacing: JW.Spacing.md) {
                Text(titleText)
                    .font(JW.Font.largeTitle)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                Text(descriptionText)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, JW.Spacing.lg)
                    .contentTransition(.opacity)
                    .id(syncState == .syncing ? syncPhase : nil)
            }
            .animation(.easeInOut(duration: 0.3), value: syncPhase)

            Spacer()

            // Actions
            VStack(spacing: JW.Spacing.md) {
                if syncState == .ready {
                    // Primary: Sync button
                    Button {
                        Task { await startSync() }
                    } label: {
                        Text("Import My Steps")
                            .font(JW.Font.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(JW.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                    }
                    .buttonPressEffect()

                    // Secondary: Skip
                    Button {
                        syncState = .skipped
                        onComplete()
                    } label: {
                        Text("Skip for Now")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                } else if syncState == .syncing {
                    // Phase indicator dots
                    HStack(spacing: 8) {
                        ForEach(Array(SyncPhase.allCases.enumerated()), id: \.offset) { index, phase in
                            Circle()
                                .fill(phaseIndex >= index ? JW.Color.accent : JW.Color.accent.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(syncPhase == phase ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: syncPhase)
                        }
                    }
                    .padding(.bottom, JW.Spacing.sm)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
            .animation(.easeInOut(duration: 0.4), value: syncState)
        }
        .background(JW.Color.backgroundPrimary)
    }

    private var phaseIndex: Int {
        SyncPhase.allCases.firstIndex(of: syncPhase) ?? 0
    }

    private var titleText: String {
        switch syncState {
        case .ready:
            return "Import Your\nStep History"
        case .syncing:
            return "Syncing..."
        case .skipped:
            return "Skipped"
        }
    }

    private var descriptionText: String {
        switch syncState {
        case .ready:
            return "We can import your last \(HealthKitManager.historySyncDays) days of steps from Apple Health to show your walking history."
        case .syncing:
            return syncPhase.message
        case .skipped:
            return "You can sync your history later in Settings."
        }
    }

    private func startSync() async {
        syncState = .syncing
        syncPhase = .connecting

        // Animate ring to first phase
        withAnimation(.easeOut(duration: 0.5)) {
            ringProgress = SyncPhase.connecting.progress
        }

        // Start actual sync in background
        let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
        async let syncTask = healthKitManager.syncHealthKitHistory(days: HealthKitManager.historySyncDays, dailyGoal: goal)

        // Phase 1: Connecting (0.5s)
        try? await Task.sleep(for: .milliseconds(500))

        await MainActor.run {
            syncPhase = .scanning
            withAnimation(.easeOut(duration: 0.6)) {
                ringProgress = SyncPhase.scanning.progress
            }
        }

        // Phase 2: Scanning (0.7s)
        try? await Task.sleep(for: .milliseconds(700))

        await MainActor.run {
            syncPhase = .importing
            withAnimation(.easeOut(duration: 0.6)) {
                ringProgress = SyncPhase.importing.progress
            }
        }

        // Wait for actual sync to complete
        _ = await syncTask

        // Phase 3: Finishing (0.5s minimum)
        await MainActor.run {
            syncPhase = .finishing
            withAnimation(.easeOut(duration: 0.4)) {
                ringProgress = SyncPhase.finishing.progress
            }
        }

        try? await Task.sleep(for: .milliseconds(500))

        // Complete ring
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                ringProgress = 1.0
            }
        }

        try? await Task.sleep(for: .milliseconds(300))

        // Sync complete — proceed directly to final screen
        await MainActor.run {
            JustWalkHaptics.success()
            onComplete()
        }
    }
}

#Preview {
    HealthKitSyncView(onComplete: {})
}
