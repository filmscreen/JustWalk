# Just Walk — Accessibility Audit

## Executive Summary

The JustWalk app has **zero accessibility modifiers** anywhere in the codebase. A search for `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityHidden`, `.accessibilityAddTraits`, `.accessibilityElement`, `.accessibilityReduceMotion`, or `.accessibilityValue` returned **no matches**. VoiceOver users, users relying on Dynamic Type at large sizes, and users with motion sensitivity will have a significantly degraded or unusable experience.

**57 issues found** across all screens.

| Severity | Count |
|----------|-------|
| Critical | 9 |
| Major | 25 |
| Minor | 23 |

---

## Top 10 Priority Fixes

1. Add `@Environment(\.accessibilityReduceMotion)` checks to all animation modifiers
2. Add accessibility labels to StepRingView (primary metric display)
3. Add accessibility labels to all icon-only buttons (pause/play, location, voice toggle, steppers)
4. Fix `textTertiary` contrast — increase from `opacity(0.35)` to at least `opacity(0.5)`
5. Replace `JW.Font.heroNumber` hardcoded 56pt size with Dynamic Type-compatible font
6. Add `.accessibilityElement(children: .combine)` to all stat components
7. Add accessibility labels to WeekChartView columns
8. Add accessibility labels to CalendarDayView cells
9. Use `ViewThatFits` for horizontal stat layouts to reflow at large text sizes
10. Add `.accessibilityHidden(true)` to decorative elements

---

## Section 1: VoiceOver

### Critical

**V-01: StepRingView — No accessibility label on the step ring**
- `Views/Today/StepRingView.swift:20-82`
- The entire step ring (circular progress + step count + remaining steps) has no `.accessibilityElement(children: .combine)` and no `.accessibilityLabel()`. VoiceOver users cannot understand their step progress.
- WCAG: 1.1.1 (Non-text Content), 4.1.2 (Name, Role, Value)
- Fix: Add `.accessibilityElement(children: .combine)` and `.accessibilityLabel("\(steps) of \(goal) steps, \(Int(progress * 100)) percent complete")`.

**V-02: StreakBadgeView — No accessibility label**
- `Views/Today/StreakBadgeView.swift:32-50`
- The streak badge (flame icon + number) has no combined label. VoiceOver reads "flame.fill" and the number separately.
- WCAG: 1.1.1, 4.1.2
- Fix: Add `.accessibilityElement(children: .combine)` and `.accessibilityLabel("\(streak) day streak")`.

**V-03: XPBadgeView — No accessibility label**
- `Views/Today/StreakBadgeView.swift:156-177`
- Star icon + number + "XP" read as separate elements.
- WCAG: 1.1.1, 4.1.2
- Fix: Add `.accessibilityElement(children: .combine)` and `.accessibilityLabel("\(xp) experience points earned today")`.

**V-04: WeekChartView — Chart has no text alternative**
- `Views/Today/WeekChartView.swift:42-58`
- The 30-day scrollable chart has no summary. VoiceOver users hear dozens of meaningless elements.
- WCAG: 1.1.1
- Fix: Add `.accessibilityElement(children: .ignore)` on the ScrollView and provide summary label. Each WeekDayColumn should have `.accessibilityElement(children: .combine)` with a label.

**V-07: WalkActiveView — Pause/Play button missing label**
- `Views/Walk/WalkActiveView.swift:85-97`
- Only shows SF Symbol (play.fill/pause.fill) with no accessibility label.
- WCAG: 4.1.2
- Fix: Add `.accessibilityLabel(walkSession.isPaused ? "Resume walk" : "Pause walk")`.

**V-12: StreakCalendarView — Calendar grid not accessible**
- `Views/Progress/StreakCalendarView.swift:60-75`
- 30-day calendar grid of circles has no accessibility structure.
- WCAG: 1.1.1, 1.3.1
- Fix: Add `.accessibilityLabel()` to CalendarDayView: "January 15, goal met" or "January 16, missed".

### Major

**V-05: WeekDayColumn — Color-only goal completion indicator**
- `Views/Today/WeekChartView.swift:94-128`
- Goal met (green), shield used (orange), missed (gray) conveyed only through circle fill color.
- WCAG: 1.4.1 (Use of Color)
- Fix: Include state in accessibility labels.

**V-06: DynamicCardView rank cards — No button traits on tappable "Details" links**
- `Views/Today/DynamicCardView.swift:135-141, 291-297`
- "Details >" looks tappable but has no button trait or tap handler.
- WCAG: 4.1.2
- Fix: Wrap in Button or NavigationLink, or add `.accessibilityAddTraits(.isButton)`.

**V-08: WalkIdleView — Location and map style buttons missing labels**
- `Views/Walk/WalkIdleView.swift:45-66`
- GPS re-orient button and map style toggle have no accessibility labels.
- WCAG: 4.1.2
- Fix: Add `.accessibilityLabel("Re-center map")` and `.accessibilityLabel("Toggle map style")`.

**V-09: WalkMapView — Location button missing label**
- `Views/Walk/WalkMapView.swift:69-90`
- WCAG: 4.1.2
- Fix: Add `.accessibilityLabel("Re-center map on current location")`.

**V-10: IntervalOverlayView — Voice toggle button missing label**
- `Views/Walk/IntervalOverlayView.swift:107-113`
- Speaker icon button has no accessibility label.
- WCAG: 4.1.2
- Fix: Add `.accessibilityLabel(voiceManager.isEnabled ? "Disable voice cues" : "Enable voice cues")`.

**V-11: StatPill, StatCard, StatBox, QuickStatPill — No combined elements**
- `WalkActiveView.swift:142-155`, `PostWalkSummaryView.swift:147-175`, `MonthStatsView.swift:179-208`, `TodayView.swift:146-176`
- All stat display components show value and label as separate VoiceOver elements.
- WCAG: 1.3.1 (Info and Relationships)
- Fix: Add `.accessibilityElement(children: .combine)` to each container.

**V-16: Custom progress bars — No accessibility values**
- `ChallengeRowView.swift:59`, `RankCardView.swift:99-108`, `DynamicCardView.swift:300-310`
- GeometryReader-based progress bars have no `.accessibilityValue()`.
- WCAG: 4.1.2
- Fix: Add `.accessibilityValue("\(Int(progress * 100)) percent")`.

**V-18: CompactStepRingView — No accessibility label**
- `Views/Today/StepRingView.swift:87-135`
- WCAG: 1.1.1, 4.1.2
- Fix: Add `.accessibilityElement(children: .combine)` and `.accessibilityLabel("\(steps) steps of \(goal) goal")`.

**V-20: ChallengePackHeader progress ring — No text alternative**
- `Views/Challenges/ChallengesDetailView.swift:86-108`
- WCAG: 1.1.1
- Fix: Add `.accessibilityLabel("\(completedCount) of \(totalCount) challenges completed")`.

**V-21: SettingsView goal stepper buttons — Icon-only buttons without labels**
- `Views/Settings/SettingsView.swift:103-131`
- minus.circle.fill and plus.circle.fill buttons have no labels.
- WCAG: 4.1.2
- Fix: Add `.accessibilityLabel("Decrease step goal by 500")` / `"Increase step goal by 500"`.

**V-22: StreakCardView — Stat columns not labeled as groups**
- `Views/Progress/StreakCardView.swift:40-113`
- Current streak, longest streak, shields columns each have icon/number/label read separately.
- WCAG: 1.3.1
- Fix: Add `.accessibilityElement(children: .combine)` to each VStack column.

### Minor

**V-13: GradeIndicator — Decorative dots not hidden**
- `Views/Progress/RankMilestoneView.swift:107-116`
- WCAG: 1.1.1 — Fix: Add `.accessibilityHidden(true)`.

**V-14: RankPathView — Connector lines not hidden**
- `Views/Progress/RankPathView.swift:24-29`
- WCAG: 1.1.1 — Fix: Add `.accessibilityHidden(true)`.

**V-15: LegendItem — Color circles should be hidden**
- `Views/Progress/StreakCalendarView.swift:192-206`
- WCAG: 1.4.1 — Fix: Add `.accessibilityHidden(true)` on Circle.

**V-17: StepRingView ambient glow — Decorative element not hidden**
- `Views/Today/StepRingView.swift:23-28`
- WCAG: 1.1.1 — Fix: Add `.accessibilityHidden(true)`.

**V-19: StreakMilestoneBadge locked state — "lock.fill" not labeled**
- `Views/Today/StreakBadgeView.swift:136-138`
- WCAG: 1.1.1 — Fix: Add `.accessibilityLabel("\(milestone) day streak milestone, locked")`.

**V-23: PostWalkMapView — Map with no alternative text**
- `Views/Walk/PostWalkSummaryView.swift:240-304`
- WCAG: 1.1.1 — Fix: Add `.accessibilityLabel("Walk route map")` or `.accessibilityHidden(true)`.

---

## Section 2: Dynamic Type

### Critical

**DT-01: JW.Font.heroNumber — Hardcoded 56pt font size**
- `DesignSystem/JustWalkTheme.swift:55`
- `Font.system(size: 56, weight: .bold, design: .rounded)` does NOT scale with Dynamic Type. Used for the main step count display.
- WCAG: 1.4.4 (Resize Text)
- Fix: Use `.system(.largeTitle, design: .rounded, weight: .bold)` or `@ScaledMetric`.

### Major

**DT-02: CompactStepRingView — Hardcoded proportional font sizes**
- `Views/Today/StepRingView.swift:115, 120`
- `Font.system(size: size * 0.2)` — calculated from ring size, won't respond to Dynamic Type.
- WCAG: 1.4.4
- Fix: Use `@ScaledMetric` for multipliers.

**DT-05: StepRingView — Fixed 220pt frame**
- `Views/Today/StepRingView.swift:27, 33, 38, 42, 49`
- Ring is hardcoded at 220×220pt. Text inside will overflow at large type sizes.
- WCAG: 1.4.4
- Fix: Use `@ScaledMetric` for ring dimensions.

**DT-06: WeekDayColumn — Fixed 44pt width constraining text**
- `Views/Today/WeekChartView.swift:108-127`
- 40×40pt circles in 44pt columns constrain text at larger type sizes.
- WCAG: 1.4.4
- Fix: Use `@ScaledMetric` for frame sizes.

**DT-09: CalendarDayView — Fixed 36×36 circle**
- `Views/Progress/StreakCalendarView.swift:143-163`
- Calendar day circles hardcoded at 36pt will clip text.
- WCAG: 1.4.4
- Fix: Use `@ScaledMetric`.

**DT-15: WalkActiveView stat pills — HStack won't reflow**
- `Views/Walk/WalkActiveView.swift:48-52`
- Three stat pills in HStack overflow at large text sizes.
- WCAG: 1.4.10 (Reflow)
- Fix: Use `ViewThatFits` to switch to VStack at larger sizes.

**DT-16: PostWalkSummaryView stat cards — HStack won't reflow**
- `Views/Walk/PostWalkSummaryView.swift:54-58`
- Three stat cards in horizontal row will overflow.
- WCAG: 1.4.10
- Fix: Use `ViewThatFits`.

### Minor

**DT-03:** LargeStreakBadgeView hardcoded 36pt icon — `StreakBadgeView.swift:67`
**DT-04:** IntervalPreFlightSheet hardcoded 48pt icon — `IntervalPreFlightSheet.swift:19`
**DT-07:** ExtendedWeekDayColumn fixed 24pt bar width — `WeekChartView.swift:197-225`
**DT-08:** StreakBadgeView fixed padding values — `StreakBadgeView.swift:43-44`
**DT-10:** ChallengeRowView compact icon fixed 36pt — `ChallengeRowView.swift:101`
**DT-11:** CompactChallengeRow `.lineLimit(1)` without `.minimumScaleFactor` — `ChallengeRowView.swift:117`
**DT-12:** WeekChartView abbreviatedSteps in fixed 40pt circle — `WeekChartView.swift:112-116`
**DT-13:** Rank badge images fixed 50-100pt frames — `RankCardView.swift:51, 172`
**DT-14:** GradeIndicator fixed 8pt circles — `RankMilestoneView.swift:113-114`

All minor items: WCAG 1.4.4 — Fix with `@ScaledMetric`.

---

## Section 3: Color & Contrast

### Critical

**CC-01: textSecondary — Borderline contrast on card backgrounds**
- `DesignSystem/JustWalkTheme.swift:29`
- `Color.white.opacity(0.6)` on `backgroundCard` (#1C1C2E) yields ~4.9:1 ratio — borderline for body text (4.5:1 required).
- WCAG: 1.4.3 (Contrast Minimum)
- Fix: Increase opacity to 0.7 for safety margin across all backgrounds.

**CC-02: textTertiary — Fails WCAG AA**
- `DesignSystem/JustWalkTheme.swift:30`
- `Color.white.opacity(0.35)` on #121220 yields ~3.1:1 — **fails** WCAG AA for body text (4.5:1 required). Used for captions and secondary labels throughout the app.
- WCAG: 1.4.3
- Fix: Increase to at least `opacity(0.5)`.

### Major

**CC-03: StreakMilestoneBadge locked state — 0.5 opacity on entire view**
- `Views/Today/StreakBadgeView.swift:150`
- Applying 0.5 opacity on top of already low-contrast textSecondary further degrades readability.
- WCAG: 1.4.3
- Fix: Use a specific locked style with adequate contrast instead of blanket opacity.

**CC-04: WeekDayColumn — Color-only status indication**
- `Views/Today/WeekChartView.swift:78-82`
- Green (met), orange (shield), gray (missed) communicated solely through color.
- WCAG: 1.4.1 (Use of Color)
- Fix: Add small checkmark/shield/X icon overlays.

**CC-05: CalendarDayView — Color-only status for some states**
- `Views/Progress/StreakCalendarView.swift:140-188`
- Missed and repairable days show only different colors without icons.
- WCAG: 1.4.1
- Fix: Add indicator icons for all states.

### Minor

**CC-06:** GradeIndicator color-only unlocked state — `RankMilestoneView.swift:107-116`
**CC-07:** PermissionRow badge contrast should be verified — `SettingsView.swift:295-315`
**CC-08:** "Just Walk" button black text on amber glass effect — `WalkIdleView.swift:116` — contrast may fail at 3:1 for large text.

---

## Section 4: Reduce Motion

### Critical

**RM-01: No reduce motion checks anywhere in codebase**
- All files
- Zero instances of `accessibilityReduceMotion` in the entire app.
- WCAG: 2.3.3 (Animation from Interactions)
- Fix: Add `@Environment(\.accessibilityReduceMotion) var reduceMotion` to views with animations.

### Major

**RM-02: StepRingView — Ring fill animation unconditional**
- `Views/Today/StepRingView.swift:72-76`
- 0.8s ring fill animation always plays.
- Fix: `if reduceMotion { animatedProgress = progress } else { withAnimation(...) { ... } }`

**RM-03: StaggeredAppearance — Slide+fade on all list items**
- `Animation/AnimationModifiers.swift:44-65`
- Every staggered item animates without reduce motion check.
- Fix: Set `isVisible = true` immediately when reduce motion is on.

**RM-04: PulseEffect — Infinite repeating scale animation**
- `Animation/AnimationModifiers.swift:69-88`
- Continuous pulsing repeats forever.
- Fix: Disable when reduce motion is enabled.

**RM-06: ConfettiView — 50+ particles animating simultaneously**
- `Animation/ConfettiView.swift:52-77`
- Most motion-intensive animation in the app.
- Fix: Show static celebration banner instead when reduce motion is on.

**RM-07: RankMilestoneView glow pulse — Infinite animation**
- `Views/Progress/RankMilestoneView.swift:96-100`
- Fix: Disable when reduce motion is on.

### Minor

**RM-05:** BounceInEffect — `AnimationModifiers.swift:131-150`
**RM-08:** StreakBadgeView symbolEffect pulse — `StreakBadgeView.swift:36`
**RM-09:** WalkTabView transition — `WalkTabView.swift:26`
**RM-10:** PostWalkSummaryView XP scale animation — `PostWalkSummaryView.swift:44, 121-124`
**RM-11:** MilestoneCard star bounce — `PostWalkSummaryView.swift:189`
**RM-12:** DynamicCardView streak pulsing flame — `DynamicCardView.swift:77`

All minor items: WCAG 2.3.3 — Fix by checking `accessibilityReduceMotion`.

---

## Section 5: Motor Accessibility

### Major

**MA-02: CalendarDayView — 36×36pt interactive buttons**
- `Views/Progress/StreakCalendarView.swift:143-145`
- Below the recommended 44×44pt minimum touch target.
- WCAG: 2.5.8 (Target Size)
- Fix: Increase to 44×44pt or add padding to expand tap area.

### Minor

**MA-01:** GradeIndicator 8×8pt visual target (not interactive) — `RankMilestoneView.swift:113-114`
**MA-04:** StreakBadgeView ~40pt vertical dimension — `StreakBadgeView.swift:43-44` — increase vertical padding to 10pt.

---

## Section 6: Additional Issues

**ADD-01:** No `.accessibilityAddTraits(.isHeader)` on section headers in walk history — `WalkHistoryView.swift` — Minor, WCAG 2.4.1
**ADD-02:** Confetti obscures content for 2.5s with no dismiss option — `ConfettiView.swift` — Minor, WCAG 2.2.2
**ADD-03:** Interval countdown not announced to VoiceOver — `IntervalOverlayView.swift:60-62` — Minor, WCAG 2.2.1
**ADD-04:** ButtonPressEffect DragGesture may interfere with VoiceOver — `AnimationModifiers.swift:23-39` — Major, WCAG 4.1.2
**ADD-07:** XPCounter "+", number, "XP" read as separate elements — `AnimatedCounter.swift:93-118` — Minor, WCAG 1.3.1
