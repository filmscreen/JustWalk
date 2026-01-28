//
//  WhyWeNeedAccessSheet.swift
//  Just Walk
//
//  Explains why the app needs HealthKit access.
//

import SwiftUI

struct WhyWeNeedAccessSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: JWDesign.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)

                        Text("Why We Need Access")
                            .font(.title2.bold())
                    }
                    .padding(.bottom, JWDesign.Spacing.sm)

                    // What we read
                    VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
                        Label("What We Read", systemImage: "eye.fill")
                            .font(JWDesign.Typography.headlineBold)
                            .foregroundStyle(.teal)

                        BulletPoint(text: "Step count from your iPhone and Apple Watch")
                        BulletPoint(text: "Walking distance")
                        BulletPoint(text: "Workout history for interval walking sessions")
                    }

                    Divider()
                        .padding(.vertical, JWDesign.Spacing.sm)

                    // What we DON'T access
                    VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
                        Label("What We Don't Access", systemImage: "lock.shield.fill")
                            .font(JWDesign.Typography.headlineBold)
                            .foregroundStyle(.green)

                        BulletPoint(text: "Heart rate or health vitals", icon: "xmark")
                        BulletPoint(text: "Sleep data", icon: "xmark")
                        BulletPoint(text: "Medical records or medications", icon: "xmark")
                        BulletPoint(text: "Any other personal health information", icon: "xmark")
                    }

                    Divider()
                        .padding(.vertical, JWDesign.Spacing.sm)

                    // Privacy note
                    VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
                        Label("Your Privacy", systemImage: "hand.raised.fill")
                            .font(JWDesign.Typography.headlineBold)
                            .foregroundStyle(.blue)

                        Text("Your step data stays on your device and in your iCloud. We never upload your health data to external servers or share it with third parties.")
                            .font(JWDesign.Typography.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: JWDesign.Spacing.xl)
                }
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                .padding(.top, JWDesign.Spacing.lg)
            }
            .navigationTitle("Health Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Bullet Point

private struct BulletPoint: View {
    let text: String
    var icon: String = "checkmark"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(icon == "checkmark" ? .teal : .secondary)
                .frame(width: 16)

            Text(text)
                .font(JWDesign.Typography.body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    WhyWeNeedAccessSheet()
}
