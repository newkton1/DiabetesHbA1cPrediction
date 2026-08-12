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
    ///
    /// `context` is kept as a parameter for source compatibility with
    /// existing call sites, but all the actual Core Data reads now happen
    /// off the main thread — see `refreshAllCountsInBackground()`.
    ///
    /// Previously `countEntity`/`countLoggedMeals`/`hasHealthKitGlucose`/
    /// `hasHealthKitExercise` ran synchronously here, each issuing its own
    /// `context.count(for:)` call on the main thread. Individually these
    /// looked cheap, but once `countPostMealGlucose` and
    /// `countDistinctGlucoseDays` (the two biggest offenders) were already
    /// moved to a background context, Instruments Time Profiler showed
    /// these four — 300-500ms each on real data volumes — as the next
    /// layer of main-thread cost on every `DashboardView.onAppear`. Same
    /// fix as before: do the reads off the main thread, publish once.
    func refresh(context: NSManagedObjectContext) {
        refreshAllCountsInBackground()
    }

    /// Recomputes every cold-start count together on a single background
    /// Core Data context so none of it runs on the main thread, then
    /// publishes all results (and their derived milestones) back on the
    /// main thread in one hop. Uses the shared persistent container
    /// directly rather than a passed-in context, since this needs its own
    /// private background context, not the caller's (typically
    /// main-thread) one.
    private func refreshAllCountsInBackground() {
        PersistenceController.shared.container.performBackgroundTask { [weak self] bgContext in
            let glucoseCount = Self.countEntity("GlucoseReadingEntity", in: bgContext)
            let loggedMeals = Self.countLoggedMeals(in: bgContext)
            let exerciseCount = Self.countEntity("ExerciseSessionEntity", in: bgContext)
            let glucoseHK = Self.hasHealthKitGlucose(in: bgContext)
            let exerciseHK = Self.hasHealthKitExercise(in: bgContext)
            let daysLogged = Self.countDistinctGlucoseDays(in: bgContext)
            let postMealCount = Self.countPostMealGlucose(in: bgContext)

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.glucoseReadingCount = glucoseCount
                self.mealCount = loggedMeals
                self.exerciseCount = exerciseCount
                self.glucoseFromHealthKit = glucoseHK
                self.exerciseFromHealthKit = exerciseHK
                self.glucoseDaysLogged = daysLogged
                self.postMealGlucoseCount = postMealCount

                // Auto-set first-time milestones based on the fresh counts.
                if self.glucoseReadingCount > 0 && !self.hasLoggedFirstGlucose {
                    self.hasLoggedFirstGlucose = true
                }
                if self.mealCount > 0 && !self.hasLoggedFirstMeal {
                    self.hasLoggedFirstMeal = true
                }
                if self.exerciseCount > 0 && !self.hasLoggedExercise {
                    self.hasLoggedExercise = true
                }
                if !self.hasLoggedPostMealGlucose && postMealCount > 0 {
                    self.hasLoggedPostMealGlucose = true
                }
            }
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

    private nonisolated static func countEntity(_ name: String, in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: name)
        return (try? context.count(for: request)) ?? 0
    }

    private nonisolated static func countLoggedMeals(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "MealEntity")
        request.predicate = NSPredicate(format: "mealType != %@", "plannedMeal")
        return (try? context.count(for: request)) ?? 0
    }

    /// Count of distinct calendar days (in the user's current calendar and
    /// timezone) on which at least one glucose reading exists.
    ///
    /// Previously this fetched every reading's timestamp and called
    /// `Calendar.dateComponents([.year, .month, .day], from:)` on each one
    /// to build a `Set<DateComponents>`. `dateComponents` does real
    /// Gregorian/ICU timezone work per call — individually cheap, but it
    /// adds up to several seconds across thousands of readings, and this
    /// ran synchronously on the main thread every time `refresh(context:)`
    /// was called. Confirmed via Instruments Time Profiler as the
    /// next-heaviest main-thread cost once `countPostMealGlucose` was fixed.
    ///
    /// `Calendar.ordinality(of: .day, in: .era, for:)` identifies the same
    /// "which calendar day is this" bucket — still timezone/calendar-aware,
    /// so day boundaries stay correct — but returns a plain `Int`, which is
    /// far cheaper to compute and to hash/compare in a `Set` than a
    /// `DateComponents` struct. `nonisolated` for the same reason as
    /// `countPostMealGlucose` below: this project builds with
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and this now runs
    /// inside `performBackgroundTask`'s closure, off the Main Actor.
    private nonisolated static func countDistinctGlucoseDays(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<GlucoseReadingEntity>(entityName: "GlucoseReadingEntity")
        request.propertiesToFetch = ["timestamp"]
        guard let readings = try? context.fetch(request) else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(readings.compactMap { reading -> Int? in
            guard let ts = reading.timestamp else { return nil }
            return calendar.ordinality(of: .day, in: .era, for: ts)
        })
        return uniqueDays.count
    }

    /// Whether any glucose readings came from HealthKit (CGM or similar).
    private nonisolated static func hasHealthKitGlucose(in context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "GlucoseReadingEntity")
        request.predicate = NSPredicate(format: "source == %@", "HealthKit")
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    /// Whether any exercise sessions came from HealthKit (Apple Watch, etc.).
    /// HealthKit-synced workouts have "HealthKit UUID:" in their notes field.
    /// NOTE: `notes CONTAINS %@` can't use an index (substring match), so
    /// this is a full-table scan — one more reason this belongs off the
    /// main thread rather than in `refresh(context:)` directly.
    private nonisolated static func hasHealthKitExercise(in context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ExerciseSessionEntity")
        request.predicate = NSPredicate(format: "notes CONTAINS %@", "HealthKit UUID:")
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    /// Count of distinct glucose readings that fall 1–3 hours after any
    /// logged meal.
    ///
    /// Previously this fetched every `MealEntity` and every
    /// `GlucoseReadingEntity` and ran a full nested loop (every meal ×
    /// every reading) synchronously on the caller's context — an
    /// O(meals × readings) scan that, on real device data volumes, took
    /// long enough to trip Instruments' Hang detector and eventually block
    /// the main thread for 20+ seconds (confirmed via Time Profiler).
    ///
    /// This version fetches only timestamps (no full object materialisation),
    /// sorts both lists once, merges each meal's 1–3 hour window into a
    /// minimal set of non-overlapping intervals (meals are already sorted
    /// ascending, so this is a single pass), then sweeps the sorted readings
    /// once against those merged intervals. Every reading is still counted
    /// at most once even if it falls inside more than one meal's window,
    /// matching the original `Set`-based dedup — but the whole thing runs in
    /// roughly O((meals + readings) log(meals + readings)) instead of
    /// O(meals × readings), and callers now run it on a background context
    /// (see `refreshPostMealGlucoseCount`) rather than the main thread.
    /// Marked `nonisolated` because this project builds with
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise
    /// implicitly isolate this `static func` to the Main Actor — defeating
    /// the whole point of running it inside `performBackgroundTask`'s
    /// closure, which executes on Core Data's private background queue, not
    /// the Main Actor. This function only ever touches the background
    /// `context` passed in and no actor-isolated state, so it's safe to opt
    /// out of Main Actor isolation entirely.
    private nonisolated static func countPostMealGlucose(in context: NSManagedObjectContext) -> Int {
        let mealRequest = NSFetchRequest<NSDictionary>(entityName: "MealEntity")
        mealRequest.predicate = NSPredicate(format: "mealType != %@", "plannedMeal")
        mealRequest.resultType = .dictionaryResultType
        mealRequest.propertiesToFetch = ["timestamp"]
        mealRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        let readingRequest = NSFetchRequest<NSDictionary>(entityName: "GlucoseReadingEntity")
        readingRequest.resultType = .dictionaryResultType
        readingRequest.propertiesToFetch = ["timestamp"]
        readingRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        guard let mealDicts = try? context.fetch(mealRequest), !mealDicts.isEmpty,
              let readingDicts = try? context.fetch(readingRequest), !readingDicts.isEmpty else {
            return 0
        }

        let mealTimes = mealDicts.compactMap { $0["timestamp"] as? Date }
        let readingTimes = readingDicts.compactMap { $0["timestamp"] as? Date }
        guard !mealTimes.isEmpty, !readingTimes.isEmpty else { return 0 }

        // Merge each meal's post-meal window into non-overlapping intervals.
        var mergedWindows: [(start: Date, end: Date)] = []
        for mealTime in mealTimes {
            let windowStart = mealTime.addingTimeInterval(60 * 60)      // 1 hour after
            let windowEnd = mealTime.addingTimeInterval(3 * 60 * 60)    // 3 hours after
            if let last = mergedWindows.last, windowStart <= last.end {
                mergedWindows[mergedWindows.count - 1].end = max(last.end, windowEnd)
            } else {
                mergedWindows.append((start: windowStart, end: windowEnd))
            }
        }

        // Single forward sweep over the sorted readings against the merged,
        // non-overlapping windows — each reading is visited at most once.
        var matchCount = 0
        var readingIndex = 0
        for window in mergedWindows {
            while readingIndex < readingTimes.count && readingTimes[readingIndex] < window.start {
                readingIndex += 1
            }
            while readingIndex < readingTimes.count && readingTimes[readingIndex] <= window.end {
                matchCount += 1
                readingIndex += 1
            }
        }
        return matchCount
    }
}
