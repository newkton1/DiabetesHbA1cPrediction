# Future Feature: Manual In-App Language Switch

**Status:** Scoped, not implemented. Deferred to v3 backlog (see `TODO.md`
→ Future Features). Likely audience is small (effectively Robert), so not
worth building unless Japanese users specifically request it.

## Problem
DF currently follows the iPhone's system locale for displayed language, with
no in-app override. A user whose iPhone region is Japan but who prefers
English (or vice versa) has no way to change DF's language without changing
the whole OS language/region, which affects every app.

## Proposed location
Same Section in `UserProfileView.swift` as the Weight/Height unit switches
(~line 265-325). Add an "App Language" row styled identically — a `Menu`
with a checkmark list, showing current selection + chevron — placed next to
"Weight Units" / "Height Units".

## Proposed implementation

1. **New model — `AppLanguageProfile.swift`**: singleton `ObservableObject`
   cloned from the existing `HeightWeightUnitProfile` pattern. Cases:
   `.system` (default, follows OS), `.en`, `.ja`. Persisted to
   `UserDefaults` (e.g. key `app_language_override`).

2. **Wire into `DiabetesHbA1cPredictionApp.swift`**: hold
   `@StateObject var languageProfile = AppLanguageProfile.shared` at the app
   root, apply `.environment(\.locale, languageProfile.resolvedLocale)` on
   `ContentView()`, and add `.id(languageProfile.selection)` on the same view
   to force a full subtree rebuild when the user switches (otherwise some
   already-rendered views/formatters won't pick up the change until
   navigating away and back).

## Caveats to verify during implementation

1. `.environment(\.locale, ...)` only re-resolves `Text`/`Label` built from
   `LocalizedStringKey` literals (how most of this app is written). It does
   **not** affect `NSLocalizedString(...)` or `String(localized:)` calls made
   outside a SwiftUI view body (e.g. inside `HealthKitManager`,
   `XLSXExporter`, Core Data validation messages). None found in a quick
   scan, but re-check before assuming full coverage.
2. Date/number formatting also follows `\.locale`, but any `DateFormatter`
   etc. manually instantiated with `Locale.current` baked in at init won't
   update until recreated — verify against the Dashboard/glucose chart code.
3. `ReferencesView` and the Privacy Policy page load **external web content**
   from GitHub Pages — an in-app switch has zero effect on those pages'
   language. Making them follow the in-app choice would need separate work
   (language-specific URLs, or injecting `Accept-Language` into the
   `WKWebView` request).
4. Only `en`/`ja` exist in `Localizable.xcstrings` today, so the picker is a
   two-option-plus-system toggle, consistent with the existing
   `HeightWeightUnitProfile` override pattern.
5. Cosmetic-only: Home Screen app name, Settings.app entry, Siri/Spotlight
   text, and system keyboard/share-sheet chrome stay in whatever the OS
   language is — this only affects text drawn by DF's own SwiftUI views.

## Deeper audit (2026-08-14) — confirms and raises the caveats above

Reviewed `HeightWeightUnitProfile.swift` (the pattern to clone),
`DiabetesHbA1cPredictionApp.swift` (no existing `.environment(\.locale,...)`
today — clean slate), and `ReferencesView.swift` / `PrivacyPolicyView.swift`
(confirmed: both load one hardcoded GitHub Pages URL each via `WKWebView`,
no language variant — caveat 3 above stands as described, would need a
`ja`/`en` URL pair or an `Accept-Language` header to fix separately).

Two findings below are **new and change the effort estimate** — they're
concrete gaps, not hypothetical ones to "re-check later."

### A. Six call sites branch on `Locale.current` directly, not on any
### environment value
`DashboardView.swift` (×2), `GlucoseLogView.swift`, `ExerciseLogView.swift`
(×2), and `MultiSelectFoodSearchView.swift` all contain:
```swift
let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
```
used to pick between cached JA/EN `DateFormatter`s, choose "、" vs ", "
separators, and reorder sync-message text. `Locale.current` reads the
**device's OS locale** — it is not affected by SwiftUI's
`.environment(\.locale, ...)` at all. Every one of these six sites would
need to be rewritten to consult `AppLanguageProfile` instead of
`Locale.current` for the switch to actually work on this logic.

(Separately, `Locale.current.region?.identifier` checks in
`HealthKitManager.swift`, `HeightWeightUnitProfile.swift`,
`HbA1cUserProfile.swift`, `CountryHbA1cMapping.swift`, and
`GlucoseLogView.swift` are **region**-based, not language-based — they
drive mg/dL vs mmol/L, NGSP vs IFCC, and lbs/kg defaults. These are
correctly out of scope for a language-only switch and should be left
alone.)

### B. `NSLocalizedString(...)` does not follow SwiftUI's `\.locale`
### environment value, ever — regardless of where it's called from
This session established `NSLocalizedString(_:comment:)` /
`String(format: NSLocalizedString(...), ...)` as the pattern for all
dynamic/parameterized strings (sync messages, "%lld g carbs", "%@ per
serving", etc.). It's now used across 11 files: `GlucoseLogView`,
`ExerciseLogView`, `DashboardView`, `SelectedFoodRow`,
`MultiSelectFoodSearchView`, `UserProfileView`, `MealLogView`,
`GettingStartedChecklistView`, `ColdStartEmptyStateView`. Correcting
caveat 1 above: it's not just calls made *outside* a view body that are
unaffected — `NSLocalizedString` always resolves via `Bundle.main`, using
the OS's preferred-language list, independent of SwiftUI's environment
system. So none of these ~11 files' dynamic strings would follow an
in-app override as currently written, wherever they're called from.

Fixing this means either:
- **Ship a partial switch** — plain `Text("...")` literals (the majority
  of the app's UI) follow the override; the ~11 files' dynamic strings
  keep following the OS language. Smaller, shippable, but inconsistent:
  a user who sets DF to Japanese on an English-OS phone would still see
  English sync messages and per-serving captions.
- **Full coverage** — add a bundle-swap helper (e.g.
  `AppLanguageProfile.shared.localizedString(_:comment:)` that loads
  `Bundle(path: Bundle.main.path(forResource: "ja"/"en", ofType: "lproj")!)`
  instead of defaulting to `Bundle.main`), then swap every existing
  `NSLocalizedString(...)` call site (~11 files) to route through it.
  Mechanical but touches meaningfully more code than the original
  "one profile + one environment injection" estimate implied.

### C. Confirmed clean, but for the "wrong" reason
No `NSLocalizedString`/`String(localized:)` usage found in
`HealthKitManager.swift`, `XLSXExporter.swift`,
`ClinicalSummaryExporter.swift`, or `DataImportEngine.swift` — not
because they already handle both languages, but because their strings
are hardcoded English with no localization at all. XLSX/clinical-summary
exports will stay in English regardless of OS or in-app language either
way; unrelated to this feature, just noting it's a pre-existing gap this
switch won't touch.

## Effort estimate (revised)
The new-object + environment-injection + menu-row skeleton is still
small. But making the switch visibly complete requires deciding between
the "partial" and "full coverage" options in B above, plus migrating the
six `Locale.current` call sites in A. Recommend deciding on the
partial-vs-full tradeoff before starting implementation — that decision
changes the size of the work by roughly the same margin as the initial
skeleton itself.
