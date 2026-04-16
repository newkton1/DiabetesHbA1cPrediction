# Seed Demo Data — Resumable Plan

Goal: enhance `PreviewData.swift` so the simulator can be populated with 12 weeks of realistic demo data at the tap of a DEBUG-only button, enough to visually review the new dashed-line HbA1c chart and event strip.

## Status checklist

- [x] Read baseline PreviewData.swift and DataExportView.swift
- [ ] Step 1 — Extend PreviewData glucose seed to 12 weeks of CGM/finger-stick readings
- [ ] Step 2 — Add lab HbA1c seed (~10 results as GlucoseReadingEntity, source "Hospital Lab Test")
- [ ] Step 3 — Extend meals to ~30 across 12 weeks
- [ ] Step 4 — Extend exercise to ~20 across 12 weeks
- [ ] Step 5 — Add "Seed demo data" button to DataExportView
- [ ] Step 6 — User builds and verifies

## Data shape decisions

- Window: 84 days (12 weeks) ending today
- Lab HbA1c: 10 results every ~9 days, NGSP % values trending 7.4 → 6.6, alternating units "NGSP %" and "mmol/mol", source "Hospital Lab Test"
- CGM/meter: dense last 14 days (3/day ≈ 42), sparse prior 70 days (1/day ≈ 70), total ~112, sources "TestCGM" / "TestMeter"
- Meals: 30 spread across window, realistic macros
- Exercise: 20 spread across window, mix of walking/cycling/strength

## Files touched
- `/sessions/nifty-inspiring-fermi/mnt/DiabetesHbA1cPrediction/PreviewData.swift` — expand `populate(context:)`
- `/sessions/nifty-inspiring-fermi/mnt/DiabetesHbA1cPrediction/DataExportView.swift` — add button section (still DEBUG-only)

## Resume instructions
If this session ends partway: read this file, check which boxes are ticked, open PreviewData.swift and look for the `// ── 3. Glucose Readings` block to see how far the rewrite got. DataExportView button lives right after the existing "Export" section.
