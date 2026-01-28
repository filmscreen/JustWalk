# Just Walk — App Icon Design Specification

## Concept

A minimalist progress ring on a dark background. The ring is incomplete (~75-80% filled), suggesting ongoing progress and habit building. This differentiates from competitors who all use walking figure silhouettes.

---

## Design Philosophy

- **Minimal** — One visual element, no clutter
- **Premium** — Apple-quality, not "app store generic"
- **On-brand** — Matches the in-app experience exactly
- **Meaningful** — The incomplete ring = always progressing, never "done"

---

## Primary Design (Recommended)

### Canvas
- **Size:** 1024 x 1024 px (App Store requirement)
- **Shape:** Square with no rounded corners (iOS adds them automatically)
- **Safe zone:** Keep key elements within center 800 x 800 px

### Background
- **Color:** #0D0D0F (near-black, matches app)
- **Alternative:** #1C1C1E (slightly lighter, more visible on dark wallpapers)
- **Gradient option:** Subtle radial gradient from #1C1C1E (center) to #0D0D0F (edges)

### The Ring

**Dimensions:**
- **Outer diameter:** 680 px (66% of canvas)
- **Stroke width:** 64 px
- **Inner diameter:** 552 px

**Position:**
- Centered on canvas (172 px from each edge)

**Ring Track (background):**
- **Color:** #2C2C2E (dark gray, 20% visible)
- **Full circle:** 360°

**Ring Progress (foreground):**
- **Color:** Brand green gradient
  - Start: #30D158 (primary green)
  - End: #4ADE80 (lighter green)
- **Arc:** 270° (75% complete)
- **Start position:** 12 o'clock (top center)
- **Direction:** Clockwise
- **End position:** 9 o'clock (left side)

**Ring Style:**
- **Line cap:** Round (both ends)
- **No shadow on ring itself**

### Glow Effect (Subtle)
- **Color:** #30D158 at 15% opacity
- **Blur:** 40 px
- **Applied to:** Progress ring only (not track)
- **Purpose:** Adds depth, suggests energy

### Gap Detail
- The ~90° gap (from 9 o'clock to 12 o'clock) should feel intentional
- Gap represents "room to grow" and "journey in progress"

---

## Visual Reference (ASCII)

```
        ┌─────────────────────────────────┐
        │                                 │
        │         ▄▄▄▄▄▄▄▄▄▄▄            │
        │       ▄█           ██▄          │
        │      █▀             ▀█         │
        │     █▌    (empty)    ▐█        │
        │     █▌               ▐█        │
        │     █▌               ▐█        │
        │      █▄             ▄█         │
        │       ▀█▄▄▄▄▄▄▄▄▄▄▄█▀          │
        │            ███                  │
        │            ███  ← Gap here      │
        │                                 │
        └─────────────────────────────────┘

Ring: Green gradient (#30D158 → #4ADE80)
Track: Dark gray (#2C2C2E)
Background: Near-black (#0D0D0F)
```

---

## Color Specifications

| Element | Hex | RGB | Use |
|---------|-----|-----|-----|
| Background | #0D0D0F | 13, 13, 15 | Canvas fill |
| Ring Track | #2C2C2E | 44, 44, 46 | Unfilled portion |
| Ring Start | #30D158 | 48, 209, 88 | Progress start (12 o'clock) |
| Ring End | #4ADE80 | 74, 222, 128 | Progress end (9 o'clock) |
| Glow | #30D158 @ 15% | — | Subtle depth |

---

## Gradient Specifications

### Ring Gradient
- **Type:** Linear
- **Angle:** 135° (top-right to bottom-left)
- **Stops:**
  - 0%: #30D158
  - 100%: #4ADE80

### Background Gradient (Optional)
- **Type:** Radial
- **Center:** 50% 50%
- **Stops:**
  - 0%: #1C1C1E
  - 100%: #0D0D0F

---

## Size Variations

iOS requires multiple sizes. The design should work at all:

| Size | Use | Notes |
|------|-----|-------|
| 1024 x 1024 | App Store | Full detail |
| 180 x 180 | iPhone @3x | Primary app icon |
| 120 x 120 | iPhone @2x | Older devices |
| 167 x 167 | iPad Pro | |
| 152 x 152 | iPad | |
| 87 x 87 | Spotlight @3x | |
| 80 x 80 | Spotlight @2x | |
| 60 x 60 | Notification @3x | |
| 40 x 40 | Notification @2x | |

**Small size considerations:**
- Ring stroke may need to be proportionally thicker at small sizes
- Glow effect may need to be reduced or removed
- Test at 60x60 to ensure ring is clearly visible

---

## Do's and Don'ts

### Do ✓
- Keep the ring perfectly centered
- Maintain consistent stroke width
- Use exact brand colors
- Test on both light and dark wallpapers
- Test at small sizes (notification, spotlight)
- Export with no transparency
- Export without rounded corners (iOS adds them)

### Don't ✗
- Add text or wordmarks
- Add a walking figure inside the ring
- Make the ring 100% complete (defeats the concept)
- Use drop shadows (looks dated)
- Add borders or outlines
- Use pure black (#000000) — too harsh
- Add noise or texture

---

## Alternative Variations

### Variation A: Centered Step Count

Add "0" inside the ring (suggesting fresh start):

```
        ╭─────────────╮
       │   ▄▄▄▄▄▄▄    │
       │  █       █   │
       │ █    0    █  │  ← "0" in center
       │  █       █   │     Light gray, subtle
       │   ▀▀▀ ▀▀▀    │
        ╰─────────────╯
```

- Number: "0"
- Font: SF Pro Rounded, Bold
- Size: 280 px
- Color: #8E8E93 (secondary gray)
- Position: Dead center

**Pros:** Adds meaning, connects to step counting
**Cons:** More complex, may not read at small sizes

---

### Variation B: Walking Figure Inside (Very Subtle)

Tiny walking figure watermark inside ring:

```
        ╭─────────────╮
       │   ▄▄▄▄▄▄▄    │
       │  █       █   │
       │ █    🚶   █  │  ← Figure at 10-15% opacity
       │  █       █   │
       │   ▀▀▀ ▀▀▀    │
        ╰─────────────╯
```

- Icon: SF Symbol `figure.walk`
- Size: 200 px
- Color: #FFFFFF at 10% opacity
- Position: Centered

**Pros:** Connects to walking theme without being obvious
**Cons:** May look cluttered, hard to see at small sizes

---

### Variation C: Multiple Rings (Apple Fitness Style)

Two concentric rings:

```
        ╭─────────────╮
       │  ▄▄▄▄▄▄▄▄▄   │
       │ █  ▄▄▄▄▄  █  │  ← Outer: Green (steps)
       │ █ █     █ █  │     Inner: Orange (streak)
       │ █  ▀▀▀▀▀  █  │
       │  ▀▀▀▀▀▀▀▀▀   │
        ╰─────────────╯
```

- Outer ring: #30D158 (steps)
- Inner ring: #FF9F0A (streak)
- Different completion percentages

**Pros:** More visual interest, ties to streak feature
**Cons:** Too similar to Apple Fitness, more complex

---

## Recommended Final Design

**Go with the primary design (single ring, no additions):**

- Cleanest, most distinctive
- Works at all sizes
- Instantly recognizable
- Doesn't need explanation
- Premium, confident, minimal

---

## Production Files Needed

Request these from your designer:

1. **Master file:** 1024x1024 PNG, no transparency
2. **App Icon Set:** All iOS sizes (use Xcode asset catalog)
3. **Source file:** Figma, Sketch, or AI for future edits
4. **Marketing versions:**
   - With rounded corners (for web/marketing)
   - On device mockups
   - Dark and light background versions for press kit

---

## AI Image Generation Prompt

If using Midjourney, DALL-E, or similar:

```
Minimalist app icon, single progress ring on dark background, 
ring is 75% complete with a gap at top, ring color is vibrant 
green (#30D158) with subtle gradient to lighter green, 
ring has soft glow effect, background is near-black (#0D0D0F), 
no text, no figures, no symbols inside ring, 
Apple iOS app icon style, ultra clean, premium quality, 
centered composition, 1024x1024
```

**Negative prompt:**
```
walking figure, person, shoes, footprints, text, letters, 
numbers, hearts, flames, complex, busy, gradients background,
3D, shadows, borders, frames
```

---

## Figma/Sketch Specifications

### Layer Structure
```
📁 App Icon
  └── 📁 Background
      └── Rectangle (1024x1024, #0D0D0F, Corner Radius: 0)
  └── 📁 Ring
      └── Ring Track (Circle, Stroke: 64px, #2C2C2E)
      └── Ring Progress (Arc, Stroke: 64px, Gradient, 270°)
      └── Glow (Ring Progress copy, Blur: 40px, Opacity: 15%)
```

### Figma Arc Settings
- **Ring Progress:**
  - Type: Arc
  - Start: -90° (12 o'clock)
  - Sweep: 270°
  - Stroke: 64px
  - Cap: Round

---

## Testing Checklist

Before finalizing:

- [ ] Looks good on light wallpaper (Home screen)
- [ ] Looks good on dark wallpaper (Home screen)  
- [ ] Readable at 60x60 (notification size)
- [ ] Stands out in App Store search results
- [ ] Doesn't look like Pedometer++, StepsApp, etc.
- [ ] Ring clearly reads as "progress"
- [ ] Gap is noticeable but not jarring
- [ ] Colors match app exactly
- [ ] No banding in gradients
- [ ] Exported at correct sizes with no transparency
