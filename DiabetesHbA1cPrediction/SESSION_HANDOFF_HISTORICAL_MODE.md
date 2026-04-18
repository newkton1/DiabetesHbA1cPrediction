# Session Handoff — Historical Mode for What-If

Created: 16 April 2026, evening session.
Continuation of: `SESSION_HANDOFF_OPTION_C.md` (that handoff covers the Zone-1 Dashboard work and the now-completed copy rewrites for Zone-2 intro screen).

## Why this plan exists

The Option C architecture routes behavioural output to the What-If view (`PlannedMealView` → `MealBuilderView` sheet). The first-pass Step D rewrote user-visible labels to scenario language ("Projected" instead of "Estimated"), but the underlying numbers still come from `HbA1cPredictionEngine.predictWithPlannedMeal(...)`, which is a forward projection from a literature formula. Copy cover alone is a weak defence.

Robert's sharper question (16 Apr evening): "the What-If view should refer to changes caused by *historic* meals — it should say what happened when you did this previously, not predict the future."

That insight reframes the defence: descriptive retrospective analysis on the user's own data is genuinely not a prediction. Dexcom and Libre don't do it. It earns the differentiation and neutralises App Review 1.4.1 for this surface.

## Target architecture

**Primary mode — Historical aggregate.** When the user has built a planned meal, query past meals with similar carbohydrate / glycaemic load / category profile. For each match, look at the glucose excursion in the 2-hour post-prandial window. Surface median + range. No forward claim.

Copy shape: "You've logged **N** meals in the last 90 days with carbs within ±15 g of this planned feast. In the 2 hours after those meals, your glucose rose a median of **+47 mg/dL** (range +22 to +89). Over that window, your lab HbA1c trend was **6.8% → 6.9%**."

**Fallback mode — Soft projection.** When matches < threshold (e.g., < 3 similar past meals), show an empty/soft state rather than falling back to the engine: "Not enough history yet. Log **3 more meals** with similar carbs to see your personal pattern."

The existing `HbA1cPredictionEngine` is **not** deleted. It stays in the codebase as an internal signal that may, in future, power a coached onboarding flow or be exposed behind a developer toggle. But its output is removed from the user-visible What-If surface.

## Core Data context (verified 16 Apr)

What's already available for matching:

**`MealEntity`**
- `timestamp: Date?` (when eaten) / `plannedDateTime: Date?` (when planned)
- `mealType: String?` (e.g. "feast")
- `calories: Double`
- `macronutrients: NSSet?` of `MacronutrientEntity`
- `foodItems: NSSet?` of `MealFoodItemEntity`

**`MealFoodItemEntity`** (per-food line item)
- `carbsPerServing: Double` · `proteinPerServing: Double` · `fatPerServing: Double` · `fiberPerServing: Double`
- `glycemicIndex: Int16`
- `quantity: Double` · `servingSize: Double`
- `foodCategory: String?` (e.g. "grain", "dairy")

**`GlucoseReadingEntity`**
- `glucoseValue: Double` (mg/dL canonical)
- `timestamp: Date?`
- Source field exists (CGM vs fingerstick) — verify when implementing

Everything we need for "similar meal" matching + "2-hour post-prandial excursion" analysis exists in the data model. No migration needed.

## New components to build

### 1. `SimilarMealMatcher` (new file — `Analytics/SimilarMealMatcher.swift` or root)

Static utility. One method:

```swift
struct SimilarMealMatch {
    let meal: MealEntity
    let similarityScore: Double   // 0..1, higher = closer
}

enum SimilarMealMatcher {
    static func findSimilar(
        to plannedCarbs: Double,
        glycaemicLoad: Double,
        categoryProfile: [String: Double],   // e.g. {"grain":0.6,"dairy":0.2,...}
        withinDays: Int = 90,
        context: NSManagedObjectContext
    ) -> [SimilarMealMatch]
}
```

**Matching heuristic** (first version — refine later):
- Weight 0.6: carbs within ±15 g of planned
- Weight 0.3: total GL within ±20% of planned
- Weight 0.1: category profile cosine-similarity ≥ 0.5
- Hard filter: `timestamp` within `withinDays` and not equal to the meal currently under construction
- Hard filter: must have at least one glucose reading within 2 hours after `timestamp`

Return sorted by similarityScore desc.

**Design decisions locked 16 Apr 2026:**
- **No `mealType` filter.** Planned feasts match any past meal with similar carb/GL profile, regardless of whether past meals were tagged "feast" or not. More data early on; accepts that behavioural context is mixed. Revisit if Step G.7 testing shows the mix produces noisy aggregates.
- **Minimum `analysedCount` for showing aggregates: 3.** Below 3, render the empty state.

### 2. `GlucoseExcursionAnalyser` (new file — `Analytics/GlucoseExcursionAnalyser.swift`)

```swift
struct GlucoseExcursion {
    let preMealBaseline: Double      // mg/dL, median of readings in 30 min before meal
    let peakValue: Double             // mg/dL max in [meal, meal+2h]
    let peakDelta: Double             // peakValue - preMealBaseline
    let peakMinutesAfterMeal: Int
    let returnedToBaseline: Bool      // did glucose return to within +10 mg/dL of baseline by +3h?
    let timeToReturnMinutes: Int?
    let readingCount: Int             // number of CGM points used
}

enum GlucoseExcursionAnalyser {
    static func analyse(
        meal: MealEntity,
        context: NSManagedObjectContext
    ) -> GlucoseExcursion?    // nil if insufficient glucose data around this meal
}
```

Require at least 3 glucose readings in the [meal-30min, meal+2h] window. If sparse fingerstick only (one or two readings), return nil — we don't have enough to claim an excursion. CGM users will get data; sparse fingerstick users will simply be told "not enough data."

### 3. `HistoricalPatternSummary` (new file — `Analytics/HistoricalPatternSummary.swift`)

Takes N `SimilarMealMatch` results, runs `GlucoseExcursionAnalyser` on each, returns an aggregate:

```swift
struct HistoricalPatternSummary {
    let matchCount: Int
    let analysedCount: Int           // matchCount minus those with insufficient glucose data
    let medianPeakDelta: Double?     // mg/dL
    let peakDeltaRange: ClosedRange<Double>?
    let medianTimeToReturn: Int?     // minutes, nil if mostly no-return
    let hba1cAtFirstMatch: Double?   // IFCC
    let hba1cAtLastMatch: Double?    // IFCC
    let confidence: ConfidenceLevel  // derived from analysedCount

    enum ConfidenceLevel {
        case insufficient        // analysedCount < 3
        case limited             // 3..<6
        case reasonable          // 6..<12
        case strong              // ≥ 12
    }
}
```

Copy decision: at `insufficient`, don't show numbers at all — just the soft empty state.

### 4. UI rewiring — `MealBuilderView.swift`

Two user-visible places in `MealBuilderView.swift` render engine output today (identified in Step C audit):

1. Inline "Estimated Impact" block (approx. lines 166-200)
2. Section-wrapped `EstimatedImpactContent` view (approx. lines 345-360, struct defined ~line 667)

Both paths currently go through `predictionEngine.predict(from: input)` / `predictionEngine.predictWithPlannedMeal(...)` and display two numbers: glucose rise and HbA1c delta.

**Replace:**
- Swap engine call for `HistoricalPatternSummary.build(plannedMeal:, context:)` (new factory method that orchestrates Matcher → Analyser → Summary).
- When `confidence == .insufficient`, render the empty state.
- When ≥ `.limited`, render historical aggregates.
- Rename struct: `EstimatedImpactContent` → `HistoricalPatternContent` (or `ScenarioPatternContent`).
- Rename function: `computeEstimatedImpact(...)` → `buildHistoricalPattern(...)`.
- Keep all internal variable names (`estimatedGlucoseRise`, etc.) free to rename or leave — not user-visible.

### 5. Copy (final — to lock in Step H below)

**Section header:** "Your pattern with similar meals" (replacing "Estimated Impact").
**Aggregate line:** "Based on **\(matchCount) similar meals** in the last 90 days."
**Glucose line:** "Typical rise: **+\(Int(medianPeakDelta)) mg/dL** (range +\(low)–+\(high))."
**HbA1c line (only if we have lab data spanning the window):** "Your lab HbA1c during these meals: **\(first) → \(last)** \(unit)."
**Exercise offset:** unchanged — exercise recommendation is already a general wellness suggestion, not a prediction.
**Empty state:** "**Not enough history yet.** Log 3 more meals with similar carbs to see how your glucose usually responds."

## Step plan (each step is independently buildable)

- [ ] **Step G.1** — Create `Analytics/` folder (if not already present). Write `SimilarMealMatcher.swift`. Unit-testable pure function; no view code.
- [ ] **Step G.2** — Write `GlucoseExcursionAnalyser.swift`. Unit-testable. Requires small peak-detection logic.
- [ ] **Step G.3** — Write `HistoricalPatternSummary.swift`. Ties G.1 + G.2 together. Factory method `build(plannedMeal:, context:)`.
- [ ] **Step G.4** — In `MealBuilderView.swift`, locate the `EstimatedImpactContent` struct (~line 667) and replace its body. Keep the struct name for now (rename in G.6).
- [ ] **Step G.5** — In `MealBuilderView.swift`, locate the inline "Estimated Impact" block (~lines 166-200) and replace with a call to the new historical content view.
- [ ] **Step G.6** — Rename `EstimatedImpactContent` → `HistoricalPatternContent` throughout, and rename `computeEstimatedImpact` / related helpers. String-level find-replace.
- [ ] **Step G.7** — Build on simulator. Verify: (a) With the seeded demo data (10 lab HbA1c + 30 meals + ~112 glucose readings over 12 weeks), does a planned feast surface historical aggregates? (b) With an empty database, does the empty state render cleanly?
- [ ] **Step G.8** — If G.7 surfaces any behavioural or UX issues, list them and decide in-session whether to fix now or add to the deferred pile.
- [ ] **Step G.9** — Update `SESSION_HANDOFF_OPTION_C.md` + this handoff to reflect final state.

## Open design decisions for Robert

Ordered by how soon they block progress.

1. ~~Meal-type filter.~~ **DECIDED 16 Apr evening:** no filter — match any similar-carb meal regardless of `mealType`. May revisit after G.7 testing.
2. **Similarity carb tolerance.** ±15 g is a starting guess. Could be ±20% of planned carbs instead (proportional). Affects match count.
3. **Lookback window.** 90 days matches the HbA1c red-cell-pool span. Do we also want a shorter "recent trend" (say, last 30 days) displayed separately?
4. **What to show when user has a feast planned but has not yet fed the app any glucose data around past meals.** Probably the empty state — "Your glucose readings don't overlap with your past meals yet." But worth checking.
5. **Exercise offset recommendation** — keep it? It's one of the current features the user likes. The walk recommendation is driven by `estimatedGlucoseRise` today. In historical mode, we could drive it off `medianPeakDelta` instead — same logic, different source number. Easy swap.
6. **Engine fallback in UI or not?** I recommend **no user-facing engine fallback** — if there's insufficient history, say so plainly. A silent swap-in of engine output would defeat the point of the redesign.

## Known risks

- **Seeded demo data may not align.** The existing seed data in `PreviewData.populate(...)` puts glucose readings and meals on similar date ranges but not necessarily with glucose readings clustered around meal timestamps. May need a seed-data tweak so that at least some demo meals have adjacent glucose data. File: `PreviewData.swift`.
- **CGM vs fingerstick source.** Fingerstick excursion analysis is fundamentally unreliable (two points can't characterise a curve). If user is fingerstick-only, the analyser will return nil for most meals and the empty state will dominate. This is correct behaviour — we shouldn't fake data. But it should be called out in copy or in a future "import your CGM data" prompt.
- **Performance.** Fetching meals for the last 90 days + fetching glucose readings for each match is 2N queries at worst. On a small dataset (seeded or early user) this is trivial. At 1000+ meals / 100k+ glucose readings this needs a single batched query. Do the simple version first; optimise if needed.
- **Xcode project file.** New Swift files in `Analytics/` subfolder will need to be added to the .xcodeproj manually (Xcode won't pick them up automatically unless folder is a "folder reference"). Remind Robert after creation.

## Current session status at handoff creation

- Session: `c3fa84c4-2207-4100-9041-30cff324810a` (16 Apr 2026)
- Branch: (Robert is managing git locally — see SESSION_HANDOFF_OPTION_C for branch policy)
- Files changed this session pending commit: `DashboardView.swift`, `PlannedMealView.swift`, `SESSION_HANDOFF_OPTION_C.md`, deleted `PredictionView.swift`, created `SESSION_HANDOFF_HISTORICAL_MODE.md`.
- Completed: Step D.1 (delete orphan), D.2 (PlannedMealView copy rewrite).
- Cancelled: Step D.3 as originally scoped (MealBuilderView copy-only rewrite). Superseded by this plan.
- Next action in this session (if compute permits): begin Step G.1 — write `SimilarMealMatcher.swift`.
