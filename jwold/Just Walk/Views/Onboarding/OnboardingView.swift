//
//  OnboardingView.swift
//  Just Walk
//
//  Permission Prime: Premium first-run onboarding experience.
//  Builds trust and explains value before triggering system permission popups.
//
//  Design Philosophy: Premium, Friendly, Trustworthy
//  Uses Just Walk Design System tokens exclusively.
//

import SwiftUI

/// Premium single-screen onboarding that maximizes permission conversion.
struct OnboardingView: View {

    // MARK: - Properties

    /// Completion handler called when onboarding is finished
    let onComplete: () -> Void

    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isAnimating = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            JWDesign.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero Section
                heroSection

                Spacer()
                    .frame(height: JWDesign.Spacing.xxxl)

                // Value Props Section
                valuePropsSection

                Spacer()

                // CTA Section
                ctaSection
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)
            .padding(.bottom, JWDesign.Spacing.xxl)
        }
        .onAppear {
            withAnimation(JWDesign.Animation.smooth) {
                isAnimating = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            // Animated hero icon
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 80))
                .foregroundStyle(JWDesign.Gradients.brand)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                .opacity(isAnimating ? 1 : 0)
                .scaleEffect(isAnimating ? 1 : 0.8)

            // Title
            Text("Just Walk")
                .font(JWDesign.Typography.displayMedium)
                .foregroundStyle(.primary)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 10)

            // Tagline
            Text("Your steps. Your privacy.")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 10)
        }
        .animation(JWDesign.Animation.smooth.delay(0.1), value: isAnimating)
    }

    // MARK: - Value Props Section

    private var valuePropsSection: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            ValuePropRow(
                icon: "heart.fill",
                iconColor: .red,
                title: "Sync Your History",
                subtitle: "See your step history instantly"
            )
            .opacity(isAnimating ? 1 : 0)
            .offset(x: isAnimating ? 0 : -20)
            .animation(JWDesign.Animation.smooth.delay(0.2), value: isAnimating)

            ValuePropRow(
                icon: "iphone.gen3",
                iconColor: JWDesign.Colors.brandPrimary,
                title: "Live Step Counter",
                subtitle: "Real-time updates from your pocket"
            )
            .opacity(isAnimating ? 1 : 0)
            .offset(x: isAnimating ? 0 : -20)
            .animation(JWDesign.Animation.smooth.delay(0.3), value: isAnimating)

            ValuePropRow(
                icon: "bell.badge.fill",
                iconColor: JWDesign.Colors.warning,
                title: "Smart Reminders",
                subtitle: "Stay on track with streak alerts"
            )
            .opacity(isAnimating ? 1 : 0)
            .offset(x: isAnimating ? 0 : -20)
            .animation(JWDesign.Animation.smooth.delay(0.4), value: isAnimating)
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            // Primary CTA Button
            Button {
                HapticService.shared.playSelection()
                startOnboarding()
            } label: {
                HStack(spacing: JWDesign.Spacing.sm) {
                    if permissionManager.isRequestingPermissions {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Start Walking")
                    }
                }
            }
            .buttonStyle(JWGradientButtonStyle())
            .disabled(permissionManager.isRequestingPermissions)
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 20)
            .animation(JWDesign.Animation.smooth.delay(0.5), value: isAnimating)

            // Privacy note
            Text("Your data stays on your device. We never sell or share your health information.")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(isAnimating ? 1 : 0)
                .animation(JWDesign.Animation.smooth.delay(0.6), value: isAnimating)
        }
    }

    // MARK: - Actions

    private func startOnboarding() {
        Task {
            // Request all permissions
            await permissionManager.requestAllPermissions()

            // Complete onboarding regardless of permission outcomes
            // App gracefully degrades if permissions denied
            await MainActor.run {
                HapticService.shared.playSuccess()
                onComplete()
            }
        }
    }
}

// MARK: - Value Prop Row Component

private struct ValuePropRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: JWDesign.Spacing.lg) {
            // Icon in circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: JWDesign.IconSize.large))
                    .foregroundStyle(iconColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                Text(title)
                    .font(JWDesign.Typography.bodyBold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(JWDesign.Spacing.cardPadding)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView {
        print("Onboarding complete!")
    }
}

#Preview("Onboarding - Dark") {
    OnboardingView {
        print("Onboarding complete!")
    }
    .preferredColorScheme(.dark)
}
