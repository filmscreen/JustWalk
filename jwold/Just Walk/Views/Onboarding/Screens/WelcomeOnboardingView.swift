//
//  WelcomeOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI

struct WelcomeOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var opacity = 0.0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating)

            Text("Just Walk")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Walk more. Feel better.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text("The simple way to build a healthier you,\none step at a time.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: { coordinator.next() }) {
                Text("Get Started")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) { opacity = 1.0 }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WelcomeOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
