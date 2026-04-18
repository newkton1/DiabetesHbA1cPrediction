//  HistoricalPatternSummary.swift  –  DiabetesHbA1cPrediction
//
//  Orchestrator that ties SimilarMealMatcher + GlucoseExcursionAnalyser
//  together to answer a single question: "When this user has eaten
//  meals similar to the one they're planning now, how did their
//  glucose actually respond?"
//
//  Output is descriptive (what happened) not predictive (what will
//  happen). Use it to replace engine-based projections in the What-If
//  flow. When confidence is `.insufficient`, the UI should show an
//  empty state rather than any numeric aggregate.
//

import Foundation
import CoreData

/// Aggregated glucose pattern across past meals similar to a planned one.
struct HistoricalPatternSummary {

    /// How many past meals matched on carbs / GL.
    let matchCount: Int
    /// Of those matches, how many had enough glucose data around them
    /// to yield a usable excursion.
    let analysedCount: Int

    /// Median peak-delta (mg/dL) across analysed matches. Nil when
    /// `analysedCount < minAnalysedForAggregates`.
    let medianPeakDelta: Double?
    /// Low..high range of peak-delta across analysed matches.
    let peakDeltaRange: ClosedRange<Double>?
    /// Median minutes until glucose returned to within
    /// `GlucoseExcursionAnalyser.returnThresholdMgDl` of baseline.
    /// Nil when most matches never returned.
    let medianTimeToReturn: Int?

    /// Earliest and latest lab HbA1c (IFCC mmol/mol) taken during the
    /// span of the matched meals. Both nil when fewer than two lab
    /// results exist in that span.
    let hba1cAtFirstMatch: Double?
    let hba1cAtLastMatch: Double?

    /// Overall data-quality signal. Drives whether the UI renders
    /// aggregates or an empty state.
    let confidence: ConfidenceLevel

    enum ConfidenceLevel {
        case insufficient   // analysedCount < 3
        case limited        // 3..<6
        case reasonable     // 6..<12
        case strong         // ≥ 12
    }

    /// Minimum analysed matches required to surface numeric aggregates
    /// to the user. Below this, the UI shows the empty state.
    static let minAnalysedForAggregates: Int = 3

    // MARK: - Factory

    /// Build a summary for a planned meal defined by its carb / GL
    /// totals. All the Core Data work happens here; the returned
    /// struct is pure value.
    static func build(
        plannedCarbs: Double,
        plannedGL: Double,
        excludingMealID: UUID? = nil,
        context: NSManagedObjectContext
    ) -> HistoricalPatternSummary {

        // 1. Find similar past meals.
        let matches = SimilarMealMatcher.findSimilar(
            plannedCarbs: plannedCarbs,
            plannedGL: plannedGL,
            excludingMealID: excludingMealID,
            context: context
        )

        guard !matches.isEmpty else {
            return empty(matchCount: 0)
        }

        // 2. Analyse each match.
        var excursions: [GlucoseExcursion] = []
        for match in matches {
            if let excursion = GlucoseExcursionAnalyser.analyse(
                meal: match.meal,
                context: context
            ) {
                excursions.append(excursion)
            }
        }

        let analysedCount = excursions.count
        let confidence = confidenceLevel(forAnalysed: analysedCount)

        // 3. If we can't show aggregates, return a skeleton summary
        //    that still reports the raw match/analysed counts so the
        //    UI can offer the right empty-state copy.
        guard analysedCount >= minAnalysedForAggregates else {
            return HistoricalPatternSummary(
                matchCount: matches.count,
                analysedCount: analysedCount,
                medianPeakDelta: nil,
                peakDeltaRange: nil,
                medianTimeToReturn: nil,
                hba1cAtFirstMatch: nil,
                hba1cAtLastMatch: nil,
                confidence: confidence
            )
        }

        // 4. Aggregate peak deltas.
        let peakDeltas = excursions.map { $0.peakDelta }
        let medianPeak = median(peakDeltas)
        let minPeak = peakDeltas.min() ?? medianPeak
        let maxPeak = peakDeltas.max() ?? medianPeak

        // 5. Aggregate time-to-return across matches that did return.
        let returnTimes = excursions.compactMap { $0.timeToReturnMinutes }
        let medianReturn: Int? = {
            // Only report the median if a majority actually returned.
            guard returnTimes.count >= excursions.count / 2 + 1 else { return nil }
            return Int(median(returnTimes.map(Double.init)))
        }()

        // 6. Lab HbA1c at first / last match (if lab data is available).
        let sortedMatches = matches
            .compactMap { $0.meal.timestamp.map { (date: $0, match: $0) } }
            .sorted { $0.date < $1.date }
        let (hba1cFirst, hba1cLast) = fetchHbA1cBrackets(
            from: sortedMatches.first?.date,
            to: sortedMatches.last?.date,
            context: context
        )

        return HistoricalPatternSummary(
            matchCount: matches.count,
            analysedCount: analysedCount,
            medianPeakDelta: medianPeak,
            peakDeltaRange: minPeak...maxPeak,
            medianTimeToReturn: medianReturn,
            hba1cAtFirstMatch: hba1cFirst,
            hba1cAtLastMatch: hba1cLast,
            confidence: confidence
        )
    }

    // MARK: - Helpers

    private static func empty(matchCount: Int) -> HistoricalPatternSummary {
        HistoricalPatternSummary(
            matchCount: matchCount,
            analysedCount: 0,
            medianPeakDelta: nil,
            peakDeltaRange: nil,
            medianTimeToReturn: nil,
            hba1cAtFirstMatch: nil,
            hba1cAtLastMatch: nil,
            confidence: .insufficient
        )
    }

    private static func confidenceLevel(forAnalysed n: Int) -> ConfidenceLevel {
        switch n {
        case ..<3: return .insufficient
        case 3..<6: return .limited
        case 6..<12: return .reasonable
        default: return .strong
        }
    }

    /// Fetches earliest and latest lab HbA1c values (IFCC mmol/mol)
    /// in the given date range. Lab results are persisted in
    /// `GlucoseReadingEntity` with `source == "Hospital Lab Test"` and
    /// unit of "NGSP %" or "mmol/mol", matching the convention used by
    /// `DashboardView.GlucoseTrendChartView.labPoints`.
    private static func fetchHbA1cBrackets(
        from start: Date?,
        to end: Date?,
        context: NSManagedObjectContext
    ) -> (first: Double?, last: Double?) {
        guard let start = start, let end = end, start < end else {
            return (nil, nil)
        }

        let request: NSFetchRequest<GlucoseReadingEntity> = GlucoseReadingEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "source == %@", "Hospital Lab Test"),
            NSPredicate(format: "unit IN %@", ["NGSP %", "mmol/mol"]),
            NSPredicate(format: "timestamp >= %@", start as NSDate),
            NSPredicate(format: "timestamp <= %@", end as NSDate)
        ])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: true)]

        let results: [GlucoseReadingEntity]
        do {
            results = try context.fetch(request)
        } catch {
            #if DEBUG
            print("HistoricalPatternSummary lab fetch failed: \(error)")
            #endif
            return (nil, nil)
        }

        guard results.count >= 2 else { return (nil, nil) }

        let firstIFCC = toIFCC(value: results.first!.value, unit: results.first!.unit)
        let lastIFCC = toIFCC(value: results.last!.value, unit: results.last!.unit)
        return (firstIFCC, lastIFCC)
    }

    /// Convert a lab HbA1c reading to canonical IFCC mmol/mol.
    private static func toIFCC(value: Double, unit: String?) -> Double {
        switch unit {
        case "NGSP %": return ngspToIFCC(value)
        case "mmol/mol": return value
        default: return value   // unknown — treat as already IFCC
        }
    }

    /// Median of a double array. Returns 0 for empty input.
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
