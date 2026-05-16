# Diabetes Feast — On-Device AI Feature Plans

*Created 12 May 2026*
*No cloud processing. All AI runs on the Neural Engine via Core ML / Apple Foundation Models.*

---

## Current Architecture Summary

The app today is built around these key components:

- **FoodDatabase** — a singleton backed by a bundled JSON file of 1,576 food items across 34 categories. Each `FoodItem` has name, category, serving size/unit, calories, carbs, protein, fat, fiber, and glycaemic index. Search is basic `String.contains` matching.

- **MealBuilder / MealBuilderView** — manual meal composition. The user searches the food database, selects items, adjusts servings. Meals are persisted as `MealEntity` with related `MealFoodItemEntity` records in Core Data.

- **SimilarMealMatcher** — finds past meals within a tolerance window of the planned meal's carbs (±15g) and glycaemic load (±20%). Returns scored matches sorted by similarity. Lookback window is 90 days.

- **GlucoseExcursionAnalyser** — characterises the glucose response around a past meal: pre-meal baseline, peak value, peak delta, time to return to baseline. Requires minimum 3 post-meal CGM readings.

- **HistoricalPatternSummary** — orchestrator that ties SimilarMealMatcher + GlucoseExcursionAnalyser together. Outputs descriptive aggregates (median peak delta, time to return) with a confidence level. Explicitly designed as "what happened" not "what will happen."

- **SpikeCorrelator** — matches high glucose readings (>170 mg/dL) to high-GI meals eaten 60–120 minutes prior.

- **DawnEffectNotificationManager** — detects elevated 4–8 AM glucose patterns and sends informational notifications.

- **FoodSearchView / MultiSelectFoodSearchView** — SwiftUI search interfaces for browsing and selecting foods. Category-grouped when not searching, filtered list when searching.

---

## Feature 1: Camera-Based Food Recognition

### What it does
User photographs their plate. An on-device Core ML image classifier identifies the foods. The app maps recognised foods to existing `FoodDatabase` items and pre-populates the meal builder.

### Why it matters
Manual meal logging is the highest-friction part of the app. Every meal requires multiple searches through 1,576 items. Camera recognition could reduce a 2-minute process to a 10-second confirmation.

### Technical approach

**Framework:** Vision + Core ML (available from iOS 14+, optimised on A16+ Neural Engine)

**Model options:**
1. **Apple's built-in food classification** — available via `VNClassifyImageRequest` with the `.food` taxonomy. Zero model size overhead, but limited to ~100 broad food categories. May be too coarse for GI/GL-sensitive matching (e.g., distinguishes "rice" but not "white rice" vs "brown rice").
2. **Custom Core ML model** — train or license a food-specific classifier with 200–500 categories mapped to the app's 34 food categories. Model size typically 50–200 MB. Can be trained with Create ML or converted from TensorFlow/PyTorch via `coremltools`.
3. **Hybrid** — use Apple's built-in classification for the broad category, then present a filtered short-list from `FoodDatabase` for the user to confirm the specific item. This avoids needing a highly granular model while still dramatically reducing search friction.

**Recommended approach: Option 3 (Hybrid)**

This is the lowest-risk path. The flow would be:

```
Camera → VNClassifyImageRequest → top 3 classifications
    → map each classification to FoodDatabase categories
    → present filtered food list (e.g., "Rice" → show all rice items)
    → user taps to confirm specific item (e.g., "Brown rice, cooked")
    → item added to MealBuilder
```

**Integration points in current code:**

- `MealBuilderView.swift` — add a camera button alongside the existing "Add Food" button. New state: `@State private var showingCamera = false`
- `FoodSearchView.swift` — add an optional `prefilterCategory: String?` parameter. When set, the view opens pre-filtered to that category rather than showing all 34.
- `FoodDatabase.swift` — add a mapping dictionary: `classificationToCategory: [String: [String]]` that maps Vision framework classification labels to food database categories. E.g., `"rice": ["Rice & Grains"]`, `"salad": ["Vegetables", "Salads"]`.
- New file: `FoodRecognitionService.swift` — wraps the Vision framework call, returns top-N classifications with confidence scores.

**Privacy:** The camera frame is processed by Core ML on the Neural Engine. No image data leaves the device. No image is stored unless the user explicitly chooses to attach a photo to the meal log.

**Minimum hardware:** iPhone 12 (A14 Bionic) for acceptable performance. iPhone 16 (A18) for real-time preview classification.

### App Review considerations
- Food recognition is not a medical feature. It's a convenience input method.
- The user always confirms the food selection — the AI never auto-logs a meal.
- Frame clearly as "helps you find foods faster" not "identifies what you're eating."

---

## Feature 2: Natural Language Meal Entry

### What it does
User types or dictates a free-text description like "two slices of wholemeal toast with peanut butter and a black coffee" and the app parses it into structured food items matched against `FoodDatabase`.

### Why it matters
Even faster than camera for known meals. Especially useful for repeat meals the user eats regularly. Also handles foods that are hard to photograph (e.g., ingredients mixed into a dish).

### Technical approach

**Framework:** Apple Foundation Models (on-device LLM, available from iOS 18.4+ on iPhone 16+)

**Flow:**
```
User text input → on-device Foundation Model
    → structured output: [{food: "toast, wholemeal", quantity: 2, unit: "slice"},
                          {food: "peanut butter", quantity: 1, unit: "tbsp"},
                          {food: "coffee, black", quantity: 1, unit: "cup"}]
    → fuzzy match each item against FoodDatabase.allFoods
    → present matches for user confirmation
    → add confirmed items to MealBuilder
```

**Key implementation details:**

- Use the Foundation Models framework `LanguageModel` API with a structured output schema. The prompt instructs the model to extract food items, quantities, and units from the user's text.
- Fuzzy matching against `FoodDatabase` can use string distance (Levenshtein) or the Natural Language framework's `NLEmbedding` for semantic similarity. E.g., "wholemeal toast" should match "Bread, whole wheat, toasted."
- The on-device model handles synonyms, regional terms, and casual language naturally. "Chips" → "French fries" or "Potato crisps" depending on locale context.

**Integration points:**

- `MealBuilderView.swift` — add a text/microphone button. New state for the text input sheet.
- `FoodDatabase.swift` — add a `fuzzySearch(query:)` method that uses `NLEmbedding.wordEmbedding(for: .english)` to find semantically similar food names when exact string matching fails.
- New file: `NLPMealParser.swift` — handles the Foundation Model prompt, structured output parsing, and FoodDatabase matching.

**Minimum hardware:** iPhone 16 (A18 Pro) — required for on-device Foundation Models.

**Fallback for older devices:** Offer the text input UI but use keyword extraction + existing `FoodDatabase.search()` instead of the Foundation Model. Less accurate but still useful.

### App Review considerations
- Text parsing is a convenience feature, not medical.
- User always confirms parsed results before logging.
- No data sent to any server — the Foundation Model runs entirely on-device.

---

## Feature 3: Historical Pattern Summarisation

### What it does
The app generates natural language summaries of the user's own historical glucose, meal, and exercise data. E.g., "Over the last 30 days, your glucose readings were typically 15–25 mg/dL lower on days when you walked more than 4 km before breakfast."

### Why it matters
The data is already there — `SimilarMealMatcher`, `GlucoseExcursionAnalyser`, `SpikeCorrelator`, and `DawnEffectNotificationManager` all detect patterns. But they present findings as charts and numbers. An on-device LLM could articulate these patterns in plain language, making the data more accessible to users who aren't comfortable reading charts.

### Technical approach

**Framework:** Apple Foundation Models (on-device LLM, iOS 18.4+, iPhone 16+)

**Architecture:** The app does NOT feed raw glucose data to the LLM. Instead:

```
Existing analysers (SimilarMealMatcher, SpikeCorrelator, etc.)
    → produce structured summaries (already implemented)
    → feed summary structs to Foundation Model as context
    → Foundation Model generates natural language description
    → display in a "Your Patterns" card on the Dashboard
```

This is important for two reasons:
1. **Performance** — pre-aggregated data is tiny compared to raw glucose streams.
2. **Accuracy** — the maths is done by tested, deterministic code. The LLM only translates numbers into words.

**Example prompt context fed to the model:**
```
The user has logged 47 meals in the last 30 days.
Their median post-meal glucose rise for meals with GL > 40 was 62 mg/dL.
Their median post-meal glucose rise for meals with GL < 20 was 28 mg/dL.
On 12 days they walked more than 4 km. Their average fasting glucose on walk days was 108 mg/dL vs 127 mg/dL on non-walk days.
The dawn effect pattern was detected on 8 of the last 14 days.

Write a brief, friendly summary of these patterns for the user.
Do not give medical advice. Do not predict future outcomes.
Use phrases like "your data shows" and "in the past 30 days."
```

**Integration points:**

- `DashboardView.swift` — add a "Your Patterns" card below the existing GMI card.
- `HistoricalPatternSummary.swift` — already produces the structured data. Add a `naturalLanguageSummary()` method that calls the Foundation Model.
- `SpikeCorrelator.swift` — expose aggregate statistics (spike count, most common trigger food) for the summary context.
- New file: `PatternNarrator.swift` — manages the Foundation Model prompt construction and response formatting.

**Minimum hardware:** iPhone 16 (A18 Pro).

**Fallback for older devices:** Show the existing chart-based pattern views. No NLP summary.

### App Review considerations — CRITICAL
This is the most sensitive feature for App Review. Key safeguards:

1. **Never use the word "predict" or "recommendation" anywhere** — in code comments, UI strings, or App Review notes.
2. **Frame as retrospective observation only** — "Your data showed..." not "Your glucose will..."
3. **The LLM prompt must include strict guardrails** — "Do not give medical advice. Do not suggest medication changes. Do not predict future glucose levels. Only describe what has already been recorded."
4. **Add a visible disclaimer** below every generated summary: "This summary describes patterns in your recorded data. It is not medical advice. Consult your healthcare provider for treatment decisions."
5. **The LLM generates text, not numbers** — all numerical analysis comes from the existing deterministic analysers. The LLM cannot hallucinate a glucose value because it never sees raw readings.

---

## Feature 4: Smart Food Search with Semantic Matching

### What it does
Replaces the current `String.contains` search in `FoodDatabase` with semantic search that handles synonyms, regional food names, abbreviations, and typos.

### Why it matters
Current search for "chips" returns nothing if the database only has "French fries" or "Potato crisps." Users searching for "pb&j" won't find "Peanut butter" and "Jam." Regional terms like "aubergine" vs "eggplant" or "courgette" vs "zucchini" are missed entirely.

### Technical approach

**Framework:** Natural Language framework (`NLEmbedding`, available from iOS 13+)

**Implementation:**

```swift
// In FoodDatabase.swift — new method
func semanticSearch(query: String, topK: Int = 20) -> [FoodItem] {
    guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
        return search(query: query) // fallback to string matching
    }

    // Score each food name by embedding distance to the query
    let scored = allFoods.compactMap { food -> (FoodItem, Double)? in
        let distance = embedding.distance(between: query.lowercased(),
                                           and: food.name.lowercased())
        guard distance < 1.5 else { return nil } // threshold
        return (food, distance)
    }

    return scored
        .sorted { $0.1 < $1.1 }
        .prefix(topK)
        .map { $0.0 }
}
```

**Enhancements:**
- Build a synonym dictionary for common aliases: `["pb": "peanut butter", "oj": "orange juice", "chips": "french fries", "crisps": "potato chips"]`
- Add locale-aware mappings: UK English ↔ US English food terms.
- Use `NLLanguageRecognizer` to detect input language for multilingual food databases in future.

**Integration points:**

- `FoodDatabase.swift` — add `semanticSearch()` method alongside existing `search()`.
- `FoodSearchView.swift` — swap `search(query:)` for `semanticSearch(query:)` when available.
- `MultiSelectFoodSearchView.swift` — same change.

**Minimum hardware:** Any device running iOS 13+. No Neural Engine required — `NLEmbedding` is lightweight.

### App Review considerations
None — this is a pure UI/UX improvement to search quality. No health implications.

---

## Feature 5: Anomaly Detection on Personal Baseline

### What it does
A lightweight on-device model learns the user's personal glucose patterns over time and flags readings that are unusual compared to their own baseline. Not "your glucose is high" (which the app already does with fixed thresholds) but "this reading is unusual for you at this time of day and activity level."

### Why it matters
Fixed thresholds (e.g., >170 mg/dL = spike) don't account for individual variation. A user whose typical fasting glucose is 95 mg/dL seeing 140 mg/dL is significant, while a user who typically runs at 130 mg/dL seeing 140 mg/dL is unremarkable.

### Technical approach

**Framework:** Create ML (`MLLinearRegressor` or `MLBoostedTreeRegressor`, on-device training available from iOS 15+)

**Architecture:**
- Train a simple regression model on-device using the user's own historical data.
- Features: hour of day, day of week, minutes since last meal, last meal GL, minutes since last exercise, exercise intensity, recent 3-reading glucose trend.
- Target: glucose reading value.
- Anomaly = actual reading deviates from model's expected value by more than 1.5× the model's historical RMSE.

**Key design decisions:**
- Model retrains weekly (or when the user opens the app after 7+ days of new data).
- Minimum 30 days of data before the model activates — avoid noisy signals from sparse data.
- This is the same approach the `DawnEffectNotificationManager` already uses conceptually, but generalised to all times of day.

**Integration points:**

- New file: `PersonalBaselineModel.swift` — manages on-device training, inference, and anomaly scoring.
- `GlucoseLogView.swift` — add an optional "unusual" indicator on readings that the model flags.
- `DashboardView.swift` — surface anomaly count in a summary card.

**Minimum hardware:** iPhone 12 (A14). Create ML on-device training is lightweight for tabular data.

### App Review considerations
- Frame as "compares this reading to your own historical pattern" — never "detects a medical condition."
- The indicator is informational, like the existing colour-coded glucose ranges.
- No alert, no notification, no urgency — just a subtle visual marker.

---

## Implementation Priority

| Priority | Feature | Effort | Impact | Min Device |
|----------|---------|--------|--------|------------|
| 1 | Smart Food Search (Feature 4) | Low | Medium | iPhone 8+ |
| 2 | Camera Food Recognition (Feature 1) | Medium | High | iPhone 12+ |
| 3 | NLP Meal Entry (Feature 2) | Medium | High | iPhone 16 |
| 4 | Pattern Summarisation (Feature 3) | Medium | Medium | iPhone 16 |
| 5 | Anomaly Detection (Feature 5) | High | Medium | iPhone 12+ |

Feature 4 (Smart Search) is recommended first because it's low effort, works on all devices, and improves the existing search experience immediately. Feature 1 (Camera) is the highest-impact single feature for reducing meal logging friction.

---

## App Review Strategy for AI Features

All AI features should be presented to App Review with these principles:

1. **On-device only** — emphasise that no health data is transmitted to any server, no cloud AI is used.
2. **User confirmation required** — AI never auto-logs data. The user always reviews and confirms.
3. **Retrospective, not predictive** — AI describes what happened, never what will happen.
4. **Not a medical device** — AI features are convenience and data organisation tools.
5. **Existing precedent** — reference apps like mySugr (Roche) and Sugarmate that use similar on-device analysis and have been approved.

---

## Privacy Statement Impact

The current privacy statement ("No data is transmitted to any server. No analytics. No accounts. Your health data never leaves your iPhone.") remains fully accurate with all proposed features. On-device AI strengthens this position — it's a competitive advantage over apps that require cloud processing.
