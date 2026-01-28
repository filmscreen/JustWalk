//
//  SettingsView.swift
//  JustWalk
//
//  Settings screen with goals, streak info, preferences, and more
//

import StoreKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    private var persistence: PersistenceManager { PersistenceManager.shared }
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    private var notificationManager: NotificationManager { NotificationManager.shared }
    private var hapticsManager: HapticsManager { HapticsManager.shared }
    private var voiceManager: IntervalVoiceManager { IntervalVoiceManager.shared }
    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }
    private var healthKitManager: HealthKitManager { HealthKitManager.shared }

    @State private var profile: UserProfile = .default
    @State private var showProPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var showStreakDetail = false
    @State private var showShieldDetail = false
    @State private var showStreakReminderSheet = false

    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                goalSection
                streakShieldsSection
                notificationsSection
                walksSection
                displaySection
                proSection
                dataSupportSection

                // Debug/Developer section (always available for tester mode toggle)
                Section("Developer") {
                    NavigationLink("Debug Settings") {
                        DebugSettingsView()
                    }
                    .listRowBackground(JW.Color.backgroundCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(JW.Color.backgroundPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                profile = persistence.loadProfile()
                loadPermissionStatuses()
            }
            .onChange(of: profile) { _, newValue in
                persistence.saveProfile(newValue)
            }
            .sheet(isPresented: $showProPaywall) {
                ProUpgradeView(onComplete: { showProPaywall = false })
            }
            .sheet(isPresented: $showStreakDetail) {
                StreakDetailSheet()
            }
            .sheet(isPresented: $showShieldDetail) {
                ShieldDetailSheet()
            }
            .sheet(isPresented: $showStreakReminderSheet) {
                StreakReminderSheet()
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    PersistenceManager.shared.clearAllData()
                    CloudKitSyncManager.shared.deleteCloudData()
                    NotificationManager.shared.cancelAllPendingNotifications()
                    profile = .default
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently erase all walks, streaks, and settings. This cannot be undone.")
            }
        }
    }

    // MARK: - 1. Your Goal

    private var goalSection: some View {
        Section("Your Goal") {
            HStack {
                Button {
                    if profile.dailyStepGoal > 1000 {
                        profile.dailyStepGoal -= 500
                        JustWalkHaptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(profile.dailyStepGoal > 1000 ? JW.Color.accent : .gray)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(profile.dailyStepGoal.formatted()) steps")
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: profile.dailyStepGoal)

                Spacer()

                Button {
                    if profile.dailyStepGoal < 25000 {
                        profile.dailyStepGoal += 500
                        JustWalkHaptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(profile.dailyStepGoal < 25000 ? JW.Color.accent : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 2. Streak & Shields

    private var streakShieldsSection: some View {
        Section("Streak & Shields") {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(JW.Color.streak)
                Text("\(streakManager.streakData.currentStreak) \(streakManager.streakData.currentStreak == 1 ? "day" : "days")")
            }
            .listRowBackground(JW.Color.backgroundCard)

            Button {
                showShieldDetail = true
            } label: {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accentBlue)
                    Text("\(shieldManager.shieldData.availableShields) \(shieldManager.shieldData.availableShields == 1 ? "shield" : "shields") available")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)

            Button {
                showStreakDetail = true
            } label: {
                Text("View Calendar")
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 3. Notifications

    private var systemNotificationsAllowed: Bool {
        switch notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private var streakReminderTimeLabel: String {
        var components = DateComponents()
        components.hour = notificationManager.streakReminderHour
        components.minute = notificationManager.streakReminderMinute
        guard let date = Calendar.current.date(from: components) else { return "7:00 PM" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            if systemNotificationsAllowed {
                // Streak Reminder — tapping opens detail sheet
                Button {
                    showStreakReminderSheet = true
                } label: {
                    HStack {
                        Text("Streak Reminder")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(notificationManager.streakRemindersEnabled ? streakReminderTimeLabel : "Off")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)

                // Goal Celebrations — simple toggle
                Toggle("Goal Celebrations", isOn: Binding(
                    get: { notificationManager.goalCelebrationsEnabled },
                    set: { notificationManager.goalCelebrationsEnabled = $0 }
                ))
                .listRowBackground(JW.Color.backgroundCard)
            } else if notificationPermissionStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Notifications")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Blocked")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            } else {
                Button {
                    Task {
                        _ = await notificationManager.requestAuthorization()
                        loadPermissionStatuses()
                    }
                } label: {
                    HStack {
                        Text("Notifications")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Enable")
                            .foregroundStyle(JW.Color.accentBlue)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }
        }
    }

    // MARK: - 4. Walks

    private var walksSection: some View {
        Section("Walks") {
            Toggle("Audio Coaching", isOn: Binding(
                get: { voiceManager.isEnabled },
                set: { voiceManager.isEnabled = $0 }
            ))
            .listRowBackground(JW.Color.backgroundCard)

            Toggle("Haptics", isOn: Binding(
                get: { hapticsManager.isEnabled },
                set: { hapticsManager.isEnabled = $0 }
            ))
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 5. Display

    private var displaySection: some View {
        Section("Display") {
            Toggle("Use Metric (km)", isOn: $profile.useMetricUnits)
                .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 6. Pro

    private var proSection: some View {
        Section {
            if subscriptionManager.isPro {
                HStack {
                    Text("Status")
                    Spacer()
                    Label("Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(JW.Color.accent)
                }
                .listRowBackground(JW.Color.backgroundCard)
            } else {
                Button {
                    showProPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Upgrade to Pro")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(subscriptionManager.proAnnualProduct?.displayPrice ?? "$39.99")/year")
                                .foregroundStyle(.secondary)
                        }
                        Text("Unlimited Walks · More Protection · Full History")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }

            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 8. Data & Support

    private var dataSupportSection: some View {
        Section("Data & Support") {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Health Data Access")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(healthKitManager.isAuthorized ? "Granted" : "Not Granted")
                        .foregroundStyle(healthKitManager.isAuthorized ? .green : .secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)

            ShareLink(
                item: URL(string: "https://apps.apple.com/app/just-walk/id6740066018")!,
                message: Text("Check out Just Walk — it makes walking fun!")
            ) {
                HStack {
                    Text("Share Just Walk")
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)

            NavigationLink("Support & Legal") {
                SupportLegalView(profile: profile)
            }
            .listRowBackground(JW.Color.backgroundCard)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Text("Delete All Data")
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - Helpers

    private func loadPermissionStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
}

// MARK: - Streak Reminder Sheet

struct StreakReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    private var notificationManager: NotificationManager { NotificationManager.shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Streak Reminder", isOn: Binding(
                        get: { notificationManager.streakRemindersEnabled },
                        set: { notificationManager.streakRemindersEnabled = $0 }
                    ))
                    .listRowBackground(JW.Color.backgroundCard)
                } footer: {
                    Text("Get a reminder in the evening if you haven't hit your step goal yet.")
                        .font(JW.Font.caption)
                }

                if notificationManager.streakRemindersEnabled {
                    Section("Reminder Time") {
                        DatePicker("Time", selection: streakReminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .listRowBackground(JW.Color.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Streak Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var streakReminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationManager.streakReminderHour
                components.minute = notificationManager.streakReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationManager.streakReminderHour = components.hour ?? 19
                notificationManager.streakReminderMinute = components.minute ?? 0
            }
        )
    }
}

// MARK: - Legacy Badges View

struct LegacyBadgesView: View {
    let badges: [LegacyBadge]

    var body: some View {
        List(badges) { badge in
            HStack {
                Image(systemName: "rosette")
                    .font(.title)
                    .foregroundStyle(JW.Color.streak)

                VStack(alignment: .leading) {
                    Text(badge.name)
                        .font(.headline)
                    Text("Earned \(badge.earnedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
        .scrollContentBackground(.hidden)
        .background(JW.Color.backgroundPrimary)
        .navigationTitle("Legacy Badges")
    }
}
