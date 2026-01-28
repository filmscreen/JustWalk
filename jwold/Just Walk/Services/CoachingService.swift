//
//  CoachingService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import Combine

/// AI Coaching service that provides personalized tips and feedback
@MainActor
final class CoachingService: ObservableObject {

    static let shared = CoachingService()

    // MARK: - Published Properties

    @Published var currentTip: CoachingTip?
    @Published var recentTips: [CoachingTip] = []
    @Published var weeklyInsight: String?
    @Published var dailyLimitReached = false

    // MARK: - Private Properties

    private var lastTipTime: Date?
    private let minTimeBetweenTips: TimeInterval = 300 // 5 minutes
    private let freeTierManager = FreeTierManager.shared

    private init() {
        updateLimitStatus()
    }

    // MARK: - Free Tier Properties

    /// Check if user can receive more tips today
    var canReceiveTip: Bool {
        freeTierManager.canReceiveCoachingTip
    }

    /// Remaining tips for today (free users)
    var remainingTipsToday: Int {
        freeTierManager.remainingTipsToday
    }

    /// Update the limit reached status
    private func updateLimitStatus() {
        dailyLimitReached = !freeTierManager.isPro && !freeTierManager.canReceiveCoachingTip
    }

    // MARK: - Tip Generation

    /// Generate a contextual tip based on current stats
    func generateTip(
        currentSteps: Int,
        dailyGoal: Int,
        currentPhase: IWTPhase? = nil,
        paceCategory: PaceCategory? = nil
    ) -> CoachingTip {

        // Check if we're in an IWT session
        if let phase = currentPhase {
            return generateIWTTip(phase: phase, paceCategory: paceCategory)
        }

        // Generate progress-based tip
        return generateProgressTip(steps: currentSteps, goal: dailyGoal)
    }

    /// Generate IWT-specific coaching tip
    private func generateIWTTip(phase: IWTPhase, paceCategory: PaceCategory?) -> CoachingTip {
        switch phase {
        case .warmup:
            return CoachingTip(
                category: .iwt,
                title: "Warming Up",
                message: "Start with an easy pace. Let your muscles warm up gradually.",
                icon: "flame"
            )

        case .brisk:
            if let pace = paceCategory {
                if pace.isBriskForIWT {
                    return CoachingTip(
                        category: .technique,
                        title: "Perfect Pace!",
                        message: "You're maintaining an excellent brisk walking pace. Keep it up!",
                        icon: "hand.thumbsup.fill"
                    )
                } else {
                    return CoachingTip(
                        category: .technique,
                        title: "Pick Up the Pace",
                        message: "Try to walk faster - you should be slightly out of breath but able to talk.",
                        icon: "hare.fill"
                    )
                }
            }
            return CoachingTipTemplates.iwtTips[0]

        case .slow:
            if let pace = paceCategory {
                if pace.isSlowForIWT {
                    return CoachingTip(
                        category: .technique,
                        title: "Good Recovery",
                        message: "Perfect recovery pace. Use this time to catch your breath.",
                        icon: "checkmark.circle.fill"
                    )
                } else {
                    return CoachingTip(
                        category: .technique,
                        title: "Slow Down",
                        message: "This is your recovery phase. Slow down to let your heart rate drop.",
                        icon: "tortoise.fill"
                    )
                }
            }
            return CoachingTipTemplates.iwtTips[1]

        case .cooldown:
            return CoachingTip(
                category: .health,
                title: "Cool Down",
                message: "Gradually reduce your pace. This helps prevent muscle soreness.",
                icon: "snowflake"
            )

        case .paused:
            return CoachingTip(
                category: .motivation,
                title: "Take Your Time",
                message: "Rest as needed. When you're ready, tap resume to continue.",
                icon: "pause.circle.fill"
            )

        case .completed:
            return CoachingTip(
                category: .milestone,
                title: "Session Complete!",
                message: "Excellent work! Consistent IWT sessions improve cardiovascular health.",
                icon: "trophy.fill"
            )

        case .classic:
            return CoachingTip(
                category: .technique,
                title: "Find Your Rhythm",
                message: "Maintain a steady pace. Focus on posture and breathing.",
                icon: "figure.walk"
            )
        }
    }

    /// Generate progress-based coaching tip
    private func generateProgressTip(steps: Int, goal: Int) -> CoachingTip {
        let progress = Double(steps) / Double(goal)
        let remaining = goal - steps
        let timeOfDay = Calendar.current.component(.hour, from: Date())

        // Time-based contextual tips
        if timeOfDay < 10 && progress < 0.1 {
            return CoachingTip(
                category: .motivation,
                title: "Good Morning!",
                message: "A morning walk is a great way to start your day. Let's get moving!",
                icon: "sunrise.fill"
            )
        }

        if timeOfDay >= 12 && timeOfDay < 14 && progress < 0.3 {
            return CoachingTip(
                category: .motivation,
                title: "Lunch Walk?",
                message: "Consider a walk during your lunch break. It boosts afternoon energy!",
                icon: "sun.max.fill"
            )
        }

        if timeOfDay >= 18 && progress < 0.7 {
            return CoachingTip(
                category: .motivation,
                title: "Evening Push",
                message: "You have \(remaining.formatted()) steps to go. An evening walk can help you reach your goal!",
                icon: "moon.stars.fill"
            )
        }

        // Progress-based tips
        return CoachingTipTemplates.progressTip(steps: steps, goal: goal)
    }

    // MARK: - Weekly Insights

    /// Generate weekly insight based on stats
    /// Generate weekly insight based on stats
    func generateWeeklyInsight(stats: WeeklySummary) -> String {
        var insights: [String] = []

        // Average steps analysis
        if stats.averageSteps >= 10000 {
            insights.append("Excellent! You averaged \(stats.averageSteps.formatted()) steps per day.")
        } else if stats.averageSteps >= 7500 {
            insights.append("Good progress with \(stats.averageSteps.formatted()) average daily steps.")
        } else {
            insights.append("You averaged \(stats.averageSteps.formatted()) steps. Let's aim higher this week!")
        }

        // Best day celebration
        if let bestDay = stats.dailyData.max(by: { $0.steps < $1.steps }), bestDay.steps > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: bestDay.date)
            insights.append("Your best day was \(dayName) with \(bestDay.steps.formatted()) steps.")
        }

        // Activity consistency
        if stats.daysActive == 7 {
            insights.append("You were active every day this week!")
        } else if stats.daysActive >= 5 {
            insights.append("You were active \(stats.daysActive) out of 7 days.")
        } else {
            insights.append("Try to be active more days this week for better results.")
        }

        weeklyInsight = insights.joined(separator: " ")
        return weeklyInsight ?? ""
    }

    // MARK: - Milestone Tips

    /// Generate tip for reaching a 500-step increment
    func incrementMilestoneTip(increment: Int) -> CoachingTip {
        let tips = [
            "Keep the momentum going!",
            "You're building healthy habits!",
            "Every step counts!",
            "Consistency is key!",
            "You're doing great!"
        ]

        let randomMessage = tips[increment % tips.count]

        return CoachingTip(
            category: .milestone,
            title: "\((increment * 500).formatted()) Steps!",
            message: "\(randomMessage) \(20 - increment) increments to your daily goal.",
            icon: "star.fill"
        )
    }

    /// Generate tip for reaching daily goal
    func goalReachedTip(steps: Int) -> CoachingTip {
        return CoachingTip(
            category: .milestone,
            title: "Goal Achieved!",
            message: "Congratulations on reaching \(steps.formatted()) steps today! You're building a healthier lifestyle.",
            icon: "trophy.fill"
        )
    }

    // MARK: - Random Tips

    /// Get a random health or motivation tip
    func getRandomTip() -> CoachingTip {
        let allTips = CoachingTipTemplates.motivationTips +
                      CoachingTipTemplates.healthTips +
                      CoachingTipTemplates.iwtTips

        return allTips.randomElement() ?? CoachingTipTemplates.motivationTips[0]
    }

    // MARK: - Tip History

    func addToHistory(_ tip: CoachingTip) {
        // Check free tier limit before adding
        guard canReceiveTip else {
            updateLimitStatus()
            return
        }

        recentTips.insert(tip, at: 0)
        if recentTips.count > 10 {
            recentTips.removeLast()
        }
        currentTip = tip
        lastTipTime = Date()

        // Track tip usage for free tier
        freeTierManager.recordCoachingTipShown()
        updateLimitStatus()
    }

    func shouldShowNewTip() -> Bool {
        // Check free tier limit first
        guard canReceiveTip else { return false }

        guard let lastTime = lastTipTime else { return true }
        return Date().timeIntervalSince(lastTime) >= minTimeBetweenTips
    }

    /// Get a tip that respects the free tier limit, returns nil if limit reached
    func getTipIfAllowed() -> CoachingTip? {
        guard canReceiveTip else {
            updateLimitStatus()
            return nil
        }
        return getRandomTip()
    }
    // MARK: - Contextual Tips

    /// Generate tips based on remaining steps, converting to distance and time
    func generateContextualTips(steps: Int, goal: Int) -> [CoachingTip] {
        let remainingSteps = max(0, goal - steps)
        guard remainingSteps > 0 else {
            return [CoachingTip(
                category: .milestone,
                title: "Goal Met!",
                message: "You've hit your daily goal. Enjoy the rest of your day!",
                icon: "star.fill"
            )]
        }

        var tips: [CoachingTip] = []

        // Tip 1: Distance to Goal
        // Avg stride length ~0.762 meters (2.5 feet)
        let strideLengthMeters = 0.762
        let metersRemaining = Double(remainingSteps) * strideLengthMeters
        let distanceRemaining = FormatUtils.formatDistance(metersRemaining)

        tips.append(CoachingTip(
            category: .progress,
            title: "Distance to Goal",
            message: "To reach your goal, you have to walk approximately \(distanceRemaining).",
            icon: "map.fill"
        ))

        // Tip 2: Time context
        // Avg walking speed ~100 steps/min. 15 mins = 1500 steps.
        let stepsIn15Mins = 1500
        tips.append(CoachingTip(
            category: .motivation,
            title: "Quick Walk",
            message: "A 15 minute walk equates to about \(stepsIn15Mins.formatted()) steps.",
            icon: "timer"
        ))
        
        // Tip 3: Time to Goal
        let minutesToGoal = remainingSteps / 100
        if minutesToGoal > 0 {
             tips.append(CoachingTip(
                category: .health,
                title: "Time Remaining",
                message: "At a moderate pace, you're about \(minutesToGoal) minutes away from your goal.",
                icon: "figure.walk"
            ))
        }

        return tips
    }
}
