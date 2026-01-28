# StepRepository Migration Guide

## Overview

This document describes the architectural migration from fragmented step tracking logic to a unified `StepRepository` that serves as the **Single Source of Truth** for all step counts.

## The Problem: Step Drift

Previously, step counting logic was scattered across multiple files:
- `StepTrackingService.swift` - HealthKit + CoreMotion + App Group
- `HealthKitService.swift` - HealthKit queries
- `PedometerService.swift` - CoreMotion wrapper
- `BackgroundTaskManager.swift` - Direct CMPedometer queries
- Widget files - (Was suspected to have CMPedometer, but actually already reads from App Group)

This fragmentation caused **Step Drift** where the Widget and App showed different numbers.

## The Solution: Monotonic Ratchet Architecture

### Core Principle
**The step count NEVER decreases during the day.**

### Data Inputs
| Variable | Source | Characteristics |
|----------|--------|-----------------|
| A | CMPedometer | Live, noisy, immediate |
| B | HKStatisticsQuery | Verified, laggy, de-duplicated |
| C | App Group UserDefaults | Cached high score |

### The Algorithm
```swift
currentMax = max(Variable A, Variable B)
finalDisplayValue = max(currentMax, Variable C)
```

### Actions When Value Increases
1. Save to App Group UserDefaults
2. Update `@Published` property for SwiftUI
3. Call `WidgetCenter.shared.reloadAllTimelines()`
4. Sync to Supabase leaderboard (throttled)

## New Files Created

### 1. `StepRepository.swift`
The unified singleton that replaces all step tracking logic.

```swift
@MainActor
final class StepRepository: ObservableObject {
    static let shared = StepRepository()

    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayDistance: Double = 0
    @Published var stepGoal: Int = 10_000

    var goalReached: Bool { todaySteps >= stepGoal }
    var goalProgress: Double { ... }
    var stepsRemaining: Int { ... }
}
```

**Key Features:**
- Monotonic ratchet (steps never decrease)
- HKObserverQuery for background Watch syncs
- Thread-safe App Group writes
- Throttled widget refreshes (15s)
- Throttled Supabase syncs (30s)
- Swift 6 concurrency compliant

### 2. `StepTrackingService+RepositoryBridge.swift`
Compatibility layer for gradual migration.

```swift
extension StepTrackingService {
    var repositorySteps: Int { StepRepository.shared.todaySteps }
    var repositoryDistance: Double { StepRepository.shared.todayDistance }

    func initializeRepository() async {
        await StepRepository.shared.initialize()
    }
}
```

## Migration Instructions

### Step 1: Add Files to Xcode Project
1. Add `StepRepository.swift` to the main app target
2. Add `StepTrackingService+RepositoryBridge.swift` to the main app target
3. Ensure App Group capability is configured: `group.com.onworldtech.JustWalk`

### Step 2: Initialize on App Launch
In your `Just_WalkApp.swift` or App Delegate:

```swift
@main
struct Just_WalkApp: App {
    init() {
        // Initialize StepRepository
        Task {
            await StepRepository.shared.initialize()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(StepRepository.shared)
        }
    }
}
```

### Step 3: Handle App Foreground
```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
    Task {
        await StepRepository.shared.handleAppForeground()
    }
}
```

### Step 4: Update SwiftUI Views
**Before (using StepTrackingService):**
```swift
struct DashboardView: View {
    @StateObject private var stepService = StepTrackingService.shared

    var body: some View {
        Text("\(stepService.todaySteps)")
    }
}
```

**After (using StepRepository):**
```swift
struct DashboardView: View {
    @StateObject private var stepRepo = StepRepository.shared

    var body: some View {
        Text("\(stepRepo.todaySteps)")
    }
}
```

### Step 5: Migrate Watch Sync
Update your WatchConnectivity handler to notify StepRepository:

```swift
func handleWatchMessage(_ message: [String: Any]) {
    if let watchSteps = message["senderSteps"] as? Int {
        Task {
            await StepRepository.shared.handleWatchSync(watchSteps: watchSteps)
        }
    }
}
```

## File Disposition

| File | Action | Reason |
|------|--------|--------|
| `StepRepository.swift` | **NEW** | Single source of truth |
| `StepTrackingService+RepositoryBridge.swift` | **NEW** | Compatibility layer |
| `BackgroundTaskManager.swift` | **UPDATED** | Now uses StepRepository |
| `SimpleWalkWidgets.swift` | **CLEANED** | Removed unused CMPedometer |
| `StepTrackingService.swift` | **KEEP** | Still needed for session tracking (IWT) |
| `PedometerService.swift` | **DEPRECATE** | StepRepository handles pedometer |
| `HealthKitService.swift` | **PARTIAL DEPRECATE** | Keep authorization, deprecate step queries |

### What to Keep in StepTrackingService
- Session tracking for Interval Walking Training (IWT)
- `isTracking`, `sessionSteps`, `sessionDistance`
- Heart rate and calorie tracking during workouts
- WatchConnectivity for workout coordination

### What to Deprecate in PedometerService
The entire service can be deprecated. StepRepository now handles all CMPedometer operations internally.

```swift
// Add to PedometerService.swift
@available(*, deprecated, message: "Use StepRepository for step tracking")
final class PedometerService { ... }
```

### What to Keep in HealthKitService
- Authorization methods
- Workout saving
- Non-step health data queries

### What to Deprecate in HealthKitService
```swift
@available(*, deprecated, message: "Use StepRepository.shared.todaySteps")
func fetchDeDuplicatedSteps(...) { ... }

@available(*, deprecated, message: "Use StepRepository.shared.fetchVerifiedSteps()")
func fetchVerifiedSteps(...) { ... }
```

## Widget Architecture

The widget is now a "dumb" display that only reads from App Group:

```
┌─────────────────────────────────────────────────────────┐
│                        App                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │            StepRepository (SSOT)                │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐   │   │
│  │  │CMPedometer│  │HealthKit │  │ App Group │   │   │
│  │  │   (A)     │  │   (B)     │  │   (C)     │   │   │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘   │   │
│  │        │              │              │         │   │
│  │        └──────────────┼──────────────┘         │   │
│  │                       ▼                        │   │
│  │              max(max(A,B), C)                  │   │
│  │                       │                        │   │
│  │                       ▼                        │   │
│  │              Save to App Group ───────────────────────┐
│  │                       │                        │   │  │
│  │                       ▼                        │   │  │
│  │          WidgetCenter.reloadAllTimelines()    │   │  │
│  └─────────────────────────────────────────────────┘   │  │
└─────────────────────────────────────────────────────────┘  │
                                                             │
┌─────────────────────────────────────────────────────────┐  │
│                      Widget                             │  │
│  ┌─────────────────────────────────────────────────┐   │  │
│  │              Read from App Group  ◄─────────────────┘  │
│  │                       │                         │   │
│  │                       ▼                         │   │
│  │              Display todaySteps                 │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Testing Checklist

- [ ] App shows same steps as Apple Health app
- [ ] Widget shows same steps as app
- [ ] Steps never decrease during the day
- [ ] Widget updates within 15 seconds of step increase
- [ ] Background refresh updates App Group correctly
- [ ] Day change resets steps to zero
- [ ] Watch sync triggers HealthKit refresh
- [ ] Goal progress is calculated correctly
- [ ] Supabase leaderboard receives updates

## Rollback Plan

If issues occur, you can rollback by:
1. Reverting `BackgroundTaskManager.swift` to use the old direct queries
2. Removing StepRepository from app initialization
3. Views continue working with StepTrackingService

The bridge extension allows both systems to coexist during migration.
