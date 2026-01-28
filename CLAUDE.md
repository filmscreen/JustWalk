# Just Walk V2 - Build Instructions

## Build Commands
- **Build & Check for Errors:** `xcodebuild -scheme JustWalk -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build`
- **Run Tests:** `xcodebuild test -scheme JustWalk -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Coding Guidelines
- Use SwiftUI for all views.
- Use @Observable for data models (Swift 5.9+).
- Do not use NSManagedObject (use SwiftData or Codable/JSON).