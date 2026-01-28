//
//  PowerWalkSettingsView.swift
//  Just Walk
//
//  Settings screen for Power Walk audio, haptic, and Live Activity preferences.
//  Provides focused control over Power Walk-specific options.
//

import SwiftUI

struct PowerWalkSettingsView: View {
    @ObservedObject private var audioCueService = AudioCueService.shared
    @ObservedObject private var hapticService = HapticService.shared
    @ObservedObject private var preferencesManager = PowerWalkPreferencesManager.shared
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true

    var body: some View {
        List {
            // Audio Section
            audioSection

            // Haptics Section
            hapticsSection

            // Live Activity Section
            liveActivitySection

            // Defaults Section
            defaultsSection
        }
        .navigationTitle("Power Walk Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section {
            settingsToggle(
                "Voice Guidance",
                icon: "speaker.wave.2.fill",
                description: "Announces phase changes",
                isOn: $audioCueService.voiceGuidanceEnabled
            )

            settingsToggle(
                "Countdown",
                icon: "timer",
                description: "\"3, 2, 1\" before transitions",
                isOn: $audioCueService.countdownEnabled
            )

            settingsToggle(
                "Sound Effects",
                icon: "music.note",
                description: "Chimes for phase changes",
                isOn: $audioCueService.soundEffectsEnabled
            )

            settingsToggle(
                "Duck Music",
                icon: "headphones",
                description: "Lower music volume during cues",
                isOn: $audioCueService.duckMusicEnabled
            )
        } header: {
            Text("Audio")
        }
    }

    // MARK: - Haptics Section

    private var hapticsSection: some View {
        Section {
            settingsToggle(
                "Phase Change Vibrations",
                icon: "waveform.path",
                description: "Feel transitions on your wrist",
                isOn: $hapticService.intervalHapticsEnabled
            )
        } header: {
            Text("Haptics")
        }
    }

    // MARK: - Live Activity Section

    private var liveActivitySection: some View {
        Section {
            settingsToggle(
                "Lock Screen & Dynamic Island",
                icon: "iphone.badge.play",
                description: "See progress without unlocking",
                isOn: $liveActivityEnabled
            )
        } header: {
            Text("Live Activity")
        }
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        Section {
            // Duration picker
            VStack(alignment: .leading, spacing: 12) {
                Label("Default Duration", systemImage: "clock.fill")
                    .font(.body)

                Picker("Duration", selection: Binding(
                    get: { preferencesManager.defaultDurationMinutes },
                    set: { preferencesManager.setDefaultDurationMinutes($0) }
                )) {
                    ForEach(PowerWalkPreferencesManager.defaultDurationOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)

            // Preset picker
            NavigationLink {
                DefaultPresetPickerView()
            } label: {
                HStack {
                    Label("Default Preset", systemImage: "star.fill")
                    Spacer()
                    Text(preferencesManager.defaultPreset.name)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Defaults")
        }
    }

    // MARK: - Helper View

    private func settingsToggle(
        _ title: String,
        icon: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: icon)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color(hex: "00C7BE"))
        .onChange(of: isOn.wrappedValue) { _, _ in
            HapticService.shared.playSelection()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PowerWalkSettingsView()
    }
}
