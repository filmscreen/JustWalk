//
//  LevelUpInsight.swift
//  Just Walk
//
//  Created by Just Walk Team.
//

import Foundation

struct LevelUpInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
}

extension LevelUpInsight {
    static let allInsights: [LevelUpInsight] = [
        LevelUpInsight(title: "Park Further Away", description: "Park at the back of the lot to add 200+ steps per trip.", icon: "car.circle.fill"),
        LevelUpInsight(title: "Stair Master", description: "Take the stairs instead of the elevator for anything under 3 floors.", icon: "stairs"),
        LevelUpInsight(title: "Talk & Walk", description: "Pace around the room or outside whenever you're on a phone call.", icon: "phone.circle.fill"),
        LevelUpInsight(title: "Post-Meal Stroll", description: "A 10-minute walk after eating aids digestion and boosts step count.", icon: "fork.knife.circle.fill"),
        LevelUpInsight(title: "One Stop Early", description: "Get off the bus or train one stop early and walk the rest.", icon: "tram.circle.fill"),
        LevelUpInsight(title: "Walking Meetings", description: "Taking a meeting? Suggest a walking meeting if it's audio-only.", icon: "person.3.sequence.fill"),
        LevelUpInsight(title: "Hydration Station", description: "Use a smaller water bottle/glass so you have to walk to refill it more often.", icon: "drop.circle.fill"),
        LevelUpInsight(title: "Pet Patrol", description: "Extend your dog's morning walk by just 2 blocks.", icon: "pawprint.circle.fill"),
        LevelUpInsight(title: "Commercial Break", description: "Watching TV? Get up and move during every commercial break.", icon: "tv.circle.fill"),
        LevelUpInsight(title: "The Long Route", description: "Take the longest path to the restroom or printer at work.", icon: "figure.walk"),
        LevelUpInsight(title: "Coffee Run", description: "Walk to a local coffee shop instead of driving or making it effectively.", icon: "cup.and.saucer.fill"),
        LevelUpInsight(title: "Explore", description: "Walk down a street in your neighborhood you've never been on.", icon: "map.circle.fill"),
        LevelUpInsight(title: "Podcast Time", description: "Only listen to your favorite podcast while you are walking.", icon: "headphones.circle.fill"),
        LevelUpInsight(title: "Morning Sun", description: "Start the day with a 5-minute walk to set your circadian rhythm.", icon: "sun.max.circle.fill"),
        LevelUpInsight(title: "Lunch Lap", description: "Spend the last 15 minutes of your lunch break taking a quick lap.", icon: "clock.badge.checkmark.fill"),
        LevelUpInsight(title: "Social Steps", description: "Catch up with a friend on a walk instead of sitting at a cafe.", icon: "figure.socialdance"),
        LevelUpInsight(title: "Grocery Laps", description: "Walk every aisle of the grocery store before you start picking items.", icon: "cart.circle.fill"),
        LevelUpInsight(title: "Hourly Movement", description: "Set a timer to walk for 2 minutes every hour you sit.", icon: "timer.circle.fill"),
        LevelUpInsight(title: "Sunset Stroll", description: "Wind down your day with a calm walk around the block.", icon: "moon.stars.circle.fill"),
        LevelUpInsight(title: "Email & Walk", description: "If you can, dictate emails while walking safely.", icon: "envelope.circle.fill"),
        LevelUpInsight(title: "School Run", description: "If feasible, walk the kids to school or the bus stop.", icon: "figure.and.child.holdinghands"),
        LevelUpInsight(title: "Clean Sweep", description: "Cleaning the house vigorously adds a surprising amount of steps.", icon: "sparkles"),
        LevelUpInsight(title: "Date Night Walk", description: "Go for a romantic stroll before or after your dinner date.", icon: "heart.circle.fill"),
        LevelUpInsight(title: "Nature Fix", description: "Find a local park and walk one trail this weekend.", icon: "leaf.circle.fill"),
        LevelUpInsight(title: "Waiting Game", description: "Waiting for an appointment? Walk outside instead of sitting in the lobby.", icon: "clock.arrow.circlepath")
    ]
}
