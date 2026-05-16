//  GlucoseExcursionAnalyser.swift  –  DiabetesHbA1cPrediction
//
//  Analyses the glucose excursion around a past meal: baseline, peak,
//  peak delta, and return-to-baseline behaviour. Returns nil when
//  there are too few glucose readings around the meal to characterise
//  an excursion (typical for fingerstick-only users with sparse logs).
//
//  All values are normalised to mg/dL internally. Readings stored as
//  mmol/L (non-US/JP locales) are converted (×18) at the fetch step.
//

import Foundation
import CoreData

/// The glucose response pattern around a single meal.
struct GlucoseExcursion {
    /// Median of glucose readings in the 30 minutes before the meal.
    let preMealBaseline: Double
    /// Peak glucose value within 2 h after the meal.
    let peakValue: Double
    /// peakValue − preMealBaseline. Positive for typical responses.
    let peakDelta: Double
    /// Minutes from meal timestamp to the peak reading.
    let peakMinutesAfterMeal: Int
    /// True if glucose returned to within `returnThresholdMgDl` of
    /// baseline before the 3 h cutoff.
    let returnedToBaseline: Bool
    /// Minutes from meal timestamp to the first post-peak reading
    /// within `returnThresholdMgDl` of baseline. Nil if never returned.
    let timeToReturnMinutes: Int?
    /// Total CGM/fingerstick readings used in the analysis (pre + post).
    let readingCount: Int
}

enum GlucoseExcursionAnalyser {

    // MARK: - Tunables

    /// Minimum number of readings required in the post-meal window
    /// [meal, meal + 2h] to produce an excursion. Below this, the
    /// excursion is considered uncharacterisable.
    static let minPostMealReadings: Int = 3

    /// How close (mg/dL) glucose must come to baseline to count as
    /// "returned to baseline."
    static let returnThresholdMgDl: Double = 10.0

    /// Pre-meal window (minutes) used to compute baseline.
    static let preMealWindowMinutes: Int = 30

    /// Post-meal window (minutes) used to find the peak.
    static let postMealWindowMinutes: Int = 120

    /// Extended window (minutes) used to detect return-to-baseline.
    static let returnWindowMinutes: Int = 180

    // MARK: - Public API

    /// Analyse the glucose excursion around `meal`. Returns nil when
    /// there's insufficient post-meal data to draw a pattern.
    static func analyse(
        meal: MealEntity,
        context: NSManagedObjectContext
    ) -> GlucoseExcursion? {

        guard let mealTime = meal.timestamp else { return nil }

        // Build a wide fetch window covering pre-meal baseline through
        // return-to-baseline detection.
        let windowStart = mealTime.addingTimeInterval(TimeInterval(-preMealWindowMinutes * 60))
        let windowEnd = mealTime.addingTimeInterval(TimeInterval(returnWindowMinutes * 60))

        let request: NSFetchRequest<GlucoseReadingEntity> = GlucoseReadingEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@ AND (unit == %@ OR unit == %@)",
            windowStart as NSDate, windowEnd as NSDate, "mg/dL", "mmol/L"
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: true)]

        let rawReadings: [GlucoseReadingEntity]
        do {
            rawReadings = try context.fetch(request)
        } catch {
            #if DEBUG
            print("GlucoseExcursionAnalyser fetch failed: \(error)")
            #endif
            return nil
        }

        // Normalise all readings to mg/dL and pair with timestamps.
        struct NormalisedReading {
            let timestamp: Date
            let valueMgDl: Double
        }
        let readings: [NormalisedReading] = rawReadings.compactMap { reading in
            guard let ts = reading.timestamp else { return nil }
            let valueMgDl = reading.unit == "mmol/L" ? reading.value * 18.0 : reading.value
            return NormalisedReading(timestamp: ts, valueMgDl: valueMgDl)
        }

        // Partition readings into pre / post / return buckets.
        var preMeal: [NormalisedReading] = []
        var postMeal: [NormalisedReading] = []      // [meal, meal+2h]
        var returnWindow: [NormalisedReading] = []  // [meal+2h, meal+3h]

        let postMealEnd = mealTime.addingTimeInterval(TimeInterval(postMealWindowMinutes * 60))

        for reading in readings {
            if reading.timestamp < mealTime {
                preMeal.append(reading)
            } else if reading.timestamp <= postMealEnd {
                postMeal.append(reading)
            } else {
                returnWindow.append(reading)
            }
        }

        // Require enough post-meal coverage to characterise an excursion.
        guard postMeal.count >= minPostMealReadings else { return nil }

        // Baseline: median of pre-meal readings. If none, use the first
        // post-meal reading as a proxy (this will bias peakDelta
        // slightly downwards, which is acceptable and conservative).
        let baseline: Double = {
            if !preMeal.isEmpty {
                return Self.median(preMeal.map { $0.valueMgDl })
            }
            return postMeal.first?.valueMgDl ?? 0
        }()

        // Peak: max post-meal reading.
        guard let peakReading = postMeal.max(by: { $0.valueMgDl < $1.valueMgDl }) else {
            return nil
        }
        let peakDelta = peakReading.valueMgDl - baseline
        let peakMinutes = Int(peakReading.timestamp.timeIntervalSince(mealTime) / 60.0)

        // Return-to-baseline: look after the peak time in both post and
        // returnWindow buckets.
        let postPeak = (postMeal + returnWindow)
            .filter { $0.timestamp > peakReading.timestamp }

        var returned = false
        var returnMinutes: Int? = nil
        for reading in postPeak {
            if reading.valueMgDl <= baseline + returnThresholdMgDl {
                returned = true
                returnMinutes = Int(reading.timestamp.timeIntervalSince(mealTime) / 60.0)
                break
            }
        }

        return GlucoseExcursion(
            preMealBaseline: baseline,
            peakValue: peakReading.valueMgDl,
            peakDelta: peakDelta,
            peakMinutesAfterMeal: peakMinutes,
            returnedToBaseline: returned,
            timeToReturnMinutes: returnMinutes,
            readingCount: preMeal.count + postMeal.count + returnWindow.count
        )
    }

    // MARK: - Helpers

    /// Median of a non-empty array of doubles. Returns 0 for empty input.
    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let n = sorted.count
        if n.isMultiple(of: 2) {
            return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        }
        return sorted[n / 2]
    }
}
