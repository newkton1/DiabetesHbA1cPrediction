import HealthKit
@preconcurrency import CoreData
import Foundation
import Combine

/// HealthKitManager handles all interactions with Apple HealthKit.
///
/// This class manages:
/// - Authorization requests for HealthKit data access
/// - Fetching workout and exercise data
/// - Fetching step count and active calories
/// - Fetching blood glucose readings (from FreeStyle Libre 2 and other connected monitors)
/// - Syncing HealthKit data to CoreData for local persistence
///
/// IMPORTANT: Privacy considerations
/// - Users must explicitly grant permission to read HealthKit data
/// - The app's Info.plist MUST include NSHealthShareUsageDescription key
/// - Users can revoke access at any time in Settings > Health > Data Access & Devices
/// - All HealthKit operations must happen on a background thread
/// - Glucose data from continuous glucose monitors requires explicit user permission
///
/// Example usage:
/// ```swift
/// let manager = HealthKitManager.shared
/// await manager.requestAuthorization()
/// let workouts = await manager.fetchRecentWorkouts(days: 30)
/// ```
@MainActor
class HealthKitManager: ObservableObject {

    // MARK: - Properties

    /// Indicates whether the user has authorized HealthKit access
    @Published var isAuthorized: Bool = false

    /// Stores any authorization error messages for debugging/UI feedback
    @Published var authorizationError: String?

    /// Shared singleton instance
    static let shared = HealthKitManager()

    /// The HKHealthStore instance for all HealthKit operations
    private let healthStore = HKHealthStore()

    // MARK: - Initialization

    private init() {
        // Private initializer to enforce singleton pattern
    }

    // MARK: - Authorization

    /// Requests read permission for HealthKit data types.
    ///
    /// This method requests access to:
    /// - Step count
    /// - Active energy burned
    /// - Apple exercise time
    /// - Blood glucose readings
    /// - Workouts
    ///
    /// - Returns: True if authorization was successful, false otherwise
    /// - Note: This is an async method that updates published properties on completion
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.authorizationError = "HealthKit is not available on this device"
            self.isAuthorized = false
            return false
        }

        // Define the types we want to read
        let readTypes: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            HKWorkoutType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            self.isAuthorized = true
            return true
        } catch {
            self.authorizationError = error.localizedDescription
            self.isAuthorized = false
            return false
        }
    }
    
    /// Legacy completion-based authorization for backward compatibility
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Task {
            let result = await requestAuthorization()
            completion(result)
        }
    }

    // MARK: - Data Fetching Methods

    /// Fetches recent workouts from HealthKit.
    ///
    /// - Parameter days: Number of days back to query (default: 30)
    /// - Returns: Array of HKWorkout objects, sorted by date descending
    func fetchRecentWorkouts(days: Int = 30) async -> [HKWorkout] {
        guard isAuthorized else {
            return []
        }

        let workoutType = HKWorkoutType.workoutType()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        ]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            self.healthStore.execute(query)
        }
    }
    
    /// Legacy completion-based workout fetching for backward compatibility
    func fetchRecentWorkouts(days: Int = 30, completion: @escaping ([HKWorkout]) -> Void) {
        Task {
            let workouts = await fetchRecentWorkouts(days: days)
            completion(workouts)
        }
    }

    /// Fetches the total step count for a specific date.
    ///
    /// - Parameter date: The date for which to fetch step count
    /// - Returns: Total steps as a Double
    /// - Note: The returned value is the sum of all step count samples for that day
    func fetchStepCount(for date: Date) async -> Double {
        guard isAuthorized else {
            return 0
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("Error fetching step count: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }

                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }

                let steps = sum.doubleValue(for: HKUnit.count())
                continuation.resume(returning: steps)
            }

            self.healthStore.execute(query)
        }
    }
    
    /// Legacy completion-based step count fetching for backward compatibility
    func fetchStepCount(for date: Date, completion: @escaping (Double) -> Void) {
        Task {
            let steps = await fetchStepCount(for: date)
            completion(steps)
        }
    }

    /// Fetches total active calories burned over a specified number of days.
    ///
    /// - Parameter days: Number of days back to query (default: 30)
    /// - Returns: Total active calories as a Double
    /// - Note: Uses HKUnit.kilocalorie() for calorie measurement
    func fetchActiveCalories(days: Int = 30) async -> Double {
        guard isAuthorized else {
            return 0
        }

        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("Error fetching active calories: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }

                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }

                let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                continuation.resume(returning: calories)
            }

            self.healthStore.execute(query)
        }
    }
    
    /// Legacy completion-based calorie fetching for backward compatibility
    func fetchActiveCalories(days: Int = 30, completion: @escaping (Double) -> Void) {
        Task {
            let calories = await fetchActiveCalories(days: days)
            completion(calories)
        }
    }

    /// Fetches total walking/running distance over a specified number of days.
    ///
    /// - Parameter days: Number of days back to query (default: 30)
    /// - Returns: Total distance in kilometers as a Double
    func fetchWalkingRunningDistance(days: Int = 30) async -> Double {
        guard isAuthorized else {
            return 0
        }

        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("Error fetching walking/running distance: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }

                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }

                let distanceKm = sum.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                continuation.resume(returning: distanceKm)
            }

            self.healthStore.execute(query)
        }
    }

    /// Fetches blood glucose readings from HealthKit.
    ///
    /// This method retrieves glucose samples, which may come from:
    /// - FreeStyle Libre 2 continuous glucose monitor
    /// - Dexcom G6/G7 continuous glucose monitor
    /// - Other connected glucose monitors that integrate with HealthKit
    /// - Manual glucose entries by the user
    ///
    /// - Parameter days: Number of days back to query (default: 30)
    /// - Returns: Array of tuples containing (date, glucose value in mg/dL)
    /// - Note: Glucose values are in mg/dL (standard unit for HealthKit blood glucose data)
    func fetchGlucoseReadings(days: Int = 30) async -> [(date: Date, value: Double)] {
        guard isAuthorized else {
            return []
        }

        let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        ]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: glucoseType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching glucose readings: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let glucoseReadings = samples.map { sample in
                    let value = sample.quantity.doubleValue(for: HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter()))
                    // Convert mmol/L to mg/dL: mg/dL = mmol/L × 18
                    let mgdL = value * 18.0
                    return (date: sample.startDate, value: mgdL)
                }

                continuation.resume(returning: glucoseReadings)
            }

            self.healthStore.execute(query)
        }
    }
    
    /// Legacy completion-based glucose fetching for backward compatibility
    func fetchGlucoseReadings(days: Int = 30, completion: @escaping ([(date: Date, value: Double)]) -> Void) {
        Task {
            let readings = await fetchGlucoseReadings(days: days)
            completion(readings)
        }
    }

    // MARK: - CoreData Syncing Methods
    
    /// Data structure for transferring workout data across isolation boundaries
    private struct WorkoutData: Sendable {
        let uuid: String
        let startDate: Date
        let endDate: Date
        let type: String
        let duration: Double
        let caloriesBurned: Double
        let distanceKm: Double
    }

    /// Syncs recent workouts from HealthKit to CoreData.
    ///
    /// This method:
    /// 1. Fetches workouts from HealthKit for the specified number of days
    /// 2. Checks CoreData to avoid duplicate imports (using workout UUID)
    /// 3. Creates ExerciseSessionEntity records for new workouts
    /// 4. Saves to CoreData and returns the number of newly imported workouts
    ///
    /// - Parameters:
    ///   - context: NSManagedObjectContext for CoreData operations
    ///   - days: Number of days back to sync (default: 30)
    /// - Returns: Count of newly imported workouts
    /// - Note: Operates on a background thread; context should be created for background operations
    func syncExerciseToCorData(context: NSManagedObjectContext, days: Int = 30) async -> Int {
        guard isAuthorized else {
            return 0
        }

        let workouts = await fetchRecentWorkouts(days: days)
        
        // Extract workout data into Sendable struct before crossing isolation boundary
        let workoutDataList: [WorkoutData] = workouts.map { workout in
            var calories: Double = 0
            if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let statistics = workout.statistics(for: activeEnergyType),
               let sumQuantity = statistics.sumQuantity() {
                calories = sumQuantity.doubleValue(for: HKUnit.kilocalorie())
            }

            var distanceKm: Double = 0
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
               let statistics = workout.statistics(for: distanceType),
               let sumQuantity = statistics.sumQuantity() {
                distanceKm = sumQuantity.doubleValue(for: HKUnit.meterUnit(with: .kilo))
            }

            return WorkoutData(
                uuid: workout.uuid.uuidString,
                startDate: workout.startDate,
                endDate: workout.endDate,
                type: workout.workoutActivityType.description,
                duration: workout.duration / 60.0, // Convert seconds to minutes for CoreData
                caloriesBurned: calories,
                distanceKm: distanceKm
            )
        }

        return await Self.importWorkoutsToCoreData(workoutDataList: workoutDataList, context: context)
    }
    
    /// Legacy completion-based exercise sync for backward compatibility
    func syncExerciseToCorData(context: NSManagedObjectContext, days: Int = 30, completion: @escaping (Int) -> Void) {
        Task {
            let count = await syncExerciseToCorData(context: context, days: days)
            completion(count)
        }
    }
    
    /// Data structure for transferring glucose data across isolation boundaries
    private struct GlucoseData: Sendable {
        let date: Date
        let value: Double
    }

    /// Syncs blood glucose readings from HealthKit to CoreData.
    ///
    /// This method:
    /// 1. Fetches glucose samples from HealthKit for the specified number of days
    /// 2. Checks CoreData to avoid duplicate imports (by matching timestamps)
    /// 3. Creates GlucoseReadingEntity records for new readings
    /// 4. Saves to CoreData and returns the number of newly imported readings
    ///
    /// - Parameters:
    ///   - context: NSManagedObjectContext for CoreData operations
    ///   - days: Number of days back to sync (default: 30)
    /// - Returns: Count of newly imported glucose readings
    /// - Note: Deduplication uses timestamp matching (within 1 second tolerance)
    func syncGlucoseToCorData(context: NSManagedObjectContext, days: Int = 30) async -> Int {
        guard isAuthorized else {
            return 0
        }

        let glucoseReadings = await fetchGlucoseReadings(days: days)
        
        // Convert to Sendable struct
        let glucoseDataList: [GlucoseData] = glucoseReadings.map { reading in
            GlucoseData(date: reading.date, value: reading.value)
        }

        return await Self.importGlucoseToCoreData(glucoseDataList: glucoseDataList, context: context)
    }
    
    /// Legacy completion-based glucose sync for backward compatibility
    func syncGlucoseToCorData(context: NSManagedObjectContext, days: Int = 30, completion: @escaping (Int) -> Void) {
        Task {
            let count = await syncGlucoseToCorData(context: context, days: days)
            completion(count)
        }
    }

    // MARK: - Private CoreData Import Helpers
    
    /// Imports workout data to CoreData (nonisolated to work with context.perform)
    private static nonisolated func importWorkoutsToCoreData(workoutDataList: [WorkoutData], context: NSManagedObjectContext) async -> Int {
        await withCheckedContinuation { continuation in
            context.perform {
                var count = 0
                
                for workoutData in workoutDataList {
                    // Check if this workout already exists in CoreData using its UUID
                    let fetchRequest = NSFetchRequest<ExerciseSessionEntity>(
                        entityName: "ExerciseSessionEntity"
                    )
                    fetchRequest.predicate = NSPredicate(
                        format: "notes CONTAINS %@",
                        workoutData.uuid
                    )

                    do {
                        let existingWorkouts = try context.fetch(fetchRequest)
                        if !existingWorkouts.isEmpty {
                            // Already imported, skip
                            continue
                        }
                    } catch {
                        print("Error checking for duplicate workout: \(error.localizedDescription)")
                        continue
                    }

                    // Create new ExerciseSessionEntity
                    let entity = ExerciseSessionEntity(context: context)
                    entity.id = UUID()
                    entity.startDate = workoutData.startDate
                    entity.endDate = workoutData.endDate
                    entity.type = workoutData.type
                    entity.duration = workoutData.duration
                    entity.caloriesBurned = workoutData.caloriesBurned
                    // Estimate intensity from calories and duration (moderate = 5)
                    if workoutData.duration > 0 {
                        let calPerMin = workoutData.caloriesBurned / workoutData.duration
                        entity.intensity = min(10, max(1, calPerMin / 2.0))
                    } else {
                        entity.intensity = 5
                    }
                    // Store HealthKit UUID and distance in notes for reference
                    var noteParts = ["HealthKit UUID: \(workoutData.uuid)"]
                    if workoutData.distanceKm > 0 {
                        noteParts.append(String(format: "Distance: %.2f km", workoutData.distanceKm))
                    }
                    entity.notes = noteParts.joined(separator: " | ")

                    count += 1
                }

                // Save to CoreData
                do {
                    try context.save()
                } catch {
                    print("Error saving exercise data to CoreData: \(error.localizedDescription)")
                }
                
                continuation.resume(returning: count)
            }
        }
    }
    
    /// Imports glucose data to CoreData (nonisolated to work with context.perform)
    private static nonisolated func importGlucoseToCoreData(glucoseDataList: [GlucoseData], context: NSManagedObjectContext) async -> Int {
        await withCheckedContinuation { continuation in
            context.perform {
                var count = 0
                
                for glucoseData in glucoseDataList {
                    // Check if this glucose reading already exists in CoreData
                    let fetchRequest = NSFetchRequest<GlucoseReadingEntity>(
                        entityName: "GlucoseReadingEntity"
                    )

                    // Use timestamp matching with 1-second tolerance to avoid duplicates
                    let startRange = glucoseData.date.addingTimeInterval(-1)
                    let endRange = glucoseData.date.addingTimeInterval(1)
                    fetchRequest.predicate = NSPredicate(
                        format: "timestamp >= %@ AND timestamp <= %@",
                        startRange as NSDate,
                        endRange as NSDate
                    )

                    do {
                        let existingReadings = try context.fetch(fetchRequest)
                        if !existingReadings.isEmpty {
                            // Already imported, skip
                            continue
                        }
                    } catch {
                        print("Error checking for duplicate glucose reading: \(error.localizedDescription)")
                        continue
                    }

                    // Create new GlucoseReadingEntity
                    let entity = GlucoseReadingEntity(context: context)
                    entity.timestamp = glucoseData.date
                    entity.value = glucoseData.value
                    entity.source = "HealthKit"

                    count += 1
                }

                // Save to CoreData
                do {
                    try context.save()
                } catch {
                    print("Error saving glucose data to CoreData: \(error.localizedDescription)")
                }
                
                continuation.resume(returning: count)
            }
        }
    }

    // MARK: - Daily Activity Sync

    /// Data structure for daily activity summaries
    private struct DailyActivityData: Sendable {
        let date: Date
        let steps: Double
        let distanceKm: Double
        let calories: Double
        let estimatedMinutes: Double
    }

    /// Fetches a daily statistic for a given quantity type over a date range.
    ///
    /// - Parameters:
    ///   - identifier: The HKQuantityTypeIdentifier to query
    ///   - unit: The HKUnit to use for the result
    ///   - start: Start date of the range
    ///   - end: End date of the range
    /// - Returns: The cumulative sum for that day, or 0 if no data
    private func fetchDailyStatistic(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("Error fetching \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            self.healthStore.execute(query)
        }
    }

    /// Syncs daily walking/activity data from HealthKit to CoreData.
    ///
    /// Unlike `syncExerciseToCorData` which only imports formal HKWorkout records,
    /// this method fetches ambient step count, walking distance, and active calories
    /// that the iPhone records automatically during casual walking throughout the day.
    ///
    /// For each day with meaningful activity (>500 steps), it creates an
    /// ExerciseSessionEntity of type "Walking" spanning the full day.
    ///
    /// - Parameters:
    ///   - context: NSManagedObjectContext for CoreData operations
    ///   - days: Number of days back to sync (default: 30)
    /// - Returns: Count of newly imported daily activity records
    func syncDailyActivityToCorData(context: NSManagedObjectContext, days: Int = 30) async -> Int {
        guard isAuthorized else {
            return 0
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyDataList: [DailyActivityData] = []

        // Fetch daily stats for each day
        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            // Fetch steps, distance, and calories for this day
            let steps = await fetchDailyStatistic(
                identifier: .stepCount,
                unit: HKUnit.count(),
                start: dayStart,
                end: dayEnd
            )

            // Skip days with minimal activity (less than 500 steps)
            guard steps >= 500 else { continue }

            let distanceKm = await fetchDailyStatistic(
                identifier: .distanceWalkingRunning,
                unit: HKUnit.meterUnit(with: .kilo),
                start: dayStart,
                end: dayEnd
            )

            let calories = await fetchDailyStatistic(
                identifier: .activeEnergyBurned,
                unit: HKUnit.kilocalorie(),
                start: dayStart,
                end: dayEnd
            )

            // Estimate walking minutes from steps (roughly 100 steps per minute of walking)
            let estimatedMinutes = steps / 100.0

            dailyDataList.append(DailyActivityData(
                date: dayStart,
                steps: steps,
                distanceKm: distanceKm,
                calories: calories,
                estimatedMinutes: estimatedMinutes
            ))
        }

        guard !dailyDataList.isEmpty else { return 0 }

        return await Self.importDailyActivityToCoreData(dailyDataList: dailyDataList, context: context)
    }

    /// Imports daily activity data to CoreData (nonisolated to work with context.perform)
    private static nonisolated func importDailyActivityToCoreData(dailyDataList: [DailyActivityData], context: NSManagedObjectContext) async -> Int {
        await withCheckedContinuation { continuation in
            context.perform {
                var count = 0
                let calendar = Calendar.current

                for activityData in dailyDataList {
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: activityData.date) ?? activityData.date

                    // Check if we already have a "Daily Walking" entry for this date
                    let fetchRequest = NSFetchRequest<ExerciseSessionEntity>(
                        entityName: "ExerciseSessionEntity"
                    )
                    fetchRequest.predicate = NSPredicate(
                        format: "notes CONTAINS %@ AND startDate >= %@ AND startDate < %@",
                        "DailyActivity",
                        activityData.date as NSDate,
                        dayEnd as NSDate
                    )

                    do {
                        let existing = try context.fetch(fetchRequest)
                        if !existing.isEmpty {
                            // Already have this day's data — update it with latest values
                            if let entity = existing.first {
                                entity.duration = activityData.estimatedMinutes
                                entity.caloriesBurned = activityData.calories
                                entity.notes = String(format: "DailyActivity | Steps: %.0f | Distance: %.2f km", activityData.steps, activityData.distanceKm)
                                // Intensity based on steps: light (<5000), moderate (5000-10000), vigorous (>10000)
                                if activityData.steps >= 10000 {
                                    entity.intensity = 7
                                } else if activityData.steps >= 5000 {
                                    entity.intensity = 5
                                } else {
                                    entity.intensity = 3
                                }
                            }
                            continue
                        }
                    } catch {
                        print("Error checking for duplicate daily activity: \(error.localizedDescription)")
                        continue
                    }

                    // Create new ExerciseSessionEntity for this day's walking activity
                    let entity = ExerciseSessionEntity(context: context)
                    entity.id = UUID()
                    entity.startDate = activityData.date
                    entity.endDate = dayEnd
                    entity.type = "Walking"
                    entity.duration = activityData.estimatedMinutes
                    entity.caloriesBurned = activityData.calories
                    entity.notes = String(format: "DailyActivity | Steps: %.0f | Distance: %.2f km", activityData.steps, activityData.distanceKm)

                    // Intensity based on step count
                    if activityData.steps >= 10000 {
                        entity.intensity = 7
                    } else if activityData.steps >= 5000 {
                        entity.intensity = 5
                    } else {
                        entity.intensity = 3
                    }

                    count += 1
                }

                // Save to CoreData
                do {
                    try context.save()
                } catch {
                    print("Error saving daily activity data to CoreData: \(error.localizedDescription)")
                }

                continuation.resume(returning: count)
            }
        }
    }

    // MARK: - Utility Methods

    /// Checks whether HealthKit is available on the current device.
    ///
    /// HealthKit is available on iPhone 6s and later with iOS 9.0 or later.
    /// It is not available on iPad or other devices.
    ///
    /// - Returns: True if HealthKit is available, false otherwise
    static func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
}

// MARK: - HKWorkoutActivityType Extension

extension HKWorkoutActivityType {
    /// Provides a human-readable description of the workout activity type
    var description: String {
        switch self {
        case .americanFootball:
            return "American Football"
        case .archery:
            return "Archery"
        case .australianFootball:
            return "Australian Football"
        case .badminton:
            return "Badminton"
        case .baseball:
            return "Baseball"
        case .basketball:
            return "Basketball"
        case .bowling:
            return "Bowling"
        case .boxing:
            return "Boxing"
        case .climbing:
            return "Climbing"
        case .cricket:
            return "Cricket"
        case .crossTraining:
            return "Cross Training"
        case .cycling:
            return "Cycling"
        case .dance:
            return "Dance"
        case .cardioDance:
            return "Dance Inspired Cardio"
        case .elliptical:
            return "Elliptical"
        case .equestrianSports:
            return "Equestrian Sports"
        case .fencing:
            return "Fencing"
        case .fishing:
            return "Fishing"
        case .functionalStrengthTraining:
            return "Functional Strength Training"
        case .golf:
            return "Golf"
        case .gymnastics:
            return "Gymnastics"
        case .handball:
            return "Handball"
        case .hiking:
            return "Hiking"
        case .hockey:
            return "Hockey"
        case .hunting:
            return "Hunting"
        case .lacrosse:
            return "Lacrosse"
        case .martialArts:
            return "Martial Arts"
        case .mindAndBody:
            return "Mind and Body"
        case .mixedMetabolicCardioTraining:
            return "Mixed Metabolic Cardio Training"
        case .paddleSports:
            return "Paddle Sports"
        case .play:
            return "Play"
        case .preparationAndRecovery:
            return "Preparation and Recovery"
        case .racquetball:
            return "Racquetball"
        case .rowing:
            return "Rowing"
        case .rugby:
            return "Rugby"
        case .running:
            return "Running"
        case .sailing:
            return "Sailing"
        case .skatingSports:
            return "Skating Sports"
        case .downhillSkiing:
            return "Skiing"
        case .snowboarding:
            return "Snowboarding"
        case .soccer:
            return "Soccer"
        case .softball:
            return "Softball"
        case .squash:
            return "Squash"
        case .stairClimbing:
            return "Stair Climbing"
        case .stepTraining:
            return "Step Training"
        case .surfingSports:
            return "Surfing Sports"
        case .swimming:
            return "Swimming"
        case .tableTennis:
            return "Table Tennis"
        case .tennis:
            return "Tennis"
        case .trackAndField:
            return "Track and Field"
        case .traditionalStrengthTraining:
            return "Traditional Strength Training"
        case .volleyball:
            return "Volleyball"
        case .walking:
            return "Walking"
        case .waterFitness:
            return "Water Fitness"
        case .waterPolo:
            return "Water Polo"
        case .waterSports:
            return "Water Sports"
        case .wrestling:
            return "Wrestling"
        case .yoga:
            return "Yoga"
        case .barre:
            return "Barre"
        case .coreTraining:
            return "Core Training"
        case .pilates:
            return "Pilates"
        case .socialDance:
            return "Social Dance"
        case .flexibility:
            return "Stretching"
        case .wheelchairWalkPace:
            return "Wheelchair Walk Pace"
        case .wheelchairRunPace:
            return "Wheelchair Run Pace"
        case .taiChi:
            return "Tai Chi"
        case .mixedCardio:
            return "Mixed Cardio"
        case .handCycling:
            return "Hand Cycling"
        default:
            return "Other"
        }
    }
}
