//
//  PostMealSetupView.swift
//  Just Walk
//
//  Setup screen for the Post-Meal Walk. Dead simple — shows info
//  about the 10-minute walk and a Start button. No configuration needed.
//

import SwiftUI

struct PostMealSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hasSeenPostMealEducation") private var hasSeenEducation = false
    @State private var showEducation = false
    @State private var showCountdown = false

    let onStartWalk: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                JWDesign.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "34C759").opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(hex: "34C759"))
                    }

                    // Title + description
                    VStack(spacing: JWDesign.Spacing.sm) {
                        Text("Post-Meal Walk")
                            .font(.title2.bold())
                            .padding(.top, JWDesign.Spacing.lg)

                        Text("A 10-minute walk after eating helps regulate blood sugar and aids digestion.")
                            .font(JWDesign.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, JWDesign.Spacing.xxl)
                    }

                    // Duration display
                    VStack(spacing: 4) {
                        Text("10")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("min")
                            .font(JWDesign.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 100, height: 100)
                    .background(JWDesign.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.large))
                    .padding(.top, JWDesign.Spacing.xxxl)

                    // Reassurance text
                    Text("No special pace needed. Just walk.")
                        .font(JWDesign.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, JWDesign.Spacing.lg)

                    Spacer()

                    // Start button
                    Button {
                        HapticService.shared.playSelection()
                        onStartWalk()
                    } label: {
                        Text("Start Walk")
                    }
                    .buttonStyle(JWPrimaryButtonStyle(color: Color(hex: "34C759")))
                    .padding(.horizontal, JWDesign.Spacing.xl)

                    // Always free indicator
                    Text("Always free")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, JWDesign.Spacing.sm)
                        .padding(.bottom, JWDesign.Spacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEducation = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            if !hasSeenEducation {
                try? await Task.sleep(nanoseconds: 500_000_000)
                showEducation = true
            }
        }
        .sheet(isPresented: $showEducation) {
            PostMealEducationSheet(
                onDismiss: {
                    hasSeenEducation = true
                    showEducation = false
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    PostMealSetupView(onStartWalk: {})
}
