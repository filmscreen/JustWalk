//
//  PostMealSetupView.swift
//  JustWalk
//
//  Simple setup screen for the 10-minute post-meal walk.
//  No configuration needed — just info and a Start button.
//

import SwiftUI

struct PostMealSetupView: View {
    @AppStorage("hasSeenPostMealEducation") private var hasSeenPostMealEducation = false
    @State private var showEducation = false
    @State private var navigateToCountdown = false
    @Environment(\.dismiss) private var dismiss
    
    var onComplete: (() -> Void)? = nil

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: JW.Spacing.xl) {
                    // Header icon + title
                    VStack(spacing: JW.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(JW.Color.accentPurple.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "fork.knife")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(JW.Color.accentPurple)
                        }
                        .padding(.top, JW.Spacing.xl)

                        Text("Post-Meal Walk")
                            .font(JW.Font.largeTitle)
                            .foregroundStyle(JW.Color.textPrimary)

                        Text("A 10-minute walk after eating helps regulate blood sugar and aids digestion.")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, JW.Spacing.xl)
                    }

                    // Duration display
                    VStack(spacing: JW.Spacing.sm) {
                        Text("10")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(JW.Color.textPrimary)

                        Text("min")
                            .font(JW.Font.title3)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                    .frame(width: 120, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: JW.Radius.xl)
                            .fill(JW.Color.backgroundCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: JW.Radius.xl)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                    // Reassurance
                    HStack(spacing: JW.Spacing.sm) {
                        Image(systemName: "figure.walk")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textTertiary)
                        Text("No special pace needed. Just walk.")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }

                    Spacer(minLength: 120)
                }
            }

            // Bottom: Start button
            VStack {
                Spacer()

                VStack(spacing: JW.Spacing.md) {
                    Button(action: handleStartTap) {
                        Text("Start Walk")
                            .font(JW.Font.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(JW.Color.accent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                    }
                    .buttonPressEffect()
                }
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showEducation = true }) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showEducation) {
            PostMealEducationSheet {
                hasSeenPostMealEducation = true
                showEducation = false
            }
        }
        .navigationDestination(isPresented: $navigateToCountdown) {
            PostMealCountdownView {
                // First call the completion handler to reset state in parent
                onComplete?()
                // Then dismiss this view
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func handleStartTap() {
        JustWalkHaptics.buttonTap()
        navigateToCountdown = true
    }
}

#Preview {
    NavigationStack {
        PostMealSetupView()
    }
}

// MARK: - Post-Meal Education Sheet

struct PostMealEducationSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        EducationSheetTemplate(
            icon: "fork.knife",
            iconColor: JW.Color.streak,
            title: "How Post-Meal Walks Work",
            message: "A 10-minute walk after eating can reduce blood sugar spikes by up to 30%.\n\nBest within 30 minutes of a meal. No special pace needed — just walk.",
            onContinue: onDismiss
        )
    }
}
