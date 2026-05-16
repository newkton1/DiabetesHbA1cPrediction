import Foundation
import CoreData
import Combine

// MARK: - Dawn Effect Detection Engine
//
// This file provides dawn effect detection and dawn-adjusted glucose averaging.
// The multi-factor HbA1c prediction engine that previously lived here has been
// archived to "Old HbA1C prediction code.swift" — it was not surfaced in the UI.
//
// The Dashboard GMI value is computed by the pure Bergenstal 2018 formula in
// DashboardView.swift (GMIComputer struct). This file supports it by detecting
// dawn effect patterns and persisting that state for UI notifications.

/// Lightweight engine that detects dawn effect patterns from glucose data
/// and provides dawn-adjusted glucose averaging for informational display.
class GmiEstimateEngine: ObservableObject {

    /// Set after each run — true if dawn effect pattern was detected algorithmically
    @Published var lastRunDetectedDawnEffect: Bool = UserDefaults.standard.bool(forKey: "lastRunDetectedDawnEffect")
    /// Set after each run — true if dawn compensation was applied (user-enabled or detected)
    @Published var lastRunAppliedDawnCompensation: Bool = UserDefaults.standard.bool(forKey: "lastRunAppliedDawnCompensation")

    // MARK: - Public API

    /// Runs dawn effect detection and persists state. Called when the user taps the
    /// GMI value on the Dashboard to trigger a refresh.
    @discardableResult
    func runPredictionAndSave(context: NSManagedObjectContext) -> Bool {
        // Fetch meals for dawn detection (need to exclude meal-related morning spikes)
        let meals = fetchMeals(from: context, days: 30) ?? []

        // Fetch timestamped readings for dawn detection
        guard let timestampedReadings = fetchGlucoseReadingsWithTimestamps(from: context, days: 14),
              !timestampedReadings.isEmpty else {
            lastRunDetectedDawnEffect = false
            lastRunAppliedDawnCompensation = false
            persistState()
            return false
        }

        // Run automatic dawn detection (no user toggle — purely algorithmic)
        let dawnDetected = detectDawnEffect(readings: timestampedReadings, meals: meals)

        // Update published state and persist
        lastRunDetectedDawnEffect = dawnDetected
        lastRunAppliedDawnCompensation = dawnDetected
        persistState()

        return dawnDetected
    }

    // MARK: - Dawn Effect Support

    /// Represents a glucose reading with its timestamp for time-of-day analysis
    struct TimestampedGlucoseReading {
        let value: Double    // mg/dL (normalised)
        let timestamp: Date
    }

    /// Fetches glucose readings with timestamps from Core Data for dawn effect analysis.
    /// Both mg/dL and mmol/L readings are accepted and normalised to mg/dL.
    private func fetchGlucoseReadingsWithTimestamps(
        from context: NSManagedObjectContext,
        days: Int
    ) -> [TimestampedGlucoseReading]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlucoseReadingEntity")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND (unit == %@ OR unit == %@)", cutoffDate as NSDate, "mg/dL", "mmol/L")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject] else {
                return nil
            }

            let readings = results.compactMap { object -> TimestampedGlucoseReading? in
                guard let glucoseValue = object.value(forKey: "value") as? NSNumber,
                      let timestamp = object.value(forKey: "timestamp") as? Date else { return nil }
                let unit = object.value(forKey: "unit") as? String ?? "mg/dL"
                // Exclude HbA1c lab test entries — only glucose readings
                let source = object.value(forKey: "source") as? String ?? ""
                if source == "Hospital Lab Test" { return nil }

                let mgdlValue: Double
                if unit == "mmol/L" {
                    mgdlValue = glucoseValue.doubleValue * 18.0182
                } else {
                    mgdlValue = glucoseValue.doubleValue
                }
                return TimestampedGlucoseReading(value: mgdlValue, timestamp: timestamp)
            }

            return readings.isEmpty ? nil : readings
        } catch {
            #if DEBUG
            print("Error fetching timestamped glucose readings: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Calculates time-weighted average glucose with dawn effect compensation.
    /// Divides the day into 5 windows and down-weights the dawn window (04:00–08:00)
    /// to reduce the impact of liver-driven morning glucose spikes.
    ///
    /// Time windows:
    ///   - Dawn:      04:00–08:00  (weight: 0.6 when dawn effect active)
    ///   - Morning:   08:00–12:00  (weight: 1.0)
    ///   - Afternoon: 12:00–18:00  (weight: 1.0)
    ///   - Evening:   18:00–22:00  (weight: 1.0)
    ///   - Night:     22:00–04:00  (weight: 1.0)
    private static let dawnWeightFactor: Double = 0.6

    func calculateDawnAdjustedAverage(_ readings: [TimestampedGlucoseReading]) -> Double {
        guard !readings.isEmpty else { return 0 }

        let calendar = Calendar.current

        var dawnReadings: [Double] = []
        var morningReadings: [Double] = []
        var afternoonReadings: [Double] = []
        var eveningReadings: [Double] = []
        var nightReadings: [Double] = []

        for reading in readings {
            let hour = calendar.component(.hour, from: reading.timestamp)
            switch hour {
            case 4..<8:
                dawnReadings.append(reading.value)
            case 8..<12:
                morningReadings.append(reading.value)
            case 12..<18:
                afternoonReadings.append(reading.value)
            case 18..<22:
                eveningReadings.append(reading.value)
            default:
                nightReadings.append(reading.value)
            }
        }

        var weightedSum = 0.0
        var totalWeight = 0.0

        let windows: [(readings: [Double], weight: Double)] = [
            (dawnReadings, Self.dawnWeightFactor),
            (morningReadings, 1.0),
            (afternoonReadings, 1.0),
            (eveningReadings, 1.0),
            (nightReadings, 1.0)
        ]

        for window in windows {
            if !window.readings.isEmpty {
                let windowAvg = window.readings.reduce(0, +) / Double(window.readings.count)
                weightedSum += windowAvg * window.weight
                totalWeight += window.weight
            }
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    /// Detects dawn effect pattern from glucose readings and meal data.
    ///
    /// For CGM-like data (many readings): looks for 5+ days out of last 14 where
    /// morning peak (04:00–08:00) exceeds night baseline (00:00–03:00) by 30+ mg/dL
    /// with no meal logged in the preceding 14 hours.
    ///
    /// For finger stick data (fewer readings): looks for 3+ fasting morning readings
    /// above 130 mg/dL in the last 30 days with no meal for 14+ hours prior.
    func detectDawnEffect(
        readings: [TimestampedGlucoseReading],
        meals: [NSManagedObject]
    ) -> Bool {
        let calendar = Calendar.current

        let last14Days = readings.filter {
            guard let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) else { return false }
            return $0.timestamp >= cutoff
        }

        let uniqueDays = Set(last14Days.map { calendar.startOfDay(for: $0.timestamp) })
        let readingsPerDay = uniqueDays.count > 0 ? Double(last14Days.count) / Double(uniqueDays.count) : 0

        if readingsPerDay >= 10 {
            return detectDawnEffectCGM(readings: last14Days, meals: meals, calendar: calendar)
        } else {
            let last30Days = readings.filter {
                guard let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) else { return false }
                return $0.timestamp >= cutoff
            }
            return detectDawnEffectFingerStick(readings: last30Days, meals: meals, calendar: calendar)
        }
    }

    // MARK: - Private Dawn Effect Helpers

    /// CGM detection: looks for rising glucose pattern 04:00–08:00 vs 00:00–03:00 baseline
    private func detectDawnEffectCGM(
        readings: [TimestampedGlucoseReading],
        meals: [NSManagedObject],
        calendar: Calendar
    ) -> Bool {
        var dayGroups: [Date: [TimestampedGlucoseReading]] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.timestamp)
            dayGroups[day, default: []].append(reading)
        }

        var dawnDayCount = 0

        for (day, dayReadings) in dayGroups {
            let nightBaseline = dayReadings
                .filter { calendar.component(.hour, from: $0.timestamp) < 4 }
                .map { $0.value }

            let morningReadings = dayReadings
                .filter {
                    let hour = calendar.component(.hour, from: $0.timestamp)
                    return hour >= 4 && hour < 8
                }
                .map { $0.value }

            guard !nightBaseline.isEmpty, !morningReadings.isEmpty else { continue }

            let nightAvg = nightBaseline.reduce(0, +) / Double(nightBaseline.count)
            let morningPeak = morningReadings.max() ?? 0

            let morningEnd = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
            let lookbackStart = calendar.date(byAdding: .hour, value: -14, to: morningEnd) ?? day

            let hasMealBefore = meals.contains { meal in
                guard let mealTime = meal.value(forKey: "timestamp") as? Date else { return false }
                return mealTime >= lookbackStart && mealTime < morningEnd
            }

            if morningPeak - nightAvg > 30 && !hasMealBefore {
                dawnDayCount += 1
            }
        }

        return dawnDayCount >= 5
    }

    /// Finger stick detection: looks for high fasting morning readings
    private func detectDawnEffectFingerStick(
        readings: [TimestampedGlucoseReading],
        meals: [NSManagedObject],
        calendar: Calendar
    ) -> Bool {
        var suspectDawnCount = 0

        let morningReadings = readings.filter {
            calendar.component(.hour, from: $0.timestamp) < 9
        }

        for reading in morningReadings {
            guard reading.value > 130 else { continue }

            let lastMealBefore = meals
                .compactMap { meal -> Date? in
                    guard let mealTime = meal.value(forKey: "timestamp") as? Date,
                          mealTime < reading.timestamp else { return nil }
                    return mealTime
                }
                .max()

            let hoursSinceMeal: Double
            if let lastMeal = lastMealBefore {
                hoursSinceMeal = reading.timestamp.timeIntervalSince(lastMeal) / 3600.0
            } else {
                hoursSinceMeal = 24
            }

            if hoursSinceMeal > 14 {
                suspectDawnCount += 1
            }
        }

        return suspectDawnCount >= 3
    }

    // MARK: - Data Fetching Helpers

    /// Fetches meal entities from Core Data
    private func fetchMeals(
        from context: NSManagedObjectContext,
        days: Int
    ) -> [NSManagedObject]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MealEntity")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@", cutoffDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            return try context.fetch(fetchRequest) as? [NSManagedObject]
        } catch {
            #if DEBUG
            print("Error fetching meals: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - State Persistence

    private func persistState() {
        UserDefaults.standard.set(lastRunDetectedDawnEffect, forKey: "lastRunDetectedDawnEffect")
        UserDefaults.standard.set(lastRunAppliedDawnCompensation, forKey: "lastRunAppliedDawnCompensation")
    }
}
