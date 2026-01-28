//
//  SavePresetSheet.swift
//  Just Walk
//
//  Sheet for saving custom interval configurations as presets.
//  Includes name entry and validation feedback.
//

import SwiftUI

/// Sheet for saving a custom preset
struct SavePresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: IntervalEditorViewModel
    @State private var presetName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: JWDesign.Spacing.lg) {
                // Icon
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(JWDesign.Colors.brandSecondary)
                    .padding(.top, JWDesign.Spacing.lg)

                // Title
                VStack(spacing: JWDesign.Spacing.xs) {
                    Text("Save Custom Preset")
                        .font(JWDesign.Typography.displaySmall)
                        .foregroundStyle(.primary)

                    Text("Give your interval configuration a name")
                        .font(JWDesign.Typography.body)
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                }

                // Configuration summary
                HStack(spacing: JWDesign.Spacing.sm) {
                    Text(viewModel.easyDurationFormatted)
                        .foregroundStyle(JWDesign.Colors.success)
                    Text("/")
                        .foregroundStyle(Color(.secondaryLabel))
                    Text(viewModel.briskDurationFormatted)
                        .foregroundStyle(JWDesign.Colors.brandSecondary)
                    Text("×")
                        .foregroundStyle(Color(.secondaryLabel))
                    Text("\(viewModel.numberOfIntervals) intervals")
                        .foregroundStyle(.primary)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(JWDesign.Spacing.sm)
                .background(JWDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.small))

                // Name input
                VStack(alignment: .leading, spacing: JWDesign.Spacing.xs) {
                    Text("Preset Name")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(Color(.secondaryLabel))

                    TextField("e.g., My Quick Burn", text: $presetName)
                        .textFieldStyle(.plain)
                        .font(JWDesign.Typography.body)
                        .padding(JWDesign.Spacing.md)
                        .background(JWDesign.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: JWDesign.Radius.small)
                                .stroke(
                                    validationBorderColor,
                                    lineWidth: isNameFieldFocused ? 2 : 1
                                )
                        )
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            attemptSave()
                        }

                    // Validation error or count
                    HStack {
                        if let error = viewModel.validationError,
                           case .emptyName = error {
                            Text(error.localizedDescription)
                                .font(JWDesign.Typography.caption)
                                .foregroundStyle(JWDesign.Colors.error)
                        } else if let error = viewModel.validationError,
                                  case .duplicateName = error {
                            Text(error.localizedDescription)
                                .font(JWDesign.Typography.caption)
                                .foregroundStyle(JWDesign.Colors.error)
                        } else {
                            Text("\(viewModel.customPresets.count) of 5 custom presets used")
                                .font(JWDesign.Typography.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, JWDesign.Spacing.md)

                Spacer()

                // Save button
                Button {
                    attemptSave()
                } label: {
                    Text("Save Preset")
                        .font(JWDesign.Typography.headlineBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JWDesign.Spacing.md)
                }
                .buttonStyle(JWGradientButtonStyle())
                .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .padding(.horizontal, JWDesign.Spacing.md)
                .padding(.bottom, JWDesign.Spacing.md)
            }
            .background(JWDesign.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var validationBorderColor: Color {
        if let error = viewModel.validationError {
            switch error {
            case .emptyName, .duplicateName:
                return JWDesign.Colors.error
            default:
                return Color(.separator)
            }
        }
        return isNameFieldFocused ? JWDesign.Colors.brandSecondary : Color(.separator)
    }

    private func attemptSave() {
        if viewModel.saveAsPreset(name: presetName) {
            onSave()
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Save Preset Sheet") {
    SavePresetSheet(
        viewModel: IntervalEditorViewModel()
    ) {
        print("Saved!")
    }
}
