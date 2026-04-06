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

                        // Top section: Full-width HbA1c card with notices
                        HbA1cCardView(prediction: hbA1cPredictions.first)

                        if predictionEngine.lastRunAppliedDawnCompensation {
                            DawnEffectNoticeBanner()
                        }

                        if isGlucoseDataStale {
                            StaleDataWarningBanner()
                        }

                        MedicalDisclaimerBanner()

                        // Bottom section: Chart on left, Action cards on right
                        HStack(alignment: .top, spacing: 8) {
                            // Left side: Glucose Trend Chart
                            VStack(spacing: 12) {
                                if !hbA1cPredictions.isEmpty {
                                    GlucoseTrendChartView(predictions: Array(hbA1cPredictions))
                                        .id(hbA1cPredictions.count)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                        .frame(height: 200)
                                        .overlay(
                                            Text("No glucose data")
                                                .foregroundColor(.secondary)
                                        )
                                        .padding(.horizontal)
                                }
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
                        // MARK: - HbA1c Display Card
                        HbA1cCardView(prediction: hbA1cPredictions.first)

                        if predictionEngine.lastRunAppliedDawnCompensation {
                            DawnEffectNoticeBanner()
                        }

                        if isGlucoseDataStale {
                            StaleDataWarningBanner()
                        }

                        MedicalDisclaimerBanner()

                        // MARK: - HbA1c Trend Chart
                        if !hbA1cPredictions.isEmpty {
                            GlucoseTrendChartView(predictions: Array(hbA1cPredictions))
                                .id(hbA1cPredictions.count)
                        }
                        
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
                Text("Your early morning readings appear consistently elevated without meals. This pattern is sometimes called the dawn effect and affects about 20% of Type 2 diabetics. The app has adjusted your HbA1c estimate to account for this. We recommend discussing this with your endocrinologist. You can enable or disable this in your profile under Health Conditions.")
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

// MARK: - HbA1cCardView Component
/// A prominent card displaying the current estimated HbA1c value
/// with color coding based on risk level.
/// Uses IFCC (mmol/mol) internally and displays in user's preferred unit.
private struct HbA1cCardView: View {
    let prediction: HbA1cPredictionEntity?
    @ObservedObject private var profile = HbA1cUserProfile.shared

    /// Determine the color based on HbA1c value (using IFCC thresholds).
    /// Thresholds in IFCC mmol/mol:
    /// - Green: < 39 (non-diabetic, <5.7%)
    /// - Yellow: 39-47 (prediabetic, 5.7-6.4%)
    /// - Orange: 48-58 (diabetic controlled, 6.5-7.5%)
    /// - Red: > 58 (above target, >7.5%)
    private var hbA1cColor: Color {
        guard let prediction = prediction else { return .gray }
        let ifccValue = prediction.predictedValue

        switch ifccValue {
        case ..<39:
            return .green
        case 39..<48:
            return .yellow
        case 48...58:
            return .orange
        default:
            return .red
        }
    }

    /// Get the risk category text for the current HbA1c value (using IFCC thresholds).
    private var riskCategoryText: String {
        guard let prediction = prediction else { return "No Data" }
        return HbA1cThresholds.riskCategory(forIFCC: prediction.predictedValue)
    }
    
    /// Get the display value in the user's preferred unit
    private var displayValue: String {
        guard let prediction = prediction else { return "--" }
        let ifccValue = prediction.predictedValue
        let displayVal = fromCanonicalIFCC(value: ifccValue, to: profile.effectiveUnit)
        
        switch profile.effectiveUnit {
        case .ngsp:
            return String(format: "%.1f", displayVal)
        case .ifcc:
            return String(format: "%.0f", displayVal)
        }
    }
    
    /// Get the unit suffix for display
    private var unitSuffix: String {
        profile.effectiveUnit.shortUnit
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Estimated HbA1c")
                .font(.headline)
                .foregroundColor(.secondary)

            if let prediction = prediction {
                HStack(alignment: .center, spacing: 4) {
                    Text(displayValue)
                        .font(.largeTitle.bold())
                    Text(unitSuffix)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(hbA1cColor)

                Text("Last updated: \(formatDate(prediction.predictionDate ?? Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No prediction data")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(prediction != nil ? "Estimated HbA1c: \(displayValue) \(unitSuffix), \(riskCategoryText)" : "No prediction data available")
    }

    /// Format a date for display.
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - GlucoseTrendChartView Component
/// A chart displaying HbA1c predictions over a rolling 12-week (84-day) window.
/// Plots one data point per week — the latest stored HbA1cPredictionEntity for each
/// 7-day period — so the chart and the headline figure always agree.
/// Data fills from the left as weeks accumulate; once all 12 weeks are populated
/// the oldest week drops off the left edge as new weeks arrive.
/// Y-axis values on the right; unit legend on the left (matching blood glucose chart style).
/// US/Japan: displays NGSP %, scale 3–11
/// Other regions: displays IFCC mmol/mol, scale 20–60
private struct GlucoseTrendChartView: View {
    let predictions: [HbA1cPredictionEntity]

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

    /// Color based on IFCC thresholds (unit-independent)
    private func pointColor(forIfcc ifcc: Double) -> Color {
        switch ifcc {
        case ..<39:   return .green
        case 39..<48: return .yellow
        case 48...58: return .orange
        default:      return .red
        }
    }

    /// Convert a stored IFCC value to the display unit
    private func displayValue(forIfcc ifcc: Double) -> Double {
        isNgsp ? ifccToNGSP(ifcc) : ifcc
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

    /// Chart data: one point per week — the latest prediction within each 7-day bucket.
    /// Weeks with no prediction are simply absent, so the line connects only populated weeks.
    private var weeklyPoints: [(weekStart: Date, display: Double, ifcc: Double)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: windowStart)

        // Build weekly buckets (12 full weeks + current partial week at index 12)
        var buckets: [Int: (latest: Date, ifcc: Double)] = [:]
        for prediction in predictions {
            guard let date = prediction.predictionDate, date >= start else { continue }
            let daysSinceStart = calendar.dateComponents([.day], from: start, to: date).day ?? 0
            let weekIndex = daysSinceStart / 7
            guard weekIndex >= 0 && weekIndex <= 12 else { continue }

            if let existing = buckets[weekIndex] {
                if date > existing.latest {
                    buckets[weekIndex] = (latest: date, ifcc: prediction.predictedValue)
                }
            } else {
                buckets[weekIndex] = (latest: date, ifcc: prediction.predictedValue)
            }
        }

        // Convert buckets to chart points, using the week's start date for even spacing
        return buckets.compactMap { weekIndex, data in
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: start) else {
                return nil
            }
            return (weekStart: weekStart, display: displayValue(forIfcc: data.ifcc), ifcc: data.ifcc)
        }.sorted { $0.weekStart < $1.weekStart }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("12-Week HbA1c Trend")
                    .font(.headline)

                Spacer()

                // Legend: prediction circle (color matches latest point) + lab diamond
                if !labPoints.isEmpty {
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(weeklyPoints.last.map { pointColor(forIfcc: $0.ifcc) } ?? Color.yellow)
                                .frame(width: 7, height: 7)
                            Text("Predicted")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "diamond.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                            Text("Lab")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, isLandscape ? 8 : 0)

            if weeklyPoints.isEmpty {
                Text("Run predictions over time to see your trend here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    ForEach(weeklyPoints, id: \.weekStart) { item in
                        LineMark(
                            x: .value("Week", item.weekStart, unit: .day),
                            y: .value(yAxisLabel, item.display)
                        )
                        .foregroundStyle(pointColor(forIfcc: item.ifcc))
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Week", item.weekStart, unit: .day),
                            y: .value(yAxisLabel, item.display)
                        )
                        .foregroundStyle(pointColor(forIfcc: item.ifcc))
                        .symbolSize(40)
                    }

                    // Lab HbA1c results — blue diamonds overlaid on the trend line
                    ForEach(labPoints, id: \.date) { lab in
                        PointMark(
                            x: .value("Week", lab.date, unit: .day),
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
                .accessibilityLabel("12-week HbA1c trend chart with \(weeklyPoints.count) data points")
            }
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

// MARK: - Medical Disclaimer Banner
/// A compact disclaimer banner reminding users that predictions are not medical advice.
/// Displayed wherever HbA1c predictions or risk categories appear.
struct MedicalDisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("For informational purposes only — not a substitute for professional medical advice.")
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
