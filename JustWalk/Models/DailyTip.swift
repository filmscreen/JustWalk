//
//  DailyTip.swift
//  JustWalk
//
//  50 evergreen daily tips with random rotation
//

import Foundation

struct DailyTip: Identifiable, Equatable, Hashable {
    let id: Int
    let icon: String      // SF Symbol name
    let title: String     // Bold headline (2-4 words)
    let subtitle: String  // One clear sentence
}

// MARK: - All 50 Tips

extension DailyTip {
    static let allTips: [DailyTip] = [
        // Permission-Giving (1-10)
        DailyTip(id: 1, icon: "clock", title: "Five Minutes Counts", subtitle: "A 5-minute walk is infinitely better than no walk."),
        DailyTip(id: 2, icon: "tortoise", title: "Slow Counts", subtitle: "You don't have to walk fast. Any pace builds the habit."),
        DailyTip(id: 3, icon: "checkmark.circle", title: "Short Is Fine", subtitle: "A 10-minute walk still counts. Don't let time stop you."),
        DailyTip(id: 4, icon: "shoe", title: "No Gear Needed", subtitle: "You don't need special shoes. Just go."),
        DailyTip(id: 5, icon: "hand.thumbsup", title: "Imperfect Days Count", subtitle: "Walked less than usual? You still showed up."),
        DailyTip(id: 6, icon: "arrow.up.right", title: "Start Small", subtitle: "The goal isn't to walk far. It's to walk often."),
        DailyTip(id: 7, icon: "arrow.triangle.2.circlepath", title: "Progress Not Perfection", subtitle: "Missing one day doesn't erase your progress."),
        DailyTip(id: 8, icon: "star", title: "Good Enough Wins", subtitle: "A short walk beats a perfect walk that never happens."),
        DailyTip(id: 9, icon: "figure.walk.motion", title: "Motivation Follows Action", subtitle: "Don't wait to feel like it. Start, then feel it."),
        DailyTip(id: 10, icon: "figure.walk", title: "Walking Is Enough", subtitle: "You don't need to run. Walking is complete exercise."),

        // Finding Opportunities (11-20)
        DailyTip(id: 11, icon: "hourglass", title: "Use the Wait", subtitle: "Waiting for something? Pace around. Steps are steps."),
        DailyTip(id: 12, icon: "chair", title: "Break the Sit", subtitle: "A 2-minute walk every hour adds up fast."),
        DailyTip(id: 13, icon: "phone", title: "Walk Your Calls", subtitle: "Take phone calls on your feet."),
        DailyTip(id: 14, icon: "car", title: "Parking Lot Bonus", subtitle: "Early for something? Walk the lot first."),
        DailyTip(id: 15, icon: "arrow.triangle.swap", title: "Walk the Long Way", subtitle: "Take the scenic route. Extra steps, same destination."),
        DailyTip(id: 16, icon: "bag", title: "Errand Walk", subtitle: "Walk to one nearby errand. Small trips add up."),
        DailyTip(id: 17, icon: "lightbulb", title: "Walk While Thinking", subtitle: "Got a decision to make? Walk on it."),
        DailyTip(id: 18, icon: "tv", title: "TV Break Steps", subtitle: "Walk during commercials. 100 steps at a time."),
        DailyTip(id: 19, icon: "sun.max", title: "Lunch Break Walk", subtitle: "Even 10 minutes outside resets your afternoon."),
        DailyTip(id: 20, icon: "person.2", title: "Walk to Talk", subtitle: "Need to catch up with someone? Walk together."),

        // Health Benefits (21-30)
        DailyTip(id: 21, icon: "face.smiling", title: "Mood Boost", subtitle: "A 10-minute walk can lift your mood for 2 hours."),
        DailyTip(id: 22, icon: "heart", title: "Heart Health", subtitle: "Walking 30 min daily lowers heart disease risk by 35%."),
        DailyTip(id: 23, icon: "calendar", title: "Add Years", subtitle: "Regular walkers live an average of 7 years longer."),
        DailyTip(id: 24, icon: "chart.line.uptrend.xyaxis", title: "Steps Compound", subtitle: "1,000 extra steps daily = 365,000 steps a year."),
        DailyTip(id: 25, icon: "fork.knife", title: "Blood Sugar Help", subtitle: "A post-meal walk cuts blood sugar spikes by 30%."),
        DailyTip(id: 26, icon: "brain.head.profile", title: "Brain Builder", subtitle: "Walking grows the part of your brain that handles memory."),
        DailyTip(id: 27, icon: "shield", title: "Fewer Sick Days", subtitle: "Regular walkers get 43% fewer colds."),
        DailyTip(id: 28, icon: "moon.zzz", title: "Better Sleep", subtitle: "Walkers fall asleep faster and sleep deeper."),
        DailyTip(id: 29, icon: "figure.walk.circle", title: "Joint Health", subtitle: "Walking lubricates joints. Movement is medicine."),
        DailyTip(id: 30, icon: "clock.arrow.2.circlepath", title: "No Time? No Problem", subtitle: "Three 10-minute walks equal one 30-minute walk."),

        // Mental Benefits (31-40)
        DailyTip(id: 31, icon: "wind", title: "Walk It Off", subtitle: "Stressed? A 15-minute walk lowers cortisol fast."),
        DailyTip(id: 32, icon: "puzzlepiece", title: "Unstick Your Brain", subtitle: "Stuck on a problem? Walking helps connect the dots."),
        DailyTip(id: 33, icon: "arrow.clockwise", title: "Mood Reset", subtitle: "Feeling off? A quick walk can shift your entire day."),
        DailyTip(id: 34, icon: "leaf", title: "Anxiety Relief", subtitle: "Walking calms your nervous system naturally."),
        DailyTip(id: 35, icon: "paintbrush", title: "Creative Boost", subtitle: "Stanford found walking increases creativity by 60%."),
        DailyTip(id: 36, icon: "cloud.fog", title: "Clear the Fog", subtitle: "Mental fatigue? Walking restores focus better than coffee."),
        DailyTip(id: 37, icon: "heart.circle", title: "Process Emotions", subtitle: "Walking helps your brain work through hard feelings."),
        DailyTip(id: 38, icon: "bolt.shield", title: "Stress Buffer", subtitle: "Regular walkers handle stress better over time."),
        DailyTip(id: 39, icon: "battery.100.bolt", title: "Energy Paradox", subtitle: "Feeling tired? Walking creates energy, not drains it."),
        DailyTip(id: 40, icon: "tree", title: "Nature Multiplier", subtitle: "Walking outside amplifies every benefit."),

        // Habit Wisdom (41-50)
        DailyTip(id: 41, icon: "repeat", title: "Consistency Wins", subtitle: "A short walk daily beats a long walk weekly."),
        DailyTip(id: 42, icon: "arrow.right.circle", title: "Just Start", subtitle: "You don't have to feel ready. Just step outside."),
        DailyTip(id: 43, icon: "alarm", title: "Same Time Helps", subtitle: "Walk at the same time daily. Routine builds habits."),
        DailyTip(id: 44, icon: "shoe.circle", title: "The First Step", subtitle: "The hardest part is shoes on. Then momentum takes over."),
        DailyTip(id: 45, icon: "person.fill.checkmark", title: "Identity Shift", subtitle: "You're not trying to walk more. You're becoming a walker."),
        DailyTip(id: 46, icon: "checkmark.seal", title: "Show Up Streak", subtitle: "Every walk is a vote for the person you want to be."),
        DailyTip(id: 47, icon: "2.circle", title: "Two-Day Rule", subtitle: "Never skip twice. One miss is fine. Two breaks momentum."),
        DailyTip(id: 48, icon: "gift", title: "Future You Thanks You", subtitle: "Today's walk is a gift to tomorrow."),
        DailyTip(id: 49, icon: "chart.bar.fill", title: "Compound Interest", subtitle: "Today's steps are tomorrow's strength."),
        DailyTip(id: 50, icon: "sparkles", title: "Already a Walker", subtitle: "You've walked your whole life. Now you're just intentional."),
    ]
}
