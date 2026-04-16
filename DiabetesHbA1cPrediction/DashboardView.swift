import SwiftUI
import Charts
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
    /// Fetch the latest HbA1c prediction. Sorted by date descending to get most recent.
    @FetchRequest(
        entity: HbA1cPredictionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \HbA1cPredictionEntity.predictionDate, ascending: false)]
    ) private var hbA1cPredictions: FetchedResults<HbA1cPredictionEntity>

    /// Fetch glucose readings from the last 7 days for the chart.
    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: false)]
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

    // MARK: - State
    @State private var showPredictionEngine = false
    @State private var isCalculatingPrediction = false
    @State private var showLastMealSheet = false
    // showPlannedMealSheet removed — Plan Meal now switches to the meals tab
    @State private var showPredictionResult = false
    @State private var predictionErrorMessage: String? = nil
    @State private var showPredictionError = false
    @State private var showDawnEffectDetectedAlert = false
    @State private var lastPredictionDate: Date? = nil

    // Timer-driven state for stale data detection
    @State private var currentTime = Date()
    private let staleDataTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// True when glucose readings exist but the most recent is older than 30 minutes
    private var isGlucoseDataStale: Bool {
        guard let latestTimestamp = glucoseReadings.first?.timestamp else { return false }
        return currentTime.timeIntervalSince(latestTimestamp) > 30 * 60
    }

    // Prediction engine instance
    @StateObject private var predictionEngine = HbA1cPredictionEngine()
    
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

                        // Top section: GMI card (from glucose data), notices and disclaimer
                        GMICardView(glucoseReadings: Array(glucoseReadings))

                        if predictionEngine.lastRunAppliedDawnCompensation {
                            DawnEffectNoticeBanner()
                        }

                        if isGlucoseDataStale {
                            StaleDataWarningBanner()
                        }

                        MedicalDisclaimerBanner()

                        // Bottom section: Chart on left, Action cards on right
                        HStack(alignment: .top, spacing: 8) {
                            // Left side: HbA1c Records Chart
                            VStack(spacing: 12) {
                                GlucoseTrendChartView(
                                    meals: Array(meals),
                                    exerciseSessions: Array(exerciseSessions)
                                )
                                .id(meals.count + exerciseSessions.count)
                            }
                            .frame(maxWidth: .infinity)

                            // Right side: Action Cards
                            VStack(spacing: 12) {
                                MealQuickActionsView(
                                    onAddMeal: { showLastMealSheet = true },
                                    onPlanFeast: { selectedTab = .meals }
                                )

                                QuickStatsView(
                                    mealsToday: mealsLoggedToday(),
                                    exerciseMinutesWeek: exerciseMinutesThisWeek(),
                                    lastGlucoseReading: glucoseReadings.first
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)

                        // Full-width Run New Prediction button
                        Button(action: {
                            runNewPrediction()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Run New Prediction")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isCalculatingPrediction)
                        .accessibilityLabel("Run new HbA1c prediction")
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical)
                } else {
                    // MARK: - Portrait Layout (Original)
                    VStack(spacing: 20) {
                        // MARK: - GMI (Glucose Management Indicator) Card
                        GMICardView(glucoseReadings: Array(glucoseReadings))

                        if predictionEngine.lastRunAppliedDawnCompensation {
                            DawnEffectNoticeBanner()
                        }

                        if isGlucoseDataStale {
                            StaleDataWarningBanner()
                        }

                        MedicalDisclaimerBanner()

                        // MARK: - HbA1c Records Chart
                        GlucoseTrendChartView(
                            meals: Array(meals),
                            exerciseSessions: Array(exerciseSessions)
                        )
                        .id(meals.count + exerciseSessions.count)
                        
                        // MARK: - Quick Action Cards for Meals
                        MealQuickActionsView(
                            onAddMeal: { showLastMealSheet = true },
                            onPlanFeast: { selectedTab = .meals }
                        )

                        // MARK: - Quick Stats Grid
                        QuickStatsView(
                            mealsToday: mealsLoggedToday(),
                            exerciseMinutesWeek: exerciseMinutesThisWeek(),
                            lastGlucoseReading: glucoseReadings.first
                        )

                        // MARK: - Action Button
                        Button(action: {
                            runNewPrediction()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Run New Prediction")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isCalculatingPrediction)
                        .accessibilityLabel("Run new HbA1c prediction")
                        .padding(.horizontal)

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
            .alert("Prediction Complete", isPresented: $showPredictionResult) {
                Button("OK", role: .cancel) { }
            } message: {
                if let prediction = hbA1cPredictions.first {
                    let exerciseEffect = getExerciseEffect(from: prediction)
                    Text("Your estimated HbA1c is \(HbA1cUserProfile.shared.formatHbA1c(prediction.predictedValue))\n\nExercise effect: \(exerciseEffect)")
                } else {
                    Text("Prediction saved successfully.")
                }
            }
            .alert("Prediction Error", isPresented: $showPredictionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(predictionErrorMessage ?? "An unknown error occurred.")
            }
            .alert("Dawn Effect Detected", isPresented: $showDawnEffectDetectedAlert) {
                Button("Enable adjustment") {
                    // Save dawn effect preference — user should also enable in profile
                    UserDefaults.standard.set(true, forKey: "dawnEffectAlertDismissed")
                }
                Button("Dismiss", role: .cancel) {
                    UserDefaults.standard.set(true, forKey: "dawnEffectAlertDismissed")
                }
            } message: {
                Text("Your early morning readings appear consistently elevated without meals. This pattern is sometimes called the dawn effect. The app has noted this in your wellness estimate. You may find it interesting to share this observation with your healthcare provider. You can enable or disable this in your profile under Health Conditions.")
            }
            .onReceive(staleDataTimer) { time in
                currentTime = time
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
    private func mealsLoggedToday() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return meals.filter { meal in
            guard let mealDate = meal.timestamp else { return false }
            return calendar.startOfDay(for: mealDate) == today
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

    /// Trigger the HbA1cPredictionEngine to calculate a new prediction.
    /// This method calls the prediction engine and saves the result
    /// to Core Data as a new HbA1cPredictionEntity.
    private func runNewPrediction() {
        // Cooldown guard — ignore repeated taps within 5 minutes
        if let last = lastPredictionDate, Date().timeIntervalSince(last) < 300 {
            return
        }

        isCalculatingPrediction = true

        // Run prediction on main thread (Core Data context is main queue bound)
        let result = predictionEngine.runPredictionAndSave(context: viewContext)
        
        isCalculatingPrediction = false
        
        if let _ = result {
            // Success - the FetchRequest will automatically update the UI
            lastPredictionDate = Date()
            showPredictionResult = true

            // Show dawn effect detection alert if pattern found but user hasn't explicitly enabled it in profile
            if predictionEngine.lastRunDetectedDawnEffect && predictionEngine.lastRunAppliedDawnCompensation && !UserDefaults.standard.bool(forKey: "dawnEffectAlertDismissed") {
                showDawnEffectDetectedAlert = true
            }
        } else {
            // Error - show alert with helpful message
            predictionErrorMessage = "Unable to run prediction. Please ensure you have:\n• At least one glucose reading\n• User profile information set up"
            showPredictionError = true
        }
    }
    
    /// Extracts exercise effect from prediction's contributing factors JSON
    private func getExerciseEffect(from prediction: HbA1cPredictionEntity) -> String {
        guard let jsonData = prediction.contributingFactorsJSON,
              let factors = try? JSONDecoder().decode([String: Double].self, from: jsonData) else {
            return "No data"
        }
        
        // Check for exercise-related factors
        let cardioEffect = factors["Cardio Exercise"] ?? 0
        let otherExerciseEffect = factors["Other Exercise"] ?? 0
        let totalExerciseEffect = factors["Exercise Benefits"] ?? 0
        
        if totalExerciseEffect != 0 {
            return String(format: "%.2f%% (Cardio: %.2f%%, Other: %.2f%%)", totalExerciseEffect, cardioEffect, otherExerciseEffect)
        } else if cardioEffect != 0 || otherExerciseEffect != 0 {
            return String(format: "Cardio: %.2f%%, Other: %.2f%%", cardioEffect, otherExerciseEffect)
        } else {
            return "None detected"
        }
    }
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
/// over a rolling 14-day window. Intentionally labelled "GMI," not "HbA1c," to
/// match Dexcom / FreeStyle Libre precedent and FDA guidance on terminology.
private struct GMICardView: View {
    let glucoseReadings: [GlucoseReadingEntity]
    @ObservedObject private var profile = HbA1cUserProfile.shared

    /// Rolling window length used for GMI computation.
    /// Bergenstal 2018 validates the formula on 10–14 day CGM windows.
    private static let windowDays: Int = 14

    /// Minimum reading count before we consider GMI informative.
    /// Below this we render a "not enough data" placeholder instead.
    private static let minReadings: Int = 20

    private var isNgsp: Bool { profile.effectiveUnit == .ngsp }

    /// Compute GMI from mg/dL readings within the last `windowDays` days.
    /// Returns nil when there is insufficient glucose data.
    private var gmi: GMIResult? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: Date()) ?? Date()
        let windowReadings = glucoseReadings.filter { reading in
            guard let ts = reading.timestamp, let unit = reading.unit else { return false }
            // Only mg/dL glucose points — ignore lab HbA1c entries ("NGSP %" / "mmol/mol").
            return unit == "mg/dL" && ts >= cutoff
        }
        guard windowReadings.count >= Self.minReadings else { return nil }

        let mean = windowReadings.reduce(0.0) { $0 + $1.value } / Double(windowReadings.count)
        let meanMmol = GMIComputer.mmolPerL(fromMgDl: mean)
        return GMIResult(
            gmiNgsp: GMIComputer.gmiPercent(meanMgDl: mean),
            gmiIfcc: GMIComputer.gmiMmol(meanMmolL: meanMmol),
            meanMgDl: mean,
            readingCount: windowReadings.count,
            windowDays: Self.windowDays
        )
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

    var body: some View {
        VStack(spacing: 8) {
            Text("Glucose Management Indicator")
                .font(.headline)
                .foregroundColor(.secondary)

            if let gmi = gmi {
                HStack(alignment: .center, spacing: 4) {
                    Text(formatDisplayValue(gmi))
                        .font(.largeTitle.bold())
                    Text(unitSuffix)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(rangeColor(forIfcc: gmi.gmiIfcc))

                Text("Based on \(gmi.readingCount) glucose readings · last \(gmi.windowDays) days")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Mean glucose: \(Int(gmi.meanMgDl.rounded())) mg/dL")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("GMI is a glucose-based indicator, not a laboratory HbA1c result.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            } else {
                Text("Not enough glucose data yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                Text("Log at least \(Self.minReadings) glucose readings in the last \(Self.windowDays) days to see your GMI.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if let gmi = gmi {
                return "Glucose Management Indicator: \(formatDisplayValue(gmi)) \(unitSuffix), based on \(gmi.readingCount) readings over the last \(gmi.windowDays) days."
            } else {
                return "Not enough glucose data yet to compute Glucose Management Indicator."
            }
        }())
    }
}

// MARK: - GlucoseTrendChartView Component
/// A chart displaying the user's own HbA1c records over a rolling 12-week (84-day) window.
///
/// The chart shows the user's actual lab HbA1c results (blue diamonds), connected by
/// a dashed straight-line interpolation between adjacent results. The line ends at the
/// most recent lab result — it does not extend past the user's last real measurement.
/// Meal and exercise log entries appear as small icons on a separate event strip below
/// the chart. They are displayed as contextual events alongside the records — they are
/// not inputs to the line.
///
/// Y-axis values on the right; unit legend on the left.
/// US/Japan: displays NGSP %, scale 3–11
/// Other regions: displays IFCC mmol/mol, scale 20–60
private struct GlucoseTrendChartView: View {
    let meals: [MealEntity]
    let exerciseSessions: [ExerciseSessionEntity]

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ObservedObject private var profile = HbA1cUserProfile.shared
    private var isLandscape: Bool { verticalSizeClass == .compact }

    /// Use the user's effective unit preference for display
    private var isNgsp: Bool { profile.effectiveUnit == .ngsp }

    /// Y-axis label string
    private var yAxisLabel: String { isNgsp ? "NGSP %" : "IFCC mmol/mol" }

    /// Y-axis domain
    private var yAxisDomain: ClosedRange<Double> { isNgsp ? 3.0...11.0 : 20.0...60.0 }

    /// Explicit y-axis tick values
    private var yAxisTicks: [Double] {
        isNgsp ? [3.0, 5.0, 7.0, 9.0, 11.0] : [20.0, 40.0, 60.0]
    }

    /// Convert a stored IFCC value to the display unit
    private func displayValue(forIfcc ifcc: Double) -> Double {
        isNgsp ? ifccToNGSP(ifcc) : ifcc
    }

    /// Format a lab HbA1c display value with its unit suffix.
    /// NGSP uses 1 decimal place, IFCC uses 0 decimal places.
    private func formatLabValue(_ value: Double) -> String {
        if isNgsp {
            return String(format: "%.1f %%", value)
        } else {
            return String(format: "%.0f mmol/mol", value)
        }
    }

    /// Format a lab result date as "02 Apr 2026".
    private func formatLabDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }

    /// The start of the 12-week rolling window (84 days back from today)
    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -84, to: Date()) ?? Date()
    }

    /// Generate every-other-week boundary dates for the x-axis (7 labels across 12 weeks)
    private var weekBoundaries: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: windowStart)
        return stride(from: 0, through: 12, by: 3).compactMap { week in
            calendar.date(byAdding: .day, value: week * 7, to: start)
        }
    }

    /// Actual Lab HbA1c results recorded within the 12-week window.
    /// Fetched from GlucoseReadingEntity where source == "Hospital Lab Test"
    /// and unit is "NGSP %" or "mmol/mol". Plotted as blue diamonds on the chart.
    private var labPoints: [(date: Date, display: Double)] {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlucoseReadingEntity")

        let unitPredicate = NSPredicate(format: "unit IN %@", ["NGSP %", "mmol/mol"])
        let sourcePredicate = NSPredicate(format: "source == %@", "Hospital Lab Test")
        let datePredicate = NSPredicate(format: "timestamp >= %@", windowStart as NSDate)

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            unitPredicate, sourcePredicate, datePredicate
        ])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        do {
            guard let results = try viewContext.fetch(fetchRequest) as? [NSManagedObject] else {
                return []
            }
            return results.compactMap { object in
                guard let value = object.value(forKey: "value") as? NSNumber,
                      let unit = object.value(forKey: "unit") as? String,
                      let timestamp = object.value(forKey: "timestamp") as? Date else {
                    return nil
                }
                // Convert to IFCC mmol/mol first (canonical), then to display unit
                let ifccValue: Double
                if unit == "NGSP %" {
                    ifccValue = ngspToIFCC(value.doubleValue)
                } else {
                    ifccValue = value.doubleValue
                }
                return (date: timestamp, display: displayValue(forIfcc: ifccValue))
            }
        } catch {
            #if DEBUG
            print("Error fetching Lab HbA1c readings for chart: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Meal events within the visible window, used for the event strip below the chart.
    /// Meals are displayed only as contextual markers on the time axis — they are not
    /// inputs to the line and do not affect any displayed value.
    private var mealEvents: [(date: Date, id: NSManagedObjectID)] {
        let lastDate = labPoints.last?.date ?? Date()
        return meals.compactMap { meal in
            guard let timestamp = meal.timestamp,
                  timestamp >= windowStart,
                  timestamp <= lastDate else { return nil }
            return (date: timestamp, id: meal.objectID)
        }
    }

    /// Exercise events within the visible window, used for the event strip below the chart.
    /// Exercise sessions are displayed only as contextual markers on the time axis —
    /// they are not inputs to the line and do not affect any displayed value.
    private var exerciseEvents: [(date: Date, id: NSManagedObjectID)] {
        let lastDate = labPoints.last?.date ?? Date()
        return exerciseSessions.compactMap { session in
            guard let timestamp = session.startDate,
                  timestamp >= windowStart,
                  timestamp <= lastDate else { return nil }
            return (date: timestamp, id: session.objectID)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your HbA1c Records")
                        .font(.headline)

                    if let latest = labPoints.last {
                        Text("Most recent: \(formatLabValue(latest.display)) · \(formatLabDate(latest.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Most recent HbA1c result: \(formatLabValue(latest.display)) on \(formatLabDate(latest.date))")
                    }
                }

                Spacer()

                // Legend: lab diamond + dashed connector
                if !labPoints.isEmpty {
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "diamond.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                            Text("Lab result")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 3) {
                            // Small dashed-line glyph for the legend
                            Rectangle()
                                .fill(Color.secondary.opacity(0.6))
                                .frame(width: 14, height: 1)
                                .overlay(
                                    HStack(spacing: 2) {
                                        Rectangle().fill(Color(.systemGray6)).frame(width: 3, height: 1)
                                        Spacer()
                                        Rectangle().fill(Color(.systemGray6)).frame(width: 3, height: 1)
                                    }
                                )
                            Text("Between results")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, isLandscape ? 8 : 0)

            if labPoints.isEmpty {
                Text("Enter a lab HbA1c result to see your records here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    // Dashed line connecting adjacent lab results.
                    // The line stops at the most recent lab — it does not extend
                    // past the user's last real measurement.
                    ForEach(labPoints, id: \.date) { lab in
                        LineMark(
                            x: .value("Date", lab.date, unit: .day),
                            y: .value(yAxisLabel, lab.display)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }

                    // Lab HbA1c results — solid blue diamonds at the actual measurement dates
                    ForEach(labPoints, id: \.date) { lab in
                        PointMark(
                            x: .value("Date", lab.date, unit: .day),
                            y: .value(yAxisLabel, lab.display)
                        )
                        .foregroundStyle(Color.blue)
                        .symbol(.diamond)
                        .symbolSize(70)
                    }
                }
                .chartXScale(domain: windowStart...Date())
                .chartYScale(domain: yAxisDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: yAxisTicks) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: weekBoundaries) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                            .font(.caption2)
                    }
                }
                .frame(height: isLandscape ? 160 : 120)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .leading) {
                    Text(yAxisLabel)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .offset(x: -12)
                }
                .padding(.horizontal)
                .accessibilityLabel("Your HbA1c records chart with \(labPoints.count) lab results")

                // Event strip — meals and exercise as contextual markers on the same time axis.
                // These are not inputs to the line; they are shown only for context.
                EventStripView(
                    windowStart: windowStart,
                    windowEnd: labPoints.last?.date ?? Date(),
                    weekBoundaries: weekBoundaries,
                    mealEvents: mealEvents,
                    exerciseEvents: exerciseEvents
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - EventStripView Component
/// A thin strip showing meal and exercise log entries as small icons on the same
/// time axis as the records chart above. Purely contextual — not an analytic display.
private struct EventStripView: View {
    let windowStart: Date
    let windowEnd: Date
    let weekBoundaries: [Date]
    let mealEvents: [(date: Date, id: NSManagedObjectID)]
    let exerciseEvents: [(date: Date, id: NSManagedObjectID)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "fork.knife")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Meal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Exercise")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Chart {
                ForEach(mealEvents, id: \.id) { event in
                    PointMark(
                        x: .value("Date", event.date, unit: .day),
                        y: .value("Type", "Meal")
                    )
                    .symbol(.circle)
                    .symbolSize(28)
                    .foregroundStyle(Color.orange.opacity(0.85))
                }
                ForEach(exerciseEvents, id: \.id) { event in
                    PointMark(
                        x: .value("Date", event.date, unit: .day),
                        y: .value("Type", "Exercise")
                    )
                    .symbol(.circle)
                    .symbolSize(28)
                    .foregroundStyle(Color.green.opacity(0.85))
                }
            }
            .chartXScale(domain: windowStart...Date())
            .chartXAxis {
                AxisMarks(values: weekBoundaries) { _ in
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
            .frame(height: 44)
            .accessibilityLabel("Meal and exercise events on the same timeline as your HbA1c records, shown for context only")
        }
    }
}

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
                    .frame(height: 80)
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
                            Text(isLandscape ? "Xcise" : "Exercise")
                                .font(isLandscape ? .caption2 : .caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        Text("(Week)")
                            .font(isLandscape ? .caption2 : .caption)
                            .fontWeight(.semibold)
                        Text("\(exerciseMinutesWeek) min")
                            .font(isLandscape ? .caption2 : .caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
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
                    .frame(height: 80)
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
                    .frame(height: 80)
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
                                Text("Add")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            HStack(spacing: 4) {
                                Text("Meal")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("What")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("u just ate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
                    .frame(height: 80)
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
                                Text("What")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            Text("if?")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
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
                    .frame(height: 80)
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

// MARK: - Dawn Effect Notice Banner
/// An orange notice displayed when dawn effect compensation is active.
/// Shown between the HbA1c card and the medical disclaimer.
private struct DawnEffectNoticeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "sunrise.fill")
                .font(.caption2)
                .foregroundColor(.orange)
            Text("Dawn effect adjustment applied — morning readings weighted at 60%")
                .font(.caption2)
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dawn effect adjustment applied. Morning readings weighted at 60 percent.")
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

// MARK: - Preview
#Preview {
    DashboardView(selectedTab: .constant(.dashboard))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
