# Session Handoff — 15 Apr 2026 (evening)

End of a long day. Code is in a stable state. Build succeeded. Demo data seed button works. Dashboard shows the new dashed-line HbA1c chart with lab results from seeded PreviewData.

## Decisions made this evening (not yet implemented)

### Dashboard cleanup
- **Remove** the "Estimated HbA1c" card entirely. It is redundant with the rightmost diamond on the chart and its headline framing undercuts the App Review strategy.
- **Replace** with a small inline label above/below the chart along the lines of "Most recent: 6.6 % · 02 Apr 2026". Screen-reader accessible, visually quiet.
- **Remove** the meal and exercise event strip from the Dashboard. The Dashboard becomes chart-only: quiet, outcome-focused, no per-event causal implication.

### Move meal + exercise overlay to the Glucose view
Rationale: HbA1c integrates over ~90 days so per-event dots are uninformative and strategically risky. Glucose responds within hours so per-event dots are both genuinely informative and physiologically honest. Every CGM app on the market (Dexcom, Libre, Levels, Veri, Nutrisense) does this — it is a reviewer-familiar, established UI pattern that does not trigger medical-device classification.

### Preferred visualisation in the Glucose view
- Meals: **upward vertical bars**, height proportional to carb grams (carb histogram).
- Exercise: **downward vertical bars**, colour-coded by intensity (low/moderate/vigorous).
- Both rendered under the glucose curve on a shared time axis.

### Patterns view
May end up having very little to do after this refactor. Reconsider whether it still needs to exist, or whether it becomes a longer-horizon weekly/monthly aggregate view. Decision deferred.

### Meals tab and Exercise tab
Unchanged. They remain the canonical user-facing logs.

## Bug noted but not yet fixed
`PreviewData.swift` seeds `HbA1cPredictionEntity.predictedValue` as NGSP % numbers (6.8, 7.0, 7.1, 6.9) but the card code (and presumably the prediction engine) expects canonical IFCC mmol/mol. That is why the card displays 2.8 % — `6.8 / 10.929 + 2.15 ≈ 2.8`. If we remove the card entirely this becomes moot, but if any other view reads `predictedValue` the seed values should be changed to 51, 53, 54, 52.

## Implementation order for tomorrow (suggested)

1. **Remove HbA1cCardView from Dashboard** (and its call sites at DashboardView.swift:97 and 164). Replace with an inline "Most recent" label in the chart header.
2. **Remove EventStripView from Dashboard.** Delete the struct, delete the `mealEvents` and `exerciseEvents` computed properties, drop the `meals` and `exerciseSessions` parameters from `GlucoseTrendChartView`.
3. **Add meal + exercise histograms to the Glucose view.** Upward carb-weighted bars for meals, downward intensity-coloured bars for exercise, on the glucose time axis. Start with simple bars; polish later.
4. **Remove or simplify Patterns view** once step 3 proves the overlay works.

## Still on the deferred pile from earlier
- "Run New Prediction" button on Dashboard (still present, needs removal or relabel)
- PredictionView.swift (959 lines, 114 prediction references) — major refactor
- Project rename DiabetesHbA1cPrediction → DiabetesFeast
- Comprehensive Swift string audit against vocabulary list
- App Store description rewrite
- Welcome page copy
- Privacy policy review

## Files currently in the right state
- `DashboardView.swift` — chart rewrite complete. Next step: remove card + event strip.
- `PreviewData.swift` — 12 weeks of seed data works. Prediction value unit bug noted above.
- `DataExportView.swift` — DEBUG Seed button added and working.
- `SEED_DEMO_DATA_PLAN.md` — today's checklist, all boxes ticked.
- This file — evening handoff of design decisions.

## Resume phrase for tomorrow
"Read SESSION_HANDOFF_2026-04-15.md and pick up at implementation step 1."
