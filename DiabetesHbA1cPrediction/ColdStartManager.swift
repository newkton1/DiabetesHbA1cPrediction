//
//  ColdStartManager.swift
//  DiabetesHbA1cPrediction
//
//  Tracks onboarding milestones for new users. Checks Core Data record
//  counts against thresholds to determine which features are unlocked
//  and which empty-state screens to show.
//
//  The Getting Started card uses a 4-step progressive design:
//    Step 1 – Glucose readings  (auto-detect from HealthKit or manual)
//    Step 2 – Log meals
//    Step 3 – Post-meal glucose  (auto-detect from CGM or manual)
//    Step 4 – Exercise  (auto-detect from HealthKit or manual)
//  Each step tracks up to 3 completions via a 3-segment progress bar.
//  After all 4 steps, day-count milestones (3, 7, 14) are shown.
//

import Foundation
import CoreData
import Combine

/// The four onboarding steps shown in the Getting Started card.
enum OnboardingStep: Int, CaseIterable {
    case glucose = 0
    case meals = 1
    case postMealGlucose = 2
    case exercise = 3
}

/// Observable manager that tracks cold-start onboarding progress.
/// Views observe this to decide whether to show empty states, the
/// getting-started checklist, or the normal data-driven UI.
final class ColdStartManager: ObservableObject {

    static let shared = ColdStartManager()

    // MARK: - UserDefaults Keys

    private let checklistDismissedKey = "onboardingChecklistDismissed"
    private let hasLoggedFirstGlucoseKey = "onboarding_hasLoggedFirstGlucose"
    private let hasLoggedFirstMealKey = "onboarding_hasLoggedFirstMeal"
    private let hasLoggedPostMealGlucoseKey = "onboarding_hasLoggedPostMealGlucose"
    private let hasLoggedExerciseKey = "onboarding_hasLoggedExercise"

    // MARK: - Thresholds

    /// Days of glucose data needed to unlock trend charts.
    static let trendDaysRequired = 3
    /// Days of meal + glucose data needed to unlock similar-meal history.
    static let similarMealDaysRequired = 7
    /// Days of glucose data needed to unlock GMI estimate.
    static let gmiDaysRequired = 14
    /// Minimum glucose readings for GMI (matches GMICardView.minReadings).
    static let gmiMinReadings = 20
    /// Number of completions per step in the Getting Started card.
    static let stepsPerMilestone = 3

    // MARK: - Published State

    @Published var glucoseDaysLogged: Int = 0
    @Published var mealCount: Int = 0
    @Published var exerciseCount: Int = 0
    @Published var glucoseReadingCount: Int = 0
    /// Number of post-meal glucose readings detected (glucose 1–3 hrs after a meal).
    @Published var postMealGlucoseCount: Int = 0
    /// True when glucose data is arriving via Apple HealthKit (CGM or similar).
    @Published var glucoseFromHealthKit: Bool = false
    /// True when exercise data is arriving via Apple HealthKit (Apple Watch, etc.).
    @Published var exerciseFromHealthKit: Bool = false

    /// Manually tracked milestones (persisted in UserDefaults)
    @Published var hasLoggedFirstGlucose: Bool {
        didSet { UserDefaults.standard.set(hasLoggedFirstGlucose, forKey: hasLoggedFirstGlucoseKey) }
    }
    @Published var hasLoggedFirstMeal: Bool {
        didSet { UserDefaults.standard.set(hasLoggedFirstMeal, forKey: hasLoggedFirstMealKey) }
    }
    @Published var hasLoggedPostMealGlucose: Bool {
        didSet { UserDefaults.standard.set(hasLoggedPostMealGlucose, forKey: hasLoggedPostMealGlucoseKey) }
    }
    @Published var hasLoggedExercise: Bool {
        didSet { UserDefaults.standard.set(hasLoggedExercise, forKey: hasLoggedExerciseKey) }
    }

    /// Whether the user has manually dismissed the checklist.
    @Published var checklistDismissed: Bool {
        didSet { UserDefaults.standard.set(checklistDismissed, forKey: checklistDismissedKey) }
    }

    // MARK: - Computed Milestone State

    /// True when glucose trend charts should be available.
    var trendsUnlocked: Bool { glucoseDaysLogged >= Self.trendDaysRequired }

    /// True when similar-meal history should be available.
    var similarMealsUnlocked: Bool { glucoseDaysLogged >= Self.similarMealDaysRequired && mealCount >= 5 }

    /// True when GMI estimate should be available.
    var gmiUnlocked: Bool { glucoseDaysLogged >= Self.gmiDaysRequired && glucoseReadingCount >= Self.gmiMinReadings }

    /// True when the 3-day milestone is reached.
    var reached3Days: Bool { glucoseDaysLogged >= Self.trendDaysRequired }

    /// True when the 7-day milestone is reached.
    var reached7Days: Bool { glucoseDaysLogged >= Self.similarMealDaysRequired }

    /// True when the 14-day milestone is reached.
    var reached14Days: Bool { glucoseDaysLogged >= Self.gmiDaysRequired }

    // MARK: - Step Progress (Getting Started card)

    /// How many segments (0–3) are filled for the given step.
    func segmentsFilled(for step: OnboardingStep) -> Int {
        switch step {
        case .glucose:
            if glucoseFromHealthKit { return Self.stepsPerMilestone }
            return min(glucoseReadingCount, Self.stepsPerMilestone)
        case .meals:
            return min(mealCount, Self.stepsPerMilestone)
        case .postMealGlucose:
            if glucoseFromHealthKit && mealCount > 0 {
                // CGM + meals logged → post-meal readings accumulate automatically
                return min(postMealGlucoseCount, Self.stepsPerMilestone)
            }
            return min(postMealGlucoseCount, Self.stepsPerMilestone)
        case .exercise:
            if exerciseFromHealthKit { return Self.stepsPerMilestone }
            return min(exerciseCount, Self.stepsPerMilestone)
        }
    }

    /// Whether a step is fully complete (3 of 3).
    func isStepComplete(_ step: OnboardingStep) -> Bool {
        segmentsFilled(for: step) >= Self.stepsPerMilestone
    }

    /// The current active step — the first incomplete step, or nil if all done.
    var currentStep: OnboardingStep? {
        OnboardingStep.allCases.first { !isStepComplete($0) }
    }

    /// Number of completed steps (0–4).
    var completedStepCount: Int {
        OnboardingStep.allCases.filter { isStepComplete($0) }.count
    }

    /// True when all 4 steps are complete.
    var allStepsComplete: Bool { completedStepCount >= OnboardingStep.allCases.count }

    /// Number of completed checklist items (out of 7) — kept for backward
    /// compatibility with empty-state views that reference completedCount.
    var completedCount: Int {
        var count = 0
        if hasLoggedFirstGlucose { count += 1 }
        if hasLoggedFirstMeal { count += 1 }
        if hasLoggedPostMealGlucose { count += 1 }
        if hasLoggedExercise { count += 1 }
        if reached3Days { count += 1 }
        if reached7Days { count += 1 }
        if reached14Days { count += 1 }
        return count
    }

    static let totalMilestones = 7

    /// True when the checklist should be visible.
    var shouldShowChecklist: Bool {
        !checklistDismissed &&
        !DemoDataManager.isDemoDataLoaded
    }

    /// True when all milestones are complete.
    var allMilestonesComplete: Bool { completedCount >= Self.totalMilestones }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        self.hasLoggedFirstGlucose = defaults.bool(forKey: hasLoggedFirstGlucoseKey)
        self.hasLoggedFirstMeal = defaults.bool(forKey: hasLoggedFirstMealKey)
        self.hasLoggedPostMealGlucose = defaults.bool(forKey: hasLoggedPostMealGlucoseKey)
        self.hasLoggedExercise = defaults.bool(forKey: hasLoggedExerciseKey)
        self.checklistDismissed = defaults.bool(forKey: checklistDismissedKey)
    }

    // MARK: - Refresh from Core Data

    /// Call this from views (e.g. onAppear) to refresh counts from Core Data.
    func refresh(context: NSManagedObjectContext) {
        // Count distinct days with glucose readings
        glucoseDaysLogged = countDistinctGlucoseDays(in: context)

        // Count total glucose readings
        glucoseReadingCount = countEntity("GlucoseReadingEntity", in: context)

        // Count meals (excluding planned)
        mealCount = countLoggedMeals(in: context)

        // Count exercise sessions
        exerciseCount = countEntity("ExerciseSessionEntity", in: context)

        // Detect HealthKit data sources
        glucoseFromHealthKit = hasHealthKitGlucose(in: context)
        exerciseFromHealthKit = hasHealthKitExercise(in: context)

        // Count post-meal glucose readings
        postMealGlucoseCount = countPostMealGlucose(in: context)

        // Auto-set first-time milestones based on data
        if glucoseReadingCount > 0 && !hasLoggedFirstGlucose {
            hasLoggedFirstGlucose = true
        }
        if mealCount > 0 && !hasLoggedFirstMeal {
            hasLoggedFirstMeal = true
        }
        if exerciseCount > 0 && !hasLoggedExercise {
            hasLoggedExercise = true
        }

        // Check for post-meal glucose
        if !hasLoggedPostMealGlucose && postMealGlucoseCount > 0 {
            hasLoggedPostMealGlucose = true
        }
    }

    /// Resets all onboarding state — called when demo data is wiped
    /// so the cold-start flow begins fresh.
    func resetOnboarding() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: checklistDismissedKey)
        defaults.removeObject(forKey: hasLoggedFirstGlucoseKey)
        defaults.removeObject(forKey: hasLoggedFirstMealKey)
        defaults.removeObject(forKey: hasLoggedPostMealGlucoseKey)
        defaults.removeObject(forKey: hasLoggedExerciseKey)

        // Clear cached GMI values so the cold-start GMI card shows
        // the "14 days to your first GMI" message instead of stale cache
        defaults.removeObject(forKey: "lastSuccessfulGmiNgsp")
        defaults.removeObject(forKey: "lastSuccessfulGmiIfcc")
        defaults.removeObject(forKey: "lastSuccessfulGmiDate")

        // Clear dawn effect state
        defaults.removeObject(forKey: "lastRunDetectedDawnEffect")
        defaults.removeObject(forKey: "lastRunAppliedDawnCompensation")

        checklistDismissed = false
        hasLoggedFirstGlucose = false
        hasLoggedFirstMeal = false
        hasLoggedPostMealGlucose = false
        hasLoggedExercise = false
        glucoseDaysLogged = 0
        mealCount = 0
        exerciseCount = 0
        glucoseReadingCount = 0
        postMealGlucoseCount = 0
        glucoseFromHealthKit = false
        exerciseFromHealthKit = false
    }

    // MARK: - Private Helpers

    private func countEntity(_ name: String, in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: name)
        return (try? context.count(for: request)) ?? 0
    }

    private func countLoggedMeals(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "MealEntity")
        request.predicate = NSPredicate(format: "mealType != %@", "plannedMeal")
        return (try? context.count(for: request)) ?? 0
    }

    private func countDistinctGlucoseDays(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSDictionary>(entityName: "GlucoseReadingEntity")
        request.resultType = .dictionaryResultType

        let timestampDesc = NSExpressionDescription()
        timestampDesc.name = "dayDate"
        timestampDesc.expression = NSExpression(forFunction: "trunc:",
                                                 arguments: [NSExpression(forKeyPath: "timestamp")])
        timestampDesc.expressionResultType = .dateAttributeType

        // Simpler approach: fetch all timestamps and count unique days in Swift
        let tsRequest = NSFetchRequest<GlucoseReadingEntity>(entityName: "GlucoseReadingEntity")
        tsRequest.propertiesToFetch = ["timestamp"]
        guard let readings = try? context.fetch(tsRequest) else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(readings.compactMap { reading -> DateComponents? in
            guard let ts = reading.timestamp else { return nil }
            return calendar.dateComponents([.year, .month, .day], from: ts)
        })
        return uniqueDays.count
    }

    private func checkPostMealGlucose(in context: NSManagedObjectContext) -> Bool {
        // Get all meal timestamps
        let mealRequest = NSFetchRequest<MealEntity>(entityName: "MealEntity")
        mealRequest.predicate = NSPredicate(format: "mealType != %@", "plannedMeal")
        guard let meals = try? context.fetch(mealRequest),
              !meals.isEmpty else { return false }

        // Get all glucose timestamps
        let glucoseRequest = NSFetchRequest<GlucoseReadingEntity>(entityName: "GlucoseReadingEntity")
        guard let readings = try? context.fetch(glucoseRequest),
              !readings.isEmpty else { return false }

        // Check if any glucose reading falls 1-3 hours after any meal
        for meal in meals {
            guard let mealTime = meal.timestamp else { continue }
            let windowStart = mealTime.addingTimeInterval(60 * 60)      // 1 hour after
            let windowEnd = mealTime.addingTimeInterval(3 * 60 * 60)    // 3 hours after

            for reading in readings {
                guard let readingTime = reading.timestamp else { continue }
                if readingTime >= windowStart && readingTime <= windowEnd {
                    return true
                }
            }
        }
        return false
    }

    /// Whether any glucose readings came from HealthKit (CGM or similar).
    private func hasHealthKitGlucose(in context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "GlucoseReadingEntity")
        request.predicate = NSPredicate(format: "source == %@", "HealthKit")
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    /// Whether any exercise sessions came from HealthKit (Apple Watch, etc.).
    /// HealthKit-synced workouts have "HealthKit UUID:" in their notes field.
    private func hasHealthKitExercise(in context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ExerciseSessionEntity")
        request.predicate = NSPredicate(format: "notes CONTAINS %@", "HealthKit UUID:")
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    /// Count glucose readings that fall 1–3 hours after any logged meal.
    private func countPostMealGlucose(in context: NSManagedObjectContext) -> Int {
        let mealRequest = NSFetchRequest<MealEntity>(entityName: "MealEntity")
        mealRequest.predicate = NSPredicate(format: "mealType != %@", "plannedMeal")
        guard let meals = try? context.fetch(mealRequest),
              !meals.isEmpty else { return 0 }

        let glucoseRequest = NSFetchRequest<GlucoseReadingEntity>(entityName: "GlucoseReadingEntity")
        guard let readings = try? context.fetch(glucoseRequest),
              !readings.isEmpty else { return 0 }

        var matchedReadings = Set<NSManagedObjectID>()
        for meal in meals {
            guard let mealTime = meal.timestamp else { continue }
            let windowStart = mealTime.addingTimeInterval(60 * 60)
            let windowEnd = mealTime.addingTimeInterval(3 * 60 * 60)
            for reading in readings {
                guard let readingTime = reading.timestamp else { continue }
                if readingTime >= windowStart && readingTime <= windowEnd {
                    matchedReadings.insert(reading.objectID)
                }
            }
        }
        return matchedReadings.count
    }
}
