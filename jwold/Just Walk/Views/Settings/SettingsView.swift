//
//  SettingsView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI
import StoreKit

/// Settings and preferences view
struct SettingsView: View {

    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var cloudKit = CloudKitSyncHandler.shared
    @ObservedObject private var audioCueService = AudioCueService.shared
    @ObservedObject private var hapticService = HapticService.shared
    @StateObject private var locationManager = LocationPermissionManager()
    @State private var showGoalPicker = false
    @State private var showProPaywall = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = true
    @AppStorage("preferredDistanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue
    @AppStorage("streakReminderTime") private var reminderTimeInterval: Double = SettingsView.defaultReminderTime
    @AppStorage("walkerDisplayName") private var walkerDisplayName: String = ""

    #if DEBUG
    @AppStorage("debugProOverride") private var debugProOverride: Bool = false
    #endif

    private static var defaultReminderTime: Double {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        return Calendar.current.date(from: components)?.timeIntervalSinceReferenceDate ?? 0
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: reminderTimeInterval) },
            set: { reminderTimeInterval = $0.timeIntervalSinceReferenceDate }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Custom compact header
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    List {
                        // 1. Subscription Section (Pro upgrade)
                        SettingsSubscriptionSection(showPaywall: $showProPaywall)
                            .id("top")

                        // 2. Daily Goal Section
                        goalSection

                        // 2.5. Walker Identity Section
                        identitySection

                        // 3. Units Section
                        unitsSection

                        // Browse Kit (for Lifetime Focus Mode users)
                        if storeManager.ownsLifetime {
                            browseKitSection
                        }

                        // 4. Notifications Section
                        notificationsSection

                        // 5. Haptics Section
                        feedbackSection

                        // 6. Audio Cues Section
                        audioCuesSection

                        // 7. Live Activity Section
                        liveActivitySection

                        // 8. Permissions Section
                        permissionsSection

                        // 9. iCloud Section
                        iCloudSection

                        // 10. Appearance Section
                        appearanceSection

                        // 11. About Section
                        aboutSection

                        #if DEBUG
                        // 12. Debug Section
                        debugSection
                        #endif
                    }
                    .contentMargins(.bottom, 80, for: .scrollContent)
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
                    if let tab = notification.object as? AppTab, tab == .settings {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .background(JWDesign.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showProPaywall) {
                ProPaywallView()
            }
            .onAppear {
                viewModel.checkAuthorization()
                // Sync distance unit to App Group for widgets and Watch app
                syncDistanceUnitToAppGroup()
            }
            .onChange(of: distanceUnit) { _, newValue in
                // Sync distance unit to App Group when changed
                syncDistanceUnitToAppGroup()
            }
        }
    }

    // MARK: - App Group Sync

    /// Sync distance unit to App Group for widgets and Watch app
    private func syncDistanceUnitToAppGroup() {
        let shared = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")
        shared?.set(distanceUnit, forKey: "preferredDistanceUnit")
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Daily Step Goal")
                        .font(.headline)

                    Spacer()

                    Text(viewModel.formattedGoal)
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                }

                // Goal stepper
                HStack(spacing: 16) {
                    Button {
                        viewModel.decrementGoal()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    // Goal slider
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.dailyStepGoal) },
                            set: { viewModel.setGoal(Int($0)) }
                        ),
                        in: 2000...20000,
                        step: 500
                    )
                    .tint(.blue)

                    Button {
                        viewModel.incrementGoal()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Label("Goal", systemImage: "target")
        } footer: {
            Text("The 10,000 steps goal is recommended for most adults for optimal health benefits.")
        }
    }

    // MARK: - Identity Section

    private var identitySection: some View {
        Section {
            TextField("Display Name", text: $walkerDisplayName)
        } header: {
            Label("Walker Identity", systemImage: "person.text.rectangle")
        } footer: {
            Text("This name appears on your shareable Walker Card.")
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        Section {
            Picker("Distance", selection: $distanceUnit) {
                ForEach(DistanceUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("Units", systemImage: "ruler")
        } footer: {
            Text("Affects distance display throughout the app.")
        }
    }

    // MARK: - Audio Cues Section

    private var audioCuesSection: some View {
        Section {
            // Master toggle
            Toggle(isOn: $audioCueService.soundEffectsEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2.fill")
            }
            .tint(.green)

            if audioCueService.soundEffectsEnabled {
                // Goal Reached
                Toggle(isOn: $audioCueService.goalReachedAudioEnabled) {
                    Text("Goal Reached")
                }
                .tint(.green)

                // Step Milestones
                Toggle(isOn: $audioCueService.stepMilestonesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Step Milestones")
                        Text("Every 1,000 steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)

                // Duck Music
                Toggle(isOn: $audioCueService.duckMusicEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duck Music During Cues")
                        Text("Lowers music volume when playing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
            }
        } header: {
            Label("Audio Cues", systemImage: "waveform")
        } footer: {
            Text("Hear sounds when you hit milestones.")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            // Permission status row
            HStack {
                Label("Notifications", systemImage: "bell.fill")
                Spacer()
                if viewModel.notificationsAuthorized {
                    HStack(spacing: 4) {
                        Text("Enabled")
                            .foregroundStyle(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                } else {
                    HStack(spacing: 8) {
                        Text("Disabled")
                            .foregroundStyle(.secondary)
                        Button {
                            openNotificationSettings()
                        } label: {
                            HStack(spacing: 2) {
                                Text("Enable")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.teal)
                            .font(.subheadline.bold())
                        }
                    }
                    .font(.subheadline)
                }
            }

            // Type toggles (only show if notifications enabled)
            if viewModel.notificationsAuthorized {
                Toggle("Streak at risk reminders", isOn: $viewModel.notifStreakAtRisk)
                    .tint(.teal)
                    .onChange(of: viewModel.notifStreakAtRisk) { _, _ in
                        viewModel.saveNotificationPreferences()
                    }

                // Reminder Time picker (only when streak reminders enabled)
                if viewModel.notifStreakAtRisk {
                    DatePicker(
                        "Reminder Time",
                        selection: reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderTimeInterval) { _, _ in
                        NotificationManager.shared.rescheduleStreakReminders()
                    }
                }

                Toggle("Goal celebrations", isOn: $viewModel.notifGoalCelebrations)
                    .tint(.teal)
                    .onChange(of: viewModel.notifGoalCelebrations) { _, _ in
                        viewModel.saveNotificationPreferences()
                    }

                Toggle("Milestone alerts", isOn: $viewModel.notifMilestones)
                    .tint(.teal)
                    .onChange(of: viewModel.notifMilestones) { _, _ in
                        viewModel.saveNotificationPreferences()
                    }
            }
        } header: {
            Label("Notifications", systemImage: "bell.badge.fill")
        } footer: {
            Text("Choose which notifications you'd like to receive.")
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Haptics Section

    private var feedbackSection: some View {
        Section {
            // Master toggle
            Toggle(isOn: $hapticService.hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
            }
            .tint(.green)

            if hapticService.hapticsEnabled {
                // Goal Reached
                Toggle(isOn: $hapticService.goalReachedHapticsEnabled) {
                    Text("Goal Reached")
                }
                .tint(.green)

                // Step Milestones
                Toggle(isOn: $hapticService.milestoneHapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Step Milestones")
                        Text("Every 1,000 steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
            }
        } header: {
            Label("Haptics", systemImage: "waveform")
        } footer: {
            Text("Feel a tap when you hit milestones.")
        }
    }

    // MARK: - Live Activity Section

    private var liveActivitySection: some View {
        Section {
            Toggle(isOn: $liveActivityEnabled) {
                Label("Lock Screen & Dynamic Island", systemImage: "lock.fill")
            }
            .tint(.green)

            if liveActivityEnabled {
                // Info about what Live Activity shows
                VStack(alignment: .leading, spacing: 8) {
                    SettingsFeatureRow(icon: "timer", text: "Countdown timer for each phase")
                    SettingsFeatureRow(icon: "chart.bar.fill", text: "Progress bar visualization")
                    SettingsFeatureRow(icon: "figure.walk", text: "Real-time step count")
                    SettingsFeatureRow(icon: "arrow.right.circle", text: "Next phase preview")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            }
        } header: {
            Label("Live Activity", systemImage: "platter.filled.top.and.arrow.up.iphone")
        } footer: {
            Text("Shows your Power Walk progress on the lock screen and Dynamic Island during sessions.")
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        Section {
            // HealthKit / Step Tracking status
            HStack {
                Label("Step Tracking", systemImage: "heart.fill")
                Spacer()
                if viewModel.healthKitAuthorized {
                    HStack(spacing: 4) {
                        Text("Enabled")
                            .foregroundStyle(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                } else if viewModel.healthKitDenied {
                    HStack(spacing: 8) {
                        Text("Not Enabled")
                            .foregroundStyle(.orange)
                        Button {
                            openHealthSettings()
                        } label: {
                            HStack(spacing: 2) {
                                Text("Fix")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.teal)
                            .font(.subheadline.bold())
                        }
                    }
                    .font(.subheadline)
                } else {
                    Button("Enable") {
                        Task {
                            await viewModel.requestHealthKitPermission()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.teal)
                }
            }

            // Motion & Fitness status
            HStack {
                Label("Motion & Fitness", systemImage: "figure.walk")
                Spacer()
                if viewModel.motionAuthorized {
                    HStack(spacing: 4) {
                        Text("Enabled")
                            .foregroundStyle(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                } else {
                    HStack(spacing: 8) {
                        Text("Not Enabled")
                            .foregroundStyle(.orange)
                        Button {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Text("Fix")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.teal)
                            .font(.subheadline.bold())
                        }
                    }
                    .font(.subheadline)
                }
            }

            // Location status
            HStack {
                Label("Location", systemImage: "location.fill")
                Spacer()
                if locationManager.isAuthorized {
                    HStack(spacing: 4) {
                        Text("Enabled")
                            .foregroundStyle(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                } else if locationManager.isDenied {
                    HStack(spacing: 8) {
                        Text("Not Enabled")
                            .foregroundStyle(.orange)
                        Button {
                            locationManager.openSettings()
                        } label: {
                            HStack(spacing: 2) {
                                Text("Fix")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.teal)
                            .font(.subheadline.bold())
                        }
                    }
                    .font(.subheadline)
                } else {
                    Button("Enable") {
                        locationManager.requestWhenInUseAuthorization()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.teal)
                }
            }

        } header: {
            Label("Permissions", systemImage: "lock.shield.fill")
        } footer: {
            Text("Health access is required to read your step history.")
        }
    }

    private func openHealthSettings() {
        // Try to open Health app directly, fall back to Settings
        if let healthURL = URL(string: "x-apple-health://"),
           UIApplication.shared.canOpenURL(healthURL) {
            UIApplication.shared.open(healthURL)
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - iCloud Section

    private var iCloudSection: some View {
        Section {
            // Sync Status
            HStack {
                Text("Sync Status")
                Spacer()
                HStack(spacing: 4) {
                    iCloudStatusIcon
                    Text(iCloudStatusText)
                        .foregroundStyle(iCloudStatusColor)
                }
                .font(.subheadline)
            }

            // Sign in prompt (when not signed in)
            if cloudKit.syncStatus == .noAccount {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Sign in to iCloud")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Last Synced (only when synced)
            if cloudKit.syncStatus == .synced, let lastSync = cloudKit.lastSyncDate {
                HStack {
                    Text("Last synced")
                    Spacer()
                    Text(formatRelativeTime(lastSync))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            // Error message (if any)
            if let error = cloudKit.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Sync Now button (only when signed in)
            if cloudKit.syncStatus != .noAccount {
                Button {
                    cloudKit.forceSync()
                } label: {
                    HStack {
                        if cloudKit.syncStatus == .syncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Sync Now")
                    }
                }
                .disabled(cloudKit.syncStatus == .syncing)
            }
        } header: {
            Label("iCloud", systemImage: "icloud.fill")
        } footer: {
            if cloudKit.syncStatus == .noAccount {
                Text("Sign in to iCloud in device settings to sync your progress across devices.")
            } else {
                Text("Streak Shields and progress sync automatically across your devices.")
            }
        }
    }

    private var iCloudStatusText: String {
        switch cloudKit.syncStatus {
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .noAccount: return "Not Signed In"
        case .error: return "Error"
        case .idle: return "Ready"
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private var iCloudStatusIcon: some View {
        switch cloudKit.syncStatus {
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
                .controlSize(.mini)
        case .noAccount:
            Image(systemName: "icloud.slash.fill")
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .idle:
            Image(systemName: "icloud.fill")
                .foregroundStyle(.secondary)
        }
    }

    private var iCloudStatusColor: Color {
        switch cloudKit.syncStatus {
        case .synced: return .green
        case .syncing: return .secondary
        case .noAccount: return .orange
        case .error: return .red
        case .idle: return .secondary
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://example.com/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "https://example.com/terms")!) {
                HStack {
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("About", systemImage: "info.circle.fill")
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            Picker("App Theme", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("Appearance", systemImage: "circle.lefthalf.filled.righthalf.striped.horizontal")
        }
    }

    #if DEBUG
    // MARK: - Debug Section

    private var debugSection: some View {
        Section {
            Toggle("Override Pro Status", isOn: $debugProOverride)
                .tint(.purple)
                .onChange(of: debugProOverride) { _, newValue in
                    storeManager.debugOverridePro = newValue
                }
        } header: {
            Label("Debug", systemImage: "ladybug.fill")
        } footer: {
            Text("Bypasses all Pro feature gates for testing.")
        }
    }
    #endif

    // MARK: - Store (for Focus Mode Paywall)

    @EnvironmentObject var storeManager: StoreManager
    @State private var showFocusModePaywall = false
    @State private var showKitView = false
    
    // MARK: - Browse Kit Section (for Lifetime users)
    
    private var browseKitSection: some View {
        Section {
            NavigationLink {
                KitView()
            } label: {
                Label("Browse Kit", systemImage: "bag.fill")
            }
        } header: {
            Label("Gear Recommendations", systemImage: "sparkles")
        } footer: {
            Text("Your Focus Mode hides the Kit tab, but you can still browse gear here.")
        }
    }
}

// MARK: - Feature Row Helper

private struct SettingsFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(text)
        }
    }
}

#Preview {
    SettingsView()
}
