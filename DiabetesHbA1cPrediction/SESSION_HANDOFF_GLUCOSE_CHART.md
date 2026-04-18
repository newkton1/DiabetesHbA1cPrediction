# Glucose Chart Redesign — Phased Handoff

## Vision

Replace the current 30-day horizontally-scrollable glucose chart in `GlucoseLogView.swift`
with an interactive 7-day (expandable to 14-day) chart where **the curve itself is the
interaction surface**. Users tap points on the glucose curve to reveal correlated meal and
exercise data — no separate event strip needed.

Two density modes share one interaction model:

- **Fingerstick (sparse):** Every data point is tappable. Tap reveals meal data from the
  hour before and exercise data from the hour after the reading.
- **CGM (dense):** Only spike peaks and recovery slopes are tappable hotspots. Flat-in-range
  data is thinned to ~1 point/hour for visual clarity; spike regions keep full resolution.

---

## Design Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Default window | 7 days | T2D patients care about recent trends, not 30-day history |
| Extended window | 14 days via "Show more" pull/button | Keeps option without clutter |
| Spike detection | Relative (≥50 mg/dL rise from 30-min moving average) | Different patients run at different baselines |
| Detail display | Small overlay/popover anchored to tapped point | Keeps context of where on the curve the user is looking |
| CGM thinning | 1 reading/hour for flat-in-range segments; full resolution for spikes | Reduces visual noise while preserving clinically meaningful shape |
| Stored data | Keep full 30+ day record in Core Data | Chart window ≠ data retention |
| Spike threshold | ≥50 mg/dL relative rise | Per Robert's clinical experience (baseline ~120, spike to ~170+ is concerning) |

---

## Existing Code (current state)

**File:** `GlucoseLogView.swift`
- `chartSection` computed property (line ~201–424): 30-day horizontally scrollable chart
- `readingsList` (line ~427+): List of readings with swipe-to-delete
- Uses `LineMark` + `PointMark` with colour-coded data points
- Reference lines for clinical thresholds (70/100/126/180 mg/dL or mmol/L equivalents)
- Pinned Y-axis on right side
- `convertToLocaleUnit()` handles mg/dL ↔ mmol/L display conversion
- `glucoseColor()` returns colour based on glucose value and unit
- HealthKit sync button + logic

**Entities:**
- `GlucoseReadingEntity`: timestamp, value (mg/dL canonical), unit, trend, source
- `MealEntity`: timestamp (when eaten), foodItems relationship
- `ExerciseSessionEntity`: startDate, endDate, duration, type, distance

**Analytics already built:**
- `GlucoseExcursionAnalyser.swift`: analyses pre-meal baseline → peak → return-to-baseline
  (tunables: preMealWindowMinutes=30, postMealWindowMinutes=120, returnWindowMinutes=180)
- `SimilarMealMatcher.swift`: finds meals by carb/GL similarity
- `HistoricalPatternSummary.swift`: aggregates excursion data across similar meals

---

## Phase Breakdown

### Phase H.1 — Spike Detector + Data Thinning Engine (pure Swift, no UI)

**Goal:** Create `GlucoseCurveProcessor.swift` — a utility that takes a time-sorted array
of glucose readings and produces two outputs:

1. **Thinned curve points** — for CGM data, reduce flat-in-range segments to ~1 point/hour
   while keeping full resolution around spikes. For fingerstick data, keep all points.
2. **Hotspot annotations** — an array of `CurveHotspot` structs identifying spike peaks and
   recovery inflection points, each carrying references to temporally correlated meals and
   exercise sessions.

**Key types:**

```swift
/// A point on the processed glucose curve, potentially thinned from dense CGM data.
struct CurvePoint {
    let reading: GlucoseReadingEntity
    let displayValue: Double          // converted to user's locale unit
    let isHotspot: Bool               // true = tappable spike peak or recovery point
    let hotspotType: HotspotType?     // .spikePeak or .recoverySlope
}

enum HotspotType {
    case spikePeak      // local maximum ≥50 mg/dL above preceding 30-min average
    case recoverySlope  // first point that drops back within 20 mg/dL of pre-spike baseline
}

/// Contextual data surfaced when the user taps a hotspot on the curve.
struct CurveHotspot {
    let point: CurvePoint
    let nearbyMeals: [MealEntity]       // meals within 60 min before this point
    let nearbyExercise: [ExerciseSessionEntity]  // exercise within 60 min after this point
}
```

**Tunables:**
- `spikeThresholdMgDl: Double = 50.0` — minimum relative rise to qualify as a spike
- `movingAverageWindowMinutes: Int = 30` — window for computing local baseline
- `thinningIntervalMinutes: Int = 60` — target interval for flat-in-range thinning
- `mealLookbackMinutes: Int = 60` — how far before a point to search for meals
- `exerciseLookforwardMinutes: Int = 60` — how far after a point to search for exercise
- `recoveryThresholdMgDl: Double = 20.0` — how close to baseline before marking recovery

**Density detection:**
- If readings in the window average >4/hour → CGM mode (apply thinning + spike detection)
- If ≤4/hour → fingerstick mode (all points are hotspots, no thinning)

**Files to create:** `GlucoseCurveProcessor.swift`
**Files to modify:** None
**Build gate:** ⌘B compiles clean

---

### Phase H.2 — Chart View Rewrite (SwiftUI Charts + tap interaction)

**Goal:** Replace `chartSection` in `GlucoseLogView.swift` with a new 7-day interactive
chart. The chart consumes `GlucoseCurveProcessor` output and supports tap-to-reveal on
hotspot points.

**Key changes:**
- Window: 7 days default, "Show more" extends to 14
- Remove horizontal ScrollView (7 days fits on screen without scrolling)
- `LineMark` for the glucose curve (full colour-coded line)
- `PointMark` for hotspot indicators only (larger symbol, glow/pulse effect)
- `.chartOverlay` with `GeometryProxy` to detect taps and map to nearest hotspot
- `@State` for selected hotspot → drives popover display
- Keep existing reference lines (70/100/126/180 mg/dL thresholds)
- Keep pinned Y-axis pattern
- Keep HealthKit sync button

**Popover content (anchored to tapped point):**
- Glucose value + timestamp at the tapped point
- If spike peak: "↑ +{delta} from baseline" with colour coding
- Meal card (if found): meal name, total carbs, glycaemic load, time relative to reading
- Exercise card (if found): type, duration, time relative to reading
- "No meal logged" / "No exercise logged" when nothing correlates
- Dismiss on tap outside or tap another hotspot

**Files to modify:** `GlucoseLogView.swift` (replace `chartSection`)
**Files to create:** None (popover is inline)
**Build gate:** ⌘B compiles clean, chart renders in simulator with test data

---

### Phase H.3 — Polish, Edge Cases, and CGM Thinning Verification

**Goal:** Handle edge cases, verify with both sparse and dense data, polish the popover
styling, and ensure landscape mode works.

**Tasks:**
- Test with fingerstick-only data (3–5 readings/day) — verify all points are tappable
- Test with CGM-density data (every 5 min) — verify thinning produces clean curve,
  spikes are correctly detected, flat regions are simplified
- Verify "Show more" toggle between 7 and 14 days
- Landscape layout adjustments (chart height, popover positioning)
- Accessibility: VoiceOver labels for hotspots ("Glucose spike: 185 mg/dL, 52 above
  baseline. Tap to see meal and exercise details.")
- Performance: ensure chart renders smoothly with 14 days of CGM data (~4000 readings
  thinned to ~400)

**Files to modify:** `GlucoseLogView.swift`, `GlucoseCurveProcessor.swift`
**Build gate:** ⌘B clean, manual testing in simulator

---

## Future Considerations

- **Apple Watch optical glucose sensor:** When released, data density will be CGM-like
  for all users. The spike-detection interaction model built here will be the correct UX.
- **Glucose curve as the central view:** Robert's long-term vision is that logging screens
  (meal, exercise) are purely for data entry, and the glucose curve is the read-only
  analytical surface where everything correlates.
- **Meal/exercise markers on the curve itself:** Phase H.2's hotspot system could be
  extended to show small inline icons (fork.knife / figure.walk) at the actual timestamps
  of logged meals and exercise, not just at spike peaks.

---

## Known Risks

1. **SwiftUI Charts tap detection:** `.chartOverlay` with `GeometryProxy` to map screen
   coordinates to data coordinates is well-documented but can be finicky with dense data.
   May need to use a nearest-neighbour search with a tap tolerance radius.
2. **Spike detection false positives:** A ≥50 mg/dL threshold may be too sensitive for
   patients with very volatile glucose (T1D with CGM). Consider making it configurable
   in User settings if needed later.
3. **Popover positioning at chart edges:** When a hotspot is near the left or right edge,
   the popover may clip. Need to adjust anchor point dynamically.
4. **HealthKit data gaps:** HealthKit glucose data may have irregular intervals. The
   thinning algorithm should handle gaps gracefully (don't interpolate across >2h gaps).

---

## Xcode Housekeeping

After Phase H.1: Add `GlucoseCurveProcessor.swift` to the Xcode target.
No other new files expected — H.2 and H.3 modify existing `GlucoseLogView.swift`.

---

*Written 18 Apr 2026. Continues from SESSION_HANDOFF_HISTORICAL_MODE.md.*
