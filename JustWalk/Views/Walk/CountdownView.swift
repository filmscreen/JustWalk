//
//  CountdownView.swift
//  JustWalk
//
//  3-2-1-GO countdown overlay before walks start
//

import SwiftUI

struct CountdownView: View {
    let onComplete: () -> Void
    
    @State private var currentNumber: Int = 3
    @State private var isVisible = false
    @State private var ringProgress: CGFloat = 0
    @State private var isGo = false
    @State private var goScale: CGFloat = 0.5
    @State private var goOpacity: Double = 0
    
    private let ringSize: CGFloat = 200
    
    var body: some View {
        ZStack {
            // Background with hero gradient
            JW.Color.heroGradient
                .ignoresSafeArea()
            
            // Countdown ring
            Circle()
                .stroke(JW.Color.backgroundCard, lineWidth: 8)
                .frame(width: ringSize, height: ringSize)
            
            // Progress ring (fills during each second)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    isGo ? JW.Color.accent : JW.Color.textSecondary,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
            
            // Number or GO
            Group {
                if isGo {
                    VStack(spacing: JW.Spacing.xs) {
                        Text("GO!")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(JW.Color.accent)
                        
                        Text("Let's do this")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                    .scaleEffect(goScale)
                    .opacity(goOpacity)
                } else {
                    Text("\(currentNumber)")
                        .font(.system(size: 100, weight: .black, design: .rounded))
                        .foregroundStyle(JW.Color.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .opacity(isVisible ? 1 : 0)
                        .scaleEffect(isVisible ? 1 : 0.5)
                }
            }
        }
        .onAppear {
            HapticsManager.shared.prepare()
            startCountdown()
        }
    }
    
    private func startCountdown() {
        // 3
        animateNumber(3)
        
        // 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animateNumber(2)
        }
        
        // 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            animateNumber(1)
        }
        
        // GO
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            animateGo()
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            onComplete()
        }
    }
    
    private func animateNumber(_ number: Int) {
        // Reset states
        isVisible = false
        ringProgress = 0
        currentNumber = number
        isGo = false
        
        // Escalating haptic
        switch number {
        case 3: HapticsManager.shared.buttonTap()
        case 2: HapticsManager.shared.intervalPhaseChange()
        case 1: HapticsManager.shared.intervalSpeedUp()
        default: break
        }
        
        // Number appears with emphasis spring
        withAnimation(JustWalkAnimation.emphasis) {
            isVisible = true
        }
        
        // Ring fills over ~0.8 seconds
        withAnimation(JustWalkAnimation.ringFill) {
            ringProgress = 1.0
        }
    }
    
    private func animateGo() {
        isGo = true
        ringProgress = 0
        
        // Strong haptic for GO
        HapticsManager.shared.success()
        
        // Ring fills with accent color
        withAnimation(JustWalkAnimation.ringFill) {
            ringProgress = 1.0
        }
        
        // GO appears with celebration bounce
        withAnimation(JustWalkAnimation.celebration) {
            goScale = 1.0
            goOpacity = 1.0
        }
    }
}

#Preview {
    CountdownView(onComplete: { print("Done!") })
}
