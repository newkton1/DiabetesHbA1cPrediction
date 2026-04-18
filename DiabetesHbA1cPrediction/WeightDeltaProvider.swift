//
//  WeightDeltaProvider.swift
//  DiabetesHbA1cPrediction
//
//  Pure-Swift utility that computes a weight delta for a given date by
//  comparing the nearest weight reading (within ±1 week) to the nearest
//  weight reading around a reference date 3 months earlier.
//
//  Consumed by GlucoseCurveProcessor to annotate hotspots with weight
//  context. No UI code here.
//
//  Created for Phase I of the glucose chart enhancement.
//

import Foundation

// MARK: - Output Type

/// Weight change context shown in the glucose popover.
struct WeightDelta {
    let currentWeight: Double      // kg — the weight near the glucose reading
    let currentDate: Date          // when that weight was recorded
    let referenceWeight: Double    // kg — the weight ~3 months earlier
    let referenceDate: Date        // when the reference weight was recorded
    let deltaKg: Double            // currentWeight - referenceWeight (positive = gain)

    /// True when the delta is large enough to be clinically noteworthy (≥1 kg).
    var isSignificant: Bool { abs(deltaKg) >= 1.0 }
}

// MARK: - Provider

/// Stateless provider that finds a 3-month weight delta for a given date
/// from a pre-fetched array of weekly weight samples.
struct WeightDeltaProvider {

    // MARK: - Tunables

    /// Maximum gap (seconds) between a glucose reading and the nearest weight
    /// sample for the weight to be considered "near" that reading.
    /// 7 days = 604 800 seconds.
    static let nearbyToleranceSec: TimeInterval = 7 * 24 * 3600

    /// How far back (seconds) the reference weight should be from the current
    /// weight. 90 days ≈ 3 months.
    static let referenceOffsetSec: TimeInterval = 90 * 24 * 3600

    // MARK: - Main Entry Point

    /// Compute the weight delta for a specific date.
    ///
    /// - Parameters:
    ///   - date: The timestamp of the glucose reading (or hotspot).
    ///   - samples: Weekly weight samples sorted oldest → newest,
    ///     as returned by `HealthKitManager.fetchWeeklyWeights()`.
    /// - Returns: A `WeightDelta` if both a current and reference weight
    ///   can be found within tolerance, otherwise nil.
    static func delta(
        at date: Date,
        from samples: [WeightSampleRecord]
    ) -> WeightDelta? {
        guard !samples.isEmpty else { return nil }

        // 1. Find the sample nearest to `date` within ±1 week.
        guard let current = nearestSample(to: date, in: samples, tolerance: nearbyToleranceSec) else {
            return nil
        }

        // 2. Find the sample nearest to `date - 3 months` within ±1 week.
        let referenceTarget = date.addingTimeInterval(-referenceOffsetSec)
        guard let reference = nearestSample(to: referenceTarget, in: samples, tolerance: nearbyToleranceSec) else {
            return nil
        }

        // 3. Guard against comparing the same sample to itself
        //    (can happen if there's only one weight reading in the window).
        guard abs(current.date.timeIntervalSince(reference.date)) > nearbyToleranceSec / 2 else {
            return nil
        }

        return WeightDelta(
            currentWeight: current.kilograms,
            currentDate: current.date,
            referenceWeight: reference.kilograms,
            referenceDate: reference.date,
            deltaKg: current.kilograms - reference.kilograms
        )
    }

    // MARK: - Helpers

    /// Finds the sample closest to `target` within `tolerance` seconds.
    /// Exploits the fact that samples are sorted by date for an efficient scan.
    private static func nearestSample(
        to target: Date,
        in samples: [WeightSampleRecord],
        tolerance: TimeInterval
    ) -> WeightSampleRecord? {
        var best: WeightSampleRecord? = nil
        var bestGap: TimeInterval = .greatestFiniteMagnitude

        for sample in samples {
            let gap = abs(sample.date.timeIntervalSince(target))
            if gap < bestGap {
                bestGap = gap
                best = sample
            }
            // Once we've passed the target and are moving further away, stop.
            if sample.date > target && gap > bestGap { break }
        }

        return bestGap <= tolerance ? best : nil
    }
}
