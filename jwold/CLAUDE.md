# Just Walk - Development Guidelines

## Project Overview

Just Walk is a SwiftUI iOS walking/fitness app with step tracking, streaks, interval training (Power Walk), and gear recommendations.

---

## Architecture

### Pattern: MVVM + Services

```
Views/           → SwiftUI views organized by feature
ViewModels/      → @StateObject view models (DataViewModel, etc.)
Services/        → Singleton services (.shared pattern)
Managers/        → State managers (StoreManager, ShieldInventoryManager)
Models/          → Data models and enums
Design/          → Design system (JWDesign)
```

### Singleton Services Pattern
```swift
class SomeService {
    static let shared = SomeService()
    private init() {}
}

// Usage in views:
@ObservedObject private var someService = SomeService.shared
```

---

## Design System

### JWDesign Namespace
```swift
JWDesign.Typography.headline
JWDesign.Typography.subheadline
JWDesign.Colors.background
JWDesign.Colors.secondaryBackground
JWDesign.Spacing.md
JWDesign.Spacing.horizontalInset
JWDesign.Radius.card
```

### Color Palette
| Color | Hex | Usage |
|-------|-----|-------|
| Teal | `#00C7BE` | Primary accent, goal met, Pro features |
| Green | `#34C759` | Success, Just Walk, bonus steps |
| Orange | `#FF9500` | Streak flame, protectable days, warnings |
| Yellow | `.yellow` | Trophy icons |

### Color Extension
```swift
// Project has Color(hex:) extension
Color(hex: "00C7BE")
Color(hex: "34C759")
Color(hex: "FF9500")
```

---

## View Patterns

### Sheet Presentation
```swift
.sheet(isPresented: $showSheet) {
    SomeSheet(
        param: value,
        onDismiss: { showSheet = false }
    )
    .presentationDetents([.medium])  // or [.medium, .large]
}
```

### First-Time Education Pattern
```swift
// Track with @AppStorage
@AppStorage("hasSeenFeatureEducation") private var hasSeenEducation = false
@State private var showEducation = false

// Trigger in .task
.task {
    if !hasSeenEducation && conditionMet {
        try? await Task.sleep(nanoseconds: 500_000_000)  // Let view settle
        showEducation = true
    }
}

// Mark as seen on dismiss
onDismiss: {
    hasSeenEducation = true
    showEducation = false
}
```

### Configurable Sheets (First-time vs Refresher)
```swift
struct EducationSheet: View {
    let isFirstTime: Bool  // Changes headline/content
    let dataValue: Int
    var onDismiss: () -> Void
}
```

### Callback Closures
```swift
struct SomeView: View {
    var onTap: () -> Void = {}
    var onProtectRequest: (DayStepData) -> Void = { _ in }
    var onDismiss: () -> Void = {}
}
```

---

## Component Patterns

### Reusable Row Components
```swift
struct RecentWalkRow: View {
    let workout: WorkoutHistoryItem
    var onTap: (() -> Void)? = nil
}
```

### Section Components
```swift
struct SomeSection: View {
    @ObservedObject var manager: SomeManager
    let isPro: Bool
    var onSelectItem: (Item) -> Void = { _ in }
    var onUpgrade: () -> Void = {}
}
```

### Legend Components
```swift
struct CalendarLegend: View {
    // Minimal, below main content
    // Shows: ● Label  ○ Label  🟠 Label
}
```

---

## File Naming

| Type | Convention | Example |
|------|------------|---------|
| Views | `[Name]View.swift` or `[Name]Sheet.swift` | `StreakDetailSheet.swift` |
| Sections | `[Name]Section.swift` | `ActivityHistorySection.swift` |
| Cards | `[Name]Card.swift` | `StreakHeroCard.swift` |
| Rows | `[Name]Row.swift` | `RecentWalkRow.swift` |
| Services | `[Name]Service.swift` | `StreakService.swift` |
| Managers | `[Name]Manager.swift` | `ShieldInventoryManager.swift` |

---

## UserDefaults Keys

### Naming Convention
```swift
"hasSeenShieldEducation"     // Boolean first-time flags
"hasCompletedOnboarding"     // Boolean completion flags
"dailyStepGoal"              // User preferences
"lastStreakBackfillDate"     // Timestamps
```

### Common Patterns
```swift
@AppStorage("keyName") private var value = defaultValue
UserDefaults.standard.bool(forKey: "keyName")
UserDefaults.standard.set(value, forKey: "keyName")
```

---

## Navigation

### Tab Structure
- **Today** (Dashboard) - Step ring, streaks, insights
- **Walk** - Start walks (Just Walk FREE, Power Walk PRO)
- **Progress** - History, trends, milestones, gear

### Information Architecture Principles
- **Walk tab** = Action-oriented (start walks, forward-looking)
- **Progress tab** = Reflection-oriented (history, backward-looking)
- Keep related features grouped by user intent

---

## Pro/Freemium Gating

```swift
@EnvironmentObject var storeManager: StoreManager
// or
@ObservedObject private var subscriptionManager = SubscriptionManager.shared

if storeManager.isPro {
    // Pro content
} else {
    // Free tier / upsell
}
```

---

## Haptics

```swift
HapticService.shared.playSelection()
HapticService.shared.playSuccess()
```

---

## SF Symbols Used

| Symbol | Usage |
|--------|-------|
| `figure.walk` | Just Walk, walking activity |
| `bolt.fill` | Power Walk, interval training |
| `flame.fill` | Active streak |
| `trophy.fill` | Goal exceeded |
| `shield.fill` | Streak shields |
| `info.circle` | Info/help buttons |
| `chevron.right` | Navigation indicators |
| `hand.tap.fill` | Tap hint |

---

## Visual Hierarchy Rules

### Goal Exceeded State
```
        🏆
     12,400      ← Hero metric (large, teal)
  +2,400 bonus   ← Context (smaller, green)
```
- Real accomplishment is the hero
- Bonus/context is secondary

### Education Sheets
```
     [Icon]
   Headline       ← Only for first-time
  Description
  [Rules/Tips]
  [Action Button]
```

---

## Testing Notes

- LSP errors like "Cannot find 'X' in scope" are usually scope resolution issues
- Types defined in other files will resolve at build time
- Always build in Xcode to verify actual compile errors
