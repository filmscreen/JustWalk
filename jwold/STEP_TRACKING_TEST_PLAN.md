# Step Tracking System - Test Plan & Issues Report

## Executive Summary

The step tracking system was completely rebuilt to use HealthKit as the single source of truth. Multiple critical bugs were found and fixed during comprehensive sync analysis.

**Issues Fixed:**
1. WCSession delegate conflict (Watch sync signals lost)
2. Watch complication stale data (CoreMotion bug in widget extension)
3. Step threshold blocking complication updates (>= 10 step requirement removed)
4. HealthKit throttle not bypassed on foreground (30s delay on app open)

---

## Issues Found & Fixed

### CRITICAL: WCSession Delegate Conflict

**Problem**: Both `WatchHealthManager` and `WatchSessionManager` set themselves as `WCSession.default.delegate`. Since WCSession can only have ONE delegate, `WatchSessionManager` (which initializes second) was "winning" and `WatchHealthManager` never received sync signals from iPhone.

**Impact**: The Watch would not refresh from HealthKit when signaled by iPhone, causing step counts to become stale.

**Fix Applied**:
1. Removed `WCSessionDelegate` conformance from `WatchHealthManager`
2. Made `WatchSessionManager` the sole delegate
3. Added `handleSyncSignalFromiPhone()` public method to `WatchHealthManager`
4. Updated `WatchSessionManager.handleIncomingWatchData()` to forward sync signals

**Files Changed**:
- `WatchHealthManager.swift` - Removed delegate methods, added forwarding method
- `WatchSessionManager.swift` - Added sync signal forwarding

---

### ISSUE 2: Watch Complication Stale Data

**Problem**: Watch complication showed different step count (336) than Watch app and all other surfaces (386).

**Root Cause**:
1. watchOS widget extensions can get stale CoreMotion data
2. Known Apple bug where UserDefaults read in widget extension shows old cached values
3. Widget was independently querying CoreMotion instead of using App Group data

**Fix Applied**:
1. watchOS widgets now ALWAYS use App Group data (no CoreMotion query)
2. Removed >= 10 step threshold for complication updates

**Files Changed**:
- `SimpleWalkWidgets.swift` - Added `#if os(watchOS)` to use cached data only
- `WatchHealthManager.swift` - Removed step threshold for complication updates

---

### ISSUE 3: HealthKit Throttle on Foreground

**Problem**: When user opened app within 30 seconds of last refresh, they saw stale data.

**Root Cause**: `refreshFromHealthKit()` had a 30-second throttle that wasn't bypassed on foreground.

**Fix Applied**: Added `lastHealthKitRefresh = .distantPast` in `handleAppBecomeActive()` to bypass throttle.

**Files Changed**:
- `StepTrackingService.swift` - Bypass throttle on foreground
- `WatchHealthManager.swift` - Bypass throttle on foreground

---

## Architecture Overview

### Data Flow (New Architecture)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          HEALTHKIT                                   │
│              (Single Source of Truth - De-duplicates all data)       │
└─────────────────────────────────────────────────────────────────────┘
         │                                           │
         ▼                                           ▼
┌─────────────────────┐                   ┌─────────────────────┐
│   iPhone App        │◄──sync signal────►│   Apple Watch       │
│   StepTrackingService│                   │   WatchHealthManager│
└─────────────────────┘                   └─────────────────────┘
         │                                           │
         ▼                                           ▼
┌─────────────────────┐                   ┌─────────────────────┐
│   App Group         │                   │   App Group         │
│   forDate: today    │                   │   forDate: today    │
│   todaySteps: 1234  │                   │   todaySteps: 1234  │
└─────────────────────┘                   └─────────────────────┘
         │                                           │
         ▼                                           ▼
┌─────────────────────┐                   ┌─────────────────────┐
│   Widgets           │                   │   Complications     │
└─────────────────────┘                   └─────────────────────┘
```

### Key Principles

1. **HealthKit is Truth**: HealthKit automatically de-duplicates steps from all sources (iPhone sensors, Apple Watch, third-party apps)

2. **Sync Signals, Not Data**: Watch tells iPhone "I have new data" → iPhone refreshes from HealthKit (which already contains Watch data via Apple's sync)

3. **Explicit Date Validation**: App Group stores `forDate` (the date steps are FOR), not just when updated

4. **Midnight Reset**: Both devices listen for `NSCalendarDayChanged` and check on foreground

---

## Manual Test Scenarios

### 1. Basic Functionality

| Test | Steps | Expected Result | Status |
|------|-------|-----------------|--------|
| Fresh Install | Install app, grant permissions | Shows 0 steps, syncs from HealthKit | ⬜ |
| Walking | Walk 100 steps | Count updates on both iPhone and Watch | ⬜ |
| Widget | Check home screen widget | Shows correct step count | ⬜ |
| Complication | Check Watch complication | Shows correct step count | ⬜ |

### 2. Midnight Rollover (Critical)

| Test | Steps | Expected Result | Status |
|------|-------|-----------------|--------|
| Midnight Reset | Set time to 11:59 PM, walk, wait for midnight | Steps reset to 0 at midnight | ⬜ |
| Suspended at Midnight | Close apps, wait for midnight, reopen | Steps show 0 (new day) | ⬜ |
| Widget at Midnight | Check widget after midnight | Shows 0 steps, not yesterday's count | ⬜ |
| Complication at Midnight | Check Watch complication after midnight | Shows 0 steps | ⬜ |

### 3. Sync Consistency

| Test | Steps | Expected Result | Status |
|------|-------|-----------------|--------|
| Watch → iPhone | Walk with Watch only | iPhone shows same steps after sync | ⬜ |
| iPhone → Watch | Walk with iPhone only | Watch shows same steps after sync | ⬜ |
| Both Devices | Walk with both | Shows de-duplicated total (not double) | ⬜ |
| vs HealthKit | Compare to Apple Health app | All match within 1-2 steps | ⬜ |

### 4. Edge Cases

| Test | Steps | Expected Result | Status |
|------|-------|-----------------|--------|
| App Kill | Force kill app, reopen | Restores correct count from cache/HealthKit | ⬜ |
| Airplane Mode | Walk in airplane mode, then reconnect | Syncs correctly after reconnection | ⬜ |
| Low Power Mode | Walk in low power mode | Still tracks (may delay slightly) | ⬜ |
| Background | Walk with app in background | Updates when foregrounded | ⬜ |
| Timezone Change | Change timezone by 12+ hours | Handles day boundaries correctly | ⬜ |

### 5. Performance

| Test | Metric | Target | Status |
|------|--------|--------|--------|
| HealthKit Refresh | Time to query steps | < 500ms | ⬜ |
| Widget Update | Time to refresh widget | < 2s | ⬜ |
| Memory Usage | RAM while tracking | < 50MB | ⬜ |
| Battery Impact | Battery % after 1 hour walking | < 5% | ⬜ |

---

## Unit Test Coverage

Tests created in `StepTrackingServiceTests.swift`:

### SharedStepData Tests
- ✅ `testIsForToday_WhenDateIsToday_ReturnsTrue`
- ✅ `testIsForToday_WhenDateIsYesterday_ReturnsFalse`
- ✅ `testIsForToday_WhenDateIsTomorrow_ReturnsFalse`
- ✅ `testIsForToday_AtEndOfDay_ReturnsTrue`
- ✅ `testCodable_RoundTrip`
- ✅ `testEmpty_HasDefaultValues`
- ✅ `testDataIntegrity_MaxReasonableSteps`

### StepTrackingService Tests
- ✅ `testShared_IsSingleton`
- ✅ `testInitialState_HasDefaultValues`
- ✅ `testGoalProgress_*` (zero, half, full, beyond)
- ✅ `testStepsRemaining_*` (zero, full, beyond)
- ✅ `testFormattedDistance_*` (zero, one mile)
- ✅ `testCheckForNewDay_SameDay_ReturnsFalse`
- ✅ `testSimulateTodayData_UpdatesPublishedValues`

### Supporting Type Tests
- ✅ `PaceCategoryTests` - All pace categories for IWT
- ✅ `SessionSummaryTests` - Duration calculations
- ✅ `PedometerUpdateTests` - Duration formatting
- ✅ `StepTrackingErrorTests` - Error descriptions

### Integration Tests
- ✅ `testDataConsistency_StepsAndDistanceCorrelate`
- ✅ `testWidgetDataFlow_AppGroupContainsForDate`
- ✅ `testWidgetDataFlow_StepsMatchAfterSimulation`

### Edge Case Tests
- ✅ `testEdgeCase_ZeroStepGoal_NoInfiniteProgress`
- ✅ `testEdgeCase_VeryHighStepCount_Accepted`
- ✅ `testEdgeCase_SuspiciouslyHighStepCount_NotSaved`

---

## Running Tests

```bash
# Run iPhone tests
xcodebuild test -project "Just Walk.xcodeproj" -scheme "Just Walk" -destination "platform=iOS Simulator,name=iPhone 15"

# Run Watch tests
xcodebuild test -project "Just Walk.xcodeproj" -scheme "Just Walk (Apple Watch) Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)"
```

---

## Validation Checklist Before Release

- [ ] All unit tests pass
- [ ] Manual midnight rollover test passes
- [ ] Watch-iPhone sync verified
- [ ] Widgets update correctly
- [ ] Complications update correctly
- [ ] Steps match Apple Health app
- [ ] No memory leaks detected
- [ ] Battery impact acceptable
- [ ] Tested on physical devices (not just simulator)

---

## Known Limitations

1. **HealthKit Lag**: HealthKit may lag 5-30 seconds behind real-time pedometer data. We use `max(healthKitSteps, realtimeSteps)` to show the higher value.

2. **Background Limits**: iOS/watchOS limit background execution. Step updates may pause when apps are suspended.

3. **Timezone Edge Cases**: Crossing timezone boundaries at midnight is an edge case that may show brief inconsistencies.

4. **First Launch After Midnight**: If app hasn't run since yesterday, cached data will be rejected (correct behavior), but there may be a brief moment showing 0 steps before HealthKit responds.
