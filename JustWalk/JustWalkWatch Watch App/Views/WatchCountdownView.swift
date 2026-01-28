//
//  WatchCountdownView.swift
//  JustWalkWatch Watch App
//
//  3-2-1-GO countdown overlay before interval walks start on Watch
//

import SwiftUI
import WatchKit

struct WatchCountdownView: View {
    let onComplete: () -> Void
    
    @State private var currentNumber: Int = 3
    @State private var isVisible = false
    @State private var ringProgress: CGFloat = 0
    @State private var isGo = false
    @State private var goScale: CGFloat = 0.5
    @State private var goOpacity: Double = 0
    
    private let device = WKInterfaceDevice.current()
    private let brandGreen = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    private let ringSize: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Countdown ring
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 6)
                .frame(width: ringSize, height: ringSize)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    isGo ? brandGreen : Color.white.opacity(0.6),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
            
            // Number or GO
            Group {
                if isGo {
                    Text("GO!")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(brandGreen)
                        .scaleEffect(goScale)
                        .opacity(goOpacity)
                } else {
                    Text("\(currentNumber)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .opacity(isVisible ? 1 : 0)
                        .scaleEffect(isVisible ? 1 : 0.5)
                }
            }
        }
        .onAppear {
            startCountdown()
        }
    }
    
    private func startCountdown() {
        animateNumber(3)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animateNumber(2)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            animateNumber(1)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            animateGo()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            onComplete()
        }
    }
    
    private func animateNumber(_ number: Int) {
        isVisible = false
        ringProgress = 0
        currentNumber = number
        isGo = false
        
        // Escalating haptic
        switch number {
        case 3: device.play(.click)
        case 2: device.play(.click)
        case 1: device.play(.directionUp)
        default: break
        }
        
        // Number appears
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            isVisible = true
        }
        
        // Ring fills
        withAnimation(.easeOut(duration: 0.8)) {
            ringProgress = 1.0
        }
    }
    
    private func animateGo() {
        isGo = true
        ringProgress = 0
        
        device.play(.success)
        
        withAnimation(.easeOut(duration: 0.8)) {
            ringProgress = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
            goScale = 1.0
            goOpacity = 1.0
        }
    }
}

#Preview {
    WatchCountdownView(onComplete: { print("Done!") })
}
