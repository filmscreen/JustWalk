//
//  WatchStepRingView.swift
//  JustWalkWatch Watch App
//
//  Circular step progress ring adapted for watchOS
//

import SwiftUI

struct WatchStepRingView: View {
    let steps: Int
    let goal: Int
    var size: CGFloat = 100

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1.0)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    // Brand green palette (emerald → accent → bright mint)
    private static let ringStart    = Color(red: 0x20/255, green: 0xA0/255, blue: 0x80/255)
    private static let accentGreen  = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    private static let ringEnd      = Color(red: 0x86/255, green: 0xEF/255, blue: 0xAC/255)

    private var ringGradient: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Self.ringStart,    location: 0.0),
                .init(color: Self.accentGreen,  location: 0.35),
                .init(color: Self.ringEnd,      location: 0.7),
                .init(color: Self.ringStart,    location: 1.0)
            ],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    private var lineWidth: CGFloat {
        size * 0.1
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progress >= 1.0
                        ? AnyShapeStyle(Self.accentGreen)
                        : AnyShapeStyle(ringGradient),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(steps)")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .minimumScaleFactor(0.5)

                Text("steps")
                    .font(.system(size: size * 0.09))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps.formatted()) steps")
        .accessibilityValue("\(progressPercent)% of \(goal.formatted()) step goal\(progress >= 1.0 ? ", goal complete" : "")")
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: steps) { _, _ in
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    animatedProgress = progress
                }
            }
        }
    }
}

#Preview {
    WatchStepRingView(steps: 3500, goal: 5000)
}
