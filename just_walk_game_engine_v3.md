# Project: Just Walk v3.0 – The Gamification Engine

## 1. Product Vision & Positioning
**"Noise-Canceling for the Mind."**
Just Walk is an anti-fitness app for high-functioning, burned-out professionals. We do not compete on calories, pace, or social leaderboards. We compete on **mental clarity**.
* **The User Goal:** A daily "reset button" to escape noise and anxiety.
* **The Business Goal:** Long-term retention via habit formation (Streaks) and identity progression (Ranks).
* **The Vibe:** High-end, clean, fashionable. Think *Vuori* or *Aman Resorts*, not *Gold’s Gym*.

---

## 2. The Core Loop: Defense vs. Offense
The engine creates a "Dual Loop" that separates **Retention (Defense)** from **Progression (Offense)**. This prevents user burnout while incentivizing active engagement.

### A. Defense: The "Shield & Streak" (Passive)
* **Purpose:** Safety. Reduces anxiety about "missing a workout."
* **Mechanism:** Background Step Tracking (HealthKit).
* **The Promise:** "If you hit your daily step goal—even just walking around the office—your Streak is safe. You do not need to open the app."
* **Outcome:** Keeps the user active in the database (Retention).

### B. Offense: The "Rank & XP" (Active)
* **Purpose:** Growth. Drives the feeling of "Leveling Up" in life.
* **Mechanism:** The manual "Start Walk" button in the app.
* **The Promise:** "To evolve your Rank (Status) and change your environment, you must take intentional, dedicated walks."
* **Outcome:** Drives session time and app engagement (Growth).

---

## 3. The Point Economy (XP System)
We utilize a **Time-Based Economy** to reward effort fairly. We measure **Journey Points (XP)**, not calories.

### 1. Standard Walk (The Foundation)
* **User Action:** Tap "Just Walk." Open-ended duration.
* **Scoring Rule:** **3 XP per Minute.**
* **The "Soft Cap" (Anti-Cheat & Burnout Prevention):**
    * **0–60 Mins:** 3 XP/min (Prime Incentive).
    * **60–120 Mins:** 1 XP/min (Endurance Credit).
    * **120+ Mins:** 0 XP (Safety cutoff).

### 2. Interval Walk (The Challenge)
* **User Action:** Tap "Interval Session." A structured, audio-guided experience using the Japanese Interval Method (Fast/Slow intervals).
* **Scoring Rule:** **Flat 150 XP Reward.**
* **The "Contract":** This is a fixed 30-minute session.
    * *Success:* User finishes 30 mins = **150 XP** (High Yield).
    * *Failure:* User quits early = **0 Bonus XP** (Downgrades to standard time logging only).
* **Value:** Incentivizes higher intensity without requiring a complex heart-rate formula.

### 3. Streak Bonuses (Compounding Interest)
* **Daily Bonus:** **+20 XP** for hitting the Daily Step Goal (Passive or Active).
* **Weekly Jackpot:** **+100 XP** for every 7 consecutive days of active streaks.

---

## 4. Progression Architecture (Ranks & Grades)
We replace the "Forever Grind" with frequent milestones. The user progresses through **7 Major Ranks**, each tied to a specific **Visual Environment**.
To prevent boredom between ranks, each Rank is divided into **3 Grades** (I, II, III).

### The Rank Table

| Rank | Theme / Environment | XP Threshold | Est. Time to Achieve |
| :--- | :--- | :--- | :--- |
| **1. Walker** | **Sunrise Park** <br>*(Bushes, benches, dawn light)* | **0 XP** | Day 1 |
| **2. Wayfarer** | **Suburban Streets** <br>*(Houses, picket fences, morning)* | **3,500 XP** | Month 1 |
| **3. Strider** | **The Cityscape** <br>*(Skyscrapers, geometric, midday)* | **12,000 XP** | Month 3.5 |
| **4. Pacer** | **Industrial District** <br>*(Factories, brick, sunset)* | **30,000 XP** | Month 8 |
| **5. Centurion** | **The High Peaks** <br>*(Mountains, pine trees, twilight)* | **55,000 XP** | Year 1.3 |
| **6. Voyager** | **Global Landmarks** <br>*(Eiffel Tower, Pyramids, night)* | **95,000 XP** | Year 2.0 |
| **7. Just Walker**| **The Celestial Path** <br>*(Stars, clouds, infinite space)* | **150,000 XP** | Year 3+ |

* **Grade Logic:** Moving from *Wayfarer I* to *Wayfarer II* is a "Mini-Win" (Progress bar fills, haptic celebration). Moving from *Wayfarer III* to *Strider I* is a "Major Win" (New visual theme unlocks).

---

## 5. Engagement Mechanics

### A. The Streak Shield (The Safety Net)
* **Philosophy:** "Life Happens." Punishment causes churn.
* **Allocation:**
    * *Free:* 1 Shield / Month.
    * *Pro:* 1 Shield / Week.
* **Banking:** User can bank up to **3 Shields**.
* **Auto-Deploy:** If a Daily Goal is missed and a Shield is available, the system **automatically** uses it.
    * *Notification:* "Rough day? We got you. Streak Saved."
    * *Penalty:* The Streak Count (e.g., "Day 45") is saved, but **0 XP** is awarded for that day.

### B. The Legacy Badge (Churn Prevention)
* **Problem:** Breaking a massive streak (e.g., 100 days) often causes users to quit permanently out of frustration.
* **Solution:** If a streak of **30+ days** is broken and no shields remain:
    * The counter resets to 0.
    * **BUT** the user unlocks a permanent **"Legacy Badge"** (e.g., "The 100 Club") in their profile. Their effort is immortalized, not erased.

### C. Audio & Haptics (Respectful Design)
* **Default:** Silent. We do not interrupt the user's podcast or thoughts.
* **Interval Mode:** Uses "Audio Ducking." The guide speaks ("Speed up"), lowering the user's music volume, then instantly restores it.
* **Haptic Mode:** Full support for a vibration-only experience for users who want total silence.

---

## 6. Technical & Business Guardrails

### A. Battery Optimization (Eco-Track)
* **Constraint:** Constant GPS kills battery.
* **Logic:** If the screen is locked for >5 minutes during a walk, downgrade GPS accuracy to `kCLLocationAccuracyThreeKilometers`. Rely on the Motion Chip (Pedometer) to verify the user is still moving.

### B. Anti-Cheat & Integrity
* **Speed Limit:** Auto-pause if speed >15mph (Driving).
* **The "Ghost" Check:** If the Pedometer registers 0 steps for 5 minutes during an "Active Walk," trigger a push notification: *"Are you still walking?"* If no response, auto-end the walk.
* **Time Travel:** Reject any data logs where the device timestamp appears manipulated (checking against system boot time).

### C. Accessibility (Inclusivity)
* **Wheelchair Support:** The app must check `HKWheelchairUse`.
    * *UI Update:* Change "Just Walk" → **"Just Roll."**
    * *Metric Update:* Change "Steps" → **"Pushes."**
* **Indoor Mode:** A toggle in settings to disable GPS requirements for users on treadmills or indoor tracks.

---

## 7. User Mental Model (The "Cheat Sheet")
This is how the user understands the game (Simple), versus how the engine runs (Complex).

| User Wants To... | User Action | Engine Logic (Hidden) |
| :--- | :--- | :--- |
| **Keep Streak Alive** | "I just need to move today." | Passive HealthKit sync. 0 XP, but Streak Counter +1. |
| **Rank Up** | "I'm going for a walk." | Standard Mode. 3 XP/min. Soft cap at 60 mins. |
| **Rank Up FAST** | "I want a challenge." | Interval Mode. Fixed 150 XP. Must finish 30 mins. |
| **Save a Bad Day** | "I'm sick / busy." | Auto-Shield deploys. 0 XP awarded. Streak saved. |