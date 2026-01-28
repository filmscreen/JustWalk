# Copy & Voice Audit

**Brand voice target:** Supportive, not preachy. Celebrating, not measuring. Partner, not coach. Calm, not aggressive.

---

## 1. Buttons & Actions

### Walk Flow

| Button | File:Line | Verdict | Notes |
|--------|-----------|---------|-------|
| "Just Walk" | BottomPanel.swift:20 | PASS | Inviting, brand-aligned. Primary CTA. |
| "Start Walk" | GoalPickerSheet.swift:109 | BORDERLINE | Slightly commanding. Consider "Let's Go" to match "Just Walk" energy. |
| "End Walk" | WalkActiveView.swift:111 | PASS | Direct and necessary for the context. |
| "End" | WalkActiveView.swift:126 | PASS | Destructive alert button — appropriately brief. |
| "Keep Going" | WalkActiveView.swift:131 | PASS | Encouraging cancel-action. Strong partner voice. |
| "End this walk?" | WalkActiveView.swift:125 | PASS | Question format is respectful, not presumptive. |
| "Done" | PostWalkSummaryView.swift:111 | PASS | Neutral, appropriate for dismissal. |

**Inconsistency:** "Just Walk" (inviting) vs "Start Walk" (commanding) vs "End Walk" (direct). The primary CTA is "Just Walk" but the goal-walk CTA switches to "Start Walk." Consider "Let's Walk" for the goal variant.

### Onboarding

| Button | File:Line | Verdict |
|--------|-----------|---------|
| "Got It" | OnboardingShieldView.swift:80 | PASS — warm acknowledgment |
| "Continue" | NameView.swift:74, GoalPickerView.swift:48 | PASS — neutral progression |
| "Skip" | NameView.swift:92 | PASS — non-pressuring |
| "I'm Ready" | OnboardingInstructionView.swift | PASS — confident, empowering |
| "Let's Begin" | OnboardingPromiseView.swift | PASS — inviting, partner-like |
| "Start Free Trial" | OnboardingPaywallView.swift:76 | PASS — standard commerce |
| "Maybe Later" | OnboardingPaywallView.swift:92 | PASS — gentle alternative |
| "Continue with Free" | PaywallView.swift:83 | PASS — inclusive, non-judgmental |
| "Enable Notifications" | OnboardingNotificationView.swift | PASS |
| "Not Now" | OnboardingNotificationView.swift | PASS — softer than "Skip" |

### Settings / Transactional

| Button | File:Line | Verdict |
|--------|-----------|---------|
| "Use Shield to Repair" | WeekChartView.swift:378, StreakCalendarView.swift:95 | PASS — action-descriptive |
| "Purchase & Repair" | WeekChartView.swift:391 | PASS — clear combined action |
| "Buy Shield" | ShieldDetailSheet.swift:152 | PASS — direct commerce |
| "Restore Purchases" | SettingsView.swift:95 | PASS |
| "Upgrade to Pro" | SettingsView.swift:86 | PASS |

**Overall button verdict:** Buttons are mostly well-aligned with brand voice. One inconsistency: "Start Walk" vs "Just Walk."

---

## 2. Celebrations & Success Messages

| Message | File:Line | Verdict | Notes |
|---------|-----------|---------|-------|
| "Walk Complete!" | PostWalkSummaryView.swift:31 | PASS | Warm, celebratory. |
| "Walk Logged" | PostWalkSummaryView.swift:34 | PASS | Gentle for non-XP walks. |
| "That was quick! Every step counts." | PostWalkSummaryView.swift:39 | PASS | Encouraging, not dismissive. |
| "Goal Complete!" | StepRingView.swift:73 | PASS | Clean celebration. |
| "Rank Up!" | PostWalkSummaryView.swift:208 | PASS | Energetic, earned. |
| "Grade Up!" | PostWalkSummaryView.swift:225 | PASS | Consistent with Rank Up. |
| "You're now a [Rank]" | PostWalkSummaryView.swift:212 | PASS | Personal, achievement-focused. |
| "Interval complete. Great work!" | IntervalVoiceManager.swift:60 | PASS | Warm praise. |
| "Halfway there. Keep going!" | IntervalVoiceManager.swift:70 | PASS | Encouraging midpoint. |
| "Let's get moving" | StepRingView.swift:68 | PASS | Inviting, not commanding. |
| "You're all set. Happy walking, [Name]." | OnboardingLaunchView.swift:57 | PASS | Warm send-off. Perfect partner voice. |

### Voice Cues During Walks

| Cue | Verdict | Notes |
|-----|---------|-------|
| "Warm up. Walk at an easy pace." | PASS | Calm instruction. |
| "Speed up. Walk briskly now." | FLAG | "Now" adds slight urgency. Consider "Pick up the pace." |
| "Slow down. Easy pace." | PASS | Calm, reassuring. |
| "Cool down. Almost done." | PASS | Encouraging finish. |

**Celebrations are generally consistent and warm.** No clinical or cold language in success states.

---

## 3. Error & Problem States

| Message | File:Line | Verdict | Notes |
|---------|-----------|---------|-------|
| "Walk paused" / "Looks like you're moving too fast. Open the app to resume." | NotificationManager.swift:114-115 | PASS | Explanatory, not accusatory. |
| "Still walking?" / "We haven't detected movement. Open the app if you're still going." | NotificationManager.swift:125-126 | PASS | Gentle check-in. Question format. |
| "Walks under 5 minutes don't earn XP" | PostWalkSummaryView.swift:38 | FLAG | Negative framing ("don't earn"). Consider "Walk 5+ minutes to earn XP" (positive reframe). |

**No user-facing error messages use "failed," "error," "sorry," "oops," or "problem."** All system errors are logged internally via `logger.error()` and never surfaced to users. This is well-handled.

---

## 4. Notifications

| Notification | Title | Body | Verdict |
|-------------|-------|------|---------|
| Shield deployed | "Rough day? We got you." | "A shield protected your streak. We go again tomorrow." | PASS — empathetic, partner voice. Best copy in the app. |
| Streak at risk | "Your [X]-day streak needs you" | "A short walk can keep it alive." | PASS — motivating without guilt. |
| Rank up | "Rank Up!" | "You're now a [Rank]. '[Motto]'" | PASS — celebratory. |
| Legacy badge | "Legacy Badge Earned" | "Your [X]-day streak is immortalized in [Name]." | PASS — honorific, warm. |
| Goal achieved | "Goal Achieved!" | "Congratulations! You've reached your daily step goal." | BORDERLINE | Slightly formal. "Congratulations!" could be warmer — consider "You hit your goal today!" |
| Shields low | "Shields Running Low" | "You have [X] shield(s) left. Don't miss your goal!" | FLAG | "Don't miss your goal!" is pressuring/commanding. Consider "Keep them in reserve for when you need a rest day." |
| Speed limit | "Walk paused" | "Looks like you're moving too fast..." | PASS |
| Ghost check | "Still walking?" | "We haven't detected movement..." | PASS |

**Notification voice is mostly excellent.** The shield deployed notification is the gold standard for partner voice. Two strings break the pattern: "Don't miss your goal!" (commanding) and "Congratulations!" (formal).

---

## 5. Empty States

| Empty State | File:Line | Verdict | Suggested Alternative |
|-------------|-----------|---------|----------------------|
| "No walks yet today" | XPBreakdownSheet.swift:51 | BORDERLINE | "Your first walk today is waiting" |
| "No walks yet" | RecentWalksView.swift:40 | BORDERLINE | "Your walk history starts here" |
| "No Walks Yet" | RecentWalksView.swift:154, WalkHistoryView.swift:38 | FLAG | Inconsistent capitalization ("No Walks Yet" vs "No walks yet"). Also missed opportunity for warmer copy. |
| "Start your first walk to see it here!" | RecentWalksView.swift:44 | PASS | Good secondary line — inviting. |
| "No tracked walks" | WeekChartView.swift:302 | FLAG | Clinical. Consider "Steps only — no walks tracked" |
| "No challenges available" | ChallengesCardView.swift:96 | FLAG | Passive. Consider "New challenges coming soon" |
| "Start your streak today!" | StreakManager.swift:174 | PASS | Encouraging. |
| "Start your streak!" | JustWalkWidgets.swift:445 | PASS | Consistent with above. |
| "No history found" | OnboardingCalibrationView.swift | BORDERLINE | Consider "Let's set a great starting point" |

**Pattern:** Empty states default to "No [thing]" phrasing which is factual but not warm. The brand voice would frame absence as opportunity: "Your first X awaits" instead of "No X yet."

---

## 6. Red Flags Found

### Negative Framing

| String | File:Line | Issue | Suggested Fix |
|--------|-----------|-------|---------------|
| "Some days you just can't walk" | OnboardingShieldView.swift:47 | Opens with inability framing | "Some days life gets in the way" |
| "You won't receive reminders or streak alerts" | SettingsView.swift:210 | Frames disabled state as a loss | "Reminders and streak alerts are turned off" |
| "Walks under 5 minutes don't earn XP" | PostWalkSummaryView.swift:38 | Negative rule statement | "Walk 5+ minutes to start earning XP" |
| "Don't miss your goal!" | NotificationManager.swift:170 | Commanding/pressuring | "Save them for rest days when you need a break" |

### No instances found of:
- "failed" or "failure" in user-facing text
- "you didn't" or "you haven't"
- "sorry" or "unfortunately"
- "invalid" or "incorrect"
- "required" in user-facing text

---

## 7. Terminology Consistency

### Walk Terminology — MOSTLY CONSISTENT

| Term | Usage | Verdict |
|------|-------|---------|
| "Walk" (noun) | Activities: "Free Walk", "Goal Walk", "Interval Walk" | CONSISTENT |
| "walk" (verb) | "Just Walk", "Walk briskly now" | CONSISTENT |
| "Walks" (plural) | "Walks under 5 minutes", "Dedicated Walks" | CONSISTENT |

No mixing of "walk" with "workout," "exercise," or "training" in user-facing text. "Motion & Fitness" appears only in Apple's permission prompt (system-required).

### Rank vs Level — INCONSISTENT

| String | File:Line | Term Used |
|--------|-----------|-----------|
| "Explore new ranks as you level up" | OnboardingPromiseView.swift | Both "ranks" and "level up" |
| "XP to level up" | DynamicCardView.swift:133 | "level up" |
| "Hit a new rank" | OnboardingNotificationView.swift | "rank" |
| "Rank Up!" | PostWalkSummaryView.swift:208 | "Rank" |
| All Journey/Progress views | Multiple | "Rank" |

**Issue:** The system is called "Rank" everywhere, but "level up" appears as a verb in two places. This creates cognitive dissonance — is the user leveling up or ranking up?

**Fix:** Replace "level up" with "rank up" everywhere, or adopt "advance" as the verb: "Explore new ranks as you advance."

### Shield Terminology — CONSISTENT

"Streak Shield" / "Shield" / "Shields" used correctly throughout. No mixing with "protection" or "guard."

### XP Terminology — CONSISTENT

"XP" (uppercase, no periods) used in all user-facing text. No instances of "xp", "Xp", or "experience points."

---

## 8. Number Formatting

### Step Counts — ONE INCONSISTENCY

| Context | File:Line | Format | Example |
|---------|-----------|--------|---------|
| Step ring (steps to go) | StepRingView.swift:68 | `.formatted()` | "1,234 steps to go" |
| Active walk steps | WalkActiveView.swift:51 | Raw `\(int)` | "10000" |
| Post-walk summary | PostWalkSummaryView.swift:65 | `.formatted()` | "1,234" |
| Week chart | WeekChartView.swift:209 | `.formatted()` | "10,000" |
| Recent walks | RecentWalksView.swift:119 | `.formatted()` | "5,432" |

**Bug:** `WalkActiveView.swift:51` displays step count without formatting during an active walk: `"\(walkSession.currentSteps)"`. Should use `.formatted()`.

### XP Values — CONSISTENT

All XP displays use `.formatted()`. No raw interpolation found.

### Distance — INCONSISTENT

| Context | File:Line | Format | Precision | Unit Spacing |
|---------|-----------|--------|-----------|--------------|
| Active walk | WalkActiveView.swift:150 | `"%.1fkm"` | 1 decimal | NO space |
| Active walk (miles) | WalkActiveView.swift:154 | `"%.2fmi"` | 2 decimals | NO space |
| Post-walk summary | PostWalkSummaryView.swift:153 | `"%.1f km"` | 1 decimal | Space |
| Week chart | WeekChartView.swift:216 | `"%.1f km"` | 1 decimal | Space |
| Recent walks | RecentWalksView.swift:239 | `"%.2f km"` | 2 decimals | Space |

**Issues:**
1. Unit spacing: `"5.2km"` (active walk) vs `"5.2 km"` (everywhere else)
2. Precision: `%.1f` (1 decimal) vs `%.2f` (2 decimals) for same unit
3. Miles precision (`%.2f`) differs from km precision (`%.1f`) in active walk

**Fix:** Standardize to `"%.1f km"` / `"%.1f mi"` with space before unit everywhere.

---

## 9. Date Formatting

### Patterns Found

| Context | Format | Example |
|---------|--------|---------|
| Month headers | `"MMMM yyyy"` | "January 2026" |
| Month names (challenges) | `"MMMM"` | "January" |
| Recent walk dates | `"MMM d"` | "Jan 15" |
| Walk history dates | `"MMMM d, yyyy"` | "January 15, 2026" |
| Challenge completion | `.dateStyle = .medium` | "Jan 15, 2026" |
| Walk times | `"h:mm a"` | "2:45 PM" |
| Week chart labels | `"EEE M/d"` | "Mon 1/15" |

**Issue:** Month format varies between `"MMM"` (Jan), `"MMMM"` (January), and `.medium` style. Walk dates use different formats in different views for the same data.

**Fix:** Centralize date formats into a `JW.DateFormat` enum to ensure consistency.

---

## 10. Specific Strings That Break Brand Voice

### Priority 1 — Fix These

| # | Current | File:Line | Issue | Suggested |
|---|---------|-----------|-------|-----------|
| 1 | "Don't miss your goal!" | NotificationManager.swift:170 | Commanding, pressuring | "Save them for when you need a rest day." |
| 2 | "Walks under 5 minutes don't earn XP" | PostWalkSummaryView.swift:38 | Negative rule | "Walk 5+ minutes to start earning XP" |
| 3 | "You won't receive reminders or streak alerts" | SettingsView.swift:210 | Loss-framed | "Reminders and streak alerts are turned off" |
| 4 | "No challenges available" | ChallengesCardView.swift:96 | Cold, passive | "New challenges coming soon" |

### Priority 2 — Consider These

| # | Current | File:Line | Issue | Suggested |
|---|---------|-----------|-------|-----------|
| 5 | "Some days you just can't walk" | OnboardingShieldView.swift:47 | Inability framing | "Some days life gets in the way" |
| 6 | "No walks yet today" | XPBreakdownSheet.swift:51 | Absence-focused | "Your first walk today is waiting" |
| 7 | "No walks yet" | RecentWalksView.swift:40 | Absence-focused | "Your walk history starts here" |
| 8 | "No tracked walks" | WeekChartView.swift:302 | Clinical | "Steps only — no walks tracked yet" |
| 9 | "Congratulations! You've reached your daily step goal." | NotificationManager.swift:159 | Slightly formal | "You hit your goal today!" |
| 10 | "Start Walk" | GoalPickerSheet.swift:109 | Commanding vs "Just Walk" | "Let's Go" |
| 11 | "Speed up. Walk briskly now." | IntervalVoiceManager.swift:48 | Slightly urgent | "Pick up the pace." |
| 12 | "level up" (2 places) | DynamicCardView.swift:133, OnboardingPromiseView.swift | Conflicts with "Rank" system | "rank up" or "advance" |

### Priority 3 — Formatting

| # | Issue | File:Line | Fix |
|---|-------|-----------|-----|
| 13 | Steps without `.formatted()` | WalkActiveView.swift:51 | Add `.formatted()` |
| 14 | Distance no space: `"%.1fkm"` | WalkActiveView.swift:150 | `"%.1f km"` |
| 15 | Distance no space: `"%.2fmi"` | WalkActiveView.swift:154 | `"%.1f mi"` |
| 16 | "No Walks Yet" vs "No walks yet" | RecentWalksView.swift:154 vs :40 | Standardize capitalization |
| 17 | Distance precision `%.2f` vs `%.1f` | RecentWalksView.swift:239 vs others | Standardize to `%.1f` |

---

## 11. Voice Scorecard

| Category | Score | Notes |
|----------|-------|-------|
| **Buttons** | 9/10 | One inconsistency ("Start Walk" vs "Just Walk") |
| **Celebrations** | 9/10 | Warm, consistent. Voice cues slightly coach-like. |
| **Errors** | 10/10 | No user-facing errors. All gracefully handled. |
| **Notifications** | 8/10 | "Don't miss your goal!" breaks partner voice. Shield notification is the gold standard. |
| **Empty States** | 5/10 | Default to "No [thing]" pattern. Missed opportunity for warmth. |
| **Negative Framing** | 7/10 | Four instances of negative/commanding language. |
| **Terminology** | 8/10 | "Rank" vs "level up" inconsistency. Everything else clean. |
| **Number Formatting** | 7/10 | Steps and distance have formatting gaps. XP is perfect. |
| **Date Formatting** | 6/10 | Multiple patterns for same data types. Needs centralization. |

**Overall: 7.7/10** — The app has a strong foundation of warm, partner-like copy. The celebration and notification voices are mostly excellent (shield deployed notification is the benchmark). The main areas for improvement are empty states (reframe absence as opportunity), a handful of negative framings, and formatting consistency.

---

## Gold Standard Examples (Keep These)

These strings best represent the target voice — use them as reference when writing new copy:

1. **"Rough day? We got you."** — Empathetic, uses "we," no judgment
2. **"A shield protected your streak. We go again tomorrow."** — Team language, forward-looking
3. **"Life Happens."** — Two-word empathy. Perfect.
4. **"Some days you just can't walk — and that's totally fine."** — Validates struggle (framing could improve, but tone is right)
5. **"Your [X]-day streak needs you"** — Motivating without guilt
6. **"A short walk can keep it alive."** — Gentle nudge, not a command
7. **"You're all set. Happy walking, [Name]."** — Warm farewell
8. **"That was quick! Every step counts."** — Validates effort regardless of duration
9. **"Just Walk"** — The brand in two words
10. **"Keep Going"** — Encouraging continuation as cancel-action
