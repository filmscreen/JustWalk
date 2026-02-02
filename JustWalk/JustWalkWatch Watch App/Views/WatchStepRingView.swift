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
    var streak: Int = 0
    var shields: Int = 0
    var calories: Int = 0
    var calorieGoal: Int? = nil
    var size: CGFloat = 100

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1.0)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    /// Formatted calorie text based on goal
    private var calorieText: String {
        if let goal = calorieGoal, goal > 0 {
            let diff = goal - calories
            if diff > 0 {
                return "\(diff) left"
            } else if diff < 0 {
                return "\(abs(diff)) over"
            } else {
                return "On target"
            }
        } else {
            return "\(calories) cal"
        }
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
        size * 0.08
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

            VStack(spacing: 1) {
                // Step count
                Text("\(steps)")
                    .font(.system(size: size * 0.20, weight: .bold))
                    .minimumScaleFactor(0.5)

                Text("steps")
                    .font(.system(size: size * 0.08))
                    .foregroundStyle(.secondary)

                // Streak and Shields row
                HStack(spacing: size * 0.06) {
                    // Streak
                    HStack(spacing: 2) {
                        Image(systemName: streak > 0 ? "flame.fill" : "flame")
                            .font(.system(size: size * 0.08))
                            .foregroundStyle(.orange)
                        Text("\(streak)")
                            .font(.system(size: size * 0.08, weight: .semibold))
                    }

                    // Shields
                    HStack(spacing: 2) {
                        Image(systemName: shields > 0 ? "shield.fill" : "shield")
                            .font(.system(size: size * 0.08))
                            .foregroundStyle(.blue)
                        Text("\(shields)")
                            .font(.system(size: size * 0.08, weight: .semibold))
                    }
                }
                .padding(.top, 4)

                // Calories row
                HStack(spacing: 2) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: size * 0.07))
                        .foregroundStyle(Self.accentGreen)
                    Text(calorieText)
                        .font(.system(size: size * 0.07, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, size * 0.08)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps.formatted()) steps, \(streak) day streak, \(shields) shields, \(calorieText)")
        .accessibilityValue("\(progressPercent)% of \(goal.formatted()) daily goal\(progress >= 1.0 ? ", goal complete" : "")")
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
    WatchStepRingView(
        steps: 3500,
        goal: 5000,
        streak: 12,
        shields: 2,
        calories: 1850,
        calorieGoal: 2000
    )
}
