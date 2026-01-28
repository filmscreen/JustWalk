//
//  StreakDetailSheet.swift
//  Just Walk
//
//  Streak detail view focused on ONE job: show streak status and help protect it.
//  No distance comparisons, no milestones, no activity history. Just streaks.
//

import SwiftUI

// MARK: - Streak Copy Constants

private enum StreakCopy {
    // No streak states
    static let noStreakSubtitle = "Start your streak"
    static let noStreakSupportNever = "Hit today's goal to begin"
    static let noStreakSupportPrevious = "Hit today's goal to start fresh"

    // Active streak states
    static let activeSubtitle = "Your current streak"
    static let goalMetSupport = "Keep it going tomorrow!"
    static func stepsToGoSupport(_ steps: Int) -> String {
        "\(steps.formatted()) steps to keep it going"
    }

    // At risk state
    static let atRiskSubtitle = "Streak at risk!"
    static func atRiskSupport(_ steps: Int) -> String {
        "\(steps.formatted()) steps before midnight"
    }

    // Longest streak
    static func longestStreak(_ days: Int) -> String {
        "Longest: \(days) days"
    }
    static func daysToRecord(_ days: Int) -> String {
        "\(days) day\(days == 1 ? "" : "s") to beat it!"
    }
    static let isLongest = "This is your longest streak!"
    static let newRecord = "New record!"
}

// MARK: - Streak Hero State

private enum StreakHeroState {
    case noStreakNever           // Never had a streak
    case noStreakPrevious        // Had a streak before
    case activeGoalMet           // Active, today's goal met
    case activeInProgress        // Active, still working on today
    case atRisk                  // Active but running out of time

    var fireIcon: String {
        switch self {
        case .noStreakNever, .noStreakPrevious:
            return "flame"
        case .activeGoalMet, .activeInProgress, .atRisk:
            return "flame.fill"
        }
    }

    var fireColor: Color {
        switch self {
        case .noStreakNever, .noStreakPrevious:
            return Color(.tertiaryLabel)
        case .activeGoalMet, .activeInProgress, .atRisk:
            return Color(hex: "FF9500")
        }
    }

    var shouldPulse: Bool {
        switch self {
        case .noStreakNever, .noStreakPrevious:
            return false
        case .activeGoalMet, .activeInProgress, .atRisk:
            return true
        }
    }
}

// MARK: - Streak Detail Sheet

struct StreakDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var streakService = StreakService.shared
    @ObservedObject private var healthKitService = HealthKitService.shared
    @ObservedObject private var stepRepository = StepRepository.shared
    @ObservedObject private var shieldInventory = ShieldInventoryManager.shared
    @StateObject private var dataViewModel = DataViewModel()
    @EnvironmentObject var storeManager: StoreManager

    // Sheet states
    @State private var showProtectSheet = false
    @State private var dayToProtect: DayStepData?

    // Toast state
    @State private var showProtectionToast = false
    @State private var protectedDateString = ""

    // Shield education states
    @AppStorage("hasSeenShieldEducation") private var hasSeenShieldEducation = false
    @State private var showShieldEducation = false
    @State private var showShieldInfo = false

    // Paywall state (for Pro subscription flow from shield sheet)
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if healthKitService.authorizationState == .denied {
                    deniedStatePlaceholder
                } else {
                    VStack(spacing: 16) {
                        // 1. Hero Section (Flame + Streak Count)
                        streakHeroSection

                        // 2. Longest Streak Display
                        longestStreakSection

                        // 3. Journey Timeline (Calendar Grid)
                        StreakCalendarGridView(
                            days: Array(dataViewModel.yearData.prefix(35)),
                            dailyGoal: savedDailyGoal,
                            streakService: streakService,
                            onProtectRequest: { day in
                                dayToProtect = day
                                showProtectSheet = true
                            },
                            onInfoTapped: {
                                showShieldInfo = true
                            }
                        )

                        // Intentional breathing room
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, JWDesign.Spacing.md)
                    .padding(.bottom, JWDesign.Spacing.tabBarSafeArea)
                }
            }
            .background(JWDesign.Colors.background)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(JWDesign.Colors.background, for: .navigationBar)
            .navigationTitle("Streak Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await dataViewModel.loadData()

                // Check if should show first-time shield education
                if !hasSeenShieldEducation && shieldInventory.totalShields > 0 {
                    // Slight delay to let the view settle
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    showShieldEducation = true
                }
            }
            .refreshable {
                await dataViewModel.loadData()
            }
            .sheet(isPresented: $showProtectSheet) {
                if let day = dayToProtect {
                    ProtectDayConfirmationSheet(
                        day: day,
                        dailyGoal: savedDailyGoal,
                        shieldInventory: shieldInventory,
                        onUseShield: {
                            applyShieldAndShowToast(for: day)
                        },
                        onShowPaywall: {
                            showProtectSheet = false
                            dayToProtect = nil
                            // Delay to allow sheet dismissal before showing paywall
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showPaywall = true
                            }
                        },
                        onDismiss: {
                            showProtectSheet = false
                            dayToProtect = nil
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .overlay(alignment: .bottom) {
                if showProtectionToast {
                    Text("\(protectedDateString) protected! 🛡️")
                        .font(JWDesign.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.teal))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
            }
            .sheet(isPresented: $showShieldEducation) {
                ShieldEducationSheet(
                    isFirstTime: true,
                    shieldCount: shieldInventory.totalShields,
                    onDismiss: {
                        hasSeenShieldEducation = true
                        showShieldEducation = false
                    }
                )
                .presentationDetents([.medium])
            }
            .alert("Streak Shields", isPresented: $showShieldInfo) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("Protect missed days to keep your streak alive. Shields can only be used within 7 days, and the day must be connected to your current streak.")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }

    // MARK: - Hero Section

    private var streakHeroSection: some View {
        let state = heroState
        let stepsRemaining = stepRepository.stepsRemaining

        return VStack(spacing: 8) {
            // Flame icon - state-driven
            Image(systemName: state.fireIcon)
                .font(.system(size: 60))
                .foregroundStyle(state.fireColor)
                .symbolEffect(.pulse, options: .repeating, isActive: state.shouldPulse)

            // Streak count
            Text("\(streakService.currentStreak) days")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Subtitle - state-driven
            Text(heroSubtitle(for: state))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(state == .atRisk ? Color(hex: "FF9500") : Color(.secondaryLabel))

            // Supporting text - state-driven
            if let supportText = heroSupportText(for: state, stepsRemaining: stepsRemaining) {
                Text(supportText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(supportTextColor(for: state))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current streak: \(streakService.currentStreak) days. \(heroSubtitle(for: state))")
    }

    // MARK: - Longest Streak Section

    private var longestStreakSection: some View {
        let current = streakService.currentStreak
        let longest = streakService.longestStreak
        let daysToRecord = longest - current

        return HStack(spacing: 8) {
            if current > 0 && current > longest {
                // New record!
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.yellow)
                Text(StreakCopy.newRecord)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            } else if current > 0 && current == longest {
                // Tied with longest
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.yellow)
                Text(StreakCopy.isLongest)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            } else if current > 0 && daysToRecord <= 3 {
                // Close to record - motivational
                Image(systemName: "crown")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "FF9500"))
                Text("\(StreakCopy.longestStreak(longest)) · \(StreakCopy.daysToRecord(daysToRecord))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            } else {
                // Default - just show longest
                Image(systemName: "crown")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.secondaryLabel))
                Text(StreakCopy.longestStreak(longest))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }

    // MARK: - Denied State Placeholder

    private var deniedStatePlaceholder: some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "figure.walk.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Enable step tracking to start building your streak")
                .font(JWDesign.Typography.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, JWDesign.Spacing.lg)

            Button(action: openHealthSettings) {
                Text("Enable in Settings")
                    .font(JWDesign.Typography.headlineBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JWDesign.Spacing.md)
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
            }
            .padding(.horizontal, JWDesign.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    private func openHealthSettings() {
        if let healthURL = URL(string: "x-apple-health://"),
           UIApplication.shared.canOpenURL(healthURL) {
            UIApplication.shared.open(healthURL)
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - Helpers

    private var savedDailyGoal: Int {
        let saved = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        return saved > 0 ? saved : 10_000
    }

    private var heroState: StreakHeroState {
        // No streak states
        if streakService.currentStreak == 0 {
            return streakService.previousStreakBeforeLoss > 0 ? .noStreakPrevious : .noStreakNever
        }

        // Active streak - check if goal is met
        let stepsRemaining = stepRepository.stepsRemaining
        if stepsRemaining == 0 {
            return .activeGoalMet
        }

        // Check if at risk (less than 4 hours to midnight)
        let calendar = Calendar.current
        let now = Date()
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return .activeInProgress
        }
        let minutesUntilMidnight = calendar.dateComponents([.minute], from: now, to: midnight).minute ?? 0

        if minutesUntilMidnight <= 240 {
            return .atRisk
        }

        return .activeInProgress
    }

    private func heroSubtitle(for state: StreakHeroState) -> String {
        switch state {
        case .noStreakNever, .noStreakPrevious:
            return StreakCopy.noStreakSubtitle
        case .activeGoalMet, .activeInProgress:
            return StreakCopy.activeSubtitle
        case .atRisk:
            return StreakCopy.atRiskSubtitle
        }
    }

    private func heroSupportText(for state: StreakHeroState, stepsRemaining: Int) -> String? {
        switch state {
        case .noStreakNever:
            return StreakCopy.noStreakSupportNever
        case .noStreakPrevious:
            return StreakCopy.noStreakSupportPrevious
        case .activeGoalMet:
            return StreakCopy.goalMetSupport
        case .activeInProgress:
            return StreakCopy.stepsToGoSupport(stepsRemaining)
        case .atRisk:
            return StreakCopy.atRiskSupport(stepsRemaining)
        }
    }

    private func supportTextColor(for state: StreakHeroState) -> Color {
        switch state {
        case .noStreakNever, .noStreakPrevious:
            return Color(hex: "00C7BE")
        case .activeGoalMet:
            return Color(.secondaryLabel)
        case .activeInProgress, .atRisk:
            return Color(hex: "FF9500")
        }
    }

    private func applyShieldAndShowToast(for day: DayStepData) {
        if streakService.applyStreakShield(for: day.date) {
            HapticService.shared.playSuccess()

            // Format date for toast
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            protectedDateString = formatter.string(from: day.date)

            // Show toast with animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showProtectionToast = true
            }

            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showProtectionToast = false
                }
            }
        }
        showProtectSheet = false
        dayToProtect = nil
    }
}

// MARK: - Preview

#Preview("Active Streak") {
    StreakDetailSheet()
        .environmentObject(StoreManager.shared)
}

#Preview("No Streak") {
    StreakDetailSheet()
        .environmentObject(StoreManager.shared)
}
