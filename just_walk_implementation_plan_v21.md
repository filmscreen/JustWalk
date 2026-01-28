# Just Walk — Complete Implementation Plan

> **Version:** 2.1 (iOS 26 Liquid Glass Edition)  
> **Date:** January 23, 2026  
> **Purpose:** Comprehensive implementation guide for rebuilding Just Walk with iOS 26 Liquid Glass design, intentional elegance animations, and core habit-building features.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Core Philosophy](#core-philosophy)
3. [System Architecture](#system-architecture)
4. [iOS 26 Liquid Glass Design System](#ios-26-liquid-glass-design-system)
5. [Intentional Elegance Animation System](#intentional-elegance-animation-system)
6. [Engagement Loop Design](#engagement-loop-design)
7. [Build Loop Protocol](#build-loop-protocol)
8. [Prompt Index](#prompt-index)
9. [Concurrency Plan](#concurrency-plan)
10. [Foundation Prompts](#foundation-prompts)
11. [UI Prompts](#ui-prompts)
12. [Integration Prompts](#integration-prompts)
13. [Testing Checklist](#testing-checklist)

---

## Executive Summary

### What We're Building

Just Walk is a walking habit app that helps users feel like someone who takes care of themselves. The app's core insight: **users don't want to track walks—they want validation, progress, and identity**.

**Design Philosophy:** Best-in-class iOS 26 app with Liquid Glass materials, fluid animations, and intentional elegance — no static transition screens.

### Key Systems

| System | Purpose | Metric | Can It Break? |
|--------|---------|--------|---------------|
| **Daily Goal** | "Did I move today?" | Steps (passive via HealthKit) | Resets daily |
| **Streak** | "Am I consistent?" | Consecutive days hitting goal | Yes — fragile |
| **Rank** | "Who am I becoming?" | Tracked walks ≥5 min (cumulative) | No — permanent |
| **Challenges** | "What's fun this month?" | Mix of passive + tracked walks | No — expires monthly |
| **Intervals** | "Can I push a little?" | Variable-pace walks (Pro) | No — optional mode |

### Critical Design Decisions

1. **Steps vs. Walks**: Steps show you moved. Tracked walks show you showed up. Rank rewards showing up.
2. **5-Minute Minimum**: Only tracked walks ≥5 minutes count toward rank progression.
3. **Rank is Permanent**: Unlike streaks, rank never decreases. It's your permanent walking identity.
4. **Monthly Challenges**: 5 seasonal challenges per month, auto-tracked, mix of passive and active.
5. **Dynamic Cards**: Today screen shows the most actionable/urgent item via priority-based evaluation.
6. **Liquid Glass First**: All navigation UI uses iOS 26 Liquid Glass — content never has glass applied.
7. **Intentional Elegance**: Every transition is animated; no static screen changes.

---

## Core Philosophy

### User Motivations (The "Deepest Why")

| Surface Need | Deeper Why | Deepest Why | How We Solve It |
|--------------|------------|-------------|-----------------|
| "I want to walk" | I know walking is good for me | **I want to feel like a person who takes care of themselves** | One-tap start — no friction, just go |
| "I want to hit a goal" | I don't trust myself to do "enough" | **I need external permission to stop** | Goal mode with clear "You did it!" celebration |
| "I want to see where I walked" | Want proof I did something | **I need evidence that my time mattered** | Post-walk summary with map and achievements |
| "I want to know how far I've gone" | Feel progress in real-time | **I need encouragement to not quit early** | Live stats during walk with progress bar |
| "I want my steps to count" | Need to hit daily goal | **I need to protect my streak / identity** | Auto-sync to daily progress, streak protection |
| "I want to feel motivated" | Easy to skip, hard to stay consistent | **I need something external to keep me accountable** | Streak messaging, rank progress, challenges |

### The One Action That Feeds Everything

```
Track a walk
    ↓
Steps add to daily goal → Ring fills
    ↓
Goal hit → Streak continues (+1 day)
    ↓
Walk ≥5 min → Rank progress (+1 tracked walk)
    ↓
Walk may complete a challenge (if applicable)
    ↓
Month ends → See challenge completion summary
```

**One action (track a walk) feeds all four loops.**

---

## System Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                             │
├─────────────────────────────────────────────────────────────────┤
│  HealthKit          CoreLocation           User Actions          │
│  (steps, dist,      (GPS tracking)         (start/end walk)      │
│   calories)                                                       │
└─────────────┬───────────────┬────────────────────┬───────────────┘
              │               │                    │
              ▼               ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                         MANAGERS                                 │
├─────────────────────────────────────────────────────────────────┤
│  HealthKitManager   WalkSessionManager   PersistenceManager      │
│  StreakManager      RankManager          ChallengeManager        │
│  IntervalManager    LiveActivityManager  SubscriptionManager     │
│                     DynamicCardEngine    AnimationCoordinator    │
└─────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         UI LAYER                                 │
├─────────────────────────────────────────────────────────────────┤
│  Today Screen    Walk Tab    Progress Tab    Journey Screen      │
│  (ring, streak,  (map,       (challenges,    (rank path,         │
│   dynamic card)  start walk)  rank, stats)    milestones)        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              iOS 26 LIQUID GLASS LAYER                       │ │
│  │  Tab Bar, Toolbars, Sheets, Floating Controls, Live Activity│ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Navigation Structure

```
Tab Bar (Liquid Glass)
├── Today (default)
│   └── Ring, Streak, Week Chart, Dynamic Card
│       └── Dynamic Card → Walk Tab / Journey / Challenges (morphing transitions)
│
├── Walk
│   ├── Idle State: Dark Map + "Let's Go" + "Set a Goal" + "Intervals" (Pro)
│   ├── Active State: Live stats, route, controls + Live Activity
│   ├── Interval State: Pace indicator, voice cues, phase display
│   └── Post-Walk: Summary screen (animated entrance)
│
├── Progress
│   ├── Monthly Challenges Card → Challenges Detail
│   ├── Rank Card → Journey Screen
│   ├── Streak Card
│   ├── Month Stats
│   └── Recent Walks → All Walks
│
└── Settings
    └── Daily Goal, Notifications, Pro, Map Appearance, About
```

---

## iOS 26 Liquid Glass Design System

### Core Principles

**Liquid Glass is ONLY for the navigation layer that floats above content.**

```
NEVER apply glass to:
- List items
- Content cards
- Tables
- Media
- Primary content

ALWAYS apply glass to:
- Tab bars (automatic)
- Toolbars (automatic)
- Floating action buttons
- Sheets (partial height)
- Live Activities
- Custom navigation controls
```

### Glass Variants

```swift
// Three glass variants available
.glassEffect()                           // .regular - standard glass
.glassEffect(.clear)                     // More transparent, less blur
.glassEffect(.regular.interactive())     // Responds to touch
.glassEffect(.regular.tint(.teal))       // Brand-tinted glass
```

### GlassEffectContainer for Grouped Controls

```swift
// Controls that belong together should be in a container
GlassEffectContainer {
    HStack(spacing: 16) {
        Button("Pause") { ... }
            .glassEffect()
        Button("End") { ... }
            .glassEffect()
    }
}
// This enables morphing animations between states
```

### Design Tokens (iOS 26 Updated)

```swift
enum JustWalkDesignTokens {
    // Colors
    static let primaryTeal = Color(hex: "#00C7BE")
    static let glassAccent = Color(hex: "#00C7BE").opacity(0.6)
    
    // Glass-Specific Radii (per Apple guidelines)
    enum Radius {
        static let card: CGFloat = 28        // Content cards
        static let pill: CGFloat = 999       // Pill buttons
        static let sheet: CGFloat = 34       // Bottom sheets
        static let glassControl: CGFloat = 16 // Small glass elements
    }
    
    // Ring dimensions
    static let todayRingDiameter: CGFloat = 220
    static let todayRingStrokeWidth: CGFloat = 18
    
    // Map
    static let defaultMapStyle: MapStyle = .dark  // Dark mode default
}
```

### Map Configuration

```swift
// Dark mode maps by default for visual consistency with Liquid Glass
struct WalkMapView: View {
    @AppStorage("mapAlwaysDark") var alwaysDark = true
    
    var mapStyle: MapStyle {
        if alwaysDark { return .dark }
        return colorScheme == .dark ? .dark : .standard
    }
}
```

### What Gets Glass Automatically (iOS 26)

When building with Xcode 26 SDK:
- `NavigationStack` toolbars → Automatic glass
- `TabView` → Automatic glass
- `.sheet()` partial height → Automatic glass with morphing
- `.popover()` → Automatic glass
- Standard controls during interaction → Glass transforms

### Custom Glass Components to Build

```swift
// Floating "Let's Go" button
struct FloatingStartButton: View {
    var body: some View {
        Button("Let's Go") { ... }
            .font(.title2.bold())
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .glassEffect(.regular.tint(.teal).interactive())
    }
}

// Walk controls during active session
struct ActiveWalkControls: View {
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 20) {
                Button(action: pause) {
                    Image(systemName: "pause.fill")
                }
                .glassEffect(.regular.interactive())
                
                Button(action: end) {
                    Image(systemName: "stop.fill")
                }
                .glassEffect(.regular.interactive())
            }
        }
    }
}
```

---

## Intentional Elegance Animation System

### Core Philosophy

**"Every interaction should feel considered. No screen appears — it arrives."**

Inspired by Strava's fluid feel, but restrained. Animations serve clarity, not spectacle.

### Animation Timing Standards

```swift
enum JustWalkAnimation {
    // Micro-interactions (button feedback, toggles)
    static let micro = Animation.snappy(duration: 0.18)
    
    // Standard transitions (cards appearing, state changes)
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    // Emphasis (celebrations, rank up, goal complete)
    static let emphasis = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    // Morphing (sheet presentations, glass transitions)
    static let morph = Animation.smooth(duration: 0.35)
    
    // Staggered lists (card entrances)
    static func stagger(index: Int) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
        .delay(Double(index) * 0.05)
    }
}
```

### Required Animations by Screen

#### Today Screen
| Element | Animation | Trigger |
|---------|-----------|---------|
| Step ring | Animated fill on appear | View appears |
| Ring progress | Smooth countup | Step count changes |
| Streak badge | Scale pop | Streak increments |
| Dynamic card | Slide in from bottom | View appears |
| Week chart bars | Staggered grow from bottom | View appears |

#### Walk Tab
| Element | Animation | Trigger |
|---------|-----------|---------|
| "Let's Go" button | Subtle pulse glow | Idle state |
| Start transition | Button morphs to active panel | Tap start |
| Live stats | Counting animation | Values update |
| Route drawing | Polyline draws progressively | GPS updates |
| 5-min indicator | Pop + haptic | Threshold crossed |
| End transition | Panel collapses to summary | Tap end |

#### Post-Walk Summary
| Element | Animation | Trigger |
|---------|-----------|---------|
| Stats | Staggered fade + slide up | View appears |
| Map | Fade in with route highlight | After stats |
| Achievements | Pop in with spring | After map |
| Confetti | Particle system | Qualifying walk |

#### Progress Tab
| Element | Animation | Trigger |
|---------|-----------|---------|
| Cards | Staggered entrance | View appears |
| Challenge progress bars | Animated fill | View appears |
| Rank progress | Gradient fill animation | View appears |

#### Journey Screen
| Element | Animation | Trigger |
|---------|-----------|---------|
| Rank nodes | Sequential glow | Scroll position |
| Current rank | Pulsing highlight | Always |
| Connector lines | Draw animation | View appears |

### Micro-Interaction Patterns

```swift
// Tap feedback (all tappable elements)
struct TapFeedback: ViewModifier {
    @State private var pressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.snappy(duration: 0.18), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

// Card lift on highlight
struct CardLift: ViewModifier {
    var isHighlighted: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHighlighted ? 0.2 : 0.1),
                radius: isHighlighted ? 12 : 6,
                y: isHighlighted ? 6 : 3
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
    }
}

// Animated counter (for steps, distance, duration)
struct AnimatedCounter: View {
    let value: Int
    @State private var displayValue: Int = 0
    
    var body: some View {
        Text("\(displayValue)")
            .contentTransition(.numericText())
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    displayValue = newValue
                }
            }
    }
}
```

### Haptic Feedback Coordination

```swift
enum JustWalkHaptics {
    static func buttonTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func goalComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func rankUp() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred(intensity: 0.7)
        }
    }
    
    static func fiveMinuteMilestone() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func intervalPhaseChange() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
```

### SF Symbol Animations (iOS 26)

```swift
// Use built-in symbol effects
Image(systemName: "flame.fill")
    .symbolEffect(.bounce, value: streakCount)

Image(systemName: "figure.walk")
    .symbolEffect(.pulse, isActive: isWalking)

Image(systemName: "star.fill")
    .symbolEffect(.scale, isActive: isHighlighted)
```

---

## Engagement Loop Design

### Rank System (7-Tier Ladder)

| Rank | Walks | Motto | Timeline | Meaning |
|------|-------|-------|----------|---------|
| **Walker** | 1 | "I started." | First walk | You took the first step |
| **Wayfarer** | 10 | "I'm finding my way." | ~2 weeks | You're exploring |
| **Strider** | 25 | "I've found my rhythm." | ~1 month | Walking is becoming habit |
| **Pacer** | 50 | "I keep showing up." | ~2 months | Consistent commitment |
| **Centurion** | 100 | "The path is part of me." | ~3-4 months | Walking is identity |
| **Voyager** | 200 | "I've gone the distance." | ~6-8 months | Proven dedication |
| **Just Walker** | 365 | "I am a walker." | One year | This is who you are |

**Critical Rules:**
- Only tracked walks ≥5 minutes count
- Rank never decreases — it's permanent
- After max rank, walk count becomes the ongoing metric
- 365 = "One year of walks" — meaningful milestone

### Monthly Challenges (Full Calendar)

#### January — 🌨️ Fresh Starts
| Challenge | Requirement | Type |
|-----------|-------------|------|
| New Year Walker | Track a walk on January 1st | Special |
| First Week Strong | Hit daily goal 5 of first 7 days | Consistency |
| Resolution Keeper | Hit daily goal 10 times this month | Consistency |
| Winter Warrior | Walk 15 miles total | Distance |
| Fresh Start Streak | Track 7 walks this month | Tracked Walks |

#### February — ❤️ Heart & Warmth
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Heart Health Hero | Track 10 walks of 20+ minutes | Tracked Walks |
| Valentine's Stroll | Track a walk on February 14th | Special |
| Beat the Blues | Hit daily goal 4 days in a row | Consistency |
| February Finisher | Track a walk every day of the last week | Tracked Walks |
| Love Your Heart | Walk 28 miles in 28 days | Distance |

#### March — 🌱 Spring Forward
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Spring Forward | Track 3 walks before 8am | Tracked Walks |
| Lucky Streak | Track a walk on St. Patrick's Day (Mar 17) | Special |
| March Miles | Walk 25 miles this month | Distance |
| First Day of Spring | Track a walk on March 20th | Special |
| Out of Hibernation | Track 10 walks this month | Tracked Walks |

#### April — 🌸 Renewal
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Earth Day Walker | Track a walk on April 22nd | Special |
| April Showers | Walk 12 days this month | Consistency |
| Bloom Where You Walk | Walk 3 different routes | Tracked Walks |
| 30 for 30 | Walk 30 minutes, 15 times | Tracked Walks |
| Spring Streak | Hit daily goal 14 days in a row | Consistency |

#### May — 🌷 Peak Season
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Mental Health Mile | Walk 20+ minutes, 20 days | Tracked Walks |
| Mother's Day Miles | Walk 5 miles Mother's Day week | Distance |
| Memorial Day Weekend Warrior | Walk all 3 days of Memorial Day weekend | Tracked Walks |
| May Momentum | 50,000 steps in one week | Steps |
| Merry Month of May | Walk every single day | Consistency |

#### June — ☀️ Long Days
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Solstice Walker | Track a walk on June 21st | Special |
| Father's Day Footsteps | Walk 5 miles Father's Day week | Distance |
| Early Bird Summer | Track 5 walks before 8am | Tracked Walks |
| Golden Hour | Track 5 evening walks (6-8pm) | Tracked Walks |
| June Streak | Hit daily goal 14 days in a row | Consistency |

#### July — 🌡️ Summer Smart
⚠️ **Safety focus: No aggressive volume goals due to heat**

| Challenge | Requirement | Type |
|-----------|-------------|------|
| Independence Day | Track a walk on July 4th | Special |
| Cool Morning Club | Track 8 walks before 9am | Tracked Walks |
| Hydration Hero | Walk 10 days (any safe time) | Consistency |
| Summer Consistency | Walk 15+ minutes, 20 days | Tracked Walks |
| Beat the Heat Streak | 7-day streak (morning or evening) | Consistency |

#### August — 🌅 Late Summer
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Summer Sunset | Track 5 evening walks | Tracked Walks |
| Back to Routine | Walk 5 days in a row | Consistency |
| August Every Day | Walk 10+ minutes every day of last week | Tracked Walks |
| Last Days of Summer | Walk 20 miles this month | Distance |
| Sunrise Streak | Track 7 walks before 8am | Tracked Walks |

#### September — 🍂 Fall Revival
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Labor Day Walker | Track a walk on Labor Day | Special |
| Back in the Groove | Walk 15 days this month | Consistency |
| Fall Equinox | Track a walk on September 22nd | Special |
| September Steps | 250,000 steps this month | Steps |
| Crisp Morning Club | Track 10 walks before 9am | Tracked Walks |

#### October — 🎃 Peak Fall
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Spooky Stroll | Track a walk on October 31st | Special |
| Fall Foliage | Track 12 walks this month | Tracked Walks |
| Sweater Weather | Walk 30 miles this month | Distance |
| October Consistency | Hit daily goal 20 days | Consistency |
| Twilight Walker | Track 5 evening walks | Tracked Walks |

#### November — 🦃 Gratitude
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Election Day | Track a walk on Election Day (US) | Special |
| Veterans Day Walk | Track a walk on November 11th | Special |
| Thanksgiving Stroll | Track a walk on Thanksgiving | Special |
| Gratitude Miles | Walk 25 miles this month | Distance |
| November Dedication | Hit daily goal 15 days | Consistency |

#### December — ❄️ Year End
| Challenge | Requirement | Type |
|-----------|-------------|------|
| Winter Solstice | Track a walk on December 21st | Special |
| Holiday Hustle | Walk 5 days in a row during holiday week | Consistency |
| New Year's Eve Walk | Track a walk on December 31st | Special |
| December Miles | Walk 20 miles despite the cold | Distance |
| Year-End Streak | Finish the year with a 7-day streak | Consistency |

---

## Build Loop Protocol

### ⚠️ MANDATORY FOR EVERY PROMPT

Every implementation task MUST follow this verification loop:

```
┌─────────────────────────────────────────────────────────┐
│                    BUILD LOOP PROTOCOL                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. IMPLEMENT                                           │
│     Write the Swift code per the prompt specifications  │
│                                                         │
│  2. BUILD                                               │
│     Run: xcodebuild -scheme "JustWalk" \               │
│          -destination 'platform=iOS Simulator,\        │
│          name=iPhone 16 Pro' build                     │
│                                                         │
│  3. ANALYZE                                             │
│     Parse build output for errors and warnings         │
│                                                         │
│  4. FIX                                                 │
│     Address all compilation errors                      │
│     Address significant warnings                        │
│                                                         │
│  5. REPEAT                                              │
│     Loop steps 2-4 until: BUILD SUCCEEDED              │
│                                                         │
│  6. PROCEED                                             │
│     Only after clean build, move to next task          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Build Command

```bash
xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -50
```

### Example Build Loop in Prompt

Every prompt includes this footer:

```
---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

## Prompt Index

### Foundation Layer (F)

| ID | Name | Depends On | Concurrent Group |
|----|------|------------|------------------|
| F-1 | Data Models & Persistence | — | A |
| F-2 | HealthKit Manager | F-1 | A |
| F-3 | Walk Session Manager | F-1 | B |
| F-4 | Streak Manager | F-1, F-2 | B |
| F-5 | Rank Manager | F-1 | B |
| F-6 | Challenge Manager | F-1, F-5 | C |
| F-7 | Dynamic Card Engine | F-4, F-5, F-6 | C |
| F-8 | Subscription Manager (StoreKit 2) | F-1 | A |
| F-9 | Animation Coordinator | — | A |

### UI Layer (U)

| ID | Name | Depends On | Concurrent Group |
|----|------|------------|------------------|
| U-1 | Onboarding Flow | F-1, F-2, F-8 | D |
| U-2 | Today Screen | F-2, F-4, F-7, F-9 | D |
| U-3 | Walk Tab (Idle + Active) | F-3, F-9 | D |
| U-4 | Post-Walk Summary | F-3, F-5, F-9 | E |
| U-5 | Progress Tab | F-4, F-5, F-6, F-9 | E |
| U-6 | Journey Screen | F-5, F-9 | E |
| U-7 | Challenges Screen | F-6, F-9 | E |
| U-8 | Settings Screen | F-1, F-8 | F |
| U-9 | Liquid Glass Components | F-9 | D |
| U-10 | Live Activities | F-3, L-2 | F |

### Logic Layer (L)

| ID | Name | Depends On | Concurrent Group |
|----|------|------------|------------------|
| L-1 | Walk Mode Logic (Goal/Free) | F-3 | C |
| L-2 | Interval Manager | F-3, F-8 | C |

### Integration Layer (I)

| ID | Name | Depends On | Concurrent Group |
|----|------|------------|------------------|
| I-1 | First Walk Education | F-3, F-5 | F |
| I-2 | Notifications (Quiet Partner) | F-4 | F |
| I-3 | Widgets | F-2, F-4 | G |
| I-4 | Apple Watch App | F-2, F-3 | G |

---

## Concurrency Plan

### Execution Phases

```
PHASE 1: Foundation Core (Concurrent Group A)
├── Session 1: F-1 (Data Models)
├── Session 2: F-2 (HealthKit)
├── Session 3: F-8 (Subscriptions)
└── Session 4: F-9 (Animation Coordinator)
    Wait for all ────────────────────────────►

PHASE 2: Foundation Extended (Concurrent Group B)
├── Session 1: F-3 (Walk Session)
├── Session 2: F-4 (Streak)
└── Session 3: F-5 (Rank)
    Wait for all ────────────────────────────►

PHASE 3: Logic & Engines (Concurrent Group C)
├── Session 1: F-6 (Challenges)
├── Session 2: F-7 (Dynamic Card)
├── Session 3: L-1 (Walk Modes)
└── Session 4: L-2 (Intervals)
    Wait for all ────────────────────────────►

PHASE 4: Core UI (Concurrent Group D)
├── Session 1: U-1 (Onboarding)
├── Session 2: U-2 (Today)
├── Session 3: U-3 (Walk Tab)
└── Session 4: U-9 (Glass Components)
    Wait for all ────────────────────────────►

PHASE 5: Secondary UI (Concurrent Group E)
├── Session 1: U-4 (Post-Walk)
├── Session 2: U-5 (Progress)
├── Session 3: U-6 (Journey)
└── Session 4: U-7 (Challenges)
    Wait for all ────────────────────────────►

PHASE 6: Settings & Activities (Concurrent Group F)
├── Session 1: U-8 (Settings)
├── Session 2: U-10 (Live Activities)
├── Session 3: I-1 (First Walk Education)
└── Session 4: I-2 (Notifications)
    Wait for all ────────────────────────────►

PHASE 7: Extensions (Concurrent Group G)
├── Session 1: I-3 (Widgets)
└── Session 2: I-4 (Watch App)
    Complete ────────────────────────────────►
```

### Estimated Timeline

| Phase | Sessions | Duration | Running Total |
|-------|----------|----------|---------------|
| Phase 1 | 4 concurrent | ~1 hour | 1 hour |
| Phase 2 | 3 concurrent | ~1 hour | 2 hours |
| Phase 3 | 4 concurrent | ~1.5 hours | 3.5 hours |
| Phase 4 | 4 concurrent | ~2 hours | 5.5 hours |
| Phase 5 | 4 concurrent | ~1.5 hours | 7 hours |
| Phase 6 | 4 concurrent | ~1.5 hours | 8.5 hours |
| Phase 7 | 2 concurrent | ~1 hour | 9.5 hours |

**Total: ~10 hours with 4 concurrent Claude Code sessions**

---

## Foundation Prompts

### F-1: Data Models & Persistence

```
Create the core data models and persistence layer for Just Walk.

OVERVIEW:
- All models should be Codable for UserDefaults storage
- Use @AppStorage where appropriate for simple values
- PersistenceManager handles all complex object storage

---

MODELS TO CREATE:

1. UserProfile
   - dailyStepGoal: Int (default 6000)
   - onboardingComplete: Bool
   - createdAt: Date
   - proSubscriptionActive: Bool
   - proExpirationDate: Date?

2. DailyLog
   - date: Date (day only, no time)
   - steps: Int
   - goalMet: Bool
   - trackedWalks: [TrackedWalk]

3. TrackedWalk
   - id: UUID
   - startTime: Date
   - endTime: Date
   - duration: TimeInterval
   - steps: Int
   - distance: Double (meters)
   - calories: Int
   - route: [CLLocationCoordinate2D] (Codable extension needed)
   - qualifiesForRank: Bool (computed: duration >= 300)
   - walkMode: WalkMode
   - intervalData: IntervalWalkData? (for interval walks)

4. WalkMode (enum)
   - free
   - goal(target: WalkGoal)
   - interval(program: IntervalProgram)

5. WalkGoal (enum)
   - steps(Int)
   - distance(Double) // meters
   - duration(TimeInterval)

6. IntervalProgram
   - id: UUID
   - name: String
   - phases: [IntervalPhase]
   - totalDuration: TimeInterval (computed)

7. IntervalPhase
   - pace: IntervalPace (brisk/easy)
   - duration: TimeInterval

8. IntervalPace (enum)
   - brisk
   - easy

9. IntervalWalkData
   - program: IntervalProgram
   - completedPhases: Int
   - phaseTransitions: [Date]

10. StreakData
   - currentStreak: Int
   - longestStreak: Int
   - lastGoalMetDate: Date?
   - streakStartDate: Date?

11. Rank (enum with raw values)
   - walker = 1
   - wayfarer = 10
   - strider = 25
   - pacer = 50
   - centurion = 100
   - voyager = 200
   - justWalker = 365
   
   Properties:
   - walksRequired: Int
   - title: String
   - motto: String
   - nextRank: Rank?

12. RankData
   - totalQualifyingWalks: Int
   - currentRank: Rank (computed from totalQualifyingWalks)
   - walksToNextRank: Int (computed)
   - rankHistory: [RankMilestone]

13. RankMilestone
   - rank: Rank
   - achievedDate: Date

14. Challenge
   - id: String
   - title: String
   - description: String
   - requirement: ChallengeRequirement
   - category: ChallengeCategory
   - icon: String (SF Symbol)

15. ChallengeRequirement (enum with associated values)
   - trackedWalks(count: Int, minDuration: TimeInterval?)
   - totalSteps(count: Int)
   - totalDistance(meters: Double)
   - consecutiveDays(count: Int)
   - specificDate(Date)
   - daysWithGoal(count: Int)
   - morningWalks(count: Int, beforeHour: Int)
   - eveningWalks(count: Int, afterHour: Int, beforeHour: Int)

16. ChallengeCategory (enum)
   - tracked
   - consistency
   - distance
   - steps
   - special

17. ChallengeProgress
   - challengeId: String
   - currentValue: Double
   - targetValue: Double
   - isComplete: Bool (computed)
   - completedDate: Date?

18. MonthProgress
   - month: Int
   - year: Int
   - challenges: [ChallengeProgress]

19. DynamicCardType (enum)
   - streakAtRisk(currentStreak: Int)
   - goalClose(stepsRemaining: Int)
   - rankClose(walksRemaining: Int, nextRank: Rank)
   - challengeExpiring(challenge: Challenge, daysLeft: Int)
   - challengeAlmostComplete(challenge: Challenge, percentComplete: Double)
   - newChallenges
   - rankProgress(currentRank: Rank, walksToNext: Int)

---

PERSISTENCE MANAGER:

class PersistenceManager {
    static let shared = PersistenceManager()
    
    // UserDefaults keys
    private enum Keys { ... }
    
    // CRUD operations for each model type
    func saveUserProfile(_ profile: UserProfile)
    func loadUserProfile() -> UserProfile
    
    func saveDailyLog(_ log: DailyLog)
    func loadDailyLog(for date: Date) -> DailyLog?
    func loadDailyLogs(from: Date, to: Date) -> [DailyLog]
    
    func saveStreakData(_ data: StreakData)
    func loadStreakData() -> StreakData
    
    func saveRankData(_ data: RankData)
    func loadRankData() -> RankData
    
    func saveMonthProgress(_ progress: MonthProgress)
    func loadMonthProgress(month: Int, year: Int) -> MonthProgress?
    func loadAllMonthProgress() -> [MonthProgress]
}

---

CLLocationCoordinate2D Codable Extension:

extension CLLocationCoordinate2D: Codable {
    // Implement encode/decode using latitude/longitude
}

---

PROVIDE:
1. All model structs/enums with Codable conformance
2. PersistenceManager with full implementation
3. CLLocationCoordinate2D Codable extension

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-2: HealthKit Manager

```
Create the HealthKit integration layer for Just Walk.

OVERVIEW:
- Request authorization for steps, distance, calories
- Observe step count changes in real-time
- Provide today's totals and historical data

---

HEALTHKIT MANAGER:

@Observable
class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    // Published state
    var todaySteps: Int = 0
    var todayDistance: Double = 0 // meters
    var todayCalories: Int = 0
    var isAuthorized: Bool = false
    
    // Authorization
    func requestAuthorization() async throws
    
    // Real-time observation
    func startObservingSteps()
    func stopObservingSteps()
    
    // Queries
    func fetchTodaySteps() async -> Int
    func fetchTodayDistance() async -> Double
    func fetchTodayCalories() async -> Int
    func fetchSteps(for date: Date) async -> Int
    func fetchWeeklySteps() async -> [Date: Int] // Last 7 days
    
    // Walk-specific (during tracked walk)
    func fetchSteps(from startDate: Date, to endDate: Date) async -> Int
    func fetchDistance(from startDate: Date, to endDate: Date) async -> Double
    func fetchCalories(from startDate: Date, to endDate: Date) async -> Int
}

---

IMPLEMENTATION NOTES:

1. Authorization:
   - Read: stepCount, distanceWalkingRunning, activeEnergyBurned
   - Use the system authorization dialog directly (no pre-permission screen)

2. Real-time Steps:
   - Use HKObserverQuery for background updates
   - Use HKStatisticsCollectionQuery for periodic refreshes
   - Update todaySteps on main thread

3. Historical Data:
   - Use HKStatisticsQuery for single-day totals
   - Use HKStatisticsCollectionQuery for date ranges

4. Walk Metrics:
   - Query should use walk start/end times
   - Filter to walking/running sources only

---

PROVIDE:
1. Complete HealthKitManager class
2. All query implementations
3. Background observation setup

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-3: Walk Session Manager

```
Create the walk session tracking system for Just Walk.

OVERVIEW:
- Manages active walk state (idle, active, paused)
- Tracks GPS route with Kalman filtering
- Records walk metrics in real-time
- Supports free, goal, and interval modes

---

WALK SESSION MANAGER:

@Observable
class WalkSessionManager {
    static let shared = WalkSessionManager()
    
    // State
    enum SessionState {
        case idle
        case active
        case paused
    }
    
    var state: SessionState = .idle
    var currentWalk: TrackedWalk?
    var walkMode: WalkMode = .free
    
    // Live metrics
    var elapsedTime: TimeInterval = 0
    var currentSteps: Int = 0
    var currentDistance: Double = 0
    var currentCalories: Int = 0
    var currentRoute: [CLLocationCoordinate2D] = []
    var currentPace: Double = 0 // min/mile
    
    // Goal progress
    var goalProgress: Double = 0 // 0-1
    var goalComplete: Bool = false
    
    // Interval state
    var currentIntervalPhase: Int = 0
    var phaseTimeRemaining: TimeInterval = 0
    var currentIntervalPace: IntervalPace = .easy
    
    // 5-minute indicator
    var qualifiesForRank: Bool { elapsedTime >= 300 }
    var justCrossedFiveMinutes: Bool = false // Triggers once
    
    // Actions
    func startWalk(mode: WalkMode)
    func pauseWalk()
    func resumeWalk()
    func endWalk() -> TrackedWalk
    
    // Internal
    private var timer: Timer?
    private var locationManager: CLLocationManager
    private var kalmanFilter: KalmanFilter
    
    private func startLocationTracking()
    private func stopLocationTracking()
    private func processLocation(_ location: CLLocation)
    private func updateMetrics()
    private func checkGoalCompletion()
    private func advanceIntervalPhase()
}

---

KALMAN FILTER (for GPS smoothing):

class KalmanFilter {
    private var lat: Double = 0
    private var lon: Double = 0
    private var variance: Double = -1
    
    func process(location: CLLocation) -> CLLocationCoordinate2D
    func reset()
}

---

LOCATION DELEGATE:

Handle CLLocationManagerDelegate:
- Request "when in use" authorization
- Use kCLLocationAccuracyBest
- Filter locations with horizontalAccuracy > 20m
- Apply Kalman filter to accepted locations
- Append to currentRoute

---

TIMER LOGIC:

- Update every 1 second when active
- Increment elapsedTime
- Fetch updated steps/distance from HealthKit
- Check 5-minute threshold
- Check goal completion
- Update interval phase timing

---

INTERVAL LOGIC:

When mode is .interval:
- Track phaseTimeRemaining countdown
- When phase completes:
  - Advance currentIntervalPhase
  - Reset phaseTimeRemaining
  - Update currentIntervalPace
  - Trigger haptic (JustWalkHaptics.intervalPhaseChange())
- Record phase transitions in intervalData

---

PROVIDE:
1. Complete WalkSessionManager class
2. KalmanFilter implementation
3. CLLocationManagerDelegate handling
4. Timer and metric update logic
5. Interval phase management

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-4: Streak Manager

```
Create the streak tracking system for Just Walk.

OVERVIEW:
- Calculate current streak based on consecutive goal-met days
- Detect "streak at risk" state (after 6pm, goal not met)
- Track longest streak ever achieved

---

STREAK MANAGER:

@Observable
class StreakManager {
    static let shared = StreakManager()
    
    private let persistence = PersistenceManager.shared
    private let healthKit = HealthKitManager.shared
    
    // Published state
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var streakAtRisk: Bool = false
    var lastGoalMetDate: Date?
    
    // Computed
    var didMeetGoalToday: Bool {
        // Check if today's steps >= goal
    }
    
    // Actions
    func recalculateStreak()
    func checkStreakAtRisk() -> Bool
    
    // Called when daily goal is met
    func onGoalMet()
    
    // Called at midnight or app launch
    func onDayChange()
}

---

STREAK CALCULATION LOGIC:

1. Start from today, go backwards
2. For each day, check if goal was met (from DailyLog)
3. Count consecutive days until a miss
4. Handle edge cases:
   - Today not yet met: streak = yesterday's chain (if goal met today, add 1)
   - First day ever: streak = 0 or 1 depending on goal status
   - Multiple days missed: streak resets to 0

---

STREAK AT RISK DETECTION:

func checkStreakAtRisk() -> Bool {
    let now = Date()
    let hour = Calendar.current.component(.hour, from: now)
    
    // After 6pm and haven't hit goal today
    if hour >= 18 && !didMeetGoalToday && currentStreak > 0 {
        return true
    }
    return false
}

---

DAY CHANGE HANDLING:

When day changes:
1. If yesterday's goal was met, streak continues
2. If yesterday's goal was NOT met:
   - Current streak resets to 0
   - Record streak break (for potential future "streak protection" feature)
3. Recalculate from scratch to ensure accuracy

---

PROVIDE:
1. Complete StreakManager class
2. Streak calculation algorithm
3. Streak at risk detection
4. Day change handling

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-5: Rank Manager

```
Create the rank progression system for Just Walk.

OVERVIEW:
- Track cumulative qualifying walks (≥5 minutes)
- Calculate current rank and progress to next
- Rank never decreases (permanent progression)

---

RANK MANAGER:

@Observable
class RankManager {
    static let shared = RankManager()
    
    private let persistence = PersistenceManager.shared
    
    // Published state
    var totalQualifyingWalks: Int = 0
    var currentRank: Rank = .walker
    var walksToNextRank: Int = 0
    var progressToNextRank: Double = 0 // 0-1
    var rankHistory: [RankMilestone] = []
    
    // Actions
    func addQualifyingWalk()
    func recalculateRank()
    
    // Check if walk qualifies
    func walkQualifies(_ walk: TrackedWalk) -> Bool {
        return walk.duration >= 300 // 5 minutes
    }
    
    // Called after walk ends
    func processWalk(_ walk: TrackedWalk) {
        if walkQualifies(walk) {
            addQualifyingWalk()
        }
    }
}

---

RANK THRESHOLDS (7-tier ladder):

Rank         | Walks Required
-------------|---------------
Walker       | 1
Wayfarer     | 10
Strider      | 25
Pacer        | 50
Centurion    | 100
Voyager      | 200
Just Walker  | 365

---

PROGRESS CALCULATION:

If current rank is Walker (1 walk) and user has 5 walks:
- Current rank: Walker
- Next rank: Wayfarer (10 walks)
- Walks to next: 10 - 5 = 5
- Progress: (5 - 1) / (10 - 1) = 0.44 (44%)

If user is at max rank (Just Walker):
- walksToNextRank = 0
- progressToNextRank = 1.0
- Total walks becomes the displayed metric

---

RANK UP DETECTION:

When addQualifyingWalk() is called:
1. Increment totalQualifyingWalks
2. Check if new total crosses a rank threshold
3. If rank up:
   - Update currentRank
   - Add RankMilestone to history
   - Return true (for UI celebration)
4. Recalculate progress metrics

---

PROVIDE:
1. Complete RankManager class
2. Rank enum with all properties
3. Progress calculation logic
4. Rank up detection

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-6: Challenge Manager

```
Create the monthly challenge system for Just Walk.

OVERVIEW:
- Load challenges for current month from ChallengeLibrary
- Track progress against each challenge
- Handle month rollover and archiving

---

CHALLENGE MANAGER:

@Observable
class ChallengeManager {
    static let shared = ChallengeManager()
    
    private let persistence = PersistenceManager.shared
    
    // Published state
    var currentMonthChallenges: [Challenge] = []
    var challengeProgress: [String: ChallengeProgress] = [:] // challengeId -> progress
    var completedChallengesThisMonth: Int = 0
    
    // Actions
    func loadChallengesForMonth(month: Int, year: Int)
    func updateProgress(for walk: TrackedWalk)
    func updateProgressFromHealthKit(steps: Int, date: Date)
    func checkAndArchiveMonth()
    
    // Queries
    func getProgress(for challengeId: String) -> ChallengeProgress?
    func getPastMonthResults(month: Int, year: Int) -> MonthProgress?
    func getAllPastMonths() -> [MonthProgress]
    
    // Internal
    private func evaluateChallenge(_ challenge: Challenge) -> ChallengeProgress
    private func checkCompletion(_ progress: ChallengeProgress) -> Bool
}

---

CHALLENGE LIBRARY:

struct ChallengeLibrary {
    static func challenges(for month: Int) -> [Challenge]
}

Include all 60 challenges from the monthly calendar (5 per month × 12 months).

---

PROGRESS EVALUATION:

For each ChallengeRequirement type:

1. trackedWalks(count, minDuration):
   - Query DailyLogs for current month
   - Count walks matching criteria

2. totalSteps(count):
   - Sum steps from all DailyLogs this month

3. totalDistance(meters):
   - Sum distance from all TrackedWalks this month

4. consecutiveDays(count):
   - Find longest consecutive goal-met streak this month

5. specificDate(date):
   - Check if walk exists on that date

6. daysWithGoal(count):
   - Count days with goalMet = true

7. morningWalks(count, beforeHour):
   - Count walks with startTime.hour < beforeHour

8. eveningWalks(count, afterHour, beforeHour):
   - Count walks with startTime.hour in range

---

MONTH ROLLOVER:

On month change:
1. Archive current MonthProgress
2. Clear challengeProgress dictionary
3. Load new month's challenges
4. Reset completedChallengesThisMonth

---

PROVIDE:
1. Complete ChallengeManager class
2. ChallengeLibrary with all 60 challenges
3. Progress evaluation for all requirement types
4. Month rollover logic

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-7: Dynamic Card Engine

```
Create the dynamic card selection engine for Just Walk.

OVERVIEW:
- Evaluate current state to determine which card to show
- Priority-based selection (most urgent wins)
- Single card displayed on Today screen

---

DYNAMIC CARD ENGINE:

@Observable
class DynamicCardEngine {
    static let shared = DynamicCardEngine()
    
    private let streak = StreakManager.shared
    private let rank = RankManager.shared
    private let challenge = ChallengeManager.shared
    private let healthKit = HealthKitManager.shared
    private let persistence = PersistenceManager.shared
    
    // Published state
    var currentCard: DynamicCardType?
    
    // Actions
    func evaluate() -> DynamicCardType
    func refresh()
}

---

PRIORITY ORDER (highest first):

1. STREAK AT RISK (Priority 100)
   Condition: After 6pm, goal not met, streak > 0
   Card: .streakAtRisk(currentStreak: N)

2. GOAL VERY CLOSE (Priority 90)
   Condition: Steps remaining ≤ 500
   Card: .goalClose(stepsRemaining: N)

3. RANK MILESTONE CLOSE (Priority 80)
   Condition: Walks to next rank ≤ 3
   Card: .rankClose(walksRemaining: N, nextRank: rank)

4. CHALLENGE EXPIRING SOON (Priority 70)
   Condition: Date-specific challenge, ≤ 2 days left, not complete
   Card: .challengeExpiring(challenge, daysLeft: N)

5. CHALLENGE ALMOST COMPLETE (Priority 60)
   Condition: Any challenge ≥ 80% complete
   Card: .challengeAlmostComplete(challenge, percentComplete: N)

6. NEW MONTH CHALLENGES (Priority 50)
   Condition: Days 1-3 of month
   Card: .newChallenges

7. DEFAULT: RANK PROGRESS (Priority 0)
   Card: .rankProgress(currentRank, walksToNext: N)

---

EVALUATION LOGIC:

func evaluate() -> DynamicCardType {
    let now = Date()
    let hour = Calendar.current.component(.hour, from: now)
    let dayOfMonth = Calendar.current.component(.day, from: now)
    let goal = persistence.loadUserProfile().dailyStepGoal
    let stepsRemaining = goal - healthKit.todaySteps
    
    // 1. Streak at risk
    if hour >= 18 && stepsRemaining > 0 && streak.currentStreak > 0 {
        return .streakAtRisk(currentStreak: streak.currentStreak)
    }
    
    // 2. Goal very close
    if stepsRemaining > 0 && stepsRemaining <= 500 {
        return .goalClose(stepsRemaining: stepsRemaining)
    }
    
    // 3. Rank milestone close
    if rank.walksToNextRank <= 3 && rank.walksToNextRank > 0 {
        return .rankClose(
            walksRemaining: rank.walksToNextRank,
            nextRank: rank.currentRank.nextRank!
        )
    }
    
    // 4. Challenge expiring
    // ... check date-specific challenges
    
    // 5. Challenge almost complete
    // ... check progress >= 0.8
    
    // 6. New month challenges
    if dayOfMonth <= 3 {
        return .newChallenges
    }
    
    // 7. Default
    return .rankProgress(
        currentRank: rank.currentRank,
        walksToNext: rank.walksToNextRank
    )
}

---

PROVIDE:
1. Complete DynamicCardEngine class
2. Full priority evaluation logic
3. All card type determinations

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-8: Subscription Manager (StoreKit 2)

```
Create the subscription management system using StoreKit 2.

OVERVIEW:
- Pro subscription: $39.99/year or $7.99/month
- 7-day free trial for annual
- Gate Pro features, not data
- Handle purchase, restore, subscription status

---

SUBSCRIPTION MANAGER:

@Observable
class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    // Product IDs
    static let annualProductId = "com.justwalk.pro.annual"
    static let monthlyProductId = "com.justwalk.pro.monthly"
    
    // Published state
    var isProActive: Bool = false
    var products: [Product] = []
    var purchaseInProgress: Bool = false
    var subscriptionStatus: SubscriptionStatus = .none
    
    enum SubscriptionStatus {
        case none
        case trial(expiresAt: Date)
        case active(expiresAt: Date, isAnnual: Bool)
        case expired
        case grace(expiresAt: Date)
    }
    
    // Initialization
    func loadProducts() async
    func checkSubscriptionStatus() async
    
    // Purchases
    func purchase(_ product: Product) async throws -> Transaction?
    func restorePurchases() async
    
    // Transaction handling
    func handleTransactionUpdates() async
    
    // Pro feature checks
    var canUseIntervals: Bool { isProActive }
    var canUseVibeGoals: Bool { isProActive }  // "Vibe" = time-based relaxed goals
    var canUseMapThemes: Bool { isProActive }
}

---

PRO FEATURES (What's Gated):

✓ Interval Walks (variable pace programs)
✓ Vibe Goals (time-based, relaxed targets)
✓ Map Themes (line colors, dark mode toggle)
✓ Advanced Stats (future: My Patterns)

NOT Gated (Free forever):
- All walking data
- Rank progression
- Challenges
- Streaks
- Basic goals (steps, distance)
- Core app functionality

---

STOREKIT 2 IMPLEMENTATION:

1. Product Loading:
   - Use Product.products(for:) with product IDs
   - Store in products array

2. Purchase Flow:
   - Call product.purchase()
   - Handle PurchaseResult
   - Verify transaction
   - Update isProActive

3. Subscription Status:
   - Use Transaction.currentEntitlements
   - Check for active subscription
   - Handle trial period
   - Handle grace period

4. Transaction Updates:
   - Listen for Transaction.updates
   - Handle renewals, cancellations, refunds

---

PERSISTENCE:

- Store subscription status in UserDefaults (as backup)
- Always verify with StoreKit on launch
- Sync proSubscriptionActive in UserProfile

---

PROVIDE:
1. Complete SubscriptionManager class
2. StoreKit 2 product loading
3. Purchase flow implementation
4. Subscription status checking
5. Transaction listener setup

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### F-9: Animation Coordinator

```
Create the centralized animation system for Just Walk.

OVERVIEW:
- Define all animation timing curves
- Provide reusable animation modifiers
- Coordinate haptic feedback
- Support staggered animations

---

ANIMATION COORDINATOR:

struct JustWalkAnimation {
    // Micro-interactions (button feedback, toggles)
    static let micro = Animation.snappy(duration: 0.18)
    
    // Standard transitions (cards appearing, state changes)
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    // Emphasis (celebrations, rank up, goal complete)
    static let emphasis = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    // Morphing (sheet presentations, glass transitions)
    static let morph = Animation.smooth(duration: 0.35)
    
    // Counting numbers
    static let counter = Animation.spring(response: 0.4, dampingFraction: 0.8)
    
    // Staggered lists
    static func stagger(index: Int, baseDelay: Double = 0.05) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
        .delay(Double(index) * baseDelay)
    }
    
    // Ring fill
    static let ringFill = Animation.easeOut(duration: 1.0)
    
    // Confetti burst
    static let confetti = Animation.spring(response: 0.3, dampingFraction: 0.5)
}

---

HAPTIC COORDINATOR:

struct JustWalkHaptics {
    static func buttonTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func goalComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func rankUp() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred(intensity: 0.7)
        }
    }
    
    static func fiveMinuteMilestone() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func intervalPhaseChange() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    
    static func streakIncrement() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    static func challengeComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

---

VIEW MODIFIERS:

// Tap feedback for all interactive elements
struct TapFeedbackModifier: ViewModifier {
    @State private var pressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(JustWalkAnimation.micro, value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in 
                        if !pressed {
                            pressed = true
                            JustWalkHaptics.buttonTap()
                        }
                    }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    func tapFeedback() -> some View {
        modifier(TapFeedbackModifier())
    }
}

// Card lift effect
struct CardLiftModifier: ViewModifier {
    var isHighlighted: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHighlighted ? 0.2 : 0.1),
                radius: isHighlighted ? 12 : 6,
                y: isHighlighted ? 6 : 3
            )
            .animation(JustWalkAnimation.standard, value: isHighlighted)
    }
}

extension View {
    func cardLift(isHighlighted: Bool) -> some View {
        modifier(CardLiftModifier(isHighlighted: isHighlighted))
    }
}

// Staggered appearance
struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var appeared = false
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(JustWalkAnimation.stagger(index: index), value: appeared)
            .onAppear { appeared = true }
    }
}

extension View {
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }
}

---

ANIMATED COUNTER VIEW:

struct AnimatedCounter: View {
    let value: Int
    let format: String // e.g., "%d" or "%.1f mi"
    
    var body: some View {
        Text(String(format: format, value))
            .contentTransition(.numericText())
            .animation(JustWalkAnimation.counter, value: value)
    }
}

---

CONFETTI VIEW:

struct ConfettiView: View {
    @Binding var isActive: Bool
    let colors: [Color] = [.teal, .yellow, .orange, .pink, .purple]
    
    var body: some View {
        // Implement particle system with falling confetti
        // Use Canvas for performance
        // 50-100 particles, random colors, physics-based fall
    }
}

---

PROVIDE:
1. JustWalkAnimation struct with all timing curves
2. JustWalkHaptics struct with all feedback types
3. TapFeedbackModifier
4. CardLiftModifier
5. StaggeredAppearance modifier
6. AnimatedCounter view
7. ConfettiView (basic particle system)

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

## UI Prompts

### U-1: Onboarding Flow

```
Create the onboarding experience for Just Walk with Hub & Spoke paywall.

OVERVIEW:
- Fast, focused onboarding (5 screens max before walking)
- System permission dialogs directly (no pre-permission screens)
- Hub & Spoke paywall design
- iOS 26 Liquid Glass styling

---

ONBOARDING FLOW:

Screen 1: WELCOME
- Hero image or animation (walker silhouette)
- "Just Walk"
- "Build the habit. Become a walker."
- [Get Started] button with glass effect

Screen 2: DAILY GOAL
- "What's your daily step goal?"
- Wheel picker: 4,000 / 5,000 / 6,000 / 7,500 / 10,000
- Default selection: 6,000
- Subtext: "Start small. You can always adjust later."
- [Continue]

Screen 3: PERMISSIONS (Sequential)
- Trigger HealthKit authorization (system dialog)
- On success, trigger Location authorization (system dialog)
- On success, trigger Notification authorization (system dialog)
- No custom pre-permission screens - go straight to system

Screen 4: PRO PAYWALL (Hub & Spoke)
- Can be skipped with [Maybe Later]

Screen 5: READY
- "You're all set!"
- Show step ring at 0%
- "Let's take your first walk."
- [Let's Go] → Navigate to Walk tab

---

HUB & SPOKE PAYWALL DESIGN:

Hub (Main Paywall View):
┌─────────────────────────────────────────┐
│                                         │
│     🚶 Become the walker                │
│        you want to be                   │
│                                         │
│  ┌─────────────┐  ┌─────────────┐      │
│  │ 🎯          │  │ 🗺️          │      │
│  │ Interval    │  │ Map         │      │
│  │ Training    │  │ Themes      │      │
│  │             │  │             │      │
│  │ [Learn More]│  │ [Learn More]│      │
│  └─────────────┘  └─────────────┘      │
│                                         │
│  ┌─────────────┐  ┌─────────────┐      │
│  │ 🧘          │  │ 📊          │      │
│  │ Vibe        │  │ My          │      │
│  │ Goals       │  │ Patterns    │      │
│  │             │  │ (Coming)    │      │
│  │ [Learn More]│  │             │      │
│  └─────────────┘  └─────────────┘      │
│                                         │
│    ┌─────────────────────────────┐     │
│    │  Try Pro Free for 7 Days   │     │
│    └─────────────────────────────┘     │
│                                         │
│    $39.99/year  ·  $7.99/month         │
│                                         │
│    [Maybe Later]                        │
│                                         │
└─────────────────────────────────────────┘

Spoke (Feature Detail Sheet):
- Tappable cards open .sheet() with detail
- Visual preview of feature
- 2-3 value bullets
- "Included in Pro" badge
- [Back to Pro] button

---

PAYWALL FEATURE CARDS:

1. Interval Training
   - Icon: figure.walk.motion
   - Preview: Phase diagram animation
   - Bullets:
     • Variable-pace walks with voice cues
     • "Japanese Method" (3 min brisk / 3 min easy)
     • Build endurance naturally

2. Map Themes
   - Icon: map.fill
   - Preview: Route line color swatches
   - Bullets:
     • Customize your route line color
     • Always-dark map option
     • Make your walks feel personal

3. Vibe Goals
   - Icon: leaf.fill
   - Preview: Relaxed goal picker
   - Bullets:
     • "Just 10 minutes" time goals
     • No step counting pressure
     • Perfect for mindful walks

4. My Patterns (Coming Soon)
   - Icon: chart.bar.fill
   - Preview: Insight card mockup
   - Bullets:
     • "Morning Lark" or "Night Owl"
     • See your natural walking rhythm
     • Personalized insights

---

ANIMATIONS:

- Welcome: Hero image fades in with slight scale
- Goal picker: Smooth haptic feedback on selection
- Permissions: Smooth transition between permission prompts
- Paywall cards: Staggered entrance
- Feature sheets: Morph from card (iOS 26 navigationZoom)
- Ready screen: Ring animates from 0

---

PROVIDE:
1. OnboardingCoordinator (navigation state)
2. WelcomeView
3. DailyGoalPickerView
4. PermissionsView (triggers system dialogs)
5. ProPaywallView (Hub)
6. FeatureDetailSheet (Spoke template)
7. OnboardingCompleteView

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### U-2: Today Screen

```
Create the Today screen - the app's home tab.

OVERVIEW:
- Central step ring (hero element)
- Streak display with day indicators
- Week chart showing last 7 days
- Single dynamic card (context-aware)
- iOS 26 Liquid Glass navigation

---

LAYOUT:

NavigationStack {
    ScrollView {
        VStack(spacing: 24) {
            // 1. Step Ring (hero)
            StepRingView()
            
            // 2. Streak Badge
            StreakBadgeView()
            
            // 3. Week Chart
            WeekChartView()
            
            // 4. Dynamic Card
            DynamicCardView()
        }
        .padding()
    }
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
            }
        }
    }
}

---

STEP RING VIEW:

- 220pt diameter, 18pt stroke width
- Teal gradient fill (animated on appear)
- Center shows: current steps / goal
- Below ring: "X steps to go" or "Goal reached! 🎉"
- Ring fills with JustWalkAnimation.ringFill

struct StepRingView: View {
    @Environment(HealthKitManager.self) var healthKit
    @Environment(PersistenceManager.self) var persistence
    
    var progress: Double {
        min(1.0, Double(healthKit.todaySteps) / Double(goal))
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)
            
            // Progress ring (animated)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.teal, .teal.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(JustWalkAnimation.ringFill, value: progress)
            
            // Center content
            VStack(spacing: 4) {
                AnimatedCounter(value: healthKit.todaySteps, format: "%d")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("of \(goal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }
}

---

STREAK BADGE VIEW:

- Flame icon with current streak count
- "X day streak" text
- Week day indicators (M T W T F S S)
- Filled circles for goal-met days
- Animate badge on streak increment

---

WEEK CHART VIEW:

- Last 7 days as vertical bars
- Today highlighted
- Tap bar to see exact steps
- Bars animate with staggered entrance
- Height = percentage of goal (capped at 100%)

---

DYNAMIC CARD VIEW:

- Single card based on DynamicCardEngine.currentCard
- Each card type has unique design:
  
  .streakAtRisk: Red accent, warning icon
  .goalClose: Teal accent, progress bar
  .rankClose: Gold accent, rank icon
  .challengeExpiring: Orange accent, timer
  .challengeAlmostComplete: Green accent, progress
  .newChallenges: Purple accent, sparkle
  .rankProgress: Teal accent, journey preview

- All cards have tap action (navigate to relevant screen)
- Cards use .tapFeedback() modifier

---

ANIMATIONS:

1. On appear:
   - Ring fills with progress
   - Streak badge fades in
   - Week bars grow from bottom (staggered)
   - Dynamic card slides up

2. On data change:
   - Step count animates (contentTransition)
   - Ring progress animates
   - If streak changes, badge bounces

---

PROVIDE:
1. TodayView (main container)
2. StepRingView
3. StreakBadgeView
4. WeekChartView
5. DynamicCardView (with all card type variants)

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### U-3: Walk Tab (Idle + Active + Intervals)

```
Create the Walk tab with idle, active, and interval states.

OVERVIEW:
- Idle: Dark map, "Let's Go" button, goal picker, intervals toggle (Pro)
- Active: Live stats, route drawing, controls
- Interval: Phase indicator, pace display, voice cues
- iOS 26 Liquid Glass floating controls
- Smooth state transitions (morphing, not replacing)

---

STATE MACHINE:

enum WalkTabState {
    case idle
    case active(WalkMode)
    case paused
    case ending // brief transition state
}

---

IDLE STATE LAYOUT:

ZStack {
    // Dark map (default)
    Map(...)
        .mapStyle(.imagery)  // Dark satellite/hybrid
        .ignoresSafeArea()
    
    // Bottom panel (Liquid Glass)
    VStack {
        Spacer()
        
        GlassEffectContainer {
            VStack(spacing: 16) {
                // Quick start
                Button("Let's Go") {
                    startWalk(mode: .free)
                }
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassEffect(.regular.tint(.teal).interactive())
                
                // Options row
                HStack(spacing: 12) {
                    Button("Set a Goal") {
                        showGoalPicker = true
                    }
                    .glassEffect(.regular.interactive())
                    
                    if subscriptionManager.canUseIntervals {
                        Button("Intervals") {
                            showIntervalPicker = true
                        }
                        .glassEffect(.regular.interactive())
                    } else {
                        Button("Intervals 🔒") {
                            showPaywall = true
                        }
                        .glassEffect(.clear.interactive())
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}

---

GOAL PICKER SHEET:

.sheet presentation with three goal types:

1. Steps: 1,000 / 2,000 / 3,000 / 5,000 / Custom
2. Distance: 0.5 mi / 1 mi / 2 mi / 3 mi / Custom
3. Duration: 10 min / 15 min / 20 min / 30 min / Custom

Sheet uses iOS 26 Liquid Glass background automatically.
Selecting a goal starts the walk immediately.

---

INTERVAL PICKER SHEET (Pro):

Pre-built programs:
1. "Beginner" - 2 min brisk / 3 min easy × 4
2. "Japanese Method" - 3 min brisk / 3 min easy × 5
3. "Endurance Builder" - 4 min brisk / 2 min easy × 5
4. "Quick Burst" - 1 min brisk / 1 min easy × 10

Show total duration for each.
Selecting a program starts the walk immediately.

---

ACTIVE STATE LAYOUT:

ZStack {
    // Map with route
    Map(...) {
        // Draw polyline of currentRoute
        MapPolyline(coordinates: walkSession.currentRoute)
            .stroke(.teal, lineWidth: 4)
    }
    .mapStyle(.imagery)
    .ignoresSafeArea()
    
    // Top stats panel (Liquid Glass)
    VStack {
        GlassEffectContainer {
            HStack(spacing: 24) {
                StatView(label: "Time", value: formattedDuration)
                StatView(label: "Steps", value: "\(walkSession.currentSteps)")
                StatView(label: "Distance", value: formattedDistance)
            }
            .padding()
        }
        .padding()
        
        Spacer()
        
        // 5-minute indicator (appears after 5 min)
        if walkSession.qualifiesForRank {
            Text("✓ Counts toward rank")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular.tint(.green))
        }
        
        // Goal progress (if goal mode)
        if case .goal = walkSession.walkMode {
            GoalProgressBar(progress: walkSession.goalProgress)
        }
        
        // Interval indicator (if interval mode)
        if case .interval = walkSession.walkMode {
            IntervalPhaseView(
                phase: walkSession.currentIntervalPhase,
                pace: walkSession.currentIntervalPace,
                timeRemaining: walkSession.phaseTimeRemaining
            )
        }
        
        // Bottom controls (Liquid Glass)
        GlassEffectContainer {
            HStack(spacing: 20) {
                Button(action: togglePause) {
                    Image(systemName: walkSession.state == .paused ? "play.fill" : "pause.fill")
                        .font(.title)
                }
                .glassEffect(.regular.interactive())
                
                Button(action: endWalk) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                }
                .glassEffect(.regular.tint(.red).interactive())
            }
            .padding()
        }
        .padding()
    }
}

---

INTERVAL PHASE VIEW:

VStack(spacing: 8) {
    // Pace indicator
    Text(walkSession.currentIntervalPace == .brisk ? "BRISK" : "EASY")
        .font(.title.bold())
        .foregroundStyle(walkSession.currentIntervalPace == .brisk ? .orange : .teal)
    
    // Phase countdown
    Text(formatTime(walkSession.phaseTimeRemaining))
        .font(.system(size: 32, design: .monospaced))
    
    // Phase dots (which phase are we on)
    HStack(spacing: 6) {
        ForEach(0..<totalPhases, id: \.self) { index in
            Circle()
                .fill(index <= walkSession.currentIntervalPhase ? Color.teal : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
}
.padding()
.glassEffect()

---

STATE TRANSITIONS (Intentional Elegance):

1. Idle → Active:
   - "Let's Go" button morphs into top stats panel
   - Controls slide up from bottom
   - Map zooms to user location

2. Active → Paused:
   - Play/pause button animates icon change
   - Stats panel dims slightly

3. Active → Ending:
   - Controls collapse
   - Map zooms out to show full route
   - Transition to PostWalkSummary

---

VOICE CUES (Intervals):

When interval phase changes:
- AVSpeechSynthesizer announces: "Brisk pace" or "Easy pace"
- Also trigger JustWalkHaptics.intervalPhaseChange()

---

PROVIDE:
1. WalkTabView (state machine container)
2. IdleWalkPanel
3. GoalPickerSheet
4. IntervalPickerSheet
5. ActiveWalkPanel
6. IntervalPhaseView
7. Walk controls with Liquid Glass
8. State transition animations
9. Voice cue implementation

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### U-4: Post-Walk Summary

```
Create the post-walk summary screen.

OVERVIEW:
- Appears after every walk ends
- Shows stats, map, achievements
- Confetti for qualifying walks (≥5 min)
- Animated entrance of all elements

---

LAYOUT:

NavigationStack {
    ScrollView {
        VStack(spacing: 24) {
            // Hero: "Walk Complete!" with checkmark
            HeroSection()
            
            // Stats grid
            StatsGrid(walk: walk)
            
            // Map with route
            RouteMapView(route: walk.route)
            
            // Achievements earned (if any)
            if !achievements.isEmpty {
                AchievementsSection(achievements: achievements)
            }
            
            // Rank progress (if qualified)
            if walk.qualifiesForRank {
                RankProgressSection()
            }
            
            // Done button
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding()
    }
    .overlay {
        if showConfetti {
            ConfettiView(isActive: $showConfetti)
        }
    }
}

---

HERO SECTION:

VStack(spacing: 12) {
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.teal)
        .symbolEffect(.bounce, value: appeared)
    
    Text("Walk Complete!")
        .font(.title.bold())
}

---

STATS GRID:

LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    StatCard(label: "Duration", value: formatDuration(walk.duration), icon: "clock")
    StatCard(label: "Steps", value: "\(walk.steps)", icon: "figure.walk")
    StatCard(label: "Distance", value: formatDistance(walk.distance), icon: "map")
    StatCard(label: "Calories", value: "\(walk.calories)", icon: "flame")
}

Each StatCard animates in with staggeredAppearance(index:)

---

ROUTE MAP VIEW:

Map {
    MapPolyline(coordinates: walk.route)
        .stroke(.teal, lineWidth: 4)
    
    // Start marker
    Annotation("Start", coordinate: walk.route.first!) {
        Circle().fill(.green).frame(width: 12, height: 12)
    }
    
    // End marker
    Annotation("End", coordinate: walk.route.last!) {
        Circle().fill(.red).frame(width: 12, height: 12)
    }
}
.frame(height: 200)
.clipShape(RoundedRectangle(cornerRadius: 16))
.mapStyle(.imagery) // Dark map

---

ACHIEVEMENTS SECTION:

VStack(alignment: .leading, spacing: 12) {
    Text("Achievements")
        .font(.headline)
    
    ForEach(achievements, id: \.self) { achievement in
        HStack {
            Image(systemName: achievement.icon)
                .foregroundStyle(.yellow)
            Text(achievement.title)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

Possible achievements:
- "First Walk!" (if totalQualifyingWalks == 1)
- "Counts Toward Rank" (if duration >= 5 min)
- "Rank Up!" (if rank increased)
- "Challenge Complete" (if any challenge completed)
- "Daily Goal Reached" (if hit goal during walk)
- "Streak Extended" (if streak incremented)

---

RANK PROGRESS SECTION (if walk qualified):

VStack(spacing: 8) {
    HStack {
        Text("Rank Progress")
            .font(.headline)
        Spacer()
        Text("+1 walk")
            .foregroundStyle(.teal)
    }
    
    // Progress bar to next rank
    ProgressView(value: rankManager.progressToNextRank)
        .tint(.teal)
    
    Text("\(rankManager.walksToNextRank) walks to \(rankManager.currentRank.nextRank?.title ?? "max")")
        .font(.caption)
        .foregroundStyle(.secondary)
}

---

SHORT WALK HANDLING (< 5 min):

If walk.duration < 300:
- No confetti
- Replace rank progress with education:

VStack(spacing: 8) {
    Text("Quick Walk!")
        .font(.headline)
    Text("Walks of 5 minutes or more count toward your rank. Every step counts toward your daily goal!")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
}

This is gentle education, not shame.

---

ANIMATIONS:

1. On appear:
   - Hero section: checkmark bounces in
   - Stats: staggered fade + slide up
   - Map: fades in after stats
   - Achievements: pop in one by one
   - Confetti starts (if qualifying walk)

2. Confetti:
   - 50-100 particles
   - Colors: teal, yellow, orange, pink
   - Duration: 3 seconds
   - Physics-based fall

3. Haptics:
   - JustWalkHaptics.goalComplete() when view appears

---

PROVIDE:
1. PostWalkSummaryView
2. HeroSection
3. StatsGrid with StatCard
4. RouteMapView
5. AchievementsSection
6. RankProgressSection
7. ShortWalkEducation
8. ConfettiView (full implementation)

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### U-9: Liquid Glass Components

```
Create reusable iOS 26 Liquid Glass components for Just Walk.

OVERVIEW:
- Shared glass components used across the app
- Follows Apple's "glass only for navigation layer" principle
- Consistent styling and behavior

---

GLASS DESIGN TOKENS:

enum GlassTokens {
    enum Radius {
        static let card: CGFloat = 28
        static let pill: CGFloat = 999
        static let sheet: CGFloat = 34
        static let control: CGFloat = 16
    }
    
    enum Padding {
        static let card = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        static let pill = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        static let control: CGFloat = 12
    }
}

---

FLOATING ACTION BUTTON:

struct FloatingGlassButton: View {
    let title: String
    let icon: String?
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .glassEffect(.regular.tint(tint).interactive())
        .tapFeedback()
    }
}

---

GLASS ICON BUTTON:

struct GlassIconButton: View {
    let systemName: String
    let tint: Color?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .glassEffect(tint.map { .regular.tint($0).interactive() } ?? .regular.interactive())
        .tapFeedback()
    }
}

---

GLASS CONTROL GROUP:

struct GlassControlGroup<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        GlassEffectContainer {
            content
        }
    }
}

// Usage:
GlassControlGroup {
    HStack(spacing: 16) {
        GlassIconButton(systemName: "pause.fill", tint: nil) { ... }
        GlassIconButton(systemName: "stop.fill", tint: .red) { ... }
    }
    .padding()
}

---

GLASS STAT PILL:

struct GlassStatPill: View {
    let label: String
    let value: String
    let icon: String?
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.clear)
    }
}

---

GLASS BADGE:

struct GlassBadge: View {
    let text: String
    let icon: String?
    let tint: Color
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(tint))
    }
}

---

GLASS CARD BACKGROUND:

// Note: This is NOT a glass effect - it's for content cards
// Glass should only be on navigation/floating elements
struct ContentCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(GlassTokens.Padding.card)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
    }
}

---

FLOATING BOTTOM PANEL:

struct FloatingBottomPanel<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack {
            Spacer()
            
            GlassEffectContainer {
                content
                    .padding()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

---

TOP STATS BAR:

struct TopStatsBar: View {
    let stats: [(label: String, value: String)]
    
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    if index > 0 {
                        Divider()
                            .frame(height: 30)
                    }
                    
                    VStack(spacing: 2) {
                        Text(stat.value)
                            .font(.title3.bold())
                        Text(stat.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
    }
}

---

GLASS SHEET PRESENTATION:

// For partial-height sheets with glass background
// iOS 26 does this automatically, but here's how to customize:

extension View {
    func glassSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: [PresentationDetent] = [.medium],
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                // iOS 26: glass background is automatic for partial sheets
        }
    }
}

---

PROVIDE:
1. GlassTokens enum
2. FloatingGlassButton
3. GlassIconButton
4. GlassControlGroup
5. GlassStatPill
6. GlassBadge
7. ContentCard (non-glass, for content)
8. FloatingBottomPanel
9. TopStatsBar
10. glassSheet view modifier

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### U-10: Live Activities

```
Create Live Activities for walk tracking using WidgetKit.

OVERVIEW:
- Shows walk progress on Lock Screen and Dynamic Island
- Updates in real-time during walk
- Supports both regular walks and intervals
- iOS 26 Liquid Glass styling

---

WIDGET EXTENSION SETUP:

Create a new Widget Extension target: "JustWalkLiveActivity"

Required files:
- JustWalkLiveActivity.swift
- JustWalkWidgetBundle.swift (if not already created)
- Info.plist with NSSupportsLiveActivities = YES

---

ACTIVITY ATTRIBUTES:

struct WalkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var steps: Int
        var distance: Double // meters
        var goalProgress: Double? // 0-1, nil if no goal
        var goalType: String? // "steps", "distance", "duration"
        var goalTarget: String? // "5,000 steps", "1 mile", etc.
        
        // Interval-specific
        var isIntervalWalk: Bool
        var currentPace: String? // "BRISK" or "EASY"
        var phaseTimeRemaining: TimeInterval?
        var currentPhase: Int?
        var totalPhases: Int?
    }
    
    var walkMode: String // "free", "goal", "interval"
    var startTime: Date
}

---

LIVE ACTIVITY VIEWS:

// Lock Screen (Expanded)
struct WalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>
    
    var body: some View {
        HStack {
            // Left: Walk icon
            Image(systemName: "figure.walk")
                .font(.title)
                .foregroundStyle(.teal)
            
            VStack(alignment: .leading) {
                Text(formatDuration(context.state.elapsedTime))
                    .font(.title2.bold())
                Text("\(context.state.steps) steps · \(formatDistance(context.state.distance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Right: Goal progress or interval phase
            if let progress = context.state.goalProgress {
                CircularProgressView(progress: progress)
                    .frame(width: 44, height: 44)
            } else if context.state.isIntervalWalk {
                IntervalIndicator(
                    pace: context.state.currentPace ?? "EASY",
                    timeRemaining: context.state.phaseTimeRemaining ?? 0
                )
            }
        }
        .padding()
    }
}

// Dynamic Island (Compact)
struct WalkCompactLeadingView: View {
    let context: ActivityViewContext<WalkActivityAttributes>
    
    var body: some View {
        Image(systemName: "figure.walk")
            .foregroundStyle(.teal)
    }
}

struct WalkCompactTrailingView: View {
    let context: ActivityViewContext<WalkActivityAttributes>
    
    var body: some View {
        Text(formatDuration(context.state.elapsedTime))
            .font(.caption.monospacedDigit())
    }
}

// Dynamic Island (Expanded)
struct WalkExpandedView: View {
    let context: ActivityViewContext<WalkActivityAttributes>
    
    var body: some View {
        VStack {
            HStack {
                Text(formatDuration(context.state.elapsedTime))
                    .font(.title.bold())
                Spacer()
                if context.state.isIntervalWalk, let pace = context.state.currentPace {
                    Text(pace)
                        .font(.caption.bold())
                        .foregroundStyle(pace == "BRISK" ? .orange : .teal)
                }
            }
            
            HStack(spacing: 16) {
                Label("\(context.state.steps)", systemImage: "figure.walk")
                Label(formatDistance(context.state.distance), systemImage: "map")
                
                if let progress = context.state.goalProgress {
                    Label("\(Int(progress * 100))%", systemImage: "target")
                }
            }
            .font(.caption)
        }
        .padding()
    }
}

---

ACTIVITY CONFIGURATION:

struct WalkActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Lock Screen view
            WalkLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    WalkCompactLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WalkCompactTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    WalkExpandedView(context: context)
                }
            } compactLeading: {
                WalkCompactLeadingView(context: context)
            } compactTrailing: {
                WalkCompactTrailingView(context: context)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.teal)
            }
        }
    }
}

---

LIVE ACTIVITY MANAGER:

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<WalkActivityAttributes>?
    
    func startActivity(mode: WalkMode) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = WalkActivityAttributes(
            walkMode: mode.description,
            startTime: Date()
        )
        
        let initialState = WalkActivityAttributes.ContentState(
            elapsedTime: 0,
            steps: 0,
            distance: 0,
            goalProgress: nil,
            goalType: nil,
            goalTarget: nil,
            isIntervalWalk: mode.isInterval,
            currentPace: mode.isInterval ? "EASY" : nil,
            phaseTimeRemaining: nil,
            currentPhase: nil,
            totalPhases: nil
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
        } catch {
            print("Error starting Live Activity: \(error)")
        }
    }
    
    func updateActivity(
        elapsedTime: TimeInterval,
        steps: Int,
        distance: Double,
        goalProgress: Double?,
        intervalState: IntervalState?
    ) async {
        guard let activity = currentActivity else { return }
        
        let updatedState = WalkActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            steps: steps,
            distance: distance,
            goalProgress: goalProgress,
            goalType: nil, // Set if goal mode
            goalTarget: nil,
            isIntervalWalk: intervalState != nil,
            currentPace: intervalState?.pace,
            phaseTimeRemaining: intervalState?.timeRemaining,
            currentPhase: intervalState?.currentPhase,
            totalPhases: intervalState?.totalPhases
        )
        
        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
    }
    
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}

struct IntervalState {
    let pace: String
    let timeRemaining: TimeInterval
    let currentPhase: Int
    let totalPhases: Int
}

---

INTEGRATION WITH WALKSESSIONMANAGER:

In WalkSessionManager, add Live Activity calls:

func startWalk(mode: WalkMode) {
    // ... existing code ...
    
    Task {
        await LiveActivityManager.shared.startActivity(mode: mode)
    }
}

// In timer update (every second):
func updateMetrics() {
    // ... existing code ...
    
    Task {
        await LiveActivityManager.shared.updateActivity(
            elapsedTime: elapsedTime,
            steps: currentSteps,
            distance: currentDistance,
            goalProgress: goalProgress,
            intervalState: getIntervalState()
        )
    }
}

func endWalk() -> TrackedWalk {
    // ... existing code ...
    
    Task {
        await LiveActivityManager.shared.endActivity()
    }
    
    return walk
}

---

PROVIDE:
1. WalkActivityAttributes
2. WalkLockScreenView
3. Dynamic Island views (compact, expanded)
4. WalkActivityWidget configuration
5. LiveActivityManager
6. Integration points for WalkSessionManager

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### L-2: Interval Manager

```
Create the interval walk management system.

OVERVIEW:
- Pre-built interval programs
- State machine for phase transitions
- Voice announcements
- Haptic feedback on phase changes

---

INTERVAL MANAGER:

@Observable
class IntervalManager {
    static let shared = IntervalManager()
    
    // State
    var isActive: Bool = false
    var currentProgram: IntervalProgram?
    var currentPhaseIndex: Int = 0
    var phaseTimeRemaining: TimeInterval = 0
    var currentPace: IntervalPace = .easy
    
    // Computed
    var totalPhases: Int {
        currentProgram?.phases.count ?? 0
    }
    
    var currentPhase: IntervalPhase? {
        guard let program = currentProgram,
              currentPhaseIndex < program.phases.count else { return nil }
        return program.phases[currentPhaseIndex]
    }
    
    var progressInProgram: Double {
        guard let program = currentProgram else { return 0 }
        let completedTime = program.phases.prefix(currentPhaseIndex)
            .reduce(0) { $0 + $1.duration }
        let currentPhaseProgress = (currentPhase?.duration ?? 0) - phaseTimeRemaining
        return (completedTime + currentPhaseProgress) / program.totalDuration
    }
    
    // Speech
    private let synthesizer = AVSpeechSynthesizer()
    
    // Actions
    func start(program: IntervalProgram)
    func tick() // Called every second
    func pause()
    func resume()
    func stop()
    
    // Internal
    private func advancePhase()
    private func announcePhase(_ pace: IntervalPace)
}

---

PRE-BUILT PROGRAMS:

struct IntervalPrograms {
    static let beginner = IntervalProgram(
        id: UUID(),
        name: "Beginner",
        phases: [
            // 2 min brisk, 3 min easy × 4 = 20 minutes
            IntervalPhase(pace: .brisk, duration: 120),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 120),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 120),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 120),
            IntervalPhase(pace: .easy, duration: 180),
        ]
    )
    
    static let japaneseMethod = IntervalProgram(
        id: UUID(),
        name: "Japanese Method",
        phases: [
            // 3 min brisk, 3 min easy × 5 = 30 minutes
            IntervalPhase(pace: .brisk, duration: 180),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 180),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 180),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 180),
            IntervalPhase(pace: .easy, duration: 180),
            IntervalPhase(pace: .brisk, duration: 180),
            IntervalPhase(pace: .easy, duration: 180),
        ]
    )
    
    static let enduranceBuilder = IntervalProgram(
        id: UUID(),
        name: "Endurance Builder",
        phases: [
            // 4 min brisk, 2 min easy × 5 = 30 minutes
            IntervalPhase(pace: .brisk, duration: 240),
            IntervalPhase(pace: .easy, duration: 120),
            IntervalPhase(pace: .brisk, duration: 240),
            IntervalPhase(pace: .easy, duration: 120),
            IntervalPhase(pace: .brisk, duration: 240),
            IntervalPhase(pace: .easy, duration: 120),
            IntervalPhase(pace: .brisk, duration: 240),
            IntervalPhase(pace: .easy, duration: 120),
            IntervalPhase(pace: .brisk, duration: 240),
            IntervalPhase(pace: .easy, duration: 120),
        ]
    )
    
    static let quickBurst = IntervalProgram(
        id: UUID(),
        name: "Quick Burst",
        phases: [
            // 1 min brisk, 1 min easy × 10 = 20 minutes
            // ... generate 20 phases
        ]
    )
    
    static let all: [IntervalProgram] = [
        beginner,
        japaneseMethod,
        enduranceBuilder,
        quickBurst
    ]
}

---

PHASE TRANSITION LOGIC:

func tick() {
    guard isActive, currentProgram != nil else { return }
    
    phaseTimeRemaining -= 1
    
    if phaseTimeRemaining <= 0 {
        advancePhase()
    }
}

private func advancePhase() {
    currentPhaseIndex += 1
    
    guard let program = currentProgram,
          currentPhaseIndex < program.phases.count else {
        // Program complete
        stop()
        return
    }
    
    let nextPhase = program.phases[currentPhaseIndex]
    currentPace = nextPhase.pace
    phaseTimeRemaining = nextPhase.duration
    
    // Announce and haptic
    announcePhase(nextPhase.pace)
    JustWalkHaptics.intervalPhaseChange()
}

---

VOICE ANNOUNCEMENTS:

private func announcePhase(_ pace: IntervalPace) {
    let text: String
    switch pace {
    case .brisk:
        text = "Brisk pace"
    case .easy:
        text = "Easy pace"
    }
    
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    utterance.volume = 1.0
    
    synthesizer.speak(utterance)
}

---

AUDIO SESSION:

Configure audio session to allow voice cues over other audio:

func configureAudioSession() {
    do {
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .voicePrompt,
            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        print("Audio session configuration failed: \(error)")
    }
}

---

PROVIDE:
1. IntervalManager class
2. IntervalPrograms static library
3. Phase transition logic
4. Voice announcement system
5. Audio session configuration

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

### I-2: Notifications (Quiet Partner)

```
Create the notification system with "Quiet Partner" persona.

OVERVIEW:
- Supportive, not pushy
- Specific copy for each notification type
- Respects notification preferences
- "Quiet Partner" - like a friend who checks in

---

NOTIFICATION MANAGER:

class NotificationManager {
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    
    // Notification identifiers
    enum NotificationID {
        static let eveningNudge = "evening_nudge"
        static let streakAtRisk = "streak_at_risk"
        static let morningMotivation = "morning_motivation"
        static let challengeReminder = "challenge_reminder"
    }
    
    // Request authorization
    func requestAuthorization() async throws -> Bool
    
    // Schedule notifications
    func scheduleEveningNudge()
    func scheduleStreakAtRiskAlert()
    func scheduleMorningMotivation()
    func scheduleChallengeReminder(challenge: Challenge, daysLeft: Int)
    
    // Cancel
    func cancelNotification(id: String)
    func cancelAllNotifications()
    
    // On events
    func onStreakBroken()
    func onRankUp(to rank: Rank)
    func onChallengeComplete(challenge: Challenge)
}

---

"QUIET PARTNER" NOTIFICATION COPY:

1. EVENING NUDGE (5pm, if goal not met)
   Title: "The day is almost done"
   Body: "A 15-minute walk clears the mind."
   
2. STREAK AT RISK (7pm, if goal not met and streak > 0)
   Title: "Your streak is waiting"
   Body: "There's still time. [X] days and counting."
   
3. STREAK BROKEN (morning after missed day)
   Title: "We go again"
   Body: "The streak is just a number. The habit is you. Today's a fresh start."
   
4. MORNING MOTIVATION (optional, user-enabled, 8am)
   Title: "Good morning, [Rank]"
   Body: "What if today's the day you walk a little further?"
   
5. RANK UP (immediate)
   Title: "You're a [New Rank] now"
   Body: "[Motto for new rank]"
   
6. CHALLENGE REMINDER (2 days before date-specific challenge)
   Title: "[Challenge Name] is coming up"
   Body: "Don't forget to walk on [Date]."
   
7. CHALLENGE COMPLETE (immediate)
   Title: "Challenge complete! 🎉"
   Body: "[Challenge Name] — another one down. You're building something here."

---

SCHEDULING LOGIC:

Evening Nudge:
- Schedule daily at 5:00 PM
- Condition: Only fire if daily goal not met
- Cancel if goal met before 5pm

Streak At Risk:
- Schedule daily at 7:00 PM
- Condition: Only fire if streak > 0 AND goal not met
- Cancel if goal met before 7pm

Morning Motivation:
- Optional (user setting)
- Schedule daily at 8:00 AM
- No condition (always fires if enabled)

Challenge Reminders:
- Schedule 2 days before date-specific challenges
- One-time notification

---

IMPLEMENTATION:

func scheduleEveningNudge() {
    // Create content
    let content = UNMutableNotificationContent()
    content.title = "The day is almost done"
    content.body = "A 15-minute walk clears the mind."
    content.sound = .default
    
    // Create trigger (5pm daily)
    var dateComponents = DateComponents()
    dateComponents.hour = 17
    dateComponents.minute = 0
    let trigger = UNCalendarNotificationTrigger(
        dateMatching: dateComponents,
        repeats: true
    )
    
    // Create request
    let request = UNNotificationRequest(
        identifier: NotificationID.eveningNudge,
        content: content,
        trigger: trigger
    )
    
    // Schedule
    center.add(request)
}

---

NOTIFICATION CONDITIONS:

Use UNNotificationServiceExtension or check conditions at delivery:

For evening/streak notifications, check in app delegate or scene delegate:
- When app enters foreground, check if goal met
- If goal met, cancel pending evening/streak notifications
- If not met, let them fire

---

PROVIDE:
1. NotificationManager class
2. All notification scheduling methods
3. Notification content with "Quiet Partner" copy
4. Condition checking logic
5. Event-triggered notifications (rank up, challenge complete)

---

BUILD VERIFICATION (Required):

After completing implementation:
1. Run: xcodebuild -scheme "JustWalk" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
2. Fix any errors
3. Rebuild until "BUILD SUCCEEDED"
4. Only then is this prompt complete
```

---

## Testing Checklist

### Foundation Tests

- [ ] F-1: Data models serialize/deserialize correctly
- [ ] F-1: PersistenceManager saves and loads all types
- [ ] F-2: HealthKit authorization works (direct system call)
- [ ] F-2: Step counts update in real-time
- [ ] F-3: Walk tracking starts/pauses/ends correctly
- [ ] F-3: GPS route is recorded and filtered
- [ ] F-3: Walk duration calculated correctly
- [ ] F-4: Streak increments when goal met
- [ ] F-4: Streak breaks after missed day
- [ ] F-4: Streak at risk detected after 6pm
- [ ] F-5: Rank increments after qualifying walk
- [ ] F-5: Only walks ≥5 min count
- [ ] F-5: Rank never decreases
- [ ] F-5: 7-tier ladder thresholds correct
- [ ] F-6: Challenges load for current month
- [ ] F-6: Challenge progress updates correctly
- [ ] F-6: Month rollover archives history
- [ ] F-7: Dynamic card shows correct priority
- [ ] F-8: Products load from StoreKit
- [ ] F-8: Purchase flow works
- [ ] F-8: Subscription status checks work
- [ ] F-9: Animations play correctly
- [ ] F-9: Haptics trigger appropriately

### UI Tests

- [ ] U-1: Onboarding completes and saves settings
- [ ] U-1: Permission dialogs appear directly (no custom screens before)
- [ ] U-1: Hub & Spoke paywall displays correctly
- [ ] U-2: Today screen shows correct data
- [ ] U-2: Dynamic card navigates to correct destination
- [ ] U-2: Ring animates on appear
- [ ] U-3: Walk starts with one tap
- [ ] U-3: Goal picker works correctly
- [ ] U-3: Interval picker shows programs (Pro only)
- [ ] U-3: Active walk shows live stats
- [ ] U-3: 5-minute indicator appears/changes correctly
- [ ] U-3: Interval phases transition with voice/haptic
- [ ] U-4: Post-walk shows correct achievements
- [ ] U-4: Short walk shows education message
- [ ] U-4: Confetti appears for qualifying walks
- [ ] U-5: Progress tab shows all cards
- [ ] U-5: Navigation works to all detail screens
- [ ] U-6: Journey screen shows correct current position
- [ ] U-6: All 7 ranks display with correct states
- [ ] U-7: Challenges show correct progress states
- [ ] U-7: History shows past months
- [ ] U-8: Settings changes persist
- [ ] U-9: Liquid Glass components render correctly
- [ ] U-10: Live Activity starts/updates/ends

### Integration Tests

- [ ] I-1: First walk education appears once
- [ ] I-2: Notifications schedule correctly
- [ ] I-2: "Quiet Partner" copy displays correctly
- [ ] I-3: Widgets display current data
- [ ] I-4: Watch app syncs with iPhone

### End-to-End Flows

- [ ] Fresh install → Onboarding → Today screen
- [ ] Start walk → Track 5+ min → End → See rank progress
- [ ] Start walk → Track <5 min → End → See education message
- [ ] Walk to hit daily goal → Streak increments → Celebration
- [ ] Complete monthly challenge → Toast appears
- [ ] Reach new rank → Celebration screen
- [ ] Month changes → New challenges appear
- [ ] Start interval walk (Pro) → Phases transition → Voice cues play
- [ ] Walk active → Check Lock Screen → Live Activity shows progress

### iOS 26 Specific Tests

- [ ] Tab bar has Liquid Glass treatment
- [ ] Toolbars have Liquid Glass treatment
- [ ] Sheets morph from presenting elements
- [ ] Dark map displays as default
- [ ] Animations use spring curves correctly
- [ ] SF Symbol effects work

---

## File Structure

```
JustWalk/
├── App/
│   ├── JustWalkApp.swift
│   └── MainTabView.swift
├── Models/
│   ├── UserProfile.swift
│   ├── DailyLog.swift
│   ├── TrackedWalk.swift
│   ├── WalkMode.swift
│   ├── WalkGoal.swift
│   ├── IntervalProgram.swift
│   ├── IntervalPhase.swift
│   ├── IntervalWalkData.swift
│   ├── StreakData.swift
│   ├── Rank.swift
│   ├── RankData.swift
│   ├── Challenge.swift
│   ├── MonthlyChallengePack.swift
│   ├── ChallengeProgress.swift
│   ├── MonthProgress.swift
│   ├── DynamicCardType.swift
│   └── AppState.swift
├── Managers/
│   ├── PersistenceManager.swift
│   ├── HealthKitManager.swift
│   ├── WalkSessionManager.swift
│   ├── StreakManager.swift
│   ├── RankManager.swift
│   ├── ChallengeManager.swift
│   ├── ChallengeLibrary.swift
│   ├── DynamicCardEngine.swift
│   ├── IntervalManager.swift
│   ├── SubscriptionManager.swift
│   ├── LiveActivityManager.swift
│   └── NotificationManager.swift
├── Animation/
│   ├── JustWalkAnimation.swift
│   ├── JustWalkHaptics.swift
│   ├── AnimationModifiers.swift
│   ├── AnimatedCounter.swift
│   └── ConfettiView.swift
├── Design/
│   ├── GlassTokens.swift
│   ├── GlassComponents.swift
│   └── DesignTokens.swift
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingCoordinator.swift
│   │   ├── OnboardingContainerView.swift
│   │   ├── WelcomeView.swift
│   │   ├── DailyGoalPickerView.swift
│   │   ├── PermissionsView.swift
│   │   ├── ProPaywallView.swift
│   │   ├── FeatureDetailSheet.swift
│   │   └── OnboardingCompleteView.swift
│   ├── Today/
│   │   ├── TodayView.swift
│   │   ├── StepRingView.swift
│   │   ├── StreakBadgeView.swift
│   │   ├── WeekChartView.swift
│   │   └── DynamicCardView.swift
│   ├── Walk/
│   │   ├── WalkTabView.swift
│   │   ├── IdleWalkPanel.swift
│   │   ├── ActiveWalkPanel.swift
│   │   ├── GoalPickerSheet.swift
│   │   ├── IntervalPickerSheet.swift
│   │   ├── IntervalPhaseView.swift
│   │   └── PostWalkSummaryView.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   ├── MonthlyChallengesCard.swift
│   │   ├── RankCard.swift
│   │   ├── StreakCard.swift
│   │   ├── MonthStatsCard.swift
│   │   └── RecentWalksCard.swift
│   ├── Journey/
│   │   ├── JourneyScreen.swift
│   │   ├── RankNode.swift
│   │   └── RankConnector.swift
│   ├── Challenges/
│   │   ├── ChallengesDetailView.swift
│   │   ├── ChallengeRowView.swift
│   │   └── HistoryMonthDetailView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       ├── FloatingGlassButton.swift
│       ├── GlassIconButton.swift
│       ├── GlassControlGroup.swift
│       ├── GlassStatPill.swift
│       ├── ContentCard.swift
│       ├── FloatingBottomPanel.swift
│       ├── TopStatsBar.swift
│       └── FirstWalkEducationView.swift
├── LiveActivity/
│   ├── WalkActivityAttributes.swift
│   ├── WalkLockScreenView.swift
│   ├── WalkDynamicIslandViews.swift
│   └── WalkActivityWidget.swift
├── Widgets/
│   ├── JustWalkWidgetBundle.swift
│   ├── SmallWidget.swift
│   ├── MediumWidget.swift
│   └── LockScreenWidgets.swift
└── WatchApp/
    ├── JustWalkWatchApp.swift
    ├── WatchHomeView.swift
    ├── WatchActiveWalkView.swift
    └── WatchCompleteView.swift
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | Jan 23, 2026 | Complete overhaul based on UX refinement session |
| 2.1 | Jan 23, 2026 | iOS 26 Liquid Glass, Interval Walks, Live Activities, 7-rank ladder, Build Loop Protocol, Intentional Elegance animations |

---

*This document serves as the complete implementation specification for Just Walk v2.1. All prompts are designed to be run in Claude Code regular mode with the specified concurrency plan and mandatory Build Loop Protocol.*
