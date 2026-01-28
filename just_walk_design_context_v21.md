# Just Walk — Design Context & Rationale

> **Version:** 2.1 (iOS 26 Liquid Glass Edition)  
> **Purpose:** Companion document to `just_walk_implementation_plan_v21.md` providing the strategic thinking, design decisions, and context needed to continue development in a new conversation.

---

## Product Vision

### The Core Insight

**Users don't want to track walks — they want to feel like someone who takes care of themselves.**

Just Walk is not a fitness tracker. It's an identity transformation app disguised as a walking app. The goal is to help users go from "I should walk more" to "I am a walker."

### The Identity Ladder

```
"I should walk more"           ← Starting point
        ↓
"I walked today"               ← Single action
        ↓
"I've been walking consistently" ← Habit forming
        ↓
"Walking is part of my routine"  ← Behavior change
        ↓
"I am a walker"                ← Identity shift (Just Walker rank)
```

### Target User

**Fitness beginners who are intimidated by traditional fitness apps.**

They don't want:
- Complex metrics and charts
- Aggressive goals
- Shame when they miss
- Overwhelming features

They want:
- Permission to start small
- Validation that small efforts count
- Evidence of progress
- To feel good about themselves

### Design Philosophy: Intentional Elegance

**"Every interaction should feel considered. No screen appears — it arrives."**

This app should feel best-in-class:
- iOS 26 Liquid Glass design throughout
- Fluid animations like Strava
- No static transition screens
- Micro-interactions that delight without distraction
- Premium feel without premium price pressure

---

## Key Design Decisions & Rationale

### Decision 1: Tracked Walks (Not Streaks) for Rank

**What we decided:** Rank progression is based on cumulative tracked walks ≥5 minutes, not streak length.

**Why:**
- Streaks are fragile — miss one day and you lose everything
- Streaks create anxiety and can become punishing
- Tracked walks are cumulative — you can never lose progress
- This rewards showing up intentionally, not just passive movement
- 10,000 steps from errands ≠ intentional 20-minute walk
- "Every step counts toward your goal. Every walk builds your legacy."

**The distinction:**
| Metric | What It Measures | What It Says |
|--------|------------------|--------------|
| Steps | How much you moved | "I was active" |
| Streak | Consistency hitting goal | "I'm reliable" |
| Tracked Walks | Intentional showing up | "I'm a walker" |

---

### Decision 2: 5-Minute Minimum for Rank

**What we decided:** Only walks ≥5 minutes count toward rank progression.

**Why:**
- Prevents gaming (start/stop walks for quick rank)
- 5 minutes is low enough to not feel punishing
- Creates a meaningful threshold for "intentional walk"
- Still rewards effort even if walk is short

**Where to communicate:**
- Journey screen: Full explanation
- During walk: Show indicator after 5 min ("✓ Counts toward rank")
- Post-walk (<5 min): Gentle education, not punishment
- Walk tab before starting: Don't mention (no friction)

---

### Decision 3: Four Separate Engagement Loops

**What we decided:** Daily goal, Streak, Rank, and Challenges are four separate systems that interconnect.

**Why:**
- Each serves a different psychological need
- Different timeframes create layered motivation
- One action (track a walk) feeds all four
- Prevents single point of failure for motivation

**The timeframes:**
| System | Timeframe | Psychology |
|--------|-----------|------------|
| Daily Goal | Today | "Did I do enough today?" |
| Streak | Week-to-week | "Am I consistent?" |
| Rank | Months/lifetime | "Who am I becoming?" |
| Challenges | Monthly | "What's fun right now?" |

---

### Decision 4: 7-Tier Rank Ladder

**What we decided:** Expand from 5 ranks to 7 ranks to solve the "motivation desert" between walks 1-25.

**Why:**
- Original 5-tier had gaps too wide (1 → 25 walks)
- Users need more frequent positive reinforcement early on
- New milestones at 10 and 50 walks create momentum
- 365 walks for max rank = "One year of walks" (meaningful milestone)

**The 7-Tier Ladder:**

| Rank | Walks | Motto | Timeline | Psychology |
|------|-------|-------|----------|------------|
| Walker | 1 | "I started." | First walk | You took the first step |
| Wayfarer | 10 | "I'm finding my way." | ~2 weeks | You're exploring |
| Strider | 25 | "I've found my rhythm." | ~1 month | Walking is becoming habit |
| Pacer | 50 | "I keep showing up." | ~2 months | Consistent commitment |
| Centurion | 100 | "The path is part of me." | ~3-4 months | Walking is identity |
| Voyager | 200 | "I've gone the distance." | ~6-8 months | Proven dedication |
| Just Walker | 365 | "I am a walker." | One year | This is who you are |

**Critical insight:** 365 walks ≈ one year at 1 walk/day. This makes "Just Walker" a meaningful one-year anniversary of commitment, not an arbitrary number.

---

### Decision 5: Dynamic Card (Context-Aware UI)

**What we decided:** The Today screen shows a single context-aware card that changes based on what's most relevant/urgent.

**Why:**
- Avoids information overload
- Always shows the most actionable item
- Creates appropriate urgency without constant pressure
- Single card is cleaner than multiple teasers

**Priority order (most urgent first):**
1. Streak at risk (after 6pm, goal not met)
2. Daily goal very close (≤500 steps)
3. Rank milestone close (≤3 walks)
4. Challenge expiring (date-specific, ≤2 days)
5. Challenge almost complete (≥80%)
6. New month challenges (days 1-3)
7. Default: Rank progress

---

### Decision 6: Progressive Disclosure for Rank System

**What we decided:** Don't explain rank during onboarding. Introduce it after first tracked walk.

**Why:**
- Onboarding should be fast and focused
- Rank system is meaningless without context
- After first walk, user just DID the thing — now it makes sense
- "You completed your first walk! Here's what you're building toward..."

---

### Decision 7: Cut Route Generation

**What we decided:** Remove Magic Routes / route generation feature entirely.

**Why:**
- MKDirections API not designed for circular walking routes
- Consistently buggy results (backtracking, weird paths)
- Users know where they want to walk
- Apple Maps / Google Maps handle navigation better
- Feature was cool demo but not core to habit building
- Complexity doesn't serve the beginner user

**What we kept:** Simple GPS tracking to show route on map after walk.

---

### Decision 8: "Let's Go" Not "Start Walk"

**What we decided:** Primary action button says "Let's Go" not "Start Walk" or "Track Walk."

**Why:**
- "Start Walk" is utilitarian
- "Track Walk" implies measurement
- "Let's Go" implies partnership, motivation
- Emotional language > functional language
- Small copy choices shape how users feel about the app

---

### Decision 9: Challenges Are Optional Fun

**What we decided:** Monthly challenges are awareness/discovery, not pressure.

**Why:**
- Challenges should feel like bonus content
- No penalty for ignoring them
- They expire (no guilt backlog)
- Mix of easy wins and stretch goals
- Seasonal themes create freshness

**Safety rules for challenge design:**
- No aggressive volume in July/August (heat)
- No night walking pushes
- Flexible timeframes
- Nothing that could injure beginners

---

### Decision 10: Pro Subscription — Gate Features, Not Data

**What we decided:** Pro subscription ($39.99/year, $7.99/month) gates advanced features, never user data.

**Why:**
- Beginners shouldn't pay to access their walking data
- Core habit-building features should be free
- Pro = power user features for those who want more
- Free tier should feel complete, not crippled

**Pro Features:**
- ✓ Interval Walks (variable pace programs)
- ✓ Vibe Goals (time-based, relaxed targets)
- ✓ Map Themes (line colors, dark mode toggle)
- ✓ Advanced Stats (future: My Patterns)

**Always Free:**
- All walking data
- Rank progression
- Challenges
- Streaks
- Basic goals (steps, distance)
- Core app functionality

---

### Decision 11: Interval Walks (Pro)

**What we decided:** Include variable-pace interval walks as a Pro feature.

**Why:**
- "Japanese Method" (3 min brisk / 3 min easy) has research backing
- Adds variety for users who've established the habit
- Voice cues and phase transitions feel premium
- Good fit for Pro tier — advanced but not essential

**Implementation:**
- Pre-built programs (Beginner, Japanese Method, Endurance, Quick Burst)
- Voice announcements for phase changes
- Haptic feedback on transitions
- Live Activity shows current phase
- Counts toward rank like any other walk

---

### Decision 12: Dark Mode Maps Default

**What we decided:** Maps display in dark/satellite mode by default.

**Why:**
- Looks stunning with iOS 26 Liquid Glass floating controls
- Creates visual consistency across light/dark mode app themes
- Route lines pop better against dark backgrounds
- Premium aesthetic feel
- Users can toggle to light in settings if preferred

---

### Decision 13: iOS 26 Liquid Glass Throughout

**What we decided:** Fully embrace iOS 26 Liquid Glass design language.

**Why:**
- Apple's biggest design evolution since iOS 7
- Apps that don't adopt will look dated immediately
- Liquid Glass + dark maps = striking visual identity
- Tab bars, toolbars, floating controls all get glass treatment
- Creates clear hierarchy: glass = navigation, solid = content

**Key principles:**
- Glass is ONLY for navigation layer (controls that float above content)
- NEVER apply glass to content (lists, cards, tables)
- Use GlassEffectContainer for grouped controls
- Tint glass with brand color (teal) sparingly

---

### Decision 14: Intentional Elegance Animation System

**What we decided:** Every interaction should be animated with intention. No static transitions.

**Why:**
- Differentiates from generic fitness apps
- Makes app feel premium and considered
- Strava sets the bar for fluid fitness app UX
- Micro-interactions build subconscious trust

**Animation standards:**
| Type | Timing | Use Case |
|------|--------|----------|
| Micro | 0.18s snappy | Button taps, toggles |
| Standard | 0.4s spring | Card appearance, state changes |
| Emphasis | 0.5s bouncy spring | Celebrations, milestones |
| Morph | 0.35s smooth | Sheet presentations |
| Stagger | 0.05s × index | List entrances |

**Required animations:**
- Ring fill on Today screen appear
- Step counter uses contentTransition(.numericText())
- Cards slide in with stagger
- Buttons have scale feedback on tap
- Confetti for qualifying walks
- SF Symbol effects (.bounce, .pulse) where appropriate

---

### Decision 15: "Quiet Partner" Notification Persona

**What we decided:** Notifications should feel like a supportive friend, not a nagging app.

**Why:**
- Traditional fitness app notifications feel pushy
- Beginners are already struggling with guilt
- Supportive tone builds relationship, not resentment
- Copy should feel human, not robotic

**Notification copy examples:**

| Notification | Title | Body |
|--------------|-------|------|
| Evening Nudge (5pm) | "The day is almost done" | "A 15-minute walk clears the mind." |
| Streak at Risk (7pm) | "Your streak is waiting" | "There's still time. X days and counting." |
| Streak Broken | "We go again" | "The streak is just a number. The habit is you. Today's a fresh start." |
| Rank Up | "You're a [Rank] now" | "[Motto for new rank]" |
| Challenge Complete | "Challenge complete! 🎉" | "[Challenge Name] — another one down. You're building something here." |

**Tone principles:**
- No shame, ever
- Partnership language ("we", not "you should")
- Acknowledge effort, not just results
- Brief — respect attention

---

### Decision 16: Hub & Spoke Paywall

**What we decided:** Paywall uses Hub & Spoke design instead of feature list.

**Why:**
- Feature lists create cognitive overload
- Tappable cards invite exploration
- Users can deep-dive on features they care about
- Better conversion through engagement
- Feels premium and considered

**Hub (main view):**
- Hero headline: "Become the walker you want to be"
- 4 tappable feature cards (Intervals, Map Themes, Vibe Goals, My Patterns)
- Primary CTA: "Try Pro Free for 7 Days"
- Price: "$39.99/year · $7.99/month"
- Skip: "Maybe Later"

**Spokes (detail sheets):**
- Visual preview of feature
- 2-3 value bullets
- "Included in Pro" badge
- iOS 26 glass sheet presentation (morphs from card)

---

### Decision 17: Live Activities for Active Walks

**What we decided:** Show walk progress on Lock Screen and Dynamic Island during active walks.

**Why:**
- Users often lock phone during walks
- Checking progress shouldn't require unlocking
- Dynamic Island provides glanceable info
- Interval walks benefit from phase display on Lock Screen
- Premium feature that showcases iOS capabilities

**What Live Activities show:**
- Elapsed time (primary metric)
- Steps
- Distance
- Goal progress (if goal mode)
- Current phase + pace (if interval mode)

---

## What We Explicitly Cut

| Feature | Why Cut |
|---------|---------|
| Route generation (Magic Routes) | Too buggy, MKDirections not designed for loops |
| Saved routes | Users remember where they walk, adds complexity |
| Finger-drawing routes | Cool demo but impractical |
| Turn-by-turn navigation | That's Google Maps' job |
| Achievement badges | Replaced with rank system |
| Social/sharing features | Not core to beginner habit building |
| Leaderboards | Could be demotivating for beginners |
| Alt App Icons | Low value cosmetic, defer to post-launch |
| WeatherKit / My Patterns | Phase 2 — avoid API costs for MVP |

---

## User Psychology Framework

### The "Deepest Why" Analysis

For every feature, we asked: "Why does the user want this?" three times.

**Example: "I want to see where I walked"**
- Surface: I want to see my route on a map
- Deeper: I want proof I did something
- **Deepest: I need evidence that my time mattered**

**Solution:** Post-walk summary with map and achievements

### The Motivation Stack

| Surface Need | Deeper Why | Deepest Why | Solution |
|--------------|------------|-------------|----------|
| Track my walk | Know I'm exercising | Feel like someone who takes care of themselves | One-tap start, zero friction |
| Hit a goal | Don't trust myself to do "enough" | Need external permission to stop | Goal mode with celebration |
| See my route | Want proof I did something | Need evidence that my time mattered | Post-walk summary with map |
| Know my progress | Feel progress in real-time | Need encouragement to not quit early | Live stats during walk |
| Count my steps | Need to hit daily goal | Need to protect my streak/identity | Auto-sync, streak protection |
| Stay motivated | Easy to skip, hard to stay consistent | Need something external for accountability | Streak, rank, challenges |

---

## Language & Tone Guidelines

### Do Use
- "Let's Go" (partnership)
- "Your journey" (personal)
- "Tracked walks" (clear what counts)
- "You're a [Rank]" (identity)
- Celebration: "🎉 Walk Complete!"
- "We go again" (resilience, partnership)

### Don't Use
- "Track" or "Log" as verbs (too utilitarian)
- "Workout" (intimidating)
- "Exercise" (clinical)
- "You failed to..." (shame)
- "You only walked..." (diminishing)
- "Don't forget to..." (nagging)

### Rank Mottos (Identity Statements)
- Walker: "I started."
- Wayfarer: "I'm finding my way."
- Strider: "I've found my rhythm."
- Pacer: "I keep showing up."
- Centurion: "The path is part of me."
- Voyager: "I've gone the distance."
- Just Walker: "I am a walker."

---

## Technical Context

### Design Tokens

```swift
// Colors
Primary teal: #00C7BE
Glass accent: #00C7BE at 60% opacity

// Radii (iOS 26 Liquid Glass)
Card: 28pt
Pill: 999pt (full round)
Sheet: 34pt
Control: 16pt

// Ring
Today ring diameter: 220pt
Ring stroke width: 18pt

// Map
Default style: Dark/Satellite
```

### Testing Environment
- iPhone 16 Pro simulator
- iOS 26+
- Xcode 26

### Key Technical Decisions
- HealthKit for passive step tracking
- CoreLocation for GPS during walks
- UserDefaults for persistence (simple, no server)
- SwiftUI throughout
- Combine for reactive updates
- StoreKit 2 for subscriptions
- WidgetKit for Live Activities
- AVSpeechSynthesizer for interval voice cues

---

## iOS 26 Liquid Glass Quick Reference

### What Gets Glass (Navigation Layer)
- Tab bar ✓ (automatic)
- Toolbars ✓ (automatic)
- Floating action buttons ✓
- Walk controls ✓
- Sheets (partial height) ✓ (automatic)
- Live Activities ✓

### What NEVER Gets Glass (Content Layer)
- List items ✗
- Content cards ✗
- Tables ✗
- Media ✗
- Progress bars ✗

### Glass API Cheat Sheet
```swift
// Basic glass
.glassEffect()

// Tinted glass (brand color)
.glassEffect(.regular.tint(.teal))

// Interactive glass (buttons)
.glassEffect(.regular.interactive())

// Clear glass (more transparent)
.glassEffect(.clear)

// Grouped controls
GlassEffectContainer {
    HStack { ... }
}
```

---

## Animation Quick Reference

### Timing Curves
```swift
// Micro (button taps)
Animation.snappy(duration: 0.18)

// Standard (card appearance)
Animation.spring(response: 0.4, dampingFraction: 0.75)

// Emphasis (celebrations)
Animation.spring(response: 0.5, dampingFraction: 0.6)

// Morph (sheets)
Animation.smooth(duration: 0.35)

// Stagger
Animation.spring(...).delay(Double(index) * 0.05)
```

### Required Animations
- Ring fill on appear
- Step counter contentTransition
- Card staggered entrance
- Button tap scale feedback
- Confetti on qualifying walk
- SF Symbol effects

### Haptic Patterns
- Button tap: .light
- Goal complete: .success notification
- Rank up: .heavy + delayed .heavy(0.7)
- 5-minute milestone: .medium
- Interval phase change: .rigid
- Streak increment: .soft

---

## Previous Work References

### Transcripts (in /mnt/transcripts/)
1. `2026-01-23-03-37-23-onboarding-gps-routes-backgrounds.txt`
   - Onboarding redesign (8 prompts OB-1 through OB-8)
   - GPS tracking improvements (Kalman filtering)
   - Route generation algorithm fixes (ultimately cut)
   - Walker Card backgrounds (10 Midjourney concepts)

2. `2026-01-23-16-17-06-just-walk-core-systems-design.txt`
   - Core engagement loops definition
   - Rank system design
   - Monthly challenges (60 total)
   - Dynamic card priority system
   - UI hierarchy decisions

3. `2026-01-23-19-48-42-gemini-delta-review-v21-updates.txt`
   - Gemini's proposed changes review
   - 7-rank ladder decision
   - Build Loop Protocol addition
   - iOS 26 Liquid Glass integration
   - Interval Walks / Live Activities inclusion

### Previous Handoff Docs (in /mnt/user-data/uploads/)
- just_walk_handoff_jan21.md
- just-walk-design-summary.md
- just_walk_handoff_jan22.md
- just_walk_handoff_jan22_session2.md
- gemini-implementationplan-delta.rtf
- gemini-designcontext-delta.rtf

---

## Build Loop Protocol

**Every implementation prompt MUST follow this loop:**

```
1. IMPLEMENT → Write the Swift code
2. BUILD → xcodebuild -scheme "JustWalk" ...
3. ANALYZE → Parse for errors
4. FIX → Address compilation issues
5. REPEAT → Until BUILD SUCCEEDED
6. PROCEED → Only then move to next task
```

This prevents cascading errors and ensures each component actually compiles before moving on.

---

## Claude Code Workflow Recommendation

**Use detailed prompts → Claude Code regular mode** for most work.

### Why
Our conversation was **design work** — user psychology, UX decisions, system design. These are decisions, not tasks. Claude Code shouldn't re-decide them.

### When to Use Regular Mode
- We've designed the UI/UX together
- The prompt has exact specifications
- It's mostly UI work
- The prompt includes code snippets

### When to Use Plan Mode
- The task is technical, not design
- Multiple valid approaches exist
- Implementation details not specified
- It's refactoring/cleanup

---

## Open Questions / Future Considerations

These were discussed but not fully resolved:

1. **My Patterns / Insight Cards** — Deferred to Phase 2, time-based only (no WeatherKit)
2. **Watch app complexity** — How much to replicate on Watch?
3. **Widget data refresh** — How often to update via App Groups?
4. **Notification frequency** — Current plan is minimal; monitor user feedback
5. **Challenge difficulty calibration** — Are targets appropriate for beginners?
6. **Alt App Icons** — Cosmetic Pro feature, low priority, post-launch

---

## Summary for New Chat

When starting a new conversation, provide both documents:

1. **`just_walk_implementation_plan_v21.md`** — The complete technical spec
2. **`just_walk_design_context_v21.md`** (this file) — The why behind the what

The new chat should understand:

**Core Identity:**
- This is an identity transformation app, not a fitness tracker
- Target user is intimidated beginners
- Goal: "I should walk more" → "I am a walker"

**Engagement Systems:**
- Tracked walks (not streaks) drive rank progression
- 5-minute minimum for rank qualification
- Four separate engagement loops that interconnect
- 7-tier rank ladder (1/10/25/50/100/200/365)

**Design Philosophy:**
- iOS 26 Liquid Glass design throughout
- "Intentional Elegance" animation system
- Dark maps by default
- "Quiet Partner" notification persona
- Hub & Spoke paywall design

**What's In:**
- Interval Walks (Pro)
- Live Activities
- Voice cues for intervals

**What's Cut:**
- Route generation (too buggy)
- WeatherKit (Phase 2)
- Alt App Icons (post-launch)

**Language Matters:**
- "Let's Go" not "Start Walk"
- Partnership tone, never shame
- Progressive disclosure: rank system introduced after first walk

---

*This document captures the strategic thinking and design rationale from the January 23, 2026 design sessions, updated for v2.1 with iOS 26 Liquid Glass, Interval Walks, and Intentional Elegance animations.*
