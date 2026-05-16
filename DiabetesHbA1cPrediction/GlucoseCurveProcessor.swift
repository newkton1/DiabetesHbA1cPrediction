//
//  GlucoseCurveProcessor.swift
//  DiabetesHbA1cPrediction
//
//  Pure-Swift utility that processes raw glucose readings into a display-ready
//  curve for the interactive Glucose chart. Two responsibilities:
//
//  1. **Thinning** — for CGM-density data (>4 readings/hour), reduces flat-in-range
//     segments to ~1 point per hour while keeping full resolution around spikes.
//     Fingerstick-density data passes through unthinned.
//
//  2. **Hotspot detection** — identifies spike peaks (≥50 mg/dL relative rise above
//     the preceding 30-minute moving average) and recovery points (first point that
//     drops back within 20 mg/dL of the pre-spike baseline). Each hotspot carries
//     references to temporally correlated meals and exercise sessions.
//
//  Created for Phase H.1 of the glucose chart redesign. Consumed by Phase H.2
//  (the chart view itself). No UI code here.
//

import Foundation
import CoreData

// MARK: - Output Types

/// A single point on the processed glucose curve. May represent the original
/// reading verbatim (fingerstick mode) or a survivor of thinning (CGM mode).
struct CurvePoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let valueMgDl: Double          // canonical mg/dL (stored unit)
    let displayValue: Double       // converted to user's locale unit (mg/dL or mmol/L)
    let source: String             // "Manual Finger Stick", "Continuous Glucose Monitor", etc.
    let isHotspot: Bool
    let hotspotType: HotspotType?
    let segmentID: Int             // breaks the line at gaps >2h — points in the same
                                   // contiguous run share a segmentID

    /// Colour bucket for the glucose value — matches GlucoseLogView's existing
    /// colour logic but expressed as a simple enum for the chart layer to map.
    var severity: GlucoseSeverity {
        // Thresholds are in mg/dL (canonical)
        switch valueMgDl {
        case ..<70:  return .hypo
        case ..<100: return .normal
        case ..<126: return .elevated
        case ..<180: return .high
        default:     return .veryHigh
        }
    }
}

enum HotspotType {
    /// Local maximum ≥ spikeThresholdMgDl above the preceding moving average.
    case spikePeak
    /// First point that drops back within recoveryThresholdMgDl of the pre-spike baseline.
    case recoverySlope
    /// Reading above the absolute high threshold (170 mg/dL) that wasn't caught
    /// by the relative spike detector (e.g. gradual rises).
    case highReading
}

enum GlucoseSeverity {
    case hypo, normal, elevated, high, veryHigh
}

/// Contextual data surfaced when the user taps a hotspot (or any point in
/// fingerstick mode) on the glucose curve.
struct CurveHotspot: Identifiable {
    let id: UUID           // same as the CurvePoint's id
    let point: CurvePoint
    let deltaFromBaseline: Double?           // mg/dL rise from local baseline (nil for recovery)
    let nearbyMeals: [MealSummary]           // meals within mealLookbackMinutes before this point
    let nearbyExercise: [ExerciseSummary]    // exercise that ended before this reading
    let weightDelta: WeightDelta?            // 3-month weight change context (nil if unavailable)

    /// True when at least one meal or exercise correlates with this hotspot.
    var hasContext: Bool { !nearbyMeals.isEmpty || !nearbyExercise.isEmpty }
}

/// Lightweight meal digest for display in the popover — avoids passing the
/// full Core Data object to the view layer.
struct MealSummary: Identifiable {
    let id: UUID
    let name: String
    let timestamp: Date
    let totalCarbs: Double
    let totalGL: Double
    let minutesBeforeReading: Int
}

/// Lightweight exercise digest for the popover.
struct ExerciseSummary: Identifiable {
    let id: UUID
    let type: String
    let startDate: Date
    let durationMinutes: Int
    let minutesBeforeReading: Int
    let caloriesBurned: Double
}

// MARK: - Processor

/// Stateless processor that transforms raw glucose readings + meal/exercise
/// context into a display-ready curve with hotspot annotations.
struct GlucoseCurveProcessor {

    // MARK: - Tunables

    /// Minimum relative rise (mg/dL) from the 30-min moving average to qualify
    /// as a spike peak. Based on Robert's clinical experience: baseline ~120,
    /// a ≥50 rise approaches the 180 mg/dL threshold.
    static let spikeThresholdMgDl: Double = 50.0

    /// Window (minutes) over which the local baseline is computed as a simple
    /// moving average of preceding readings.
    static let movingAverageWindowMinutes: Int = 30

    /// Target interval (minutes) between retained points in flat-in-range
    /// regions when thinning CGM data.
    static let thinningIntervalMinutes: Int = 60

    /// How far before a glucose reading (minutes) to search for correlated meals.
    static let mealLookbackMinutes: Int = 120

    /// How far before a glucose reading (minutes) to search for exercise that
    /// has already ended — so the popover only shows what happened by that point.
    static let exerciseLookbackMinutes: Int = 180
    /// How far forward (in minutes) to look for exercise that started after a
    /// glucose reading. This captures post-spike exercise that explains recovery.
    static let exerciseLookforwardMinutes: Int = 120

    /// How close (mg/dL) to the pre-spike baseline a reading must be to qualify
    /// as a "recovery" point.
    static let recoveryThresholdMgDl: Double = 20.0

    /// Absolute glucose threshold (mg/dL) above which a reading is always
    /// marked as a hotspot, even if the relative delta from the moving average
    /// is below `spikeThresholdMgDl`.  This catches gradual rises that the
    /// relative detector misses (e.g. 130→186 over 90 minutes).
    static let absoluteHighThresholdMgDl: Double = 170.0

    /// Readings-per-hour threshold that distinguishes CGM from fingerstick density.
    /// Above this → CGM mode (thinning + spike-only hotspots).
    /// At or below → fingerstick mode (all points are hotspots, no thinning).
    static let cgmDensityThreshold: Double = 4.0

    // MARK: - Main Entry Point

    /// Process raw glucose readings within a date window and return a display-ready
    /// curve plus hotspot annotations.
    ///
    /// - Parameters:
    ///   - readings: All `GlucoseReadingEntity` objects in the window, any order.
    ///   - meals: All `MealEntity` objects that might overlap the window (can be a superset).
    ///   - exerciseSessions: All `ExerciseSessionEntity` objects that might overlap the window.
    ///   - windowStart: Start of the display window.
    ///   - windowEnd: End of the display window (typically `Date()`).
    ///   - localeIsMgDl: True when the user's locale uses mg/dL; false for mmol/L.
    /// - Returns: Tuple of `(curvePoints, hotspots)` — curve is time-sorted,
    ///   hotspots reference a subset of those points.
    static func process(
        readings: [GlucoseReadingEntity],
        meals: [MealEntity],
        exerciseSessions: [ExerciseSessionEntity],
        weightSamples: [WeightSampleRecord] = [],
        windowStart: Date,
        windowEnd: Date,
        localeIsMgDl: Bool,
        windowDays: Int = 3
    ) -> (curve: [CurvePoint], hotspots: [CurveHotspot]) {

        // 1. Filter to glucose-only readings (exclude lab HbA1c entries) within
        //    the window, sorted oldest → newest.
        let hba1cUnits: Set<String> = ["NGSP %", "mmol/mol"]
        let sorted = readings
            .filter { reading in
                guard let ts = reading.timestamp,
                      let unit = reading.unit else { return false }
                return !hba1cUnits.contains(unit)
                    && ts >= windowStart
                    && ts <= windowEnd
            }
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        guard !sorted.isEmpty else { return ([], []) }

        // 2. Determine density mode.
        let isCGM = detectCGMDensity(sorted, windowStart: windowStart, windowEnd: windowEnd)

        // 3. Compute moving-average baseline for every reading (used for spike detection).
        let baselines = computeBaselines(sorted)

        // 4. Detect spike peaks and recovery points.
        let spikeAnnotations = detectSpikes(sorted, baselines: baselines)

        // 5. Thin the curve if CGM density, keeping spike regions at full resolution.
        //    For wider windows (7 days), thin more aggressively to show overall shape.
        let retainedIndices: Set<Int>
        if isCGM {
            retainedIndices = thinForCGM(sorted, spikeAnnotations: spikeAnnotations, windowDays: windowDays)
        } else {
            retainedIndices = Set(0..<sorted.count)
        }

        // 6. Build CurvePoints, assigning segment IDs to break the line at gaps >2 hours.
        let gapThreshold: TimeInterval = 2 * 3600  // 2 hours
        var curvePoints: [CurvePoint] = []
        var currentSegment = 0
        var lastTimestamp: Date? = nil

        for (i, reading) in sorted.enumerated() {
            guard retainedIndices.contains(i) else { continue }
            let ts = reading.timestamp ?? Date()

            // Increment segment when there's a gap >2h from the previous retained point
            if let prev = lastTimestamp, ts.timeIntervalSince(prev) > gapThreshold {
                currentSegment += 1
            }
            lastTimestamp = ts

            let mgDl = reading.value
            // Use the spike annotation if present; otherwise tag absolute-high readings.
            let annotation: HotspotType? = spikeAnnotations[i]
                ?? (mgDl >= absoluteHighThresholdMgDl ? .highReading : nil)
            // CGM: hotspot if it has any annotation.  Fingerstick: all are hotspots.
            let isHotspot = isCGM ? annotation != nil : true
            let display = localeIsMgDl ? mgDl : mgDl / 18.0182

            let point = CurvePoint(
                id: reading.id ?? UUID(),
                timestamp: ts,
                valueMgDl: mgDl,
                displayValue: display,
                source: reading.source ?? "Unknown",
                isHotspot: isHotspot,
                hotspotType: annotation,
                segmentID: currentSegment
            )
            curvePoints.append(point)
        }

        // 7. Build CurveHotspots with meal/exercise context.
        let hotspots = curvePoints
            .filter(\.isHotspot)
            .map { point -> CurveHotspot in
                let delta: Double? = {
                    // Find this point's index in the original sorted array to get its baseline
                    if let idx = sorted.firstIndex(where: { ($0.id ?? UUID()) == point.id }) {
                        return point.valueMgDl - baselines[idx]
                    }
                    return nil
                }()

                let nearbyMeals = findNearbyMeals(
                    before: point.timestamp,
                    lookbackMinutes: mealLookbackMinutes,
                    meals: meals
                )
                let exerciseBefore = findNearbyExercise(
                    before: point.timestamp,
                    lookbackMinutes: exerciseLookbackMinutes,
                    sessions: exerciseSessions
                )
                let exerciseAfter = findNearbyExerciseAfter(
                    timestamp: point.timestamp,
                    lookforwardMinutes: exerciseLookforwardMinutes,
                    sessions: exerciseSessions
                )
                let nearbyExercise = exerciseBefore + exerciseAfter

                let weight = WeightDeltaProvider.delta(at: point.timestamp, from: weightSamples)

                return CurveHotspot(
                    id: point.id,
                    point: point,
                    deltaFromBaseline: delta,
                    nearbyMeals: nearbyMeals,
                    nearbyExercise: nearbyExercise,
                    weightDelta: weight
                )
            }

        return (curvePoints, hotspots)
    }

    // MARK: - Density Detection

    /// Returns true when the average reading interval suggests CGM-density data
    /// (more than `cgmDensityThreshold` readings per hour on average).
    private static func detectCGMDensity(
        _ sorted: [GlucoseReadingEntity],
        windowStart: Date,
        windowEnd: Date
    ) -> Bool {
        guard sorted.count > 1 else { return false }
        let windowHours = max(1, windowEnd.timeIntervalSince(windowStart) / 3600.0)
        let readingsPerHour = Double(sorted.count) / windowHours
        return readingsPerHour > cgmDensityThreshold
    }

    // MARK: - Baseline Computation

    /// For each reading in the sorted array, compute the simple moving average
    /// of all readings within the preceding `movingAverageWindowMinutes`. If no
    /// preceding readings exist, use the reading's own value.
    private static func computeBaselines(_ sorted: [GlucoseReadingEntity]) -> [Double] {
        let windowSec = Double(movingAverageWindowMinutes) * 60.0
        var baselines = [Double](repeating: 0, count: sorted.count)

        for i in 0..<sorted.count {
            let ts = sorted[i].timestamp ?? .distantPast
            let cutoff = ts.addingTimeInterval(-windowSec)

            var sum = 0.0
            var count = 0
            // Walk backwards from i (inclusive of i itself for robustness)
            var j = i
            while j >= 0 {
                guard let jts = sorted[j].timestamp else { j -= 1; continue }
                if jts < cutoff { break }
                sum += sorted[j].value
                count += 1
                j -= 1
            }
            baselines[i] = count > 0 ? sum / Double(count) : sorted[i].value
        }
        return baselines
    }

    // MARK: - Spike Detection

    /// Walk through the sorted readings and mark spike peaks and recovery points.
    /// Returns a parallel array where each index is nil (no annotation) or a
    /// `HotspotType`.
    ///
    /// Algorithm:
    /// - A spike begins when a reading exceeds its baseline by ≥ spikeThresholdMgDl.
    /// - The spike peak is the local maximum within the contiguous above-threshold run.
    /// - After the peak, the first reading that drops within recoveryThresholdMgDl of
    ///   the pre-spike baseline is marked as recovery.
    /// - Only one peak and one recovery per spike event.
    private static func detectSpikes(
        _ sorted: [GlucoseReadingEntity],
        baselines: [Double]
    ) -> [HotspotType?] {
        var annotations = [HotspotType?](repeating: nil, count: sorted.count)
        guard sorted.count > 2 else { return annotations }

        enum State {
            case scanning
            case inSpike(peakIdx: Int, peakVal: Double, preSpikeBaseline: Double)
            case seekingRecovery(peakIdx: Int, preSpikeBaseline: Double)
        }

        var state: State = .scanning

        for i in 0..<sorted.count {
            let val = sorted[i].value
            let baseline = baselines[i]
            let delta = val - baseline

            switch state {
            case .scanning:
                if delta >= spikeThresholdMgDl {
                    // Entering a spike
                    state = .inSpike(peakIdx: i, peakVal: val, preSpikeBaseline: baseline)
                }

            case .inSpike(let peakIdx, let peakVal, let preSpikeBaseline):
                if val > peakVal {
                    // New higher peak within the same spike
                    state = .inSpike(peakIdx: i, peakVal: val, preSpikeBaseline: preSpikeBaseline)
                } else if delta < spikeThresholdMgDl {
                    // Spike is ending — mark the peak, start seeking recovery
                    annotations[peakIdx] = .spikePeak
                    state = .seekingRecovery(peakIdx: peakIdx, preSpikeBaseline: preSpikeBaseline)

                    // Check if this point itself is already a recovery
                    if abs(val - preSpikeBaseline) <= recoveryThresholdMgDl {
                        annotations[i] = .recoverySlope
                        state = .scanning
                    }
                }

            case .seekingRecovery(_, let preSpikeBaseline):
                if abs(val - preSpikeBaseline) <= recoveryThresholdMgDl {
                    annotations[i] = .recoverySlope
                    state = .scanning
                } else if delta >= spikeThresholdMgDl {
                    // New spike before recovery — mark this as a new spike start
                    state = .inSpike(peakIdx: i, peakVal: val, preSpikeBaseline: baseline)
                }
            }
        }

        // If we ended mid-spike, still mark the peak
        if case .inSpike(let peakIdx, _, _) = state {
            annotations[peakIdx] = .spikePeak
        }

        return annotations
    }

    // MARK: - CGM Thinning

    /// For CGM-density data, select which readings to retain:
    /// - All readings within ±15 minutes of any spike peak or recovery point
    ///   (full resolution around clinically interesting events).
    /// - All readings above the absolute high threshold (170 mg/dL) — these are
    ///   clinically significant even during gradual rises.
    /// - In flat regions, keep approximately one reading per `thinningIntervalMinutes`.
    /// - Always keep the first and last reading in the window.
    private static func thinForCGM(
        _ sorted: [GlucoseReadingEntity],
        spikeAnnotations: [HotspotType?],
        windowDays: Int = 3
    ) -> Set<Int> {
        // Wider windows use more aggressive thinning to show overall curve shape
        // 1-day: 30 min intervals (~48 points/day)
        // 3-day: 60 min intervals (~24 points/day, ~72 total)
        // 7-day: 120 min intervals (~12 points/day, ~84 total)
        let effectiveIntervalMinutes: Int
        if windowDays >= 7 {
            effectiveIntervalMinutes = 120
        } else if windowDays <= 1 {
            effectiveIntervalMinutes = 30
        } else {
            effectiveIntervalMinutes = thinningIntervalMinutes  // 60
        }

        // Spike margin is also wider at 7 days — keep ±10 min (just the peak shape)
        // vs ±15 min at 1–3 days (more detail around the spike)
        let spikeMarginSec: TimeInterval = windowDays >= 7 ? 10 * 60 : 15 * 60

        var retained = Set<Int>()

        // Always keep first and last
        retained.insert(0)
        retained.insert(sorted.count - 1)

        // Always retain readings above the absolute high threshold
        for i in 0..<sorted.count {
            if sorted[i].value >= absoluteHighThresholdMgDl {
                retained.insert(i)
            }
        }

        // Identify indices near spikes (keep full resolution around peaks).
        var nearSpike = Set<Int>()
        let timestamps = sorted.map { $0.timestamp ?? .distantPast }
        for i in 0..<sorted.count {
            guard spikeAnnotations[i] != nil else { continue }
            let spikeTs = timestamps[i]
            var lo = i
            while lo > 0 && spikeTs.timeIntervalSince(timestamps[lo - 1]) <= spikeMarginSec {
                lo -= 1
            }
            var hi = i
            while hi < sorted.count - 1 && timestamps[hi + 1].timeIntervalSince(spikeTs) <= spikeMarginSec {
                hi += 1
            }
            for j in lo...hi {
                nearSpike.insert(j)
            }
        }
        retained.formUnion(nearSpike)

        // Also retain local min/max points in flat regions so the curve shape
        // is preserved even after aggressive thinning (prevents flat-lining
        // between retained points that hides gentle rises and dips).
        if windowDays >= 7 {
            for i in 1..<(sorted.count - 1) {
                if nearSpike.contains(i) { continue }
                let prev = sorted[i - 1].value
                let curr = sorted[i].value
                let next = sorted[i + 1].value
                let isLocalMax = curr > prev && curr > next && (curr - min(prev, next)) >= 10
                let isLocalMin = curr < prev && curr < next && (max(prev, next) - curr) >= 10
                if isLocalMax || isLocalMin {
                    retained.insert(i)
                }
            }
        }

        // Thin flat regions: keep one reading per effectiveIntervalMinutes
        let intervalSec = Double(effectiveIntervalMinutes) * 60.0
        var lastRetainedTs: Date = sorted[0].timestamp ?? .distantPast

        for i in 1..<sorted.count {
            if nearSpike.contains(i) || retained.contains(i) { continue }
            guard let ts = sorted[i].timestamp else { continue }
            if ts.timeIntervalSince(lastRetainedTs) >= intervalSec {
                retained.insert(i)
                lastRetainedTs = ts
            }
        }

        return retained
    }

    // MARK: - Meal / Exercise Correlation

    /// Find meals logged within `lookbackMinutes` before the given timestamp.
    private static func findNearbyMeals(
        before timestamp: Date,
        lookbackMinutes: Int,
        meals: [MealEntity]
    ) -> [MealSummary] {
        let cutoff = timestamp.addingTimeInterval(-Double(lookbackMinutes) * 60.0)
        return meals.compactMap { meal in
            guard let mealTs = meal.timestamp,
                  mealTs >= cutoff,
                  mealTs <= timestamp,
                  meal.mealType != "plannedMeal" else { return nil }

            let minutesBefore = Int(timestamp.timeIntervalSince(mealTs) / 60.0)
            return MealSummary(
                id: meal.id ?? UUID(),
                name: meal.name ?? "Unnamed meal",
                timestamp: mealTs,
                totalCarbs: SimilarMealMatcher.totalCarbs(for: meal),
                totalGL: SimilarMealMatcher.totalGlycaemicLoad(for: meal),
                minutesBeforeReading: minutesBefore
            )
        }
        .sorted { $0.timestamp > $1.timestamp } // most recent first
    }

    /// Find exercise sessions that **ended** within `lookbackMinutes` before
    /// the given timestamp.  This ensures the popover only shows exercise that
    /// has actually occurred by the time of the reading — not future sessions
    /// that haven't started yet.
    private static func findNearbyExercise(
        before timestamp: Date,
        lookbackMinutes: Int,
        sessions: [ExerciseSessionEntity]
    ) -> [ExerciseSummary] {
        let cutoff = timestamp.addingTimeInterval(-Double(lookbackMinutes) * 60.0)
        return sessions.compactMap { session in
            guard let startDate = session.startDate else { return nil }
            // Compute end date from start + duration
            let endDate = session.endDate ?? startDate.addingTimeInterval(session.duration * 60.0)
            // Only include if the session ended before (or at) this reading
            // and started within the lookback window
            guard endDate <= timestamp,
                  startDate >= cutoff else { return nil }

            let minutesBefore = Int(timestamp.timeIntervalSince(endDate) / 60.0)
            return ExerciseSummary(
                id: session.id ?? UUID(),
                type: session.type ?? "Exercise",
                startDate: startDate,
                durationMinutes: Int(session.duration),
                minutesBeforeReading: minutesBefore,
                caloriesBurned: session.caloriesBurned
            )
        }
        .sorted { $0.startDate < $1.startDate } // earliest first
    }

    /// Find exercise sessions that **started** within `lookforwardMinutes` after
    /// the given timestamp. This captures post-spike exercise that explains
    /// the subsequent glucose recovery.
    private static func findNearbyExerciseAfter(
        timestamp: Date,
        lookforwardMinutes: Int,
        sessions: [ExerciseSessionEntity]
    ) -> [ExerciseSummary] {
        let cutoff = timestamp.addingTimeInterval(Double(lookforwardMinutes) * 60.0)
        return sessions.compactMap { session in
            guard let startDate = session.startDate,
                  startDate > timestamp,
                  startDate <= cutoff else { return nil }

            let minutesAfter = Int(startDate.timeIntervalSince(timestamp) / 60.0)
            return ExerciseSummary(
                id: session.id ?? UUID(),
                type: session.type ?? "Exercise",
                startDate: startDate,
                durationMinutes: Int(session.duration),
                minutesBeforeReading: -minutesAfter,  // negative indicates "after"
                caloriesBurned: session.caloriesBurned
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }
}
