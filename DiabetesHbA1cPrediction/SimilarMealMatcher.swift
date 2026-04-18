//  SimilarMealMatcher.swift  –  DiabetesHbA1cPrediction
//
//  Finds past meals that are behaviourally similar to a planned meal,
//  scored by carbohydrate and glycaemic-load proximity. Used by the
//  What-If flow to surface historical glucose patterns instead of
//  forward projections.
//
//  Design decision 16 Apr 2026: no mealType filter — a planned feast
//  may match any past meal with a similar carb/GL profile, regardless
//  of tag. Revisit if this produces noisy aggregates.
//

import Foundation
import CoreData

/// A past meal that was matched against a planned meal, with its
/// similarity score.
struct SimilarMealMatch {
    let meal: MealEntity
    /// 0.0 = dissimilar, 1.0 = near-identical carb + GL profile.
    let similarityScore: Double
    /// Convenience snapshot of the matched meal's nutritional profile,
    /// computed at match-time so downstream consumers don't need to
    /// re-walk the Core Data relationships.
    let totalCarbs: Double
    let glycaemicLoad: Double
}

enum SimilarMealMatcher {

    // MARK: - Tunables

    /// Carbohydrate tolerance (grams) used as the window around the
    /// planned meal's carbs. Past meals whose carbs fall within
    /// plannedCarbs ± `carbToleranceGrams` are eligible for matching.
    static let carbToleranceGrams: Double = 15.0

    /// Glycaemic-load tolerance (fraction of planned GL).
    /// Past meals whose GL falls within ±`glTolerancePct` of the
    /// planned GL are eligible.
    static let glTolerancePct: Double = 0.20

    /// Default lookback window in days. 90 days mirrors the HbA1c
    /// red-cell-pool span.
    static let defaultLookbackDays: Int = 90

    // MARK: - Public API

    /// Returns past meals similar to the planned meal, sorted by
    /// `similarityScore` descending. Empty array if no matches.
    ///
    /// - Parameters:
    ///   - plannedCarbs: total carbohydrate grams for the planned meal.
    ///   - plannedGL: total glycaemic load for the planned meal.
    ///   - excludingMealID: optional id of a meal to exclude (typically
    ///     the planned meal itself if it has already been persisted).
    ///   - withinDays: lookback window (defaults to 90).
    ///   - context: Core Data context to query.
    static func findSimilar(
        plannedCarbs: Double,
        plannedGL: Double,
        excludingMealID: UUID? = nil,
        withinDays: Int = defaultLookbackDays,
        context: NSManagedObjectContext
    ) -> [SimilarMealMatch] {

        // Guard against degenerate input.
        guard plannedCarbs > 0 else { return [] }

        // 1. Pull all recent meals that are not planned-future and not
        //    the meal currently under construction. We filter in Swift
        //    rather than the predicate because carb/GL are computed
        //    from related entities, not raw MealEntity columns.
        let cutoff = Calendar.current.date(byAdding: .day, value: -withinDays, to: Date()) ?? Date()
        let request: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@ AND (mealType != %@ OR mealType == nil)",
            cutoff as NSDate,
            Date() as NSDate,
            "plannedMeal"
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]

        let candidates: [MealEntity]
        do {
            candidates = try context.fetch(request)
        } catch {
            #if DEBUG
            print("SimilarMealMatcher fetch failed: \(error)")
            #endif
            return []
        }

        // 2. Score each candidate.
        var matches: [SimilarMealMatch] = []
        let carbLow = plannedCarbs - carbToleranceGrams
        let carbHigh = plannedCarbs + carbToleranceGrams
        let glLow = plannedGL * (1.0 - glTolerancePct)
        let glHigh = plannedGL * (1.0 + glTolerancePct)

        for meal in candidates {
            if let excludeID = excludingMealID, meal.id == excludeID { continue }

            let carbs = Self.totalCarbs(for: meal)
            guard carbs > 0 else { continue }

            // Hard filter: carbs must be in the ± tolerance window.
            guard carbs >= carbLow && carbs <= carbHigh else { continue }

            let gl = Self.totalGlycaemicLoad(for: meal)
            // GL is a softer signal — we score it but don't hard-filter
            // when plannedGL is 0 or the meal lacks GI data.
            let glInRange: Bool = {
                guard plannedGL > 0, gl > 0 else { return true }
                return gl >= glLow && gl <= glHigh
            }()

            // Carb proximity: 1.0 at exact match, 0.0 at the edge of tolerance.
            let carbCloseness = max(0.0, 1.0 - abs(carbs - plannedCarbs) / carbToleranceGrams)

            // GL proximity: 1.0 at exact match, 0.0 at the edge of ± glTolerancePct.
            // If either side has zero GL data, treat as neutral (0.5).
            let glCloseness: Double = {
                guard plannedGL > 0, gl > 0 else { return 0.5 }
                let diffPct = abs(gl - plannedGL) / plannedGL
                return max(0.0, 1.0 - diffPct / glTolerancePct)
            }()

            // Weighted score: carbs dominate (0.7), GL is a tie-breaker (0.3).
            // We drop the category-profile component from the original
            // spec — it added complexity for marginal gain and can be
            // layered in later.
            let score = 0.7 * carbCloseness + 0.3 * glCloseness

            // Require the carb filter plus at least a soft GL fit.
            guard glInRange else { continue }

            matches.append(SimilarMealMatch(
                meal: meal,
                similarityScore: score,
                totalCarbs: carbs,
                glycaemicLoad: gl
            ))
        }

        // 3. Sort by score descending.
        return matches.sorted { $0.similarityScore > $1.similarityScore }
    }

    // MARK: - Per-meal nutrition helpers
    //
    // These mirror the summation logic already used in MealBuilderView
    // (foodItems preferred, macronutrients as fallback). Exposed
    // `internal` so HistoricalPatternSummary can reuse them.

    /// Total carbohydrate grams for a persisted meal. Prefers
    /// `foodItems` rows; falls back to the `macronutrients` set when
    /// no per-food-item data exists (legacy meal rows).
    static func totalCarbs(for meal: MealEntity) -> Double {
        if let items = meal.foodItems as? Set<MealFoodItemEntity>, !items.isEmpty {
            return items.reduce(0.0) { $0 + $1.carbsPerServing * $1.quantity }
        }
        if let macros = meal.macronutrients as? Set<MacronutrientEntity> {
            return macros
                .filter { $0.type == "carbohydrates" || $0.type == "carbs" }
                .reduce(0.0) { $0 + $1.amount }
        }
        return 0
    }

    /// Total glycaemic load for a persisted meal, computed as
    /// Σ (carbs_i × GI_i) / 100 over food items. Returns 0 when no
    /// food-item GI data is available (legacy meals tracked only by
    /// macros can't have a GL computed).
    static func totalGlycaemicLoad(for meal: MealEntity) -> Double {
        guard let items = meal.foodItems as? Set<MealFoodItemEntity>, !items.isEmpty else {
            return 0
        }
        return items.reduce(0.0) { partial, item in
            let gi = Double(item.glycemicIndex)
            let itemCarbs = item.carbsPerServing * item.quantity
            return partial + (itemCarbs * gi) / 100.0
        }
    }
}
