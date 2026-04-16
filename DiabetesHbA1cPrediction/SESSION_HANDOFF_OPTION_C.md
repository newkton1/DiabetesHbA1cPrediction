# Option C Implementation — Handoff and Checklist

Strategy shift captured on 16 Apr 2026 after reading Bergenstal 2018 (Diabetes Care, GMI paper).

## Strategy (unchanged from yesterday's decisions, plus this)

**Two-zone architecture:**

- **Zone 1 — Dashboard.** Plays defence. Shows a GMI card (Bergenstal formula, mean CGM glucose only) that matches what Dexcom and Libre Link already display. Uses FDA-endorsed "GMI" terminology. No behavioural modelling on this screen. Reviewer sees nothing to flag.
- **Zone 2 — What-If / PredictionView.** Earns the app's differentiation. Keeps the existing behavioural engine intact (glucose + carbs + exercise + BMI + age + comorbidities), but reframes the output as *scenario exploration*, not prediction. Language shift: "projected GMI under these patterns," "scenario outcome," "what-if result." Never "predicted HbA1c" or "your A1c will be."

**Fallback:** if Apple still rejects after this, retire the behavioural engine entirely (option B).

## Key facts driving the strategy

- Bergenstal 2018 GMI formula: `GMI (%) = 3.31 + 0.02392 × mean_mg/dL`, or `GMI (mmol/mol) = 12.71 + 4.70587 × mean_mmol/L`. **Inputs: mean glucose only.** No behavioural inputs.
- Existing engine (`HbA1cPredictionEngine.swift`) uses Nathan 2008 (`(avgGlucose + 46.7) / 28.7`) as its base, then applies 8+ behavioural/demographic adjustments. **Not** GMI. Differentiates the app.
- FDA required eA1c → GMI rename specifically to stop framing it as an A1c estimate. GMI must be described as a glucose-management metric, not an A1c prediction.

## Discrete implementation steps

Each step leaves the app in a buildable state. If interrupted, pick up the next unchecked box.

- [x] **Step A** — Write this handoff file.
- [x] **Step B** — Build GMI computation + `GMICardView` component; insert into Dashboard (portrait and landscape) in place of the spot where `HbA1cCardView` used to sit. Bergenstal formula. Show the value, the unit, the mean-glucose input it was computed from, the reading count, and a short caption. Gracefully degrade when too few readings. **DONE — verified visually on iPhone 17 Pro Max simulator, showing 6.4 %, 43 readings, 131 mg/dL mean.**
- [ ] **Step B.1** — Fixes driven by first visual review (16 Apr 2026 evening):
    - **Remove the dashed line between lab diamonds on the Dashboard chart.** HbA1c integrates 90-day red-cell pool; lab points more than ~60 days apart share no overlapping physiology and a connecting line implies a trajectory that biology does not support. Show diamonds only. If we later want to connect adjacent same-quarter points, add a threshold-based segmented line, but start by removing the line entirely.
    - **Strengthen visual differentiation between GMI card and lab HbA1c chart.** Two HbA1c-like numbers in the same units on one screen confuses users. Make the chart's y-axis label say "Lab HbA1c (NGSP %)" rather than just "NGSP %". Consider adding a small glucose-drop icon next to the GMI value and a lab/flask icon beside the chart title. Re-word the chart title to something like "Your Lab HbA1c Records" if space allows.
    - **Update empty-state / subtitle copy so users understand the distinction at a glance.** The "Most recent" inline subtitle should make clear it refers to the most recent *lab* result (not GMI).
- [ ] **Step C** — Audit `PredictionView.swift`: read full file, list every user-facing string that needs to change, list every place that shows engine output.
- [ ] **Step D** — Execute the copy rewrite in `PredictionView.swift`. Replace "prediction," "predicted HbA1c," "estimate" with scenario language. Rename any engine-output labels. Update confidence/risk copy.
- [ ] **Step E** — Remove the "Run New Prediction" button from the Dashboard (both portrait and landscape). The engine now belongs on the What-If screen; running it from the Dashboard is inconsistent with the two-zone architecture.
- [ ] **Step F** — Final verification: search codebase for any remaining "Estimated HbA1c" / "predict" leaks that should have been caught, confirm clean build list, update this handoff and SESSION_HANDOFF_2026-04-15.md to reflect final state.

## Design decisions recorded this session (16 Apr 2026 evening)

### GMI from finger-stick measurements
Bergenstal 2018 was validated against CGM data covering all times of day. Finger-stick readings are typically sparse and biased toward fasting / pre-meal / bedtime, so finger-stick mean is systematically lower than true 24-hour mean. The FDA rename from eA1C to GMI was specifically because CGM finally produced data complete enough to justify the formula — using it on finger-stick alone reintroduces the problem GMI was created to solve.

**Policy:** include finger-stick readings in the mean but surface a confidence/quality indicator to the user. When CGM data dominates, label simply as "GMI." When finger-stick dominates, label as "GMI (estimate) — based mostly on finger-stick readings" or similar. Implementation deferred; not blocking Option C completion.

### Two curves on the Dashboard chart (rejected)
Considered plotting lab HbA1c diamonds and a continuous rolling-GMI trace on the same chart. Rejected — the dense GMI trace would visually dominate and the sparse lab diamonds would get lost. Cleaner separation: keep the Dashboard chart strictly about lab records, keep GMI strictly on the card. A future "GMI over time" view could live on the Glucose screen where a continuous time axis is appropriate.

### Lab-line connecting lab diamonds (to be removed)
Biologically, HbA1c integrates a ~90-day red-cell pool. Two lab results >60 days apart share little physiological overlap; joining them with a line implies a trajectory the biology does not support. Monthly labs overlap ~66% and are arguably connectable; quarterly labs are not. Most users take labs 2–4×/year. Decision: **remove the line entirely** (Step B.1). Optional future enhancement: segmented connector that only links adjacent labs within 60 days.

### Glucose view — meal & exercise histogram layout (future Step)
Design shape confirmed for when we move meal/exercise visualisation off the Dashboard and onto the Glucose view:
- Exercise as upward bars above the glucose trace. Bar height encodes distance (for cardio) or intensity (for non-cardio). Colour-coded by intensity band (low / moderate / vigorous).
- Meals as downward bars below the glucose trace. Bar height encodes carbohydrate grams.
- Shared horizontal time axis; glucose trace runs through the middle.

## Deferred (still on the original pile)

- PredictionView.swift refactor beyond copy (959 lines, 114 "prediction" references) — structural refactor is bigger than copy changes, deferred.
- Project rename DiabetesHbA1cPrediction → DiabetesFeast
- Comprehensive Swift string audit against vocabulary list
- App Store description rewrite
- Welcome page copy
- Privacy policy review
- Meal + exercise histograms on the Glucose view (shape decided — see above)
- GMI confidence/source-quality indicator for mixed CGM + finger-stick data
- Remove meal/exercise event strip from the Dashboard (belongs with the histogram migration above)
- Fix to `PreviewData` prediction-entity unit bug (mooted if engine output moves off Dashboard)

## Resume phrases

- "Continue Option C, pick up at step B.1."
- "Continue Option C, pick up at step C."
- ...etc.
