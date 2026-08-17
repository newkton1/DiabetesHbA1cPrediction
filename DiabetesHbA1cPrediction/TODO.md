# Diabetes Feast — Pending Tasks

## App Store Submission
- [x] **Rewrite App Store description** — draft complete in `App Store Description - DRAFT.md`. Uses historical/wellness framing, no predictive language. Needs final review before submission.
- [ ] **Review and finalise App Store description** — Robert to review draft, iterate on wording, prepare matching screenshots.
- [ ] **App Store screenshots** — need to match the historical framing used in the description.

## Completed — 27 Apr 2026
- [x] **Welcome screen GMI disclaimer** — added "The estimated GMI is not a substitute for a laboratory HbA1c test" to the wellness disclaimer on WelcomeSheetView.
- [x] **Glucose chart y-axis label** — fixed positioning so it no longer impinges on the chart on iPhone SE 2020. Replaced fixed offset with adaptive leading padding.
- [x] **Weight trend arrows reworked** — replaced weekly-bucket logic with chronological nearest-neighbour comparison. Works with sparse data (fortnightly readings). Added ±1 kg dead zone showing stable icon (=) for negligible changes. Replaced scale icon with "Weight trend" text label.
- [x] **Hotspot popover layout (SE 2020)** — removed chevron navigation (< 1/4 >) that caused truncation on narrow screens. Glucose value and close button now have full room. VoiceOver next/previous actions still work on the chart.
- [x] **Glucose chart x-axis date bunching** — 7-day view now labels every 2 days instead of every day, preventing overlap on SE 2020.
- [x] **Data Management visible in TestFlight** — removed `#if DEBUG` guard from export/import. Renamed section from "Developer Tools" to "Data Management". Seed demo data button remains DEBUG-only.

## Completed — 16 May 2026
- [x] **Meal save confirmation toast** — 2-second auto-dismissing popup after saving a regular meal (non-feast). Shows meal name and total carbs (e.g. "Lunch saved — 45 g carbs"). Toolbar buttons hidden during the toast. Follows same overlay pattern as glycemic warnings.

## Completed — 14 May 2026
- [x] **14-Day Activity Snapshot card** — new Dashboard card showing meal-exercise pairing ratio over the 14-day GMI window. Purely informational (no encouragement language). Only appears when ≥5 meals and ≥3 exercise sessions logged in the period. Shows count of meals with a post-meal exercise session (0–90 min window), total exercise minutes, and session count.
- [x] **Exercise Log labels** — "Last 7 Days" → "Last 7 Days Summary", added "Full Exercise Log" heading between summary card and list (portrait and landscape).
- [x] **Glucose chart chevron fix** — removed 30-day hard limit, now navigates back to earliest glucose reading.

## Testing — Follow Up ~10 May 2026
- [ ] **Weight trend arrows on real device** — confirmed working with HealthKit data (up/down/stable arrows displaying). Continue collecting Bluetooth scale data over next 2 weeks to verify consistency.
- [ ] **VoiceOver testing on iPhone 16e** — test accessibility changes from previous session.
- [ ] **Beta tester feedback** — testers now have JSON import/export via Data Management. Collect feedback on data import workflow.

## Future Features
- [ ] Food database with search/autocomplete meal entry
- [ ] Data anonymisation for beta testers (closer to beta release)
- [ ] Camera-based meal recognition via Apple Vision (future version)
- [ ] Write fingerstick data to Apple HealthKit (post-approval, point release)

## v3 Candidates (low priority — revisit only if requested)
- [ ] **Manual in-app language switch (EN/JA)** — scoped in
  `FUTURE_APP_LANGUAGE_SWITCH.md`. Skeleton (profile object + menu row) is
  small, but full coverage also needs migrating 6 `Locale.current`-based
  branches and deciding how to handle `NSLocalizedString`-driven dynamic
  strings, which don't follow SwiftUI's locale override. Likely audience
  is very small (effectively Robert); not worth building unless Japanese
  users specifically ask for it.

## v1.1-hotfix Sync
- [x] **Ported UI polish from v1.1-hotfix** (17 Aug 2026, commit `ebaca7b`) — exercise distance display in ExerciseLogView rows, DashboardView Exercise (week) card merge + landscape 3x2 Actions grid, GlucoseLogView "Lab Test Date" red label + "Enter test date" field, UserProfileView Tobacco Use relabels, ExerciseOffsetType -ing labels, and the Nagasaki Sara Udon JP-text data cleanup.

## Housekeeping
- [ ] Regenerate GitHub token (was exposed) and remove from git remote URL
