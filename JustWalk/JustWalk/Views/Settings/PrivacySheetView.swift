//
//  PrivacySheetView.swift
//  JustWalk
//
//  Simple, reassuring privacy summary.
//

import SwiftUI

struct PrivacySheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.lg) {
                    VStack(spacing: JW.Spacing.md) {
                        Text("Your data stays yours")
                            .font(JW.Font.title2)
                            .foregroundStyle(JW.Color.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            labelRow("Stored on your device")
                            labelRow("Optional iCloud sync (your account)")
                            labelRow("No analytics or tracking")
                            labelRow("No ads")
                            labelRow("No account required")
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("We never see your steps, walks, or streaks.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let url = URL(string: "https://getjustwalk.com/privacy") {
                        Link(destination: url) {
                            Text("Privacy Policy")
                                .font(JW.Font.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(JW.Color.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                        }
                    }
                }
                .padding(JW.Spacing.xl)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Privacy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func labelRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(JW.Color.accent)
            Text(text)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textPrimary)
            Spacer()
        }
    }
}

#Preview {
    PrivacySheetView()
}
