# CloudKit Sync Audit Report

**Date:** 2026-01-26
**Auditor:** Claude (automated code review)
**Codebase:** JustWalk iOS App
**CloudKit Container:** `iCloud.onworldtech.JustWalk`
**Custom Zone:** `JustWalkZone` (private database)

---

## Executive Summary

The CloudKit implementation syncs **most** critical user data, but has **several significant gaps** that would cause data loss on reinstall or device migration. The most critical issues are:

1. **Challenge progress is NOT synced at all** — users lose all monthly challenge progress on reinstall
2. **Shield conflict resolution uses MAX** (should use MIN) — exploitable for shield duplication
3. **No background/termination sync** — data can be lost if app is killed right after a walk
4. **90-day data window** — walk history and daily logs older than 90 days are never pushed to cloud
5. **Profile settings not fully restored** — displayName, stepGoal, units, and onboarding flags rely on local-wins merge that discards remote values on existing installs

---

## PHASE 1: Data Coverage

### User Identity — UserProfile

| Field | In Model | Pushed to Cloud | Pulled & Merged | Conflict Strategy | Status |
|-------|----------|-----------------|-----------------|-------------------|--------|
| `displayName` | Yes | Yes (via profileJSON) | Partial — local wins | Local settings win | **ISSUE** — on fresh install, remote displayName IS applied (no local data). On existing install with different name, remote is discarded. Acceptable behavior. |
| `dailyStepGoal` | Yes | Yes (via profileJSON) | Partial — local wins | Local settings win | **ISSUE** — same as above. After reinstall on fresh device, goal will restore. But cross-device changes are one-way. |
| `useMetricUnits` | Yes | Yes (via profileJSON) | Partial — local wins | Local settings win | Same as above |
| `hasCompletedOnboarding` | Yes | Yes (via profileJSON) | Partial — local wins | Local settings win | **BUG** — on fresh reinstall, merge only applies `createdAt` and `legacyBadges` from remote. `hasCompletedOnboarding` is NOT explicitly merged, so a reinstall will show onboarding again despite having cloud data. |
| `hasSeenFirstWalkEducation` | Yes | Yes (via profileJSON) | Partial — local wins | Local settings win | **Same BUG** — will show first walk education again after reinstall |
| `createdAt` | Yes | Yes (via profileJSON) | Yes — earliest wins | Min(local, remote) | **OK** |
| `isPro` | Yes | Yes (via profileJSON) | Partial — local wins | Local wins | **OK** — Pro restored via StoreKit, not CloudKit |
| `legacyBadges` | Yes | Yes (via profileJSON) | Yes — union merge | Union of IDs | **OK** |

### Rank & XP — RankData

| Field | In Model | Pushed | Pulled & Merged | Conflict Strategy | Status |
|-------|----------|--------|-----------------|-------------------|--------|
| `totalXP` | Yes | Yes (via rankDataJSON) | Yes | Max(local, remote) | **OK** |
| `currentRank` | Yes | Yes (via rankDataJSON) | Yes — recalculated | Derived from totalXP | **OK** |
| `currentGrade` | Yes | Yes (via rankDataJSON) | Yes — recalculated | Derived from totalXP | **OK** |
| XP transaction history | N/A | N/A | N/A | N/A | **NOT TRACKED** — no XP history model exists. XP is a running total only. |

**XP Conflict Analysis:**
- Uses `Max(local, remote)` — XP is never lost
- **However:** In offline multi-device scenario, XP earned on both devices is NOT additive. If Device A earns 100 XP (1000→1100) and Device B earns 50 XP (1000→1050) offline, merge result is 1100, not 1150. The 50 XP from Device B is lost.
- **Root cause:** No transaction log to compute true total. Only raw totalXP is compared.

### Streak — StreakData

| Field | In Model | Pushed | Pulled & Merged | Conflict Strategy | Status |
|-------|----------|--------|-----------------|-------------------|--------|
| `currentStreak` | Yes | Yes | Yes | Most recent `lastGoalMetDate` wins | **OK** |
| `longestStreak` | Yes | Yes | Yes | Max(local, remote) | **OK** |
| `lastGoalMetDate` | Yes | Yes | Yes | Most recent wins | **OK** |
| `streakStartDate` | Yes | Yes | Yes | Follows `lastGoalMetDate` winner | **OK** |
| `consecutiveGoalDays` | Yes | Yes | Yes | Max(local, remote) | **OK** |

### Shields — ShieldData

| Field | In Model | Pushed | Pulled & Merged | Conflict Strategy | Status |
|-------|----------|--------|-----------------|-------------------|--------|
| `availableShields` | Yes | Yes | Yes | **Max(local, remote)** | **BUG** — should be MIN. Max allows shield duplication exploit (see Test 4 below). |
| `lastRefillDate` | Yes | Yes | **NO** — not merged | Not handled | **BUG** — `lastRefillDate` is never merged. Could cause double-refill across devices. |
| `shieldsUsedThisMonth` | Yes | Yes | **NO** — not merged | Not handled | **BUG** — usage count not synced. One device won't know about shields used on another. |
| `purchasedShields` | Yes | Yes | Yes | Max(local, remote) | **OK** for lifetime count |

### Legacy Badges

| Field | In Model | Pushed | Pulled & Merged | Status |
|-------|----------|--------|-----------------|--------|
| `id` (UUID) | Yes | Yes (in profileJSON) | Yes — union by ID | **OK** |
| `streakLength` | Yes | Yes | Yes | **OK** |
| `earnedAt` | Yes | Yes | Yes | **OK** |
| Badge array | Yes | Yes | Yes — union merge | **OK** |

**Legacy Badge Verdict: PASS** — Union merge ensures badges are never lost across devices.

### Daily Logs

| Field | In Model | Pushed | Pulled & Merged | Conflict Strategy | Status |
|-------|----------|--------|-----------------|-------------------|--------|
| `id` | Yes | Yes (via logJSON) | Yes | N/A | OK |
| `date` | Yes | Yes | Yes | Keyed by dateString | OK |
| `steps` | Yes | Yes | Yes | Max(local, remote) | **OK** |
| `goalMet` | Yes | Yes | Yes | OR(local, remote) | **OK** |
| `shieldUsed` | Yes | Yes | Yes | OR(local, remote) | **OK** |
| `xpEarned` | Yes | Yes | Yes | Max(local, remote) | **OK** |
| `trackedWalkIDs` | Yes | Yes | Yes | Union by ID | **OK** |

**Daily Log Limitations:**
- **Only last 90 days are pushed** (cutoff in `pushAllToCloud()` line 154)
- Older logs exist locally but are never synced
- On reinstall, only cloud data (≤90 days) is restored — older history is permanently lost

### Tracked Walks

| Field | In Model | Pushed | Pulled & Merged | Status |
|-------|----------|--------|-----------------|--------|
| `id` | Yes | Yes | Yes — insert-if-missing | **OK** |
| `startTime` | Yes | Yes | Yes | OK |
| `endTime` | Yes | Yes | Yes | OK |
| `durationMinutes` | Yes | Yes | Yes | OK |
| `steps` | Yes | Yes | Yes | OK |
| `distanceMeters` | Yes | Yes | Yes | OK |
| `xpEarned` | Yes | Yes | Yes | OK |
| `mode` | Yes | Yes | Yes | OK |
| `goal` | Yes | Yes | Yes | OK |
| `intervalProgram` | Yes | Yes | Yes | OK |
| `intervalCompleted` | Yes | Yes | Yes | OK |
| `routeCoordinates` | Yes | Yes | Yes | **CONCERN** — large arrays may hit CloudKit record size limits (1 MB per record) |

**Tracked Walk Limitations:**
- **Only last 90 days are pushed** — same cutoff as daily logs
- Walk merge is insert-if-missing by UUID — immutable, no conflicts. Good.
- **Route coordinates** for long walks could be very large. No compression or CKAsset usage.

### Challenge Progress

| Field | In Model | Pushed | Pulled & Merged | Status |
|-------|----------|--------|-----------------|--------|
| `MonthlyChallengePack` | Yes | **NO** | **NO** | **CRITICAL BUG** — not synced at all |
| `ChallengeProgress.challengeId` | Yes | **NO** | **NO** | Not synced |
| `ChallengeProgress.currentValue` | Yes | **NO** | **NO** | Not synced |
| `ChallengeProgress.isComplete` | Yes | **NO** | **NO** | Not synced |
| `ChallengeProgress.completedAt` | Yes | **NO** | **NO** | Not synced |

**Root Cause:** `PersistenceManager.saveChallengePack()` does NOT post a notification. `CloudKitSyncManager` does NOT have a record type for challenge data. Challenge data is completely absent from the CloudKit schema.

### Subscription

| Aspect | Status |
|--------|--------|
| Pro status via StoreKit (not CloudKit) | **OK** — correct approach |
| Purchased shields synced via CloudKit | **OK** — `purchasedShields` field in ShieldData |
| StoreKit receipt restoration on new device | **UNTESTED** — relies on Apple infrastructure |

---

## PHASE 2: Sync Trigger Analysis

### Sync Trigger Points

| Trigger Event | Fires PersistenceManager Notification | CloudKit Push Triggered | Status |
|--------------|--------------------------------------|------------------------|--------|
| Walk completes (WalkTabView) | Yes — `.didSaveTrackedWalk`, `.didSaveDailyLog`, `.didSaveRankData` | Yes (debounced 2s) | **OK** |
| Daily goal met (StreakManager) | Yes — `.didSaveStreakData` | Yes | **OK** |
| Shield used (ShieldManager) | Yes — `.didSaveShieldData`, `.didSaveDailyLog` | Yes | **OK** |
| Shield purchased (SubscriptionManager) | Yes — `.didSaveShieldData` | Yes | **OK** |
| Rank/grade changes (RankManager) | Yes — `.didSaveRankData` | Yes | **OK** |
| Challenge progress (ChallengeManager) | **NO — no notification posted** | **NO** | **BUG** |
| App enters background | **NO handler exists** | **NO** | **BUG** |
| App launches / becomes active | N/A | Pull only (no push) | **PARTIAL** — pull works, no push on launch |
| Profile changes (settings) | Yes — `.didSaveProfile` | Yes | **OK** |

### Missing Sync Triggers

1. **`ChallengeManager.updateProgress()`** — saves to persistence but no notification, no sync
2. **`scenePhase == .background`** — no handler to flush pending sync before app is suspended
3. **App launch** — only pulls, doesn't push. If previous session's push was interrupted, stale local data won't be pushed until next data change.

---

## PHASE 3: Conflict Resolution Analysis

### Current Strategy

| Data Type | Strategy | Correct? | Notes |
|-----------|----------|----------|-------|
| **RankData.totalXP** | Max(local, remote) | **PARTIAL** | Prevents XP loss but loses offline-earned XP in multi-device conflict (not additive) |
| **StreakData.currentStreak** | Most recent lastGoalMetDate wins | **OK** | Sensible — most recent activity is authoritative |
| **StreakData.longestStreak** | Max(local, remote) | **OK** | Never decreases |
| **StreakData.consecutiveGoalDays** | Max(local, remote) | **OK** | |
| **ShieldData.availableShields** | Max(local, remote) | **BUG** | Should be MIN to prevent duplication exploit |
| **ShieldData.purchasedShields** | Max(local, remote) | **OK** | Lifetime counter |
| **ShieldData.lastRefillDate** | NOT MERGED | **BUG** | Could cause double monthly refill |
| **ShieldData.shieldsUsedThisMonth** | NOT MERGED | **BUG** | Usage tracking lost |
| **UserProfile** | Local wins (except createdAt, legacyBadges) | **PARTIAL** | Fine for preferences, but `hasCompletedOnboarding` should merge with OR logic |
| **DailyLog** | Max steps/xp, OR goalMet/shieldUsed, union walkIDs | **OK** | Well-designed merge |
| **TrackedWalk** | Insert-if-missing by UUID | **OK** | Immutable records, correct approach |
| **ChallengePack** | NOT SYNCED | **CRITICAL** | |

### Shield Duplication Exploit (Test 4 Scenario)

**Current behavior:**
1. Device A: 2 shields → uses 1 → has 1
2. Device B (offline): 2 shields → uses 1 → has 1
3. Sync: Max(1, 1) = 1 shield remaining

Actually in this specific case Max gives the right answer (1). But consider:
1. Device A: 2 shields → uses 2 → has 0
2. Device B (offline): 2 shields → uses 0 → has 2
3. Sync: Max(0, 2) = **2 shields** — but 2 were consumed on Device A!

The user effectively duplicated 2 shields. **MIN would give 0**, which is correct.

---

## PHASE 4: Error Handling Analysis

### Network Failures

| Scenario | Handled | Implementation | Status |
|----------|---------|---------------|--------|
| Sync failure sets error status | Yes | `syncStatus = .error(msg)` | **OK** — visible in debug UI |
| Failed syncs queued for retry | **NO** | No retry queue or exponential backoff | **BUG** |
| Retry on next connectivity | **NO** | No `NWPathMonitor` or reachability check | **BUG** |
| User manual sync in Settings | Yes | Debug section only (`#if DEBUG`) | **PARTIAL** — not available in production |
| Sync failure crash-free | Yes | Errors logged, status updated | **OK** |

### iCloud Not Signed In

| Scenario | Handled | Status |
|----------|---------|--------|
| App works fully offline | Yes — all data in UserDefaults | **OK** |
| User warned about no backup | **NO** — no UI indicator | **BUG** |
| No crashes when iCloud unavailable | **PARTIAL** — zone creation fails silently | **OK** (won't crash, but no user feedback) |

### iCloud Storage Full

| Scenario | Handled | Status |
|----------|---------|--------|
| Handles `quotaExceeded` | **NO** — generic error handling only | **BUG** |
| User notified | **NO** | **BUG** |
| Local data preserved | Yes — UserDefaults unaffected | **OK** |

### Specific CKError Handling

| CKError Code | Handled | Status |
|--------------|---------|--------|
| `.unknownItem` | Yes — treated as "record doesn't exist yet" | **OK** |
| `.networkUnavailable` | No specific handler | **BUG** |
| `.quotaExceeded` | No specific handler | **BUG** |
| `.serverRecordChanged` (conflict) | No — uses `.changedKeys` save policy | **ISSUE** — see below |
| `.limitExceeded` | Partially — batches at 400 | **OK** |
| `.retryAfterError` | Not handled | **BUG** |
| `.partialFailure` | Not handled | **BUG** |

### Save Policy Issue

The implementation uses `operation.savePolicy = .changedKeys` (line 178). This means:
- If another device has modified the same record since last fetch, CloudKit will **reject** the save with `.serverRecordChanged`
- The code does NOT handle this error — the batch fails silently
- Should use `.ifServerRecordUnchanged` with conflict resolution callback, OR fetch-before-save pattern

**Current workaround:** Since records are overwritten entirely from JSON blobs, `.changedKeys` may cause silent data loss when two devices modify the same game state record simultaneously.

---

## PHASE 5: Code Review Checklist

### Security

| Check | Status | Notes |
|-------|--------|-------|
| Using private database | **PASS** | `container.privateCloudDatabase` (line 69) |
| No sensitive data in record names | **PASS** | Record names are generic: `UserGameState_v1`, `DailyLog_YYYY-MM-DD`, `Walk_UUID` |
| Subscription NOT in CloudKit | **PASS** | Pro status managed by StoreKit |

### Efficiency

| Check | Status | Notes |
|-------|--------|-------|
| `CKModifyRecordsOperation` for batch saves | **PASS** | Batches of 400 records |
| Proper query predicates | **FAIL** | Uses `NSPredicate(value: true)` — fetches ALL records every pull |
| `CKQueryCursor` for pagination | **PASS** | `fetchMore(cursor:)` implemented |
| Incremental sync (change tokens) | **FAIL** | Full re-fetch every pull — no `CKFetchRecordZoneChangesOperation` or change tokens |
| `CKSubscription` for push sync | **FAIL** | No push notifications from CloudKit — only polls on app foreground |
| Debounced push | **PASS** | 2-second debounce prevents rapid-fire saves |

### Reliability

| Check | Status | Notes |
|-------|--------|-------|
| `CKError.networkUnavailable` handling | **FAIL** | Generic error only |
| `CKError.quotaExceeded` handling | **FAIL** | Generic error only |
| `CKError.serverRecordChanged` handling | **FAIL** | Not handled — will silently fail |
| Exponential backoff | **FAIL** | No retry mechanism |
| Re-entrant sync prevention | **PASS** | `isSyncing` flag prevents overlapping syncs |
| Merge suppression | **PASS** | `isMerging` flag prevents notification loops |

---

## Issues Summary (Ranked by Severity)

### CRITICAL

| # | Issue | Impact | File | Fix Effort |
|---|-------|--------|------|------------|
| 1 | **Challenge progress not synced** | All monthly challenge progress lost on reinstall | `CloudKitSyncManager.swift`, `PersistenceManager.swift`, `ChallengeManager.swift` | Medium — add record type, notification, merge logic |
| 2 | **Shield conflict uses MAX instead of MIN** | Users can duplicate shields via offline exploit | `CloudKitSyncManager.swift:414` | Trivial — change `>` to `<` |
| 3 | **`hasCompletedOnboarding` not restored** | Users see onboarding again after reinstall despite having data | `CloudKitSyncManager.swift:428-451` | Trivial — add OR merge for boolean flags |
| 4 | **90-day data window** | Walk history and daily logs older than 90 days permanently lost on reinstall | `CloudKitSyncManager.swift:154,160` | Medium — remove cutoff or extend significantly |

### HIGH

| # | Issue | Impact | File | Fix Effort |
|---|-------|--------|------|------------|
| 5 | **No background/termination sync** | Data loss if app killed immediately after walk | `JustWalkApp.swift` | Low — add `.background` scene phase handler |
| 6 | **ShieldData.lastRefillDate not merged** | Could cause double monthly shield refill across devices | `CloudKitSyncManager.swift:408-426` | Low — add most-recent-date merge |
| 7 | **ShieldData.shieldsUsedThisMonth not merged** | Usage tracking inaccurate across devices | `CloudKitSyncManager.swift:408-426` | Low — add max merge |
| 8 | **No retry/backoff on sync failure** | Failed syncs are never retried until next data change | `CloudKitSyncManager.swift` | Medium — add retry queue |
| 9 | **XP not additive in multi-device conflict** | XP earned offline on second device lost in MAX merge | `CloudKitSyncManager.swift:364-373` | High — requires XP transaction log |

### MEDIUM

| # | Issue | Impact | File | Fix Effort |
|---|-------|--------|------|------------|
| 10 | **Full re-fetch on every pull** | Wasteful — downloads ALL records instead of changes only | `CloudKitSyncManager.swift:207-275` | High — implement `CKFetchRecordZoneChangesOperation` |
| 11 | **No CKSubscription for push updates** | Cross-device changes only detected on app foreground | `CloudKitSyncManager.swift` | Medium — add subscription + silent push |
| 12 | **`.changedKeys` save policy** | Silent data loss on server record conflict | `CloudKitSyncManager.swift:178` | Medium — implement proper conflict resolution |
| 13 | **Route coordinates may exceed 1MB** | Long walks with many coordinates could fail to save | `CloudKitSyncManager.swift:341-353` | Medium — use CKAsset for large data |
| 14 | **No user notification of sync issues** | Production users have no visibility into sync failures | UI layer | Low — add subtle sync indicator |
| 15 | **`hasSeenFirstWalkEducation` not restored** | Minor UX annoyance on reinstall | `CloudKitSyncManager.swift:428-451` | Trivial |

### LOW

| # | Issue | Impact | File | Fix Effort |
|---|-------|--------|------|------------|
| 16 | **NSPredicate(value: true) for queries** | Fetches all records — inefficient for large data sets | `CloudKitSyncManager.swift:526` | Low |
| 17 | **No iCloud account status check** | App doesn't warn user when iCloud is unavailable | UI layer | Low |
| 18 | **reloadManagers() doesn't reload ChallengeManager** | Even if challenges were synced, manager wouldn't refresh | `CloudKitSyncManager.swift:586-593` | Trivial |

---

## Test Scenario Predictions

### Test 1: Fresh Install Restore

| Data | Expected Result | Prediction |
|------|----------------|------------|
| Display name | Restored | **PASS** — profile JSON has displayName, and on fresh install local is default so remote wins via `createdAt` merge path |
| Daily step goal | Restored | **PARTIAL** — only if `createdAt` merge triggers full profile replacement. Currently only `createdAt` and `legacyBadges` are explicitly merged. **Needs verification.** |
| Total XP | Restored | **PASS** — max merge, local starts at 0 |
| Current rank | Restored | **PASS** — recalculated from XP |
| Current streak | Restored | **PASS** — most recent date wins |
| Longest streak | Restored | **PASS** — max merge |
| Available shields | Restored | **PASS** — max merge, local starts at 0 |
| Walk history | Last 90 days only | **PARTIAL** — older walks lost |
| Challenge progress | **LOST** | **FAIL** — not synced |
| Onboarding skipped | **Shows again** | **FAIL** — not merged |
| First walk education | **Shows again** | **FAIL** — not merged |

**Critical issue on fresh reinstall:** The `mergeGameState` profile merge block (lines 428-451) only applies `createdAt` and `legacyBadges` from remote. All other profile fields (displayName, dailyStepGoal, useMetricUnits, hasCompletedOnboarding, hasSeenFirstWalkEducation) use local defaults. On a fresh install, local is `UserProfile.default` — so the user gets default values, NOT their saved preferences.

**Root cause:** The merge says "local settings win" which is correct for cross-device sync, but wrong for reinstall where local is blank.

### Test 2: Offline Walk Then Sync

| Check | Prediction |
|-------|------------|
| Walk uploaded after reconnect | **PASS** — walk save triggers notification → push |
| XP synced | **PASS** — rank save triggers push |
| Daily log updated | **PASS** — daily log save triggers push |

### Test 3: Multi-Device XP Conflict

| Check | Prediction |
|-------|------------|
| Both walks appear | **PASS** — insert-if-missing merge |
| XP is additive (1000+100+50=1150) | **FAIL** — max merge gives 1100, not 1150. 50 XP from Device B is lost. |

### Test 4: Shield Anti-Exploit

| Check | Prediction |
|-------|------------|
| Device A uses 1 (has 1), Device B uses 1 (has 1) | Max(1,1) = 1 — **appears correct but wrong**. Both devices consumed a shield, so true count should be 0. |
| Device A uses 2 (has 0), Device B uses 0 (has 2) | Max(0,2) = **2 — EXPLOIT CONFIRMED**. Device A's usage is completely lost. |

### Test 5: Legacy Badge Persistence

| Check | Prediction |
|-------|------------|
| Badge appears after reinstall | **PASS** — union merge |
| Badge name correct | **PASS** |
| Streak length correct | **PASS** |
| Earned date correct | **PASS** |

### Test 6: Large Data Performance

| Check | Prediction |
|-------|------------|
| Initial sync <10s | **CONCERN** — full re-fetch of all records with no change tokens |
| Incremental sync <2s | **FAIL** — every sync is a full re-fetch, not incremental |
| App responsive during sync | **PASS** — async operations on background queue |
| No main thread blocking | **PASS** — `DispatchGroup` with main queue notify only |

---

## Recommendations (Priority Order)

### Must-Fix Before Release

1. **Add challenge progress sync** — Create `ChallengePack` record type, add `didSaveChallengePack` notification, implement merge logic (max `currentValue`, OR `isComplete`)

2. **Fix shield conflict to use MIN** — Change `CloudKitSyncManager.swift:414` from `remoteShield.availableShields > localShield.availableShields` to `remoteShield.availableShields < localShield.availableShields`

3. **Fix profile restore on fresh install** — Detect fresh install (local profile == `.default`) and take ALL remote profile fields, not just `createdAt` and `legacyBadges`

4. **Add background sync handler** — In `JustWalkApp.swift`, handle `scenePhase == .background` to force immediate push (cancel debounce, push now)

5. **Merge `shieldsUsedThisMonth` and `lastRefillDate`** — Add merge logic: `shieldsUsedThisMonth` uses MAX, `lastRefillDate` uses most recent

### Should-Fix Soon

6. **Remove or extend 90-day cutoff** — Either remove the cutoff entirely or extend to 365+ days. Users expect lifetime walk history.

7. **Add sync retry with backoff** — Queue failed operations and retry on next app foreground with exponential backoff

8. **Handle `CKError.serverRecordChanged`** — Fetch latest record, apply merge, re-save. Or switch to fetch-modify-save pattern for game state record.

9. **Reload ChallengeManager in `reloadManagers()`** — Add `ChallengeManager.shared.load()` to the reload path

### Nice-to-Have

10. **Implement incremental sync** — Use `CKFetchRecordZoneChangesOperation` with server change tokens for efficient sync

11. **Add CKSubscription** — Enable silent push notifications for cross-device real-time sync

12. **Add user-facing sync indicator** — Show sync status somewhere in production UI (not just debug)

13. **Compress route coordinates** — Use `CKAsset` for large coordinate arrays to avoid record size limits

14. **Add iCloud account status check** — Query `CKContainer.accountStatus()` on launch and warn user if not available

---

## Files That Need Changes

| File | Changes Required |
|------|-----------------|
| `CloudKitSyncManager.swift` | Challenge sync, shield MIN merge, profile fresh-install detect, shieldData full merge, retry logic, `reloadManagers()` update |
| `PersistenceManager.swift` | Add `didSaveChallengePack` notification |
| `ChallengeManager.swift` | No changes needed (notification added in PersistenceManager) |
| `JustWalkApp.swift` | Add `.background` scene phase handler |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                    JustWalkApp                       │
│  .onAppear → setup() + pullFromCloud()              │
│  .active   → pullFromCloud()                        │
│  .background → ??? (MISSING - should pushAllToCloud)│
└─────────────┬───────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────┐
│              CloudKitSyncManager                     │
│                                                      │
│  Observes Notifications:                             │
│    ✓ didSaveStreakData                                │
│    ✓ didSaveShieldData                               │
│    ✓ didSaveRankData                                 │
│    ✓ didSaveDailyLog                                 │
│    ✓ didSaveTrackedWalk                              │
│    ✓ didSaveProfile                                  │
│    ✗ didSaveChallengePack (MISSING)                  │
│                                                      │
│  Record Types:                                       │
│    UserGameState → streakJSON, shieldJSON,            │
│                    rankJSON, profileJSON              │
│    DailyLog → logJSON (keyed by dateString)           │
│    TrackedWalk → walkJSON (keyed by UUID)             │
│    ✗ ChallengePack (MISSING)                         │
│                                                      │
│  Merge Strategy:                                     │
│    RankData: max XP → recalculate                    │
│    StreakData: recent date wins + max longest         │
│    ShieldData: max available (BUG: should be min)    │
│    Profile: local wins + union badges + min createdAt│
│    DailyLog: max steps/xp, OR bools, union IDs      │
│    TrackedWalk: insert-if-missing                    │
└─────────────────────────────────────────────────────┘
```

---

## Conclusion

The CloudKit implementation has a **solid foundation** — custom zone, private database, JSON serialization, debounced push, merge logic for most data types. However, it has several gaps that would cause real user frustration:

- **Challenge progress loss** is the most impactful missing feature
- **Shield duplication** is an exploitable bug
- **Profile restore on reinstall** doesn't fully work (onboarding replays, settings lost)
- **90-day window** means long-term users lose history

These issues are all fixable with moderate effort. The architecture doesn't need to change — it just needs the gaps filled and the merge logic corrected.
