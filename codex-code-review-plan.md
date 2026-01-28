# Just Walk — Comprehensive Code Review Plan

## Objective

Perform a thorough code review of the Just Walk iOS app, identifying all bugs, design issues, performance problems, and areas for improvement. Produce an actionable report organized by severity and category.

---

## Instructions for Codex

You are reviewing the complete codebase for **Just Walk**, an iOS walking habit app. The app includes:

- **iOS App** (SwiftUI, iOS 15+)
- **watchOS App** (SwiftUI, watchOS 8+)
- **Widgets** (WidgetKit — Home screen and Lock screen)
- **HealthKit Integration** (steps, distance, heart rate, workouts)
- **StoreKit 2 Integration** (subscriptions)

Your task is to analyze every file and produce a comprehensive report covering bugs, design issues, and performance problems.

---

## Review Categories

### 1. CRITICAL BUGS — App-Breaking Issues

Look for issues that will cause crashes, data loss, or completely broken functionality:

- [ ] Force unwraps (`!`) that could crash on nil
- [ ] Unhandled optionals in critical paths
- [ ] Array index out of bounds possibilities
- [ ] Division by zero
- [ ] Infinite loops or recursion without exit conditions
- [ ] Deadlocks or race conditions
- [ ] Memory leaks causing crashes
- [ ] Uncaught exceptions
- [ ] Missing required permissions handling
- [ ] StoreKit purchase flow failures
- [ ] HealthKit authorization not handled
- [ ] Watch connectivity failures not handled

**Report format:**
```
🔴 CRITICAL: [File:Line] Description
   Impact: What breaks
   Fix: How to fix it
   Code: Show the problematic code and the fix
```

---

### 2. HIGH PRIORITY BUGS — Significant Issues

Issues that cause incorrect behavior but don't crash:

- [ ] Data not saving/loading correctly
- [ ] UI not updating when data changes
- [ ] State management issues (stale state, incorrect bindings)
- [ ] HealthKit queries returning wrong data
- [ ] Streak calculation errors
- [ ] Shield depletion/replenishment logic errors
- [ ] Subscription status not persisting
- [ ] Widget data not refreshing
- [ ] Watch-iPhone sync issues
- [ ] Notification scheduling failures
- [ ] Timer/countdown inaccuracies
- [ ] Goal completion not detected
- [ ] Walk session not ending properly

**Report format:**
```
🟠 HIGH: [File:Line] Description
   Impact: What's affected
   Repro: How to reproduce
   Fix: How to fix it
```

---

### 3. MEDIUM PRIORITY — Functionality Issues

Issues that cause degraded experience:

- [ ] Error states not shown to user
- [ ] Loading states missing
- [ ] Empty states missing or broken
- [ ] Retry logic missing for network/HealthKit failures
- [ ] Navigation issues (wrong screen, stuck states)
- [ ] Keyboard not dismissing properly
- [ ] Pull-to-refresh not working
- [ ] Dark mode issues
- [ ] Dynamic Type not supported
- [ ] Accessibility labels missing
- [ ] Haptic feedback missing or inconsistent
- [ ] Animation issues (janky, incomplete)

**Report format:**
```
🟡 MEDIUM: [File:Line] Description
   Impact: User experience issue
   Fix: Recommended solution
```

---

### 4. DESIGN & ARCHITECTURE ISSUES

Code quality and maintainability problems:

#### Architecture
- [ ] Massive view files (>500 lines) that should be split
- [ ] Business logic in views (should be in ViewModels)
- [ ] Tight coupling between components
- [ ] Missing dependency injection
- [ ] Singletons overused
- [ ] Circular dependencies
- [ ] No clear separation of concerns

#### State Management
- [ ] @State used where @StateObject should be
- [ ] @ObservedObject used where @StateObject should be
- [ ] Multiple sources of truth for same data
- [ ] State not properly scoped
- [ ] Unnecessary re-renders due to state structure

#### Data Flow
- [ ] Data passed through too many layers (prop drilling)
- [ ] Environment objects overused
- [ ] Combine publishers not properly managed
- [ ] Async/await not used where appropriate
- [ ] Completion handlers mixed with async/await

#### Error Handling
- [ ] Errors silently swallowed
- [ ] Generic catch blocks hiding specific errors
- [ ] No user-facing error messages
- [ ] No retry mechanisms
- [ ] No offline handling

#### Code Smells
- [ ] Duplicated code (DRY violations)
- [ ] Magic numbers/strings
- [ ] Overly complex functions (cyclomatic complexity)
- [ ] Deep nesting (>3 levels)
- [ ] Long parameter lists
- [ ] Dead code
- [ ] TODO/FIXME comments that should be addressed
- [ ] Commented-out code

**Report format:**
```
🔵 DESIGN: [File:Line] Category — Description
   Problem: Why this is an issue
   Recommendation: How to refactor
```

---

### 5. PERFORMANCE ISSUES

Problems affecting speed, battery, or responsiveness:

#### Memory
- [ ] Strong reference cycles (retain cycles)
- [ ] Closures capturing self strongly
- [ ] Large objects held in memory unnecessarily
- [ ] Images not properly cached/released
- [ ] Core Data / persistence memory bloat

#### CPU
- [ ] Heavy computation on main thread
- [ ] Unnecessary work in view body
- [ ] Excessive re-renders
- [ ] Inefficient algorithms (O(n²) where O(n) possible)
- [ ] Unoptimized loops
- [ ] Redundant calculations

#### Battery
- [ ] Location services running unnecessarily
- [ ] Timers not invalidated
- [ ] Background tasks running too long
- [ ] Excessive HealthKit queries
- [ ] Widget timeline updates too frequent

#### UI Performance
- [ ] List/ScrollView not using lazy loading
- [ ] Large images not downsampled
- [ ] Animations blocking main thread
- [ ] GeometryReader overused
- [ ] Complex view hierarchies

#### Network
- [ ] No request caching
- [ ] No request debouncing
- [ ] Large payloads not paginated
- [ ] No timeout handling

**Report format:**
```
⚡ PERFORMANCE: [File:Line] Category — Description
   Impact: Battery drain / UI lag / Memory usage
   Measurement: If possible, quantify the issue
   Fix: Optimization approach
```

---

### 6. HEALTHKIT SPECIFIC REVIEW

HealthKit has strict requirements. Check:

- [ ] Authorization requested for all used types
- [ ] Authorization status checked before queries
- [ ] Graceful handling when permission denied
- [ ] Queries use appropriate date predicates
- [ ] Observer queries set up for real-time updates
- [ ] Background delivery configured (if needed)
- [ ] Workout sessions properly started/ended
- [ ] Heart rate data only used with Watch
- [ ] No health data leaves the device (privacy requirement)
- [ ] HealthKit usage description in Info.plist

---

### 7. STOREKIT SPECIFIC REVIEW

StoreKit 2 subscription handling. Check:

- [ ] Products loaded on app launch
- [ ] Transaction listener set up for updates
- [ ] Purchases properly verified
- [ ] Transactions finished after processing
- [ ] Subscription status checked via `currentEntitlements`
- [ ] Restore purchases implemented
- [ ] Grace period / billing retry handled
- [ ] Price displayed correctly (localized)
- [ ] Trial period shown accurately
- [ ] Subscription expiry handled
- [ ] Pro status persists across launches

---

### 8. WATCHOS SPECIFIC REVIEW

Watch app has unique constraints. Check:

- [ ] Watch connectivity session activated
- [ ] Messages sent/received between iPhone and Watch
- [ ] Complications data provided
- [ ] Workout session properly managed
- [ ] Extended runtime session for long workouts
- [ ] Heart rate queries use workout session
- [ ] UI optimized for small screen
- [ ] No blocking operations on main thread

---

### 9. WIDGET SPECIFIC REVIEW

Widgets have strict limitations. Check:

- [ ] Timeline provider properly implemented
- [ ] Snapshot provided quickly
- [ ] Timeline entries have appropriate dates
- [ ] Widget data fetched efficiently
- [ ] App group used for shared data
- [ ] Widget reloads triggered when data changes
- [ ] All widget families supported correctly
- [ ] Lock screen widgets use correct families
- [ ] Deep links work correctly

---

### 10. SECURITY REVIEW

Check for security vulnerabilities:

- [ ] No sensitive data in UserDefaults (use Keychain)
- [ ] No API keys hardcoded
- [ ] No logging of sensitive health data
- [ ] StoreKit receipts validated properly
- [ ] No debug code in production
- [ ] App Transport Security configured
- [ ] No unsafe interpolation in URLs

---

### 11. iOS BEST PRACTICES

Check adherence to Apple guidelines:

- [ ] Uses @main for app entry point
- [ ] Proper scene lifecycle handling
- [ ] Background task properly registered
- [ ] Push notification handling (if applicable)
- [ ] Deep link / URL scheme handling
- [ ] State restoration
- [ ] App lifecycle events handled (foreground, background, terminate)
- [ ] Orientation support correct
- [ ] Safe area insets respected

---

## Output Format

Produce a report with these sections:

### Executive Summary
- Total issues found by severity
- Top 5 most critical issues
- Overall code health assessment (1-10)
- Estimated effort to fix all issues

### Critical Issues (Must Fix Before Launch)
List all 🔴 issues

### High Priority Issues (Should Fix Before Launch)
List all 🟠 issues

### Medium Priority Issues (Fix in v1.1)
List all 🟡 issues

### Design & Architecture Recommendations
List all 🔵 issues, grouped by category

### Performance Optimizations
List all ⚡ issues, grouped by impact

### HealthKit Compliance
Checklist results and any issues

### StoreKit Compliance
Checklist results and any issues

### WatchOS Review
Checklist results and any issues

### Widget Review
Checklist results and any issues

### Security Review
Checklist results and any issues

### Code Quality Metrics
- Files reviewed
- Total lines of code
- Average file size
- Largest files (potential refactor candidates)
- Test coverage (if tests exist)

### Recommended Refactors
Prioritized list of architectural improvements

### Quick Wins
Easy fixes that improve quality with minimal effort

---

## Files to Review

Review ALL Swift files in the project, including:

```
JustWalk/
├── App/
│   ├── JustWalkApp.swift
│   └── AppDelegate.swift (if exists)
├── Views/
│   ├── Today/
│   ├── Walks/
│   ├── Settings/
│   ├── Onboarding/
│   └── Components/
├── ViewModels/
├── Models/
├── Services/
│   ├── HealthKitManager.swift
│   ├── StoreManager.swift
│   ├── WorkoutManager.swift
│   └── NotificationManager.swift
├── Utilities/
├── Extensions/
└── Resources/

JustWalkWatch/
├── App/
├── Views/
├── Services/
└── Models/

JustWalkWidgets/
├── Provider/
├── Views/
└── Models/
```

---

## Example Issue Report

```
🔴 CRITICAL: HealthKitManager.swift:142 — Force unwrap on optional HealthKit result

   Impact: App crashes if HealthKit query returns no data (e.g., new user with no step history)
   
   Problematic code:
   ```swift
   let steps = result.sumQuantity()!.doubleValue(for: .count())
   ```
   
   Fix:
   ```swift
   guard let sum = result.sumQuantity() else {
       self.todaySteps = 0
       return
   }
   let steps = sum.doubleValue(for: .count())
   ```
   
   Notes: This pattern appears in 3 other places in this file. Check lines 156, 178, 203.
```

```
🟠 HIGH: WorkoutManager.swift:89 — Workout session not ended when user force-quits app

   Impact: Orphaned workout sessions in HealthKit, incorrect calorie/time data
   
   Repro: 
   1. Start Fat Burn walk
   2. Force quit app (swipe up)
   3. Reopen app — workout still "running" in HealthKit
   
   Fix: Implement scene phase observer to end workout on .background or use 
   ExtendedRuntimeSession with proper cleanup in delegate methods.
```

```
⚡ PERFORMANCE: TodayView.swift:45 — HealthKit query in view body

   Impact: Query runs on every re-render, causing UI lag and battery drain
   
   Problematic code:
   ```swift
   var body: some View {
       VStack {
           Text("\(healthManager.fetchTodaySteps())")  // Called every render!
       }
   }
   ```
   
   Fix: Move fetch to onAppear or use @Published property that updates on schedule:
   ```swift
   .onAppear {
       healthManager.fetchTodaySteps()
   }
   ```
```

---

## Final Checklist

Before submitting the report, verify:

- [ ] Every file in the project was reviewed
- [ ] All critical issues have clear reproduction steps
- [ ] All issues have specific file:line references
- [ ] All issues have concrete fix recommendations
- [ ] Issues are correctly categorized by severity
- [ ] No duplicate issues reported
- [ ] Report is actionable (developer can fix from this alone)

---

## Notes

- Focus on issues that affect the USER, not just code style preferences
- Prioritize issues that could cause App Store rejection
- HealthKit and StoreKit issues are especially important (Apple reviews these closely)
- Watch for any demo/mock/fake data that shouldn't ship in production
- Flag any TODO/FIXME comments that indicate known issues
- If you find patterns of issues, note the pattern rather than listing each instance
