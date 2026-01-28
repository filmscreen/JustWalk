//
//  CoachingTip.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation

/// AI Coaching tip categories
enum CoachingCategory: String, Codable, CaseIterable {
    case motivation = "Motivation"
    case technique = "Technique"
    case progress = "Progress"
    case health = "Health"
    case iwt = "IWT Tips"
    case milestone = "Milestone"
}

/// Represents an AI coaching tip or feedback
struct CoachingTip: Identifiable, Codable {
    let id: UUID
    let category: CoachingCategory
    let title: String
    let message: String
    let icon: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        category: CoachingCategory,
        title: String,
        message: String,
        icon: String = "figure.walk",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.icon = icon
        self.timestamp = timestamp
    }
}

/// Coaching tip templates for different scenarios
struct CoachingTipTemplates {

    // MARK: - Motivation Tips
    static let motivationTips: [CoachingTip] = [
        CoachingTip(
            category: .motivation,
            title: "Keep Moving!",
            message: "Every step counts toward your 10,000 goal. You've got this!",
            icon: "flame.fill"
        ),
        CoachingTip(
            category: .motivation,
            title: "Halfway There!",
            message: "You're at 5,000 steps! The second half is where champions are made.",
            icon: "star.fill"
        ),
        CoachingTip(
            category: .motivation,
            title: "Almost There!",
            message: "Just a few more steps to hit your goal. Push through!",
            icon: "trophy.fill"
        )
    ]

    // MARK: - IWT Tips
    static let iwtTips: [CoachingTip] = [
        CoachingTip(
            category: .iwt,
            title: "Brisk Walking",
            message: "During brisk intervals, aim for a pace where you can talk but not sing.",
            icon: "hare.fill"
        ),
        CoachingTip(
            category: .iwt,
            title: "Recovery Phase",
            message: "Use slow intervals to catch your breath while maintaining movement.",
            icon: "tortoise.fill"
        ),
        CoachingTip(
            category: .iwt,
            title: "IWT Benefits",
            message: "Interval walking improves cardiovascular fitness more than steady-pace walking.",
            icon: "heart.fill"
        )
    ]

    // MARK: - Progress Tips
    static func progressTip(steps: Int, goal: Int) -> CoachingTip {
        let progress = Double(steps) / Double(goal)
        let remaining = goal - steps

        if progress >= 1.0 {
            return CoachingTip(
                category: .milestone,
                title: "Goal Achieved!",
                message: "Congratulations! You've hit \(steps.formatted()) steps today!",
                icon: "trophy.fill"
            )
        } else if progress >= 0.75 {
            return CoachingTip(
                category: .progress,
                title: "Final Push",
                message: "Only \(remaining.formatted()) steps to go. You're in the home stretch!",
                icon: "flag.fill"
            )
        } else if progress >= 0.5 {
            return CoachingTip(
                category: .progress,
                title: "Great Progress",
                message: "You're past the halfway mark! \(remaining.formatted()) steps remaining.",
                icon: "chart.line.uptrend.xyaxis"
            )
        } else if progress >= 0.25 {
            return CoachingTip(
                category: .progress,
                title: "Building Momentum",
                message: "You've completed 25% of your goal. Keep the momentum going!",
                icon: "arrow.up.right"
            )
        } else {
            return CoachingTip(
                category: .motivation,
                title: "Let's Get Started",
                message: "A journey of 10,000 steps begins with a single step. Let's walk!",
                icon: "figure.walk"
            )
        }
    }

    // MARK: - Milestone Tips
    static func incrementMilestone(increment: Int) -> CoachingTip {
        let steps = increment * 500
        return CoachingTip(
            category: .milestone,
            title: "\(steps.formatted()) Steps!",
            message: "You've hit another 500-step milestone! \(20 - increment) increments to go.",
            icon: "checkmark.circle.fill"
        )
    }

    // MARK: - Health Tips
    static let healthTips: [CoachingTip] = [
        CoachingTip(
            category: .health,
            title: "Stay Hydrated",
            message: "Remember to drink water before, during, and after your walk.",
            icon: "drop.fill"
        ),
        CoachingTip(
            category: .health,
            title: "Posture Check",
            message: "Keep your head up, shoulders back, and engage your core while walking.",
            icon: "figure.stand"
        ),
        CoachingTip(
            category: .health,
            title: "Warm Up",
            message: "Start with a slower pace for the first few minutes to warm up your muscles.",
            icon: "thermometer.sun.fill"
        )
    ]

    // MARK: - Weekly Summary Tips
    static func weeklySummary(totalSteps: Int, daysActive: Int, avgSteps: Int) -> CoachingTip {
        return CoachingTip(
            category: .progress,
            title: "Weekly Summary",
            message: "This week: \(totalSteps.formatted()) steps over \(daysActive) days. Daily average: \(avgSteps.formatted()) steps.",
            icon: "calendar"
        )
    }
}
