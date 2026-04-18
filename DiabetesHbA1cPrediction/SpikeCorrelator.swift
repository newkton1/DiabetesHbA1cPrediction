//
//  SpikeCorrelator.swift
//  DiabetesHbA1cPrediction
//
//  Matches high glucose readings to high-GI meals eaten 90–120 minutes
//  before the reading. Used by the glucose readings list to show meal
//  context alongside readings that likely reflect a post-prandial spike.
//
//  Phase K.1 of the glucose list enhancement.
//

import Foundation
import CoreData

// MARK: - Correlation Result

/// A matched pair: a glucose reading and the high-GI meal that likely caused
/// the spike.
struct SpikeCorrelation {
    let readingID: NSManagedObjectID
    let mealName: String
    let mealTimestamp: Date
    let maxGI: Int            // highest GI food item in the meal
    let topFoodName: String   // name of the highest-GI food item
    let mealCalories: Double
}

// MARK: - Correlator

/// Stateless utility that scans glucose readings and meals to find
/// post-prandial spike correlations.
enum SpikeCorrelator {

    // MARK: - Tunables

    /// Glucose threshold in mg/dL above which a reading is considered a spike.
    static let spikeThresholdMgDl: Double = 170.0

    /// Same threshold in mmol/L (170 mg/dL ÷ 18.0182 ≈ 9.4 mmol/L).
    static let spikeThresholdMmolL: Double = 9.4

    /// Minimum glycaemic index for a food item to be considered "high GI".
    static let highGIThreshold: Int = 40

    /// Earliest meal offset before the glucose reading (seconds).
    /// 120 minutes = 7200 seconds.
    static let windowStartSec: TimeInterval = 120 * 60

    /// Latest meal offset before the glucose reading (seconds).
    /// 60 minutes = 3600 seconds.
    static let windowEndSec: TimeInterval = 60 * 60

    // MARK: - Main Entry Point

    /// Build a lookup dictionary keyed by glucose reading object ID.
    ///
    /// - Parameters:
    ///   - readings: All glucose readings (any sort order).
    ///   - meals: All meals (any sort order).
    ///   - isMgDl: True if the locale uses mg/dL, false for mmol/L.
    /// - Returns: Dictionary mapping reading objectID → `SpikeCorrelation`
    ///   for every reading that qualifies (high glucose + matching high-GI meal).
    static func correlate(
        readings: [GlucoseReadingEntity],
        meals: [MealEntity],
        isMgDl: Bool
    ) -> [NSManagedObjectID: SpikeCorrelation] {

        let threshold = isMgDl ? spikeThresholdMgDl : spikeThresholdMmolL

        // Pre-filter to high glucose readings only.
        let highReadings = readings.filter { reading in
            guard reading.timestamp != nil else { return false }

            // Determine the display value — if unit is HbA1c, skip it
            let unit = reading.unit ?? ""
            if unit == "NGSP %" || unit == "mmol/mol" { return false }

            return reading.value >= threshold
        }

        guard !highReadings.isEmpty else { return [:] }

        // Pre-compute meal info: only meals that have ≥1 food item with GI ≥ threshold.
        struct MealInfo {
            let meal: MealEntity
            let timestamp: Date
            let maxGI: Int
            let topFoodName: String
        }

        let qualifiedMeals: [MealInfo] = meals.compactMap { meal in
            guard let ts = meal.timestamp else { return nil }

            // Core Data returns NSSet — unwrap carefully
            let foodItems: [MealFoodItemEntity]
            if let nsSet = meal.foodItems as? Set<MealFoodItemEntity> {
                foodItems = Array(nsSet)
            } else if let nsSet = meal.foodItems {
                foodItems = nsSet.compactMap { $0 as? MealFoodItemEntity }
            } else {
                return nil
            }

            guard !foodItems.isEmpty else { return nil }

            // Find the food item with the highest GI
            var maxGI: Int = 0
            var topName: String = ""
            for item in foodItems {
                let gi = Int(item.glycemicIndex)
                if gi > maxGI {
                    maxGI = gi
                    topName = item.foodName ?? "Unknown food"
                }
            }

            guard maxGI >= highGIThreshold else { return nil }

            return MealInfo(meal: meal, timestamp: ts, maxGI: maxGI, topFoodName: topName)
        }

        guard !qualifiedMeals.isEmpty else { return [:] }

        // Sort meals by timestamp for efficient searching.
        let sortedMeals = qualifiedMeals.sorted { $0.timestamp < $1.timestamp }

        // For each high reading, find a matching meal in the 90–120 min window.
        var result: [NSManagedObjectID: SpikeCorrelation] = [:]

        for reading in highReadings {
            guard let readingTime = reading.timestamp else { continue }

            // Meal must have been eaten between 120 and 90 minutes before the reading.
            let windowEarliest = readingTime.addingTimeInterval(-windowStartSec)  // -120 min
            let windowLatest   = readingTime.addingTimeInterval(-windowEndSec)    // -90 min

            // Find the best matching meal (closest to the centre of the window).
            let windowCentre = readingTime.addingTimeInterval(-(windowStartSec + windowEndSec) / 2)
            var bestMeal: MealInfo?
            var bestGap: TimeInterval = .greatestFiniteMagnitude

            for mealInfo in sortedMeals {
                // Skip meals too old to be in any reading's window.
                if mealInfo.timestamp < windowEarliest.addingTimeInterval(-3600) { continue }
                // Stop if meals are too recent to match any remaining reading.
                if mealInfo.timestamp > windowLatest.addingTimeInterval(3600) { break }

                if mealInfo.timestamp >= windowEarliest && mealInfo.timestamp <= windowLatest {
                    let gap = abs(mealInfo.timestamp.timeIntervalSince(windowCentre))
                    if gap < bestGap {
                        bestGap = gap
                        bestMeal = mealInfo
                    }
                }
            }

            if let matched = bestMeal {
                result[reading.objectID] = SpikeCorrelation(
                    readingID: reading.objectID,
                    mealName: matched.meal.name ?? "Unnamed meal",
                    mealTimestamp: matched.timestamp,
                    maxGI: matched.maxGI,
                    topFoodName: matched.topFoodName,
                    mealCalories: matched.meal.calories
                )
            }
        }

        return result
    }
}
