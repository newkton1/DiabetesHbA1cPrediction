//  GlucoseExcursionAnalyser.swift  –  DiabetesHbA1cPrediction
//
//  Analyses the glucose excursion around a past meal: baseline, peak,
//  peak delta, and return-to-baseline behaviour. Returns nil when
//  there are too few glucose readings around the meal to characterise
//  an excursion (typical for fingerstick-only users with sparse logs).
//
//  All values are in mg/dL — this matches how GlucoseReadingEntity
//  stores its canonical `value` field elsewhere in the app. If that
//  convention ever changes, guard a unit conversion at the fetch step.
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
            format: "timestamp >= %@ AND timestamp <= %@",
            windowStart as NSDate, windowEnd as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: true)]

        let readings: [GlucoseReadingEntity]
        do {
            readings = try context.fetch(request)
        } catch {
            #if DEBUG
            print("GlucoseExcursionAnalyser fetch failed: \(error)")
            #endif
            return nil
        }

        // Partition readings into pre / post / return buckets.
        var preMeal: [GlucoseReadingEntity] = []
        var postMeal: [GlucoseReadingEntity] = []      // [meal, meal+2h]
        var returnWindow: [GlucoseReadingEntity] = []  // [meal+2h, meal+3h]

        let postMealEnd = mealTime.addingTimeInterval(TimeInterval(postMealWindowMinutes * 60))

        for reading in readings {
            guard let ts = reading.timestamp else { continue }
            if ts < mealTime {
                preMeal.append(reading)
            } else if ts <= postMealEnd {
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
                return Self.median(preMeal.map { $0.value })
            }
            return postMeal.first?.value ?? 0
        }()

        // Peak: max post-meal reading.
        guard let peakReading = postMeal.max(by: { $0.value < $1.value }),
              let peakTime = peakReading.timestamp else {
            return nil
        }
        let peakDelta = peakReading.value - baseline
        let peakMinutes = Int(peakTime.timeIntervalSince(mealTime) / 60.0)

        // Return-to-baseline: look after the peak time in both post and
        // returnWindow buckets.
        let postPeak: [GlucoseReadingEntity] = (postMeal + returnWindow)
            .filter { ($0.timestamp ?? .distantPast) > peakTime }

        var returned = false
        var returnMinutes: Int? = nil
        for reading in postPeak {
            if reading.value <= baseline + returnThresholdMgDl {
                returned = true
                if let ts = reading.timestamp {
                    returnMinutes = Int(ts.timeIntervalSince(mealTime) / 60.0)
                }
                break
            }
        }

        return GlucoseExcursion(
            preMealBaseline: baseline,
            peakValue: peakReading.value,
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
