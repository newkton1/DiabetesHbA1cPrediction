# V2 Japanese Localization — Planning Notes
*Status: DEFERRED — do not begin until V1 (build 33) is accepted on the App Store*

---

## FoodDatabase Structure Analysis (read-only audit, Aug 2026)

### FoodDatabase.json (Western)
- **1,579 entries**, 34 categories
- Fields: `name`, `category`, `servingSize`, `servingUnit`, `calories`, `carbohydrates`, `protein`, `fat`, `fiber`, `glycemicIndex`
- No Japanese name field exists yet
- Category names are in English

### FoodDatabase_JP.json (Japanese)
- **2,538 entries**, same field structure
- `name` field contains Japanese text (e.g., `アマランサス　玄穀`)
- Category names also in English (same as western DB)

### Categories in Western DB (34 total, sorted by count)
Asian & Japanese: 115, Breakfast Dishes: 85, Sandwiches & Wraps: 82, Soups & Stews: 79, Desserts: 79, Flavorings: 76, Beverages: 74, European Foods: 67, British Foods: 64, Frozen & Prepared Meals: 60, Salads: 60, Pasta & Italian: 57, Side Dishes: 53, Snacks: 52, Steaks & Grills: 49, Roasts & Casseroles: 46, Deli & Charcuterie: 46, Baked Goods: 43, Snacks & Sweets: 40, Burgers & Hot Dogs: 39, Pizza: 38, Fast Food: 36, Vegetables: 32, Meat & Poultry: 32, Dairy: 27, Fruits: 24, Breads & Bakery: 24, Feast: 21, Grains & Cereals: 20, Fish & Seafood: 17, Nuts & Seeds: 16, Legumes & Beans: 13, Pasta & Noodles: 11, Stews: 2

---

## Localization Plan (agreed, not yet implemented)

### FoodDatabase.json — Adding Japanese names
- Add a `nameJP` field to each of the 1,579 western entries
- App displays `nameJP` when in Japanese locale; falls back to `name` if blank
- 115 "Asian & Japanese" entries may be straightforward (many already known in Japan)
- ~1,464 truly western entries need translation (burgers, pizza, British foods, etc.)
- **Recommended approach:** batch script → LLM or DeepL/Google Translate API → human spot-check for culturally ambiguous items (e.g., Haggis, Spotted Dick, Marmite)

### Food Search UI — 和食/洋食 pill design (agreed Aug 2026, not yet implemented)
- When the user opens the Japanese food search, **和食 (Japanese foods) is shown by default** — no extra tap required
- A **洋食 (Western foods) pill** is available to switch to the western database
- The **text search box searches only the currently selected database** (not both simultaneously)
- The horizontal category chip lists (Recent, My Menu, Bakery, etc.) update to reflect whichever pill is active, all labels in Japanese
- Implementation is blocked on: (1) Robert's review of `FoodDatabase_EN_JP_Translations.xlsx`, (2) adding `nameJP` field to FoodDatabase.json entries

### Other agreed localization items
1. **Hide FDA external search** in Japanese locale (FDA is US-only, irrelevant to Japanese users)
2. **Keep internal western database** as secondary in Japanese mode (not removed, just lower priority)
3. **Translate Privacy Policy** to Japanese and host on GitHub (Task #34)
4. Western meal names shown to Japanese users should be translated (e.g., "burger" → "バーガー")

---

## V1.1 Bug Fix Backport (after V1 accepted)
*Status: DEFERRED — do not touch v1-submission until V1 is accepted*

### Cycling sync bug — two issues fixed in V2-dev (Aug 2026), need backporting to V1.1

**Bug 1 — Cycling distance imports as 0 km** (`HealthKitManager.swift`)
- Root cause: `syncExerciseToCorData` always fetched distance using `.distanceWalkingRunning`, which returns nothing for cycling workouts
- Fix applied in V2-dev: use `.distanceCycling` for cycling/hand-cycling, `.distanceSwimming` for swimming, `.distanceWalkingRunning` for all other types

**Bug 2 — Confirmation message says "walking" after cycling sync** (`ExerciseLogView.swift` + `HealthKitManager.swift`)
- Root cause: sync message said generic "1 new workout" with no type info, and ambient step data always appended "X days of walking activity" — combined these made cycling look like it was stored as walking
- Fix applied in V2-dev:
  - `importWorkoutsToCoreData` now returns `(count: Int, types: [String])`
  - `syncExerciseToCorData` return type changed to `(count: Int, types: [String])`
  - Confirmation message now says e.g. **"1 new workout (Cycling)"**
  - Ambient step data now labelled **"ambient walking activity"** to distinguish it from formal workouts

**Files to change for V1.1 backport:**
- `HealthKitManager.swift` — distance identifier switch + `importWorkoutsToCoreData` + `syncExerciseToCorData` return type + legacy wrapper
- `ExerciseLogView.swift` — call site (`exerciseResult` not `exerciseCount`) + message building block

---

## Safety Rules (do not violate)
- **NEVER place files in the Xcode source folder** `~/NewApp/DiabetesHbA1cApp/DiabetesHbA1cPrediction/DiabetesHbA1cPrediction/` — caused 2-hour build failure previously. Exception only for intentional Swift feature additions.
- All V2 changes go on the **V2-dev branch** (not v1-submission)
- Clinical summary HTML work: ONLY in `~/Desktop/DiabetesFeast_LogbookData/`
