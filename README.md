# Just Walk

A minimalist iOS step tracking app focused on building daily walking habits through streaks and gentle motivation.

## Features

- **Daily Step Tracking** — Syncs with HealthKit for accurate step counts
- **Streak System** — Build and maintain walking streaks with daily goals
- **Streak Shields** — Protect your streak on rest days (Pro feature)
- **Home Screen Widgets** — Multiple widget sizes showing steps, streaks, and weekly progress
- **Watch App** — Companion app for Apple Watch with complications
- **Live Activities** — Track walks in real-time on Lock Screen and Dynamic Island

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+

## Getting Started

1. Clone the repository
2. Open `JustWalk/JustWalk.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on simulator or device

## Project Structure

```
JustWalk/
├── JustWalk/                    # Main iOS app
│   ├── Views/                   # SwiftUI views
│   ├── Managers/                # Business logic (HealthKit, Streak, etc.)
│   ├── Models/                  # Data models
│   └── DesignSystem/            # Theme, colors, fonts
├── JustWalk Widgets/            # iOS widget extension
├── JustWalk Widgets (Watch)/    # watchOS widget extension
└── JustWalkWatch Watch App/     # watchOS companion app
```

## Architecture

- **SwiftUI** for all UI
- **@Observable** macro for state management (Swift 5.9+)
- **HealthKit** for step data
- **WidgetKit** for home screen widgets
- **ActivityKit** for Live Activities

## License

Private repository. All rights reserved.
