//
//  YoureReadyView.swift
//  JustWalk
//
//  Screen 6: Completion — "You're ready, [Name]." with animated checkmark
//

import SwiftUI

struct YoureReadyView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var circleTrim: CGFloat = 0
    @State private var checkTrim: CGFloat = 0
    @State private var glowRadius: CGFloat = 0
    @State private var showHeadline = false
    @State private var showTagline = false
    @State private var showButton = false

    private var displayName: String {
        let name = PersistenceManager.shared.loadProfile().displayName
        return name.isEmpty ? "Walker" : name
    }

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Animated checkmark
            ZStack {
                // Glow
                Circle()
                    .fill(JW.Color.accent.opacity(0.2))
                    .frame(width: 120 + glowRadius, height: 120 + glowRadius)
                    .blur(radius: 20)

                // Circle outline draws in
                Circle()
                    .trim(from: 0, to: circleTrim)
                    .stroke(JW.Color.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                // Checkmark draws in
                CheckmarkPath()
                    .trim(from: 0, to: checkTrim)
                    .stroke(JW.Color.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 44)
            }
            .frame(width: 160, height: 160)

            // Headline
            Text("You're ready, \(displayName).")
                .font(JW.Font.title1)
                .foregroundStyle(JW.Color.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(showHeadline ? 1 : 0)
                .offset(y: showHeadline ? 0 : 20)

            // Tagline
            Text("Build a healthy habit,\none step at a time.")
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(showTagline ? 1 : 0)
                .offset(y: showTagline ? 0 : 15)

            Spacer()

            // Start Walking button — extra presence for celebration
            Button(action: {
                JustWalkHaptics.success()
                onComplete()
            }) {
                Text("Start Walking")
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .shadow(color: JW.Color.accent.opacity(showButton ? 0.4 : 0), radius: 10, y: 4)
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        // Circle draws
        withAnimation(.easeOut(duration: quick ? 0.3 : 0.7).delay(quick ? 0 : 0.2)) {
            circleTrim = 1
        }

        // Checkmark draws after circle
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.4).delay(quick ? 0.1 : 0.8)) {
            checkTrim = 1
        }

        // Success haptic fires when checkmark completes
        DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0.2 : 1.0)) {
            JustWalkHaptics.success()
        }

        // Glow expands after checkmark
        if !quick {
            withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
                glowRadius = 40
            }
        }

        // Text
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0.2 : 1.2)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0.2 : 1.5)) { showTagline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0.3 : 1.8)) { showButton = true }
    }
}

// MARK: - Checkmark Path

private struct CheckmarkPath: Shape {
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
        YoureReadyView(onComplete: {})
    }
}
