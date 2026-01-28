//
//  DefaultPresetPickerView.swift
//  Just Walk
//
//  Picker for selecting the default Power Walk preset.
//  Shows built-in presets and any custom presets the user has created.
//

import SwiftUI

struct DefaultPresetPickerView: View {
    @ObservedObject private var preferencesManager = PowerWalkPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Built-in presets
            Section {
                ForEach(PowerWalkPreset.allPresets) { preset in
                    presetRow(preset)
                }
            } header: {
                Text("Built-in Presets")
            }

            // Custom presets (if any)
            if !preferencesManager.customPresets.isEmpty {
                Section {
                    ForEach(preferencesManager.customPresets) { preset in
                        presetRow(preset)
                    }
                } header: {
                    Text("Your Presets")
                }
            }
        }
        .navigationTitle("Default Preset")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Preset Row

    private func presetRow(_ preset: PowerWalkPreset) -> some View {
        Button {
            preferencesManager.setDefaultPreset(preset)
            HapticService.shared.playSelection()
            dismiss()
        } label: {
            HStack {
                // Preset icon
                Image(systemName: preset.icon)
                    .foregroundStyle(Color(hex: "00C7BE"))
                    .frame(width: 24)

                // Preset name and durations
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .foregroundStyle(.primary)
                    Text(preset.formattedDurations)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Checkmark for selected preset
                if preferencesManager.defaultPreset.id == preset.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(hex: "00C7BE"))
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DefaultPresetPickerView()
    }
}
