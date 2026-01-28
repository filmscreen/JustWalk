# Today Screen: Current Implementation Audit

## File Map

### Views (Today/)
| File | Purpose |
|------|---------|
| `Views/Today/TodayView.swift` | Main container — greeting, ring, badges, chart, cards, settings |
| `Views/Today/StepRingView.swift` | Hero circular progress ring + CompactStepRingView |
| `Views/Today/StreakBadgeView.swift` | Streak flame badge + LargeStreakBadgeView, StreakMilestoneBadge, ShieldBadgeView, WalkTimeBadgeView |
| `Views/Today/WeekChartView.swift` | 30-day horizontal scroll strip (WeekDayColumn, DayDetailPopover) + ExtendedWeekChartView |
| `Views/Today/DynamicCardView.swift` | Contextual nudge/celebration cards (6 card types) |
| `Views/Today/StreakDetailSheet.swift` | Half-sheet: streak stats, shield bank, vacation mode, jackpot, legacy badges |
| `Views/Today/ShieldDetailSheet.swift` | Half-sheet: shield bank details, purchase, refill info |
| `Views/Today/WalkTimeDetailSheet.swift` | Half-sheet: today's tracked walk breakdown |

### Inline Components (in TodayView.swift)
| Struct | Purpose |
|--------|---------|
| `QuickStatPill` | Capsule-shaped stat pill (icon + value + label) — **defined but unused in layout** |
| `IntervalSummaryCard` | Card showing walk count/minutes, navigates to Walks tab |
| `ShieldsIndicator` | Inline shield count with tap to open ShieldDetailSheet |

### Animation Utilities
| File | Purpose |
|------|---------|
| `Animation/JustWalkAnimation.swift` | Centralized animation tokens (micro, standard, emphasis, ringFill, stagger, etc.) |
| `Animation/AnimationModifiers.swift` | View modifiers: `.bounceIn()`, `.staggeredAppearance()`, `.pressEffect()`, `.buttonPressEffect()`, `.pulseEffect()`, `.shakeEffect()`, `.slideIn()`, `.glowEffect()` |
| `Animation/AnimatedCounter.swift` | Animated number display with `.contentTransition(.numericText())` |
| `Animation/ConfettiView.swift` | Particle-based confetti overlay (not currently used on Today screen) |

### Haptic Utilities
| File | Purpose |
|------|---------|
| `Animation/JustWalkHaptics.swift` | Static haptic utility — all haptic calls go through here |
| `Managers/HapticsManager.swift` | @Observable manager with per-feature toggles (isEnabled, goalReached, stepMilestone) |

### Managers (Data Layer)
| File | Purpose |
|------|---------|
| `Managers/HealthKitManager.swift` | HealthKit step fetching + simulator mock |
| `Managers/StreakManager.swift` | Streak logic, milestone detection, break/repair |
| `Managers/ShieldManager.swift` | Shield economy: auto-deploy, retroactive repair, purchase |
| `Managers/DynamicCardEngine.swift` | Card priority evaluation, dismiss/re-show timing |
| `Managers/PersistenceManager.swift` | UserDefaults-based storage for all data |
| `Managers/SubscriptionManager.swift` | StoreKit 2 pro subscription + shield IAP |
| `Managers/JustWalkWidgetData.swift` | Pushes Today data to widget shared container |

### Models
| File | Purpose |
|------|---------|
| `Models/AppState.swift` | App-wide observable: selectedTab, isWalking, etc. |
| `Models/StreakData.swift` | Codable streak model (currentStreak, longestStreak, consecutiveGoalDays, etc.) |
| `Models/ShieldData.swift` | Codable shield bank model |
| `Models/DailyLog.swift` | Per-day log (steps, goalMet, shieldUsed, trackedWalkIDs) |
| `Models/DynamicCardType.swift` | Enum with 6 card types, priority, dismiss rules |
| `Models/VacationData.swift` | Vacation mode (7-day pause, yearly limit) |
| `Models/UserProfile.swift` | Display name, metric preference, legacy badges |
| `Models/TrackedWalk.swift` | Individual walk data (mode, duration, steps) |

---

## Components

### 1. Greeting Header
- **Location:** `TodayView.swift:80-92`
- **Data:** `displayName` from `PersistenceManager.loadProfile()`, `greetingHeadline` computed from time-of-day + progress + rotating variants
- **Animations:** `.staggeredAppearance(index: 0)` — fade up on appear
- **Haptics:** None
- **Interactions:** None (read-only)

### 2. Step Ring (Hero)
- **Location:** `StepRingView.swift`
- **Data:** `steps` and `goal` passed in from TodayView; progress = steps/goal capped at 1.0
- **Visual layers:** Inner circle fill, background ring (18pt gray), progress ring (18pt gradient or solid green at 100%), green glow at 100%, center text (AnimatedCounter + subtitle + goal complete label)
- **Ring size:** 220x220 frame, 18pt stroke
- **Animations:**
  - Ring fill: `JustWalkAnimation.ringFill` (.easeOut 0.8s) on appear
  - Step updates: `JustWalkAnimation.standard` (.easeInOut 0.3s) on steps change
  - Counter: `.contentTransition(.numericText())` with `JustWalkAnimation.morph`
  - Goal complete label: `.transition(.scale.combined(with: .opacity))`
  - Bounce in: `.bounceIn(delay: 0.1)` — emphasis spring from scale 0
- **Haptics:** None directly (milestone haptics in StreakManager)
- **Interactions:** Triple-tap opens DebugOverlayView (DEBUG only)

### 3. Streak Badge
- **Location:** `StreakBadgeView.swift`
- **Data:** `streak` and `longestStreak` from `StreakManager.shared.streakData`
- **Flame color:** gray (0), orange (1-29), red (30-99), purple (100+)
- **Subtitle:** "Hit your goal today" (0), "Your longest streak" (at record), "Best: N" (below record)
- **Animations:**
  - `.symbolEffect(.pulse, .repeating)` on flame icon when streak > 0
  - `.contentTransition(.numericText())` on day count
  - `.staggeredAppearance(index: 1)` — fade up
- **Haptics:** None on tap
- **Interactions:** Tap opens `StreakDetailSheet` as `.sheet`

### 4. Week Chart
- **Location:** `WeekChartView.swift`
- **Data:** Loads 30 days of `DailyLog` via `PersistenceManager`, today uses live `liveTodaySteps` from HealthKit
- **Visual:** Horizontal `ScrollView` of `WeekDayColumn` circles (44x40), auto-scrolls to trailing (today)
- **Day circle states:** goal met (green ring), shield used (blue ring), partial (gray track + green arc), missed/0 steps (dashed gray), repairable (dashed orange), today (animated progress arc)
- **Animations:**
  - Today arc: `JustWalkAnimation.ringFill` (.easeOut 0.8s) on appear
  - Step changes: `JustWalkAnimation.standard` on steps change
  - Staggered columns: `.staggeredAppearance(index:)`
- **Haptics:** None
- **Interactions:** Tap any day circle → toggles `DayDetailPopover`

### 5. Day Detail Popover
- **Location:** `WeekChartView.swift:264-476` (DayDetailPopover)
- **Data:** DayData (date, steps, distance, walk breakdown from TrackedWalk IDs)
- **Features:** Stats, walk breakdown by mode, shield repair button, shield purchase button
- **Interactions:** "Use Streak Shield" → confirmation dialog → `shieldManager.repairDate()`; "Buy Shield" → confirmation → StoreKit purchase

### 6. Interval Summary Card
- **Location:** `TodayView.swift:335-390` (IntervalSummaryCard)
- **Data:** `todayWalkCount` and `walkTimeToday` from `loadDailyData()` → TrackedWalk objects
- **Display:** "N walks today · N min" or "No walks today"
- **Animations:** `.staggeredAppearance(index: 3)`
- **Haptics:** `JustWalkHaptics.buttonTap()` on tap
- **Interactions:** Tap navigates to Walks tab (`appState.selectedTab = .walks`)

### 7. Shields Indicator
- **Location:** `TodayView.swift:394-413` (ShieldsIndicator)
- **Data:** `shieldManager.availableShields`
- **Display:** Shield icon + "N shields ready"
- **Animations:** `.staggeredAppearance(index: 4)`
- **Haptics:** `JustWalkHaptics.buttonTap()` on tap
- **Interactions:** Tap opens `ShieldDetailSheet` as `.sheet`

### 8. Dynamic Card
- **Location:** `DynamicCardView.swift`
- **Data:** `DynamicCardEngine.shared.currentCard` — evaluates context (time, steps, streak, shields)
- **Card Types (priority order):**
  1. **Streak At Risk** (P1) — 7PM+, goal unmet, streak ≥ 1. "Let's Go" → navigateToIntervals
  2. **Goal Complete** (P2) — Goal met. Checkmark bounce animation
  3. **Streak Milestone** (P2) — 7/14/30/60/90/180/365 days. Flame bounce animation
  4. **Shield Deployed** (P3) — Auto-deployed overnight info
  5. **Almost There** (P4) — 5PM+, 80-99% goal. "Let's Finish" → navigateToIntervals
  6. **Low Shields** (P5) — Shields ≤ 1, streak ≥ 14
- **Dismiss behavior:** X button on all; swipe-right on all except streakAtRisk & shieldDeployed; auto-dismiss after 30s for celebration cards; timed re-show (2h for streakAtRisk, 3 days for lowShields)
- **Animations:**
  - Entry: `.transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))`
  - Bounce scale on GoalComplete/StreakMilestone: `JustWalkAnimation.celebration` spring from 0.5 → 1.0
  - Swipe dismiss: `.easeIn(duration: 0.2)` slide off + snap back `JustWalkAnimation.standardSpring`
  - Dismiss animation: `.easeIn(duration: 0.25)` on card engine dismiss
  - `.staggeredAppearance(index: 5)`
- **Haptics:** None directly on cards (milestone haptic fires in StreakManager.recordGoalMet)
- **Interactions:** "Let's Go" / "Let's Finish" buttons navigate to Intervals tab; X button and swipe dismiss

### 9. Settings Button (Floating)
- **Location:** `TodayView.swift:165-173`
- **Display:** `figure.walk.circle.fill` icon, 32pt, secondary color
- **Interactions:** `NavigationLink` to `SettingsView()`

### 10. Streak Detail Sheet
- **Location:** `StreakDetailSheet.swift`
- **Sections:** Hero (flame + streak count), stats grid (streak start, longest, total days, next milestone), shield status bank, vacation mode, 7-day jackpot progress, legacy badges
- **Data:** StreakManager, ShieldManager, PersistenceManager, SubscriptionManager
- **Presentation:** `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`
- **Interactions:** Share button (renders StreakShareCard), shield management link → ShieldDetailSheet, vacation activate (double confirmation dialog), Pro paywall link

### 11. Shield Detail Sheet
- **Location:** `ShieldDetailSheet.swift`
- **Sections:** Hero (shield icon + count visualization), info rows (refill, used, lifetime), how shields work, buy button
- **Presentation:** `.presentationDetents([.medium])`
- **Interactions:** Buy Shield → StoreKit purchase

---

## Animation Inventory

| Animation | Trigger | Config | Location |
|-----------|---------|--------|----------|
| Ring progress fill | onAppear | `.easeOut(duration: 0.8)` | StepRingView.swift:73 |
| Ring progress update | steps change | `.easeInOut(duration: 0.3)` | StepRingView.swift:78 |
| Step counter morph | value change | `.interpolatingSpring(stiffness: 200, damping: 20)` + `.contentTransition(.numericText())` | AnimatedCounter.swift:57 |
| Ring bounce in | onAppear | `.spring(response: 0.5, dampingFraction: 0.6)` delay 0.1s, scale 0→1 | TodayView.swift:99, AnimationModifiers.swift:131-150 |
| Greeting stagger | onAppear | `.spring(response: 0.4, dampingFraction: 0.75)` delay 0s, opacity 0→1, y+20→0 | TodayView.swift:91 |
| Streak badge stagger | onAppear | Same spring, delay 0.05s | TodayView.swift:112 |
| Week chart stagger | onAppear | Same spring, per column | TodayView.swift:121 |
| Interval card stagger | onAppear | Same spring, delay 0.15s | TodayView.swift:132 |
| Shields stagger | onAppear | Same spring, delay 0.20s | TodayView.swift:139 |
| Dynamic card stagger | onAppear | Same spring, delay 0.25s | TodayView.swift:157 |
| Flame pulse | onAppear (streak > 0) | `.symbolEffect(.pulse, .repeating)` | StreakBadgeView.swift:53 |
| Streak number transition | value change | `.contentTransition(.numericText())` | StreakBadgeView.swift:59 |
| Today arc fill (week chart) | onAppear | `.easeOut(duration: 0.8)` | WeekChartView.swift:243 |
| Today arc update (week chart) | steps change | `.easeInOut(duration: 0.3)` | WeekChartView.swift:250 |
| Week bar height (extended) | onAppear | `.easeOut(duration: 0.8)` | WeekChartView.swift:585 |
| Dynamic card entry | card appears | `.move(edge: .leading) + .opacity` insertion | TodayView.swift:152-155 |
| Dynamic card exit | card removed | `.move(edge: .trailing) + .opacity` removal | TodayView.swift:152-155 |
| Card dismiss fade | X button / engine dismiss | `.easeIn(duration: 0.25)` | TodayView.swift:145 |
| Card swipe dismiss | drag > 100pt right | `.easeIn(duration: 0.2)` slide to 500 | DynamicCardView.swift:87-88 |
| Card snap back | drag < 100pt | `JustWalkAnimation.standardSpring` (.spring response 0.35, damping 0.7) | DynamicCardView.swift:96 |
| Goal complete bounce | onAppear | `JustWalkAnimation.celebration` (.spring response 0.6, damping 0.5) scale 0.5→1.0 | DynamicCardView.swift:172 |
| Streak milestone bounce | onAppear | Same celebration spring, scale 0.5→1.0 | DynamicCardView.swift:212 |
| Goal complete label appear | progress ≥ 1.0 | `.transition(.scale.combined(with: .opacity))` | StepRingView.swift:68 |
| Dynamic card refresh | pull-to-refresh / onAppear | `JustWalkAnimation.standard` wrapping card engine refresh | TodayView.swift:181-183 |
| Green glow (ring) | progress ≥ 1.0 | Static 12% opacity glow, 25px blur (no animation) | StepRingView.swift:46-49 |

### Animation Token Reference (JustWalkAnimation.swift)
| Token | Config |
|-------|--------|
| `micro` | `.easeOut(duration: 0.15)` |
| `microBounce` | `.spring(response: 0.2, dampingFraction: 0.6)` |
| `standard` | `.easeInOut(duration: 0.3)` |
| `standardSpring` | `.spring(response: 0.35, dampingFraction: 0.7)` |
| `presentation` | `.spring(response: 0.4, dampingFraction: 0.8)` |
| `emphasis` | `.spring(response: 0.5, dampingFraction: 0.6)` |
| `celebration` | `.spring(response: 0.6, dampingFraction: 0.5)` |
| `dramatic` | `.spring(response: 0.7, dampingFraction: 0.55)` |
| `morph` | `.interpolatingSpring(stiffness: 200, damping: 20)` |
| `ringFill` | `.easeOut(duration: 0.8)` |
| `progressFill` | `.easeOut(duration: 0.5)` |
| `pulse` | `.easeInOut(duration: 0.8).repeatForever(autoreverses: true)` |
| `staggerItem` | `.spring(response: 0.4, dampingFraction: 0.75)` |
| `staggerDelay` | `0.05` seconds per index |

---

## Haptic Inventory

### Haptics Triggered on Today Screen

| Haptic | Trigger | Type | Location |
|--------|---------|------|----------|
| Button tap | IntervalSummaryCard tap | `.impactLight` | TodayView.swift:352 via JustWalkHaptics.buttonTap() |
| Button tap | ShieldsIndicator tap | `.impactLight` | TodayView.swift:400 via JustWalkHaptics.buttonTap() |
| Selection changed | Pull-to-refresh | `.selectionChanged` | TodayView.swift:189 via JustWalkHaptics.selectionChanged() |
| Streak milestone | Streak reaches 7/14/30/60/90/180/365 | `.impactHeavy` + `.notificationSuccess` (150ms delay) | StreakManager.swift:99 via JustWalkHaptics.streakMilestone() |
| Streak broken | Streak resets to 0 | `.notificationError` | StreakManager.swift:125 via JustWalkHaptics.streakBroken() |
| Shield auto-deploy | Shield used overnight | `.impactMedium` + `.notificationSuccess` (200ms delay) | ShieldManager.swift:78-81 |
| Shield repair | Retroactive repair via popover | `.notificationSuccess` | ShieldManager.swift:137 via HapticsManager.shared.shieldRepair() |
| Button press effect | WalkTimeDetailSheet "Start" buttons | `.impactLight` via `.buttonPressEffect()` modifier | AnimationModifiers.swift:31-33 |

### Haptic System Architecture
- **JustWalkHaptics** (static enum): Primary API — all static methods, checks `HapticsManager.shared.isEnabled`
- **HapticsManager** (@Observable class): Persists per-feature preferences to UserDefaults (isEnabled, goalReachedHaptic, stepMilestoneHaptic)
- **Duplication noted:** Both `JustWalkHaptics` and `HapticsManager` define the same haptic methods with slightly different names (e.g., `buttonTap()` vs `buttonTap()`, `goalComplete()` vs `goalAchieved()`)

---

## State Management Flow

### Data Sources
```
HealthKitManager.shared
  └─ fetchTodaySteps() → async Int (HealthKit or simulator mock)

PersistenceManager.shared
  ├─ loadProfile() → UserProfile (name, metric preference, legacy badges)
  ├─ loadDailyLog(for: Date) → DailyLog? (steps, goalMet, shieldUsed, walkIDs)
  ├─ loadStreakData() → StreakData
  ├─ loadShieldData() → ShieldData
  ├─ loadVacationData() → VacationData
  └─ loadTrackedWalk(by: UUID) → TrackedWalk?

StreakManager.shared (@Observable)
  └─ streakData: StreakData (currentStreak, longestStreak, etc.)

ShieldManager.shared (@Observable)
  └─ shieldData: ShieldData (availableShields, etc.)

DynamicCardEngine.shared (@Observable)
  └─ currentCard: DynamicCardType? (evaluated based on time + steps + streak + shields)

AppState (@Observable, @Environment)
  └─ selectedTab: AppTab
```

### TodayView State
```swift
@AppStorage("dailyStepGoal") dailyGoal = 5000      // UserDefaults
@State todaySteps: Int = 0                           // From HealthKit
@State walkTimeToday: Int = 0                        // Computed from TrackedWalks
@State todayWalkCount: Int = 0                       // Computed from TrackedWalks
@State showStreakDetail / showShieldDetail / showProPaywall  // Sheet toggles
```

### Data Flow on Appear
1. `onAppear` → `Task { todaySteps = await healthKitManager.fetchTodaySteps() }`
2. `loadDailyData()` → loads DailyLog → resolves TrackedWalk UUIDs → computes walkTimeToday + todayWalkCount
3. `dynamicCardEngine.refresh(dailyGoal:, currentSteps:)` → evaluates card priority
4. `pushWidgetData()` → sends steps/goal/streak/weekSteps to widget shared container
5. `checkStreakPaywallTrigger()` → shows paywall if: not Pro, 0 shields, streak ≥ 3, goal unmet, not shown today

### Refresh Triggers
- **Pull-to-refresh:** Same as onAppear flow
- **`persistence.dailyLogVersion` change:** `.onChange` re-fetches everything (reacts to background log updates)

---

## Interactions Map

| Element | Gesture | Action |
|---------|---------|--------|
| Step Ring | Triple-tap (DEBUG) | Opens `DebugOverlayView` |
| Streak Badge | Tap | Opens `StreakDetailSheet` (.sheet) |
| Week Day Circle | Tap | Toggles `DayDetailPopover` (.popover) |
| Day Detail "Use Shield" | Tap | Confirmation dialog → `shieldManager.repairDate()` |
| Day Detail "Buy Shield" | Tap | Confirmation dialog → StoreKit purchase → repair |
| Interval Summary Card | Tap | `appState.selectedTab = .walks` + haptic |
| Shields Indicator | Tap | Opens `ShieldDetailSheet` (.sheet) + haptic |
| Dynamic Card X button | Tap | Dismisses card via `dynamicCardEngine.dismiss()` |
| Dynamic Card | Swipe right > 100pt | Dismisses card (not for streakAtRisk/shieldDeployed) |
| Dynamic Card "Let's Go" | Tap | `appState.selectedTab = .walks` |
| Dynamic Card "Let's Finish" | Tap | `appState.selectedTab = .walks` |
| Settings button | Tap | `NavigationLink` to `SettingsView` |
| Streak Detail Share | Tap | Renders + shares `StreakShareCard` image |
| Streak Detail Shield Row | Tap | Opens `ShieldDetailSheet` nested sheet |
| Streak Detail Vacation | Tap | Double confirmation dialog → `vacationData.activate()` |
| Streak Detail Pro upgrade | Tap | Opens `PaywallView` sheet |
| Shield Detail Buy Shield | Tap | StoreKit purchase |
| WalkTime Detail "Start Walk" | Tap | Dismisses → navigates to Walks tab |
| Scroll view | Pull down | `.refreshable` — re-fetches all data |

---

## Preserve (What's Working Well)

1. **Centralized animation tokens** — `JustWalkAnimation` enum provides consistent motion across the app. Every animation references a named token rather than inline values.

2. **Staggered appearance pattern** — Components fade in sequentially with the `.staggeredAppearance(index:)` modifier. Creates a polished cascading reveal. Spring-based (response 0.4, damping 0.75) feels natural.

3. **Ring fill animation** — The 0.8s easeOut fill on appear is satisfying and gives the screen a "loading in" feel.

4. **DynamicCardEngine priority system** — Smart contextual cards with priority ordering, dismiss tracking, timed re-shows, and auto-dismiss for celebrations. Well-architected.

5. **Singleton manager pattern** — All managers use `.shared` singletons with `@Observable`, making state reactivity clean across views.

6. **Week chart horizontal scroll** — 30-day history with auto-scroll to today, visual encoding of goal/shield/missed/partial states, and interactive popovers.

7. **Haptic abstraction** — `JustWalkHaptics` provides semantic haptic methods (buttonTap, goalComplete, streakMilestone) rather than raw feedback types. User preference toggle respects settings.

8. **Shield repair in popover** — Elegant UX: tap a missed day → see details → repair with shield, all inline without navigating away.

---

## Issues Found

### Structural

1. **`QuickStatPill` defined but unused** — `TodayView.swift:301-331` defines `QuickStatPill` but it's never used in the body layout. Dead code.

2. **`formatQuickDistance()` defined but unused** — `TodayView.swift:248-257` computes a distance string that's never displayed. Dead code.

3. **Duplicate haptic systems** — Both `JustWalkHaptics` (static enum) and `HapticsManager` (@Observable class) define overlapping haptic methods. `JustWalkHaptics` delegates to `HapticsManager.isEnabled` but duplicates all the generator instances. The Today screen mixes both: `JustWalkHaptics.buttonTap()` in views, `HapticsManager.shared.shieldRepair()` in ShieldManager.

4. **`WalkTimeDetailSheet` exists but is never presented** — The Today screen has no button/interaction that opens `WalkTimeDetailSheet`. It appears to be orphaned from a previous layout that had a walk time badge.

### Data / State

5. **DateFormatter created repeatedly** — `todayString()` in `DynamicCardEngine.swift:224-227` and `checkStreakPaywallTrigger()` in `TodayView.swift:268-272` both create `DateFormatter` instances inline rather than using a cached/static formatter. Minor performance concern.

6. **`totalDaysGoalHit` scans 365 days synchronously** — `StreakDetailSheet.swift:358-371` iterates over 365 daily logs on the main thread every time the sheet is opened. Could cause a frame drop if PersistenceManager I/O is slow.

7. **No loading state for HealthKit** — `todaySteps` starts at 0 and updates after the async HealthKit fetch. The ring briefly shows 0 then animates to actual steps. No skeleton/placeholder is shown during the fetch.

### Visual / UX

8. **Week chart shows 30 days but only labels last 7 as day names** — Days beyond 7 show as "M/D" date format while the last 7 show weekday abbreviations. The transition between formats could confuse users.

9. **No confetti on Today screen** — `ConfettiView.swift` exists with goal-achieved and streak-milestone presets, but the Today screen never triggers confetti. The goal complete card only uses a checkmark bounce.

10. **Green glow on ring is static** — When goal is complete, the green glow (`StepRingView.swift:46-49`) appears without animation (no fade-in or pulse). It just appears when `progress >= 1.0`.

### Architecture

11. **Manager singletons accessed directly in views** — `TodayView` creates local references like `private var healthKitManager = HealthKitManager.shared` rather than using `@Environment`. This makes testing and preview injection harder.

12. **`AppState` has properties that duplicate manager data** — `AppState` has `streakData`, `shieldData`, `todayLog` properties that appear to mirror the managers. The Today screen doesn't use these AppState copies — it reads directly from managers. Potential staleness risk.
