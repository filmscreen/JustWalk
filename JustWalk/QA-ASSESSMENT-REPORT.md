# Just Walk Pro — Pre-Launch QA Assessment Report

**Assessment Date:** February 1, 2026
**Assessed By:** QA Engineer (Automated Analysis)
**App Version:** Pre-Launch
**Platform:** iOS, watchOS

---

## 1. Executive Summary

| Metric | Value |
|--------|-------|
| **Overall App Readiness Score** | **7/10** |
| **Critical Issues** | 2 |
| **Major Issues** | 3 |
| **Minor Issues** | 6 |
| **Recommendation** | **Ship with known issues** (after addressing CRIT-001) |

The app is generally well-structured with good code quality. However, there are **two critical security issues** that must be addressed before App Store submission. The most severe is a hardcoded API key in source code that poses a security risk. Once these are resolved, the app should be ready for release.

---

## 2. Critical Issues (Must Fix Before Launch)

### CRIT-001: Hardcoded Gemini API Key in Source Code

| Field | Value |
|-------|-------|
| **ID** | CRIT-001 |
| **Location** | `JustWalk/Services/GeminiService.swift:198` |
| **Severity** | CRITICAL - Security Vulnerability |

**Description:**
The Gemini AI API key was hardcoded directly in the source code.

**Status: ✅ FIXED**
- API key moved to `Secrets.xcconfig` (gitignored)
- `GeminiService.swift` now loads key from Info.plist build settings
- Compromised key was rotated

**Original Risk:**
- API key could be extracted from compiled binary
- Potential for API abuse and unauthorized usage
- Financial liability if key is compromised

---

### CRIT-002: RevenueCat API Key in Info.plist

| Field | Value |
|-------|-------|
| **ID** | CRIT-002 |
| **Location** | `JustWalk/Info.plist:24` |
| **Severity** | CRITICAL - Security Concern |

**Description:**
A RevenueCat API key is stored in Info.plist:
```xml
<key>REVENUECAT_API_KEY</key>
<string>sk_ySZkxgCmOCypmPasAuTlnrviuVSTM</string>
```

**Note:** It appears RevenueCat may not actually be in use (StoreKit 2 is used directly via `SubscriptionManager.swift`). If this key is not needed, it should be removed.

**Recommendation:**
1. If RevenueCat is not used, remove this key entirely
2. If RevenueCat is used, verify this is a PUBLIC key (not secret key)
3. RevenueCat public keys starting with `appl_` are safe; keys starting with `sk_` may be SDK keys that need review

---

## 3. Major Issues (Should Fix Before Launch)

### MAJ-001: Debug Print Statements in Production Code

| Field | Value |
|-------|-------|
| **ID** | MAJ-001 |
| **Location** | Multiple files |
| **Severity** | MAJOR - Production Readiness |

**Description:**
Multiple unguarded `print()` statements found in production code that will appear in device console logs:

**Files affected:**
- `GeminiPrompts.swift` (Lines 1108, 1109, 1119, 1121) - Exposes API responses
- `PhoneConnectivityManager.swift` (Lines 65, 260-276, 301, 350, 359)
- `PermissionsView.swift` (Lines 175-219) - 7 debug prints
- `ActiveWalkBanner.swift` (Line 81) - "Tapped!" debug message

**Risk:**
- Exposes internal data and API responses in console
- Unprofessional user experience
- Potential information leakage

**Recommendation:**
Use the existing DEBUG-guarded pattern from `DynamicCardEngine.swift`:
```swift
#if DEBUG
private func debugLog(_ message: String) {
    print("[DynamicCardEngine] \(message)")
}
#else
private func debugLog(_ message: String) {}
#endif
```

---

### MAJ-002: Force Unwrap in Production Code

| Field | Value |
|-------|-------|
| **ID** | MAJ-002 |
| **Location** | `BackgroundTaskManager.swift:49, 57` |
| **Severity** | MAJOR - Potential Crash |

**Description:**
Forced casts that could crash if the task type doesn't match:
```swift
self.handleWidgetRefreshTask(task as! BGAppRefreshTask)
self.handleHealthKitSyncTask(task as! BGProcessingTask)
```

**Risk:**
- App crash if task type mismatch occurs
- Background task failures

**Recommendation:**
Use safe casting:
```swift
guard let refreshTask = task as? BGAppRefreshTask else { return }
self.handleWidgetRefreshTask(refreshTask)
```

---

### MAJ-003: Conditional Force Unwraps

| Field | Value |
|-------|-------|
| **ID** | MAJ-003 |
| **Location** | `InsightCard.swift:269`, `StepDataManager.swift:201` |
| **Severity** | MAJOR - Code Quality |

**Description:**
Force unwraps after nil checks that could be refactored:
```swift
// InsightCard.swift:269
if best == nil || weeks.count > best!.weeks {

// StepDataManager.swift:201
.filter { todayLog == nil || $0.id != todayLog!.id }
```

**Risk:**
- While technically safe due to preceding nil check, this pattern is fragile
- Future code changes could introduce crash potential

**Recommendation:**
Use optional binding or guard statements instead.

---

## 4. Minor Issues (Can Fix Post-Launch)

### MIN-001: Fixed Frame Dimensions May Cause Layout Issues

| Field | Value |
|-------|-------|
| **ID** | MIN-001 |
| **Location** | `StepRingView.swift:26, 31, 42` |
| **Severity** | MINOR - UX on Small Screens |

**Description:**
Fixed frame dimensions of 220x220 and 200x200 pixels may not scale well on iPhone SE or smaller screens.

**Recommendation:**
Test on iPhone SE and consider using `GeometryReader` for responsive sizing.

---

### MIN-002: TODO Comment Indicates Unfinished Work

| Field | Value |
|-------|-------|
| **ID** | MIN-002 |
| **Location** | `GeminiService.swift:197` |
| **Severity** | MINOR - Code Hygiene |

**Description:**
TODO comment indicates known technical debt:
```swift
// TODO: Move API key to secure storage before production release
```

**Recommendation:**
Address as part of CRIT-001, then remove the TODO comment.

---

### MIN-003: APS Environment Set to Development

| Field | Value |
|-------|-------|
| **ID** | MIN-003 |
| **Location** | `JustWalk.entitlements:6` |
| **Severity** | MINOR - Build Configuration |

**Description:**
Push notification environment is set to "development":
```xml
<key>aps-environment</key>
<string>development</string>
```

**Recommendation:**
Ensure Archive/Release builds use "production" environment. Xcode typically handles this automatically for distribution builds, but verify in App Store Connect submission.

---

### MIN-004: Duplicate Asset Files

| Field | Value |
|-------|-------|
| **ID** | MIN-004 |
| **Location** | `Assets.xcassets/AppIcon.appiconset/` |
| **Severity** | MINOR - Asset Hygiene |

**Description:**
Found duplicate image files:
- `appicon_clean.png`
- `appicon_clean 2.png`

**Recommendation:**
Remove duplicate files to reduce app bundle size.

---

### MIN-005: LaunchScreen Duplicate Asset

| Field | Value |
|-------|-------|
| **ID** | MIN-005 |
| **Location** | `JustWalk/` root directory |
| **Severity** | MINOR - Asset Hygiene |

**Description:**
Found duplicate launch screen logo:
- `LaunchScreenLogo.png`
- `LaunchScreenLogo 2.png`

**Recommendation:**
Remove the duplicate file.

---

### MIN-006: Inconsistent Debug Logging Pattern

| Field | Value |
|-------|-------|
| **ID** | MIN-006 |
| **Location** | Various managers |
| **Severity** | MINOR - Code Consistency |

**Description:**
`DynamicCardEngine.swift` has proper `#if DEBUG` guarded logging, but other managers use unguarded prints.

**Recommendation:**
Standardize debug logging approach across all managers.

---

## 5. Warnings (Not Bugs, But Worth Noting)

### WARN-001: Watch Connectivity Fallbacks

The `PhoneConnectivityManager.swift` has good error handling but uses print statements for errors. Consider using proper logging framework.

### WARN-002: CloudKit Sync Complexity

`CloudKitSyncManager.swift` is over 1200 lines. Consider breaking into smaller, more focused components for maintainability.

### WARN-003: WeatherKit Entitlement Present

The app has `com.apple.developer.weatherkit` entitlement but unclear if it's actively used. Unused entitlements may cause App Store review questions.

### WARN-004: Location Always-On Permission

The app requests "always" location permission. Ensure you have clear user-facing explanation for why background location is needed. Apple scrutinizes always-on location requests.

---

## 6. CloudKit Schema Verification

The CloudKit implementation syncs 5 record types. **Verify these are properly set up in CloudKit Dashboard.**

### Record Types Required in CloudKit Dashboard

#### 1. `UserGameState` (single record per user)
| Field | Type | Notes |
|-------|------|-------|
| `dailyGoal` | Int64 | Step goal |
| `streakJSON` | Bytes | Encoded StreakData |
| `shieldJSON` | Bytes | Encoded ShieldData |
| `profileJSON` | Bytes | Encoded UserProfile |
| `userSettingsJSON` | Bytes | Notification/haptic/education settings |
| `milestoneStateJSON` | Bytes | Milestone achievements |

**Index Required:** None (single record with fixed ID)

#### 2. `DailyLog` (one per day)
| Field | Type | Notes |
|-------|------|-------|
| `logID` | String | Unique identifier |
| `date` | Date/Time | The day this log represents |
| `dateString` | String | ISO format for lookups |
| `steps` | Int64 | Step count for the day |
| `goalTarget` | Int64 | Goal for that day |
| `goalMet` | Int64 | 1 = met, 0 = not met |
| `shieldUsed` | Int64 | 1 = shield protected this day |

**Index Required:** `dateString` (QUERYABLE) for daily lookups

#### 3. `TrackedWalk` (one per walk)
| Field | Type | Notes |
|-------|------|-------|
| `walkJSON` | Bytes | Full encoded TrackedWalk |

**Index Required:** None (fetches all, merges by ID)

#### 4. `FoodLog` (one per food entry) ⚠️ VERIFY THIS
| Field | Type | Notes |
|-------|------|-------|
| `logID` | String | Unique identifier |
| `date` | Date/Time | When the food was logged |
| `mealType` | String | breakfast/lunch/dinner/snack/unspecified |
| `name` | String | Short display name |
| `entryDescription` | String | Full description for AI |
| `calories` | Int64 | Calorie count |
| `protein` | Int64 | Grams of protein |
| `carbs` | Int64 | Grams of carbs |
| `fat` | Int64 | Grams of fat |
| `source` | String | ai/aiAdjusted/manual |
| `createdAt` | Date/Time | Entry creation time |
| `modifiedAt` | Date/Time | Last modification time |

**Index Required:** `date` (QUERYABLE) for daily lookups

#### 5. `CalorieGoalSettings` (single record) ⚠️ VERIFY THIS
| Field | Type | Notes |
|-------|------|-------|
| `settingsID` | String | Unique identifier |
| `dailyGoal` | Int64 | Calorie goal (e.g., 1650) |
| `calculatedMaintenance` | Int64 | Calculated maintenance (e.g., 2150) |
| `sex` | String | "male" or "female" |
| `age` | Int64 | User's age |
| `heightCM` | Double | Height in centimeters |
| `weightKG` | Double | Weight in kilograms |
| `activityLevel` | String | sedentary/light/moderate/active |
| `createdAt` | Date/Time | When settings were created |
| `modifiedAt` | Date/Time | Last modification time |

**Index Required:** None (single record per user)

### CloudKit Verification Checklist

- [ ] `UserGameState` record type exists with all fields
- [ ] `DailyLog` record type exists with all fields
- [ ] `DailyLog.dateString` has QUERYABLE index
- [ ] `TrackedWalk` record type exists with `walkJSON` field
- [ ] **`FoodLog` record type exists with all 12 fields listed above**
- [ ] **`FoodLog.date` has QUERYABLE index**
- [ ] **`CalorieGoalSettings` record type exists with all 10 fields listed above**
- [ ] Custom zone `JustWalkZone` is created automatically by app

### Testing CloudKit Sync for Fuel Features

1. **Create a calorie goal** on Device A
   - Enter sex, age, height, weight, activity level
   - Set a daily calorie goal
   - Verify it syncs to Device B

2. **Log food entries** on Device A
   - Add breakfast, lunch, dinner items
   - Edit an entry (change calories)
   - Delete an entry
   - Verify all changes sync to Device B

3. **Edge cases to test:**
   - Create goal on Device A, modify on Device B (last-write-wins)
   - Log food offline, verify sync when back online
   - Delete calorie goal, verify it's removed on other devices

---

## 7. Test Coverage Gaps

The following areas could not be fully tested via static analysis and require manual testing:

| Area | Reason | Manual Test Required |
|------|--------|---------------------|
| HealthKit Integration | Requires real device with health data | Yes - test on physical device |
| CloudKit Sync | Requires network and iCloud account | Yes - test with multiple devices |
| StoreKit Purchases | Requires sandbox/TestFlight testing | Yes - test purchase flows |
| Push Notifications | Requires real device | Yes - test notification delivery |
| Watch App | Requires Apple Watch or simulator | Yes - test watch complications |
| Widget Updates | Requires device testing | Yes - test timeline updates |
| Background Tasks | Requires extended testing | Yes - verify background refresh works |
| Live Activities | Requires iOS 16.1+ device | Yes - test walk tracking banner |
| Walk GPS Tracking | Requires real device movement | Yes - test location accuracy |
| Gemini AI Responses | Requires API testing | Yes - test edge cases |

---

## 8. Positive Findings

### Code Quality Highlights

1. **Clean Architecture**: Good separation of concerns with dedicated managers for each feature area (HealthKit, CloudKit, Subscriptions, etc.)

2. **SwiftUI Best Practices**: Proper use of `@Observable`, `@MainActor`, and state management

3. **No Empty Catch Blocks**: All error handling includes proper error logging

4. **StoreKit 2 Implementation**: Modern, correct implementation of in-app purchases with proper transaction listening

5. **Privacy Compliance**:
   - Privacy policy and Terms of Service links present
   - Restore purchases button accessible
   - HealthKit usage descriptions properly configured
   - `ITSAppUsesNonExemptEncryption` set to false

6. **Error Handling**: Gemini API has comprehensive error types and handling

7. **Haptic Feedback**: Centralized `JustWalkHaptics` system for consistent UX

8. **Design System**: `JustWalkTheme` provides consistent design tokens

9. **Animation System**: Centralized `JustWalkAnimation` for consistent motion design

10. **App Icon & Launch Screen**: Properly configured with all required sizes

---

## 9. App Store Compliance Checklist

| Requirement | Status | Notes |
|-------------|--------|-------|
| Privacy Policy Link | ✅ Pass | Links to getjustwalk.com/privacy |
| Terms of Service Link | ✅ Pass | Links to getjustwalk.com/terms |
| Restore Purchases Button | ✅ Pass | Available in Settings and Paywall |
| HealthKit Usage Descriptions | ✅ Pass | Proper descriptions in Info.plist |
| Location Usage Descriptions | ✅ Pass | Both when-in-use and always descriptions |
| Motion Usage Description | ✅ Pass | Explains step counting usage |
| Photo Library Description | ✅ Pass | For saving walk summaries |
| No Private API Usage | ✅ Pass | No evidence of private API usage |
| Encryption Declaration | ✅ Pass | ITSAppUsesNonExemptEncryption = false |
| App Icon | ✅ Pass | All sizes present |
| Launch Screen | ✅ Pass | Storyboard configured |

---

## 10. Summary & Recommendations

### Before App Store Submission:

1. **MUST FIX**: Move Gemini API key to secure storage (CRIT-001)
2. **MUST FIX**: Verify/remove RevenueCat key from Info.plist (CRIT-002)
3. **SHOULD FIX**: Remove or guard all print() statements (MAJ-001)
4. **SHOULD FIX**: Replace force casts with safe casts (MAJ-002, MAJ-003)

### After Launch (Post-Release):

1. Clean up duplicate asset files
2. Standardize debug logging across all managers
3. Test UI on iPhone SE for layout issues
4. Consider refactoring CloudKitSyncManager for maintainability

### Manual Testing Checklist Before Submit:

- [ ] Complete a full walk session with GPS tracking
- [ ] Test subscription purchase flow in TestFlight
- [ ] Test restore purchases with existing subscription
- [ ] Verify widget updates with fresh step data
- [ ] Test CloudKit sync between two devices
- [ ] Test onboarding flow from fresh install
- [ ] Test streak/shield mechanics
- [ ] Test AI food logging with various inputs
- [ ] Test all notification types
- [ ] Test on iPhone SE for small screen layout

---

**Report Generated:** February 1, 2026
**Files Analyzed:** 234 Swift files
**Build Status:** ✅ BUILD SUCCEEDED (0 errors, 0 warnings)
