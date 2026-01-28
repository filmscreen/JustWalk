//
//  QuickSetupView.swift
//  JustWalk
//
//  Screen 4: Quick Setup — name input + permissions in one scrollable screen
//

import SwiftUI
import CoreMotion

struct QuickSetupView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var nameText: String = ""
    @FocusState private var isNameFieldFocused: Bool

    @State private var healthGranted = false
    @State private var motionGranted = false

    @State private var appeared = false
    @State private var showPermissions = false

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedName.isEmpty
    }

    private var anyPermissionGranted: Bool {
        healthGranted || motionGranted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: JW.Spacing.xxl) {
                // Header
                VStack(spacing: JW.Spacing.md) {
                    Text("Quick Setup")
                        .font(JW.Font.title1)
                        .foregroundStyle(JW.Color.textPrimary)

                    Text("Just a couple of things before we start.")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, JW.Spacing.xxxl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Name section
                VStack(spacing: JW.Spacing.md) {
                    Text("What should we call you?")
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    VStack(spacing: 0) {
                        TextField("Your first name", text: $nameText)
                            .font(JW.Font.title2)
                            .multilineTextAlignment(.center)
                            .focused($isNameFieldFocused)
                            .submitLabel(.continue)
                            .onSubmit { saveNameAndContinue() }

                        Rectangle()
                            .fill(isNameFieldFocused ? JW.Color.accent : Color.white.opacity(0.3))
                            .frame(height: 1)
                            .padding(.top, JW.Spacing.sm)
                            .animation(.easeInOut(duration: 0.2), value: isNameFieldFocused)
                    }
                    .padding(.horizontal, JW.Spacing.xxxl)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Permission rows — appear after name is entered
                if showPermissions {
                    VStack(spacing: JW.Spacing.lg) {
                        Text("Permissions")
                            .font(JW.Font.headline)
                            .foregroundStyle(JW.Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        SetupPermissionRow(
                            icon: "heart.fill",
                            title: "Health Data",
                            description: "To count your steps and set goals",
                            isGranted: healthGranted,
                            onRequest: {
                                Task {
                                    healthGranted = await HealthKitManager.shared.requestAuthorization()
                                }
                            }
                        )

                        SetupPermissionRow(
                            icon: "figure.walk.motion",
                            title: "Motion & Fitness",
                            description: "To detect walks automatically",
                            isGranted: motionGranted,
                            onRequest: { requestMotionAuthorization() }
                        )
                    }
                    .padding(.horizontal, JW.Spacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: JW.Spacing.xxl)

                // Buttons
                VStack(spacing: JW.Spacing.md) {
                    Button(action: { saveNameAndContinue() }) {
                        Text("Continue")
                            .font(JW.Font.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canContinue ? JW.Color.accent : JW.Color.accent.opacity(0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                    }
                    .buttonPressEffect()
                    .disabled(!canContinue)

                    Button(action: {
                        JustWalkHaptics.buttonTap()
                        onContinue()
                    }) {
                        Text("Skip for Now")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                }
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.5)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isNameFieldFocused = true
            }
        }
        .onChange(of: trimmedName) { _, newValue in
            let shouldShow = !newValue.isEmpty
            if shouldShow != showPermissions {
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : JustWalkAnimation.presentation) {
                    showPermissions = shouldShow
                }
            }
        }
    }

    // MARK: - Actions

    private func saveNameAndContinue() {
        guard canContinue else { return }
        var profile = PersistenceManager.shared.loadProfile()
        profile.displayName = trimmedName
        PersistenceManager.shared.saveProfile(profile)
        JustWalkHaptics.buttonTap()
        onContinue()
    }

    private func requestMotionAuthorization() {
        let manager = CMMotionActivityManager()
        let now = Date()
        manager.queryActivityStarting(from: now, to: now, to: .main) { _, error in
            if let error = error as? NSError,
               error.domain == CMErrorDomain,
               error.code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
                motionGranted = false
            } else {
                motionGranted = true
            }
        }
    }
}

// MARK: - Setup Permission Row

private struct SetupPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    @State private var checkmarkTrim: CGFloat = 0

    var body: some View {
        HStack(spacing: JW.Spacing.lg) {
            Image(systemName: icon)
                .font(JW.Font.title2)
                .foregroundStyle(JW.Color.accent)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)
                Text(description)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            if isGranted {
                // Animated checkmark via trim
                ZStack {
                    Circle()
                        .fill(JW.Color.success)
                        .frame(width: 28, height: 28)

                    CheckmarkShape()
                        .trim(from: 0, to: checkmarkTrim)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 14, height: 14)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                        checkmarkTrim = 1
                    }
                }
            } else {
                Button("Allow") { onRequest() }
                    .buttonStyle(.bordered)
                    .tint(JW.Color.accent)
            }
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
    }
}

// MARK: - Checkmark Shape

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        QuickSetupView(onContinue: {})
    }
}
