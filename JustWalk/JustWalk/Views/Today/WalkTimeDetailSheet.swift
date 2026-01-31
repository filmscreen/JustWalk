//
//  WalkTimeDetailSheet.swift
//  JustWalk
//
//  Half-sheet showing today's tracked walk time breakdown
//

import SwiftUI

struct WalkTimeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var walks: [TrackedWalk] = []
    @State private var totalMinutes: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if walks.isEmpty {
                    emptyState
                } else {
                    walkList
                }
            }
            .navigationTitle("Walk Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { loadData() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: JW.Spacing.lg) {
            Image(systemName: "figure.walk")
                .font(.system(size: 44))
                .foregroundStyle(JW.Color.textSecondary)

            VStack(spacing: JW.Spacing.xs) {
                Text("No walks yet today")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("Start a tracked walk to log your time.\nPassive steps don't count here.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.selectedTab = .walks
                }
            } label: {
                Text("Start Your First Walk")
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Walk List

    private var walkList: some View {
        ScrollView {
            VStack(spacing: JW.Spacing.lg) {
                // Hero stat
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundStyle(JW.Color.accent)

                        Text("\(totalMinutes)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: Double(totalMinutes)))

                        Text("min")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(JW.Color.textSecondary)
                    }

                    Text("tracked today")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, JW.Spacing.md)

                // Walk entries
                VStack(alignment: .leading, spacing: JW.Spacing.sm) {
                    Text("Today's Walks")
                        .font(JW.Font.caption.bold())
                        .foregroundStyle(JW.Color.textSecondary)
                        .textCase(.uppercase)

                    ForEach(walks) { walk in
                        WalkTimeRow(walk: walk)
                    }
                }

                // CTA
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.selectedTab = .walks
                    }
                } label: {
                    Text("Start Another Walk")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
            }
            .padding()
        }
    }

    // MARK: - Data

    private func loadData() {
        let persistence = PersistenceManager.shared
        let log = persistence.loadDailyLog(for: Date())

        if let ids = log?.trackedWalkIDs {
            walks = ids.compactMap { persistence.loadTrackedWalk(by: $0) }
                .filter(\.isDisplayable)
        }

        totalMinutes = walks.reduce(0) { $0 + $1.durationMinutes }
    }
}

// MARK: - Walk Time Row

private struct WalkTimeRow: View {
    let walk: TrackedWalk

    private var modeIcon: String {
        switch walk.mode {
        case .free: return "figure.walk"
        case .interval: return "waveform.path"
        case .fatBurn: return "heart.fill"
        case .postMeal: return "fork.knife"
        }
    }

    private var modeColor: Color {
        switch walk.mode {
        case .free: return JW.Color.accent
        case .interval: return JW.Color.accentBlue
        case .fatBurn: return JW.Color.streak
        case .postMeal: return JW.Color.accentPurple
        }
    }

    private var modeLabel: String {
        switch walk.mode {
        case .free: return "Free Walk"
        case .interval: return "Interval Walk"
        case .fatBurn: return "Fat Burn Zone"
        case .postMeal: return "Post-Meal Walk"
        }
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: walk.startTime)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: modeIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(modeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(modeLabel)
                    .font(JW.Font.subheadline.weight(.medium))
                    .foregroundStyle(JW.Color.textPrimary)

                Text("\(timeLabel) \u{00B7} \(walk.steps.formatted()) steps")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Text("\(walk.durationMinutes)m")
                .font(JW.Font.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(JW.Color.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WalkTimeDetailSheet()
        .environment(AppState())
}
