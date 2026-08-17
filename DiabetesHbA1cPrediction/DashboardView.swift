import SwiftUI
// import Charts — removed: lab HbA1c chart replaced by numeric readout in GMICardView
import Combine
import CoreData

/// Dashboard view for the Diabetes HbA1c Prediction App
/// Displays the current estimated HbA1c with color-coded risk levels,
/// glucose trends, and quick action statistics.
///
/// The view uses @FetchRequest to automatically refresh when underlying
/// Core Data entities change. The HbA1c color coding follows clinical guidelines:
/// - Green: < 5.7% (non-diabetic)
/// - Yellow: 5.7-6.4% (prediabetic)
/// - Orange: 6.5-7.5% (diabetic target range)
/// - Red: > 7.5% (above target)
struct DashboardView: View {
    // MARK: - Navigation
    @Binding var selectedTab: ContentView.Tab

    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Requests

    /// Fetch glucose readings — used by GMI card and stale data detection.
    ///
    /// Bounded to the last ~100 days: the widest window anything in this view
    /// actually reads is the 90-day lab HbA1c lookback in `GMICardView`
    /// (`labWindowDays`), with a small margin. Previously unbounded — on a
    /// demo/CGM dataset spanning many months this meant every downstream
    /// filter (`isActiveCGMUser`, `gmi`, `labResults`, the `Array(...)` copy
    /// passed to `GMICardView`) re-scanned the *entire* reading history,
    /// synchronously, on the main thread, every time this view rendered.
    /// Bounding the fetch itself shrinks N for all of them at once.
    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: false)],
        predicate: NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -100, to: Date())! as NSDate
        )
    ) private var glucoseReadings: FetchedResults<GlucoseReadingEntity>

    /// Fetch meals logged today to show count in quick stats.
    @FetchRequest(
        entity: MealEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]
    ) private var meals: FetchedResults<MealEntity>

    /// Fetch exercise sessions from the last 7 days for total minutes.
    @FetchRequest(
        entity: ExerciseSessionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: false)]
    ) private var exerciseSessions: FetchedResults<ExerciseSessionEntity>

    // MARK: - Cold Start
    @ObservedObject private var coldStart = ColdStartManager.shared
    @State private var isDemoData = DemoDataManager.isDemoDataLoaded

    // MARK: - State
    @State private var showLastMealSheet = false

    // MARK: - Cached derived state
    //
    // `isActiveCGMUser`, `mealsLoggedToday()`, and the `Array(glucoseReadings)`
    // copy passed to GMICardView all used to be recomputed live, every single
    // time `body` evaluated. Found via Instruments (Time Profiler) showing
    // ~5-6s combined main-thread cost attributed to these on a single launch.
    // Now computed once, in `refreshCachedDerivedState()`, and reused here.
    @State private var cachedIsActiveCGMUser = false
    @State private var cachedGlucoseReadingsArray: [GlucoseReadingEntity] = []
    @State private var cachedMealsLoggedToday = 0

    /// Recomputes all of the above. Called from `.onAppear` and whenever the
    /// underlying fetched results actually change — not on every render.
    private func refreshCachedDerivedState() {
        cachedGlucoseReadingsArray = Array(glucoseReadings)
        cachedIsActiveCGMUser = computeIsActiveCGMUser()
        cachedMealsLoggedToday = computeMealsLoggedToday()
    }

    /// CGM dropout warning toast — true while the sliding toast is visible
    @State private var showCGMDropoutToast = false

    // UserDefaults keys for persisting CGM dropout warning state across launches
    private let cgmDropoutDismissedKey = "cgmDropoutWarningDismissed"
    private let cgmDropoutLastShownKey = "cgmDropoutWarningLastShownAt"

    /// Dawn effect detection state — read from UserDefaults after each GMI recalculation
    @State private var dawnEffectDetected: Bool = UserDefaults.standard.bool(forKey: "lastRunDetectedDawnEffect")

    // Timer-driven state for stale data detection
    @State private var currentTime = Date()
    private let staleDataTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// True when glucose readings exist but the most recent is older than 30 minutes
    private var isGlucoseDataStale: Bool {
        guard let latestTimestamp = glucoseReadings.first?.timestamp else { return false }
        return currentTime.timeIntervalSince(latestTimestamp) > 30 * 60
    }

    // MARK: - CGM Dropout Warning Logic

    /// Returns true if reading density in the last 14 days indicates CGM usage.
    ///
    /// CGM devices produce a reading every ~5 minutes; after the 15-minute sampling
    /// step in HealthKitManager this becomes one per 15 min in CoreData.
    /// Three consecutive readings within 45 minutes are unambiguous CGM behaviour —
    /// finger-stick users cannot produce that cadence.
    ///
    /// A 14-day recency window matches the GMI calculation window so the flag
    /// naturally expires when a user switches back to finger sticks.
    private func computeIsActiveCGMUser() -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let timestamps = glucoseReadings
            .filter { ($0.timestamp ?? .distantPast) >= cutoff }
            .compactMap { $0.timestamp }
            .sorted()
        guard timestamps.count >= 3 else { return false }
        for i in 0..<(timestamps.count - 2) {
            if timestamps[i + 2].timeIntervalSince(timestamps[i]) <= 45 * 60 {
                return true
            }
        }
        return false
    }

    private var cgmDropoutWarningDismissed: Bool {
        UserDefaults.standard.bool(forKey: cgmDropoutDismissedKey)
    }

    private var cgmDropoutLastShown: Date? {
        UserDefaults.standard.object(forKey: cgmDropoutLastShownKey) as? Date
    }

    /// Shows the CGM dropout toast if all conditions are met:
    ///   1. User is an active CGM user (reading density ≥ CGM cadence in last 14 days)
    ///   2. Glucose data is stale (>30 min since last reading)
    ///   3. Warning has not been manually dismissed this episode
    ///   4. Either never shown before, or >1 hour since last appearance
    ///
    /// The toast auto-dismisses after 3 seconds but repeats hourly until the
    /// user taps ✕ or readings resume.
    private func maybeTriggerCGMDropoutWarning() {
        guard cachedIsActiveCGMUser, isGlucoseDataStale, !cgmDropoutWarningDismissed else { return }
        let now = Date()
        if let lastShown = cgmDropoutLastShown {
            guard now.timeIntervalSince(lastShown) >= 3600 else { return }
        }
        UserDefaults.standard.set(now, forKey: cgmDropoutLastShownKey)
        withAnimation(.easeInOut(duration: 0.3)) { showCGMDropoutToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { showCGMDropoutToast = false }
        }
    }

    /// Called when the user taps ✕ on the toast.
    /// Suppresses further warnings for the current dropout episode.
    /// The flag is cleared automatically when readings resume.
    private func dismissCGMDropoutWarning() {
        UserDefaults.standard.set(true, forKey: cgmDropoutDismissedKey)
        withAnimation(.easeInOut(duration: 0.3)) { showCGMDropoutToast = false }
    }

    /// Called when glucose readings resume (data is no longer stale).
    /// Resets dismissed and last-shown state so the next dropout episode
    /// can warn again from scratch.
    private func clearCGMDropoutState() {
        UserDefaults.standard.removeObject(forKey: cgmDropoutDismissedKey)
        UserDefaults.standard.removeObject(forKey: cgmDropoutLastShownKey)
        if showCGMDropoutToast {
            withAnimation(.easeInOut(duration: 0.3)) { showCGMDropoutToast = false }
        }
    }

    // Environment for detecting orientation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    /// Returns true if device is in landscape orientation
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLandscape {
                    // MARK: - Landscape Layout
                    VStack(spacing: 12) {
                        // Header with title on left
                        HStack {
                            Text("Dashboard")
                                .font(.title3.bold())
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Demo data banner (landscape)
                        if isDemoData {
                            DemoDataBannerView(onDemoDataCleared: {
                                isDemoData = false
                            })
                        }

                        // Top section: GMI card (from glucose data), notices and disclaimer
                        GMICardView(glucoseReadings: cachedGlucoseReadingsArray, onDawnEffectUpdated: { detected in
                            dawnEffectDetected = detected
                        })

                        if dawnEffectDetected {
                            DawnEffectNoticeBanner()
                        }

                        // MARK: - Getting Started Checklist (landscape)
                        if coldStart.shouldShowChecklist {
                            GettingStartedChecklistView(coldStart: coldStart, selectedTab: $selectedTab)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        MedicalDisclaimerBanner()

                        // MARK: - 14-Day Activity Snapshot (landscape)
                        ActivitySnapshotCard(
                            meals: meals,
                            exerciseSessions: exerciseSessions
                        )

                        // Action cards in a 3-column x 2-row grid in landscape
                        LandscapeActionsGrid(
                            onAddMeal: { showLastMealSheet = true },
                            onPlanFeast: { selectedTab = .meals },
                            exerciseMinutesWeek: exerciseMinutesThisWeek()
                        )

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical)
                } else {
                    // MARK: - Portrait Layout (Original)
                    VStack(spacing: 20) {
                        // MARK: - Demo Data Banner
                        if isDemoData {
                            DemoDataBannerView(onDemoDataCleared: {
                                isDemoData = false
                            })
                        }

                        // MARK: - GMI (Glucose Management Indicator) Card
                        GMICardView(glucoseReadings: cachedGlucoseReadingsArray, onDawnEffectUpdated: { detected in
                            dawnEffectDetected = detected
                        })

                        if dawnEffectDetected {
                            DawnEffectNoticeBanner()
                        }

                        // MARK: - Getting Started Checklist
                        if coldStart.shouldShowChecklist {
                            GettingStartedChecklistView(coldStart: coldStart, selectedTab: $selectedTab)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        MedicalDisclaimerBanner()

                        // MARK: - 14-Day Activity Snapshot
                        ActivitySnapshotCard(
                            meals: meals,
                            exerciseSessions: exerciseSessions
                        )

                        // MARK: - Quick Action Cards for Meals
                        MealQuickActionsView(
                            onAddMeal: { showLastMealSheet = true },
                            onPlanFeast: { selectedTab = .meals }
                        )

                        // MARK: - Quick Stats Grid
                        QuickStatsView(
                            mealsToday: cachedMealsLoggedToday,
                            exerciseMinutesWeek: exerciseMinutesThisWeek(),
                            lastGlucoseReading: glucoseReadings.first
                        )

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isLandscape {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Dashboard")
                            .font(.title3.bold())
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .sheet(isPresented: $showLastMealSheet) {
                LastMealView()
                    .environment(\.managedObjectContext, viewContext)
            }
            // Plan Meal now switches to the meals tab instead of presenting a sheet
            .onReceive(staleDataTimer) { time in
                currentTime = time
                // Each minute: either reset warning state (readings resumed)
                // or try to show the toast (readings still absent)
                if isGlucoseDataStale {
                    maybeTriggerCGMDropoutWarning()
                } else {
                    clearCGMDropoutState()
                }
            }
            .onAppear {
                // Compute cached derived state before anything reads it below.
                refreshCachedDerivedState()

                // Check on every foreground appearance — catches the case where
                // the app was backgrounded during a dropout and the timer never ticked
                maybeTriggerCGMDropoutWarning()

                // Refresh cold-start milestone state
                coldStart.refresh(context: viewContext)
                isDemoData = DemoDataManager.isDemoDataLoaded
            }
            .onChange(of: glucoseReadings.count) { _, _ in
                // FetchedResults<GlucoseReadingEntity> isn't Equatable, so we
                // can't observe it directly with .onChange — watch .count
                // instead (cheap Int comparison, covers additions/deletions,
                // which is what actually invalidates the cached values below).
                refreshCachedDerivedState()
            }
            .onChange(of: meals.count) { _, _ in
                refreshCachedDerivedState()
            }
            .overlay(alignment: .top) {
                if showCGMDropoutToast {
                    CGMDropoutToastView(onDismiss: dismissCGMDropoutWarning)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Meal Computed Properties
    
    /// Get the most recent logged meal (not planned)
    private var lastLoggedMeal: MealEntity? {
        meals.first { $0.mealType != "plannedMeal" }
    }
    
    /// Get the next upcoming planned meal
    private var nextPlannedMeal: MealEntity? {
        let now = Date()
        return meals
            .filter { $0.mealType == "plannedMeal" && ($0.plannedDateTime ?? Date.distantPast) > now }
            .sorted { ($0.plannedDateTime ?? Date.distantFuture) < ($1.plannedDateTime ?? Date.distantFuture) }
            .first
    }

    // MARK: - Helper Methods

    /// Calculate the number of meals logged today.
    /// - Returns: Count of meals with today's date.
    private func computeMealsLoggedToday() -> Int {
        let calendar = Calendar.current
        // `ordinality(of:.day, in:.era, for:)` is a cheap integer comparison —
        // avoids building a Date via `startOfDay(for:)` for every meal, which
        // is the same per-item Calendar-call anti-pattern already fixed in
        // ColdStartManager.countDistinctGlucoseDays.
        let todayOrdinal = calendar.ordinality(of: .day, in: .era, for: Date())
        return meals.filter { meal in
            guard let mealDate = meal.timestamp else { return false }
            return calendar.ordinality(of: .day, in: .era, for: mealDate) == todayOrdinal
        }.count
    }

    /// Calculate total exercise minutes from the past 7 days.
    /// - Returns: Sum of duration of all exercise sessions in the last 7 days.
    private func exerciseMinutesThisWeek() -> Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return Int(exerciseSessions
            .filter { session in
                guard let exerciseDate = session.startDate else { return false }
                return exerciseDate >= sevenDaysAgo
            }
            .reduce(0) { $0 + $1.duration })
    }

    // runNewPrediction() and getExerciseEffect() removed — Dashboard no longer
    // runs forward projections. GMI (from glucose data) + Lab HbA1c (from stored
    // results) replace the engine-based prediction. Historical pattern analysis
    // lives in What-If / HistoricalPatternContent.
}

// MARK: - GMI (Glucose Management Indicator) Computation

/// Implements the Bergenstal et al. 2018 GMI formula.
///
/// Reference: Bergenstal RM, Beck RW, Close KL, et al.
/// Glucose Management Indicator (GMI): A New Term for Estimating A1C From Continuous Glucose Monitoring.
/// Diabetes Care. 2018;41(11):2275-2280.
///
/// GMI is a glucose-derived metric whose FDA-endorsed naming deliberately distinguishes it
/// from a laboratory HbA1c result. It is computed from mean glucose over a rolling window
/// and takes no behavioural inputs.
private struct GMIComputer {
    /// GMI (NGSP %) = 3.31 + 0.02392 × mean_mg/dL
    static func gmiPercent(meanMgDl: Double) -> Double {
        return 3.31 + 0.02392 * meanMgDl
    }

    /// GMI (IFCC mmol/mol) = 12.71 + 4.70587 × mean_mmol/L
    static func gmiMmol(meanMmolL: Double) -> Double {
        return 12.71 + 4.70587 * meanMmolL
    }

    /// mg/dL → mmol/L
    static func mmolPerL(fromMgDl mg: Double) -> Double {
        return mg / 18.0182
    }
}

/// Result bundle returned when GMI can be computed from a glucose window.
private struct GMIResult {
    let gmiNgsp: Double          // %
    let gmiIfcc: Double          // mmol/mol
    let meanMgDl: Double
    let readingCount: Int
    let windowDays: Int
}

// MARK: - GMICardView Component

/// Dashboard card displaying GMI computed from the user's own glucose readings
/// over a rolling 14-day window, plus the most recent lab HbA1c value(s) from
/// the last 90 days displayed as a simple numeric readout beneath.
///
/// GMI is intentionally labelled "GMI," not "HbA1c," to match Dexcom / FreeStyle
/// Libre precedent and FDA guidance on terminology. Lab HbA1c values are kept
/// separate with a flask icon to reinforce the distinction.
private struct GMICardView: View {
    let glucoseReadings: [GlucoseReadingEntity]
    /// Callback to notify parent when dawn effect detection state changes
    var onDawnEffectUpdated: ((Bool) -> Void)? = nil
    @ObservedObject private var profile = HbA1cUserProfile.shared
    @Environment(\.managedObjectContext) private var viewContext

    /// Rolling window length used for GMI computation.
    /// Bergenstal 2018 validates the formula on 10–14 day CGM windows.
    private static let windowDays: Int = 14

    /// Minimum reading count before we consider GMI informative.
    /// Below this we render a "not enough data" placeholder instead.
    private static let minReadings: Int = 20

    /// Lab HbA1c lookback window — matches the 90-day red-cell pool biology.
    private static let labWindowDays: Int = 90

    // State for interactive features
    @State private var isRecalculating = false
    @State private var recalcFlash = false
    @State private var showLabSheet = false

    // Cached derived state — `gmi` and `labResults` used to be recomputed
    // live on every `body` evaluation (each an O(n) filter/reduce over
    // `glucoseReadings`). Instruments showed both still costing real
    // main-thread time even after the earlier fix, which only removed the
    // Core Data *write* from `gmi`, not the read/computation cost. Now
    // computed once in `refreshComputedState()` and reused below.
    @State private var cachedGmiResult: GMIResult?
    @State private var cachedLabResults: [(date: Date, ifcc: Double)] = []

    private func refreshComputedState() {
        cachedGmiResult = computeGmi()
        cachedLabResults = computeLabResults()
    }

    private var isNgsp: Bool { profile.effectiveUnit == .ngsp }

    /// Maximum age (in days) for a cached GMI to remain useful. Beyond this the
    /// entire 14-day glucose window has rolled over with no new data, so the old
    /// value is no longer representative.
    private static let staleCacheDays: Int = 30

    /// Keys for persisting the last successful GMI computation.
    private static let cachedGmiNgspKey  = "lastSuccessfulGmiNgsp"
    private static let cachedGmiIfccKey  = "lastSuccessfulGmiIfcc"
    private static let cachedGmiDateKey  = "lastSuccessfulGmiDate"

    /// Compute GMI from glucose readings within the last `windowDays` days.
    /// Accepts both mg/dL and mmol/L readings, converting mmol/L → mg/dL (×18)
    /// before averaging. Returns nil when there is insufficient glucose data.
    /// On success, caches the result to UserDefaults for the stale-data fallback.
    private func computeGmi() -> GMIResult? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: Date()) ?? Date()
        // Include both mg/dL and mmol/L glucose readings; exclude lab HbA1c entries ("NGSP %" / "mmol/mol").
        let windowReadings = glucoseReadings.filter { reading in
            guard let ts = reading.timestamp, let unit = reading.unit else { return false }
            return (unit == "mg/dL" || unit == "mmol/L") && ts >= cutoff
        }
        guard windowReadings.count >= Self.minReadings else { return nil }

        // Normalise all readings to mg/dL for the Bergenstal formula
        let sumMgDl = windowReadings.reduce(0.0) { total, reading in
            let valueMgDl = reading.unit == "mmol/L" ? reading.value * 18.0 : reading.value
            return total + valueMgDl
        }
        let mean = sumMgDl / Double(windowReadings.count)
        let meanMmol = GMIComputer.mmolPerL(fromMgDl: mean)
        let result = GMIResult(
            gmiNgsp: GMIComputer.gmiPercent(meanMgDl: mean),
            gmiIfcc: GMIComputer.gmiMmol(meanMmolL: meanMmol),
            meanMgDl: mean,
            readingCount: windowReadings.count,
            windowDays: Self.windowDays
        )

        // Cache this successful computation for the stale-data fallback.
        // NOTE: this function must stay side-effect-free with respect to
        // Core Data. It used to also call `persistGmiIfNeeded` (a Core Data
        // fetch + possible save) right here — but any Core Data save
        // triggers a change notification that re-renders this view via
        // `automaticallyMergesChangesFromParent`, which could re-trigger
        // this computation, which could save again, and so on. That
        // save→notify→re-render loop is exactly what produced the severe
        // hang seen after deleting a meal (confirmed via Instruments Time
        // Profiler). The Core Data write now happens separately in
        // `persistGmiToCoreDataIfNeeded()`, triggered from `.onAppear`/
        // `.onChange`, never from inside this computation.
        UserDefaults.standard.set(result.gmiNgsp, forKey: Self.cachedGmiNgspKey)
        UserDefaults.standard.set(result.gmiIfcc, forKey: Self.cachedGmiIfccKey)
        UserDefaults.standard.set(Date(), forKey: Self.cachedGmiDateKey)

        return result
    }

    /// Persists today's GMI estimate to Core Data (at most once per
    /// calendar day — see `persistGmiIfNeeded`'s guard). Called from
    /// `.onAppear`/`.onChange` rather than from the `gmi` getter itself,
    /// so the write happens as a controlled side effect of data changing,
    /// not as a side effect of SwiftUI evaluating `body`.
    private func persistGmiToCoreDataIfNeeded() {
        guard let result = cachedGmiResult else { return }
        Self.persistGmiIfNeeded(ngsp: result.gmiNgsp, ifcc: result.gmiIfcc, context: viewContext)
    }

    /// Saves a GMI estimate to Core Data if one hasn't already been saved today.
    /// Stores the NGSP % value in `predictedValue` with `modelVersion` set to
    /// "Bergenstal2018-NGSP" to distinguish from legacy IFCC records.
    private static func persistGmiIfNeeded(ngsp: Double, ifcc: Double, context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }

        // Check if we already saved a Bergenstal GMI today
        let request: NSFetchRequest<GmiEstimateEntity> = GmiEstimateEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "modelVersion == %@ AND predictionDate >= %@ AND predictionDate < %@",
            "Bergenstal2018-NGSP", todayStart as NSDate, todayEnd as NSDate
        )
        request.fetchLimit = 1

        let alreadySaved = (try? context.count(for: request)) ?? 0
        guard alreadySaved == 0 else { return }

        let entity = GmiEstimateEntity(context: context)
        entity.id = UUID()
        entity.predictedValue = ngsp
        entity.confidenceLevel = 1.0
        entity.predictionDate = Date()
        entity.modelVersion = "Bergenstal2018-NGSP"

        // Store IFCC value in contributing factors for reference
        if let jsonData = try? JSONSerialization.data(
            withJSONObject: ["gmiIfccMmolMol": ifcc],
            options: []
        ) {
            entity.contributingFactorsJSON = jsonData
        }

        try? context.save()
    }

    /// Returns the last successfully computed GMI if it is within `staleCacheDays`,
    /// along with how many days ago it was calculated. Returns nil if no cached
    /// value exists or if it is older than the cutoff.
    private var cachedGmi: (ngsp: Double, ifcc: Double, daysAgo: Int)? {
        let ngsp = UserDefaults.standard.double(forKey: Self.cachedGmiNgspKey)
        guard ngsp > 0,
              let date = UserDefaults.standard.object(forKey: Self.cachedGmiDateKey) as? Date else {
            return nil
        }
        let daysAgo = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999
        guard daysAgo <= Self.staleCacheDays else { return nil }
        let ifcc = UserDefaults.standard.double(forKey: Self.cachedGmiIfccKey)
        return (ngsp: ngsp, ifcc: ifcc, daysAgo: daysAgo)
    }

    // MARK: - Lab HbA1c helpers

    /// Lab HbA1c results recorded in the last 90 days, sorted oldest → newest.
    /// Each value is converted to the canonical IFCC mmol/mol for comparison,
    /// then to the user's display unit when rendered.
    private func computeLabResults() -> [(date: Date, ifcc: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.labWindowDays, to: Date()) ?? Date()
        return glucoseReadings.compactMap { reading in
            guard let ts = reading.timestamp,
                  let unit = reading.unit,
                  let source = reading.source,
                  source == "Hospital Lab Test",
                  (unit == "NGSP %" || unit == "mmol/mol"),
                  ts >= cutoff else { return nil }
            let ifcc: Double = unit == "NGSP %" ? ngspToIFCC(reading.value) : reading.value
            return (date: ts, ifcc: ifcc)
        }
        .sorted { $0.date < $1.date }
    }

    /// Format a single IFCC value for display in the user's effective unit.
    private func formatLab(_ ifcc: Double) -> String {
        profile.formatHbA1c(ifcc)
    }

    // `DateFormatter()` init does real locale/calendar/timezone setup and is
    // documented as expensive to allocate repeatedly — Instruments showed
    // `shortDate(_:)` costing over a second of main-thread time once other,
    // bigger culprits were fixed and this became visible as the next layer.
    // Cached once instead of allocated on every call. (v1.1-hotfix is
    // English-only — no Japanese variant here, unlike v2-dev's version of
    // this fix, since JP localization is out of scope for this patch.)
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f
    }()

    /// Short date string, e.g. "02 Apr".
    private func shortDate(_ date: Date) -> String {
        return Self.shortDateFormatter.string(from: date)
    }

    /// Soft reference-range colour. Uses the same IFCC thresholds as elsewhere
    /// in the app but is rendered as a gentle hue — this is a glucose-management
    /// indicator, not a diagnostic classifier.
    private func rangeColor(forIfcc ifcc: Double) -> Color {
        switch ifcc {
        case ..<39: return .green
        case 39..<48: return .yellow
        case 48...58: return .orange
        default: return .red
        }
    }

    private func formatDisplayValue(_ gmi: GMIResult) -> String {
        if isNgsp {
            return String(format: "%.1f", gmi.gmiNgsp)
        } else {
            return String(format: "%.0f", gmi.gmiIfcc)
        }
    }

    private var unitSuffix: String { profile.effectiveUnit.shortUnit }

    /// The actual GlucoseReadingEntity objects for lab results (for deletion).
    private var labReadingEntities: [GlucoseReadingEntity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.labWindowDays, to: Date()) ?? Date()
        return glucoseReadings.filter { reading in
            guard let ts = reading.timestamp,
                  let unit = reading.unit,
                  let source = reading.source,
                  source == "Hospital Lab Test",
                  (unit == "NGSP %" || unit == "mmol/mol"),
                  ts >= cutoff else { return false }
            return true
        }
        .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    /// Force recalculation of the GMI estimate and run dawn effect detection.
    private func recalculateGMI() {
        isRecalculating = true
        withAnimation(.easeInOut(duration: 0.2)) { recalcFlash = true }

        Task { @MainActor in
            let engine = GmiEstimateEngine()
            let dawnDetected = engine.runPredictionAndSave(context: viewContext)

            // Notify parent view of dawn effect state change
            onDawnEffectUpdated?(dawnDetected)

            // Schedule a local notification if dawn effect is newly detected
            if dawnDetected {
                DawnEffectNotificationManager.scheduleIfNeeded()
            }

            // Hold the spinner for 2 seconds so the user sees the recalculation feedback
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            withAnimation(.easeInOut(duration: 0.3)) {
                recalcFlash = false
                isRecalculating = false
            }
        }
    }

    var body: some View {
        // Reads the cached value computed by `refreshComputedState()`
        // (via .onAppear / .onChange below) rather than recomputing GMI
        // live on every body evaluation.
        let currentGmi = cachedGmiResult

        VStack(spacing: 8) {
            // ── GMI section ──
            HStack(spacing: 5) {
                Image(systemName: "drop.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)
                Text("Glucose Management Indicator")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            if let gmi = currentGmi {
                // Tap the GMI value to force recalculation
                Button(action: recalculateGMI) {
                    HStack(alignment: .center, spacing: 4) {
                        Text(formatDisplayValue(gmi))
                            .font(.largeTitle.bold())
                        Text(unitSuffix)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        if isRecalculating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.leading, 4)
                        }
                    }
                    .foregroundColor(rangeColor(forIfcc: gmi.gmiIfcc))
                    .opacity(recalcFlash ? 0.4 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Tap to recalculate GMI")

                Text("Based on \(gmi.readingCount) glucose readings · last \(gmi.windowDays) days")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Mean glucose: \(Int(gmi.meanMgDl.rounded())) mg/dL")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Tap the value to recalculate · GMI is an FDA-recognized and endorsed glucose-based indicator, not a laboratory HbA1c result.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            } else if let cached = cachedGmi {
                // Insufficient current data but a recent previous GMI exists
                Text("Not enough recent readings to calculate GMI")
                    .font(.body)
                    .foregroundColor(.secondary)

                let displayValue = isNgsp ? String(format: "%.1f", cached.ngsp) : String(format: "%.0f", cached.ifcc)
                Text("Your last GMI, calculated \(cached.daysAgo) \(cached.daysAgo == 1 ? "day" : "days") ago, was \(displayValue) \(unitSuffix)")
                    .font(.callout)
                    .foregroundColor(rangeColor(forIfcc: cached.ifcc))
                    .multilineTextAlignment(.center)

                Text("Log at least \(Self.minReadings) glucose readings in the last \(Self.windowDays) days to update your GMI.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                // No cached GMI at all (first-time user or >30 days stale)
                let daysLogged = ColdStartManager.shared.glucoseDaysLogged

                VStack(spacing: 6) {
                    if daysLogged >= Self.windowDays {
                        // Has enough historical days but not enough RECENT readings
                        Text("Not enough recent readings to calculate GMI")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Log at least \(Self.minReadings) glucose readings in the last \(Self.windowDays) days to see your GMI estimate.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        // True cold start — still building up data
                        let daysRemaining = Self.windowDays - daysLogged
                        Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") to your first GMI")
                            .font(.body.bold())
                            .foregroundColor(.primary)

                        Text("Your GMI estimate needs at least \(Self.minReadings) glucose readings over \(Self.windowDays) days. Keep logging daily and your first estimate will appear here automatically.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Progress bar
                        VStack(spacing: 4) {
                            Text("\(daysLogged) of \(Self.windowDays) days")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemGray4))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue)
                                        .frame(width: geo.size.width * min(Double(daysLogged) / Double(Self.windowDays), 1.0), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }
            }

            // ── Lab HbA1c section ──
            Divider()
                .padding(.top, 4)

            labHbA1cRow
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if let gmi = currentGmi {
                return "Glucose Management Indicator: \(formatDisplayValue(gmi)) \(unitSuffix), based on \(gmi.readingCount) readings over the last \(gmi.windowDays) days."
            } else if let cached = cachedGmi {
                let displayValue = isNgsp ? String(format: "%.1f", cached.ngsp) : String(format: "%.0f", cached.ifcc)
                return "Not enough recent data. Last GMI was \(displayValue) \(unitSuffix), calculated \(cached.daysAgo) days ago."
            } else {
                return "Not enough glucose data yet to compute Glucose Management Indicator."
            }
        }())
        .sheet(isPresented: $showLabSheet) {
            LabResultsSheet(labReadings: labReadingEntities)
        }
        .onAppear {
            refreshComputedState()
            persistGmiToCoreDataIfNeeded()
        }
        .onChange(of: glucoseReadings) { _, _ in
            refreshComputedState()
            persistGmiToCoreDataIfNeeded()
        }
    }

    // MARK: - Lab HbA1c row

    @ViewBuilder
    private var labHbA1cRow: some View {
        let labs = cachedLabResults

        // Centred heading — same visual weight as the GMI section above
        HStack(spacing: 5) {
            Image(systemName: "flask.fill")
                .font(.subheadline)
                .foregroundColor(.blue)
                .accessibilityHidden(true)
            Text("Lab HbA1c")
                .font(.headline)
                .foregroundColor(.secondary)
        }

        if labs.isEmpty {
            Text("No lab results in the last \(Self.labWindowDays) days")
                .font(.body)
                .foregroundColor(.secondary)
        } else if labs.count == 1 {
            let lab = labs[0]
            Button(action: { showLabSheet = true }) {
                Text(formatLab(lab.ifcc))
                    .font(.largeTitle.bold())
                    .foregroundColor(rangeColor(forIfcc: lab.ifcc))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to view and manage lab results")

            Text("\(shortDate(lab.date)) · tap to edit")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            let minIfcc = labs.map(\.ifcc).min()!
            let maxIfcc = labs.map(\.ifcc).max()!
            let latest = labs.last!

            Button(action: { showLabSheet = true }) {
                if abs(minIfcc - maxIfcc) < 0.5 {
                    Text(formatLab(latest.ifcc))
                        .font(.largeTitle.bold())
                        .foregroundColor(rangeColor(forIfcc: latest.ifcc))
                } else {
                    Text("\(formatLab(minIfcc)) – \(formatLab(maxIfcc))")
                        .font(.largeTitle.bold())
                        .foregroundColor(rangeColor(forIfcc: latest.ifcc))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to view and manage lab results")

            Text("\(labs.count) results · \(shortDate(labs.first!.date)) – \(shortDate(latest.date)) · tap to edit")
                .font(.caption)
                .foregroundColor(.secondary)
        }

    }
}

// MARK: - GlucoseTrendChartView (REMOVED)
// The chart has been replaced by a numeric lab HbA1c readout inside GMICardView.
// Plotting 2–3 lab values that differ by fractions of a percent on a chart communicated
// "nothing happened" rather than anything useful. A simple numeric range beneath the GMI
// is more honest and space-efficient.
//
// EventStripView (meal/exercise timeline) was also removed — it was subordinate to the
// chart. A future glucose-curve view will show meal/exercise markers on the intraday
// glucose timeline instead.

// NOTE: GlucoseTrendChartView and EventStripView struct definitions have been removed.
// The chart has been replaced by a numeric lab HbA1c readout inside GMICardView.
// Plotting 2–3 lab values that differ by fractions of a percent produced a visual that
// communicated "nothing happened" rather than anything useful. A simple numeric range
// beneath the GMI is more honest and space-efficient. Check git history to restore.

// MARK: - QuickStatsView Component
/// Display quick statistics in a grid layout with tappable navigation.
private struct QuickStatsView: View {
    let mealsToday: Int
    let exerciseMinutesWeek: Int
    let lastGlucoseReading: GlucoseReadingEntity?
    
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Glucose Card - Compact layout
                NavigationLink(destination: GlucoseLogView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: isLandscape ? 2 : 6) {
                            Image(systemName: "drop.fill")
                                .font(isLandscape ? .caption2 : .body)
                                .foregroundColor(.red)
                                .accessibilityHidden(true)
                            Text("Glucose")
                                .font(isLandscape ? .caption2 : .caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(isLandscape ? 6 : 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Exercise This Week Card - Compact layout
                NavigationLink(destination: ExerciseLogView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(isLandscape ? .caption : .body)
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                            Text("Exercise (week)")
                                .font(isLandscape ? .caption2 : .caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        Text("\(exerciseMinutesWeek) min")
                            .font(isLandscape ? .caption2 : .caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(isLandscape ? 6 : 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                // Meals History Card - Compact layout
                NavigationLink(destination: MealLogView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: isLandscape ? 4 : 6) {
                            Image(systemName: "fork.knife")
                                .font(isLandscape ? .caption : .body)
                                .foregroundColor(.orange)
                                .accessibilityHidden(true)
                            Text("Meals History")
                                .font(isLandscape ? .caption2 : .caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(isLandscape ? 6 : 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // User Card - Compact layout
                NavigationLink(destination: UserProfileView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: isLandscape ? 4 : 6) {
                            Image(systemName: "person.fill")
                                .font(isLandscape ? .caption : .body)
                                .foregroundColor(.green)
                                .accessibilityHidden(true)
                            Text("User")
                                .font(isLandscape ? .caption2 : .caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(isLandscape ? 6 : 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - StatCard Component
/// A small card displaying a single statistic with icon and label.
private struct StatCard: View {
    let title: String
    let value: String
    var unit: String = ""
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - MealQuickActionsView Component
/// Quick action cards for adding meals and planning feasts
private struct MealQuickActionsView: View {
    let onAddMeal: () -> Void
    let onPlanFeast: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: isLandscape ? 6 : 12) {
                // Add Meal Card — simple quick-action, no meal history
                Button(action: onAddMeal) {
                    VStack(alignment: .leading, spacing: 4) {
                        if isLandscape {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .accessibilityHidden(true)
                                Text("Add Meal")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                            }
                            Text("Log what you just ate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundColor(.orange)
                                    .accessibilityHidden(true)
                                Text("Add Meal")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                            }
                            Text("Log what you just ate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(isLandscape ? 6 : 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // What if? Card — navigates to the feast planning tab
                Button(action: onPlanFeast) {
                    VStack(alignment: .leading, spacing: 4) {
                        if isLandscape {
                            HStack(spacing: 4) {
                                Image(systemName: "party.popper.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                                Text("What if?")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                            }
                            Text("Plan Feast Treat")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "party.popper.fill")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                                Text("What if?")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                            }
                            Text("Plan Feast Treat")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(isLandscape ? 6 : 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
        }
    }
}

// MARK: - DashboardActionCardContent Component
/// Shared visual content (icon + title, optional subtitle) for a single
/// dashboard action card. Callers wrap this in a Button or NavigationLink
/// depending on the action, and apply the standard card background/frame.
private struct DashboardActionCardContent: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 80)
        .padding(6)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - LandscapeActionsGrid Component
/// Landscape-only 3-column x 2-row arrangement of all six dashboard action
/// cards, with equal horizontal and vertical gutters throughout:
///   Add Meal | Glucose | Exercise (week)
///   What if? | Meals History | User
private struct LandscapeActionsGrid: View {
    let onAddMeal: () -> Void
    let onPlanFeast: () -> Void
    let exerciseMinutesWeek: Int

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 12) {
                Button(action: onAddMeal) {
                    DashboardActionCardContent(icon: "plus.circle.fill", iconColor: .orange, title: "Add Meal", subtitle: "Log what you just ate")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                NavigationLink(destination: GlucoseLogView()) {
                    DashboardActionCardContent(icon: "drop.fill", iconColor: .red, title: "Glucose", subtitle: nil)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ExerciseLogView()) {
                    DashboardActionCardContent(icon: "figure.walk", iconColor: .blue, title: "Exercise (week)", subtitle: "\(exerciseMinutesWeek) min")
                }
                .buttonStyle(.plain)

                Button(action: onPlanFeast) {
                    DashboardActionCardContent(icon: "party.popper.fill", iconColor: .blue, title: "What if?", subtitle: "Plan Feast Treat")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                NavigationLink(destination: MealLogView()) {
                    DashboardActionCardContent(icon: "fork.knife", iconColor: .orange, title: "Meals History", subtitle: nil)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: UserProfileView()) {
                    DashboardActionCardContent(icon: "person.fill", iconColor: .green, title: "User", subtitle: nil)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Dawn Effect Notice Banner
/// An orange informational notice shown when a consistent early-morning glucose
/// rise pattern is detected without a preceding meal. This is observational —
/// it describes a pattern in the user's data, not a diagnosis.
private struct DawnEffectNoticeBanner: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sunrise.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Pattern noticed: glucose readings between 4–8 AM have been consistently higher than overnight, with no meals logged beforehand.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text("This is sometimes called the \"dawn effect\" — a natural rise in glucose driven by hormones in the early morning. It is common in people with diabetes and does not necessarily indicate a problem. Your GMI value includes these readings as part of its standard calculation.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pattern noticed: early morning glucose readings are consistently higher than overnight readings with no meals logged. Tap for more information.")
    }
}

// MARK: - Stale Data Warning Banner
/// Warning banner displayed when the most recent glucose reading is older than 30 minutes.
/// Alerts the user to check their CGM Bluetooth connection and bridge app.
private struct StaleDataWarningBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.red)
            Text("No glucose data received in the last 30 minutes. Check your CGM Bluetooth connection and bridge app (e.g. Zukka).")
                .font(.caption2)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: No glucose data received in the last 30 minutes. Check your CGM Bluetooth connection.")
    }
}

// MARK: - CGM Dropout Toast View

/// Auto-dismissing toast that slides in from the top of the dashboard when the
/// app detects that a CGM user's readings have stopped arriving for >30 minutes.
///
/// Behaviour:
/// - Appears only when reading density confirms the user is an active CGM user
///   (3+ readings within 45 min in the last 14 days)
/// - Auto-dismisses after 3 seconds; repeats once per hour until the user taps ✕
/// - Tapping ✕ suppresses it for the current dropout episode
/// - The suppression clears automatically when readings resume
private struct CGMDropoutToastView: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
                .foregroundColor(.white)
                .accessibilityHidden(true)
            Text("No CGM readings in 30+ min. Check your Bluetooth and bridge app (e.g. Zukka).")
                .font(.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss CGM connection warning")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.88))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No CGM readings in the last 30 minutes. Check your Bluetooth connection and bridge app.")
    }
}

// MARK: - Wellness Disclaimer Banner
/// A compact disclaimer banner reminding users that this is a wellness app providing estimates only.
/// Displayed wherever HbA1c estimates or trend categories appear.
struct MedicalDisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("Diabetes Feast is a wellness app. Estimates shown are for personal tracking only — not medical diagnoses or treatment advice.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Lab Results Management Sheet
/// Displays all lab HbA1c results with swipe-to-delete.
private struct LabResultsSheet: View {
    let labReadings: [GlucoseReadingEntity]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profile = HbA1cUserProfile.shared
    @State private var readingsToShow: [GlucoseReadingEntity] = []

    private var isNgsp: Bool { profile.effectiveUnit == .ngsp }

    var body: some View {
        NavigationStack {
            List {
                if readingsToShow.isEmpty {
                    Text("No lab results to display.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(readingsToShow, id: \.objectID) { reading in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formattedValue(for: reading))
                                    .font(.title3.bold())
                                    .foregroundColor(colorForReading(reading))

                                if let ts = reading.timestamp {
                                    Text(dateString(ts))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if let unit = reading.unit {
                                Text(unit)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteReadings)
                }

                Section {
                    Text("Swipe left on a result to delete it. This cannot be undone.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Lab HbA1c Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                readingsToShow = labReadings
            }
        }
    }

    private func formattedValue(for reading: GlucoseReadingEntity) -> String {
        guard let unit = reading.unit else { return "—" }
        let value = reading.value
        if unit == "NGSP %" {
            if isNgsp {
                return String(format: "%.1f%%", value)
            } else {
                return String(format: "%.0f mmol/mol", ngspToIFCC(value))
            }
        } else {
            // mmol/mol
            if isNgsp {
                return String(format: "%.1f%%", ifccToNGSP(value))
            } else {
                return String(format: "%.0f mmol/mol", value)
            }
        }
    }

    private func colorForReading(_ reading: GlucoseReadingEntity) -> Color {
        guard let unit = reading.unit else { return .primary }
        let ifcc: Double = unit == "NGSP %" ? ngspToIFCC(reading.value) : reading.value
        switch ifcc {
        case ..<39: return .green
        case 39..<48: return .yellow
        case 48...58: return .orange
        default: return .red
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func deleteReadings(at offsets: IndexSet) {
        for index in offsets {
            let reading = readingsToShow[index]
            viewContext.delete(reading)
        }
        readingsToShow.remove(atOffsets: offsets)

        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            print("[LabResultsSheet] Delete failed: \(error)")
            #endif
        }
    }
}

// MARK: - 14-Day Activity Snapshot Card
/// Displays how many logged meals in the last 14 days had a post-meal
/// exercise session, using a dual-window breakdown:
///   - "Early" = exercise started within 0–90 min of the meal
///   - "Later" = exercise started within 90–180 min of the meal
/// The headline shows the combined total (0–180 min). This captures both
/// people who walk immediately after eating and those who wait for glucose
/// to start rising before heading out.
///
/// Only appears when the user has logged at least 5 meals and 3 exercise
/// sessions in the period — below that there is not enough data for
/// the ratio to be meaningful.
///
/// The card is purely informational: no encouragement, no judgment,
/// just the numbers. It auto-refreshes via Core Data's @FetchRequest
/// and sits on the Dashboard aligned with the 14-day GMI window.
private struct ActivitySnapshotCard: View {
    let meals: FetchedResults<MealEntity>
    let exerciseSessions: FetchedResults<ExerciseSessionEntity>

    /// Window length — matches the GMI calculation period.
    private static let windowDays: Int = 14

    /// Minimum thresholds before displaying the card.
    private static let minMeals: Int = 5
    private static let minExerciseSessions: Int = 3

    /// Dual pairing windows (minutes after meal).
    private static let earlyWindowEnd: Double = 90
    private static let lateWindowEnd: Double = 180

    // MARK: - Computed Data

    /// Meals logged (not planned) in the last 14 days.
    private var recentMeals: [MealEntity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: Date()) ?? Date()
        return meals.filter { meal in
            guard let ts = meal.timestamp else { return false }
            return ts >= cutoff && meal.mealType != "plannedMeal"
        }
    }

    /// Exercise sessions in the last 14 days.
    private var recentExercise: [ExerciseSessionEntity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: Date()) ?? Date()
        return exerciseSessions.filter { session in
            guard let start = session.startDate else { return false }
            return start >= cutoff
        }
    }

    /// Whether the card should be displayed at all.
    private var meetsThreshold: Bool {
        recentMeals.count >= Self.minMeals && recentExercise.count >= Self.minExerciseSessions
    }

    /// Returns the smallest gap (in minutes) between a meal and any subsequent
    /// exercise session, or nil if no exercise falls within the late window.
    private func earliestExerciseGap(for meal: MealEntity) -> Double? {
        guard let mealTime = meal.timestamp else { return nil }
        let gaps = recentExercise.compactMap { session -> Double? in
            guard let exerciseStart = session.startDate else { return nil }
            let gap = exerciseStart.timeIntervalSince(mealTime) / 60.0
            guard gap >= 0 && gap <= Self.lateWindowEnd else { return nil }
            return gap
        }
        return gaps.min()
    }

    /// Breakdown of paired meals into early (0–90 min) and later (90–180 min).
    private var pairingBreakdown: (early: Int, later: Int, total: Int) {
        var early = 0
        var later = 0
        for meal in recentMeals {
            if let gap = earliestExerciseGap(for: meal) {
                if gap <= Self.earlyWindowEnd {
                    early += 1
                } else {
                    later += 1
                }
            }
        }
        return (early: early, later: later, total: early + later)
    }

    /// Total exercise minutes in the 14-day window.
    private var totalExerciseMinutes: Int {
        Int(recentExercise.reduce(0) { $0 + $1.duration })
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }

    // MARK: - Body

    var body: some View {
        if meetsThreshold {
            let breakdown = pairingBreakdown
            let mealCount = recentMeals.count

            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "figure.walk.motion")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .accessibilityHidden(true)
                    Text("14-Day Activity Snapshot")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(breakdown.total)")
                        .font(.title.bold())
                        .foregroundColor(.green)
                    Text("of \(mealCount) meals")
                        .font(.body)
                        .foregroundColor(.primary)
                }

                Text("had a post-meal exercise session logged")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Dual-window breakdown — two-column layout so
                // narrow screens (SE 2020 portrait) break cleanly.
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(breakdown.early) within")
                        Text("90 min")
                    }
                    .foregroundColor(.primary)
                    Text("·")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(breakdown.later) after")
                        Text("90–180 min")
                    }
                    .foregroundColor(.primary)
                }
                .font(.caption)

                Divider()
                    .padding(.vertical, 2)

                HStack(spacing: 16) {
                    Label("\(totalExerciseMinutes) min total", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(recentExercise.count) sessions", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(breakdown.total) of \(mealCount) meals in the last 14 days had a post-meal exercise session. \(breakdown.early) within 90 minutes, \(breakdown.later) between 90 and 180 minutes. \(totalExerciseMinutes) total minutes across \(recentExercise.count) sessions.")
        }
    }
}

// MARK: - Preview
#Preview {
    DashboardView(selectedTab: .constant(.dashboard))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
