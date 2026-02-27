import SwiftUI
import Charts
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
    @State private var showPlannedMealSheet = false
    @State private var showPredictionResult = false
    @State private var predictionErrorMessage: String? = nil
    @State private var showPredictionError = false
    
    // Prediction engine instance
    private let predictionEngine = HbA1cPredictionEngine()
    
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
                    VStack(spacing: 16) {
                        // Header with title on left
                        HStack {
                            Text("Dashboard")
                                .font(.system(size: 22, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Split section: Chart + HbA1c card on left, Action cards on right
                        HStack(alignment: .top, spacing: 16) {
                            // Left side: HbA1c Card + Glucose Trend Chart
                            VStack(spacing: 12) {
                                // HbA1c card at top
                                HbA1cCardView(prediction: hbA1cPredictions.first)
                                
                                if !glucoseReadings.isEmpty {
                                    GlucoseTrendChartView(glucoseReadings: Array(glucoseReadings))
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
                                    lastMeal: lastLoggedMeal,
                                    nextPlannedMeal: nextPlannedMeal,
                                    onLogLastMeal: { showLastMealSheet = true },
                                    onPlanMeal: { showPlannedMealSheet = true }
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
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical)
                } else {
                    // MARK: - Portrait Layout (Original)
                    VStack(spacing: 20) {
                        // MARK: - HbA1c Display Card
                        HbA1cCardView(prediction: hbA1cPredictions.first)

                        // MARK: - HbA1c Trend Chart
                        if !glucoseReadings.isEmpty {
                            GlucoseTrendChartView(glucoseReadings: Array(glucoseReadings))
                        }
                        
                        // MARK: - Quick Action Cards for Meals
                        MealQuickActionsView(
                            lastMeal: lastLoggedMeal,
                            nextPlannedMeal: nextPlannedMeal,
                            onLogLastMeal: { showLastMealSheet = true },
                            onPlanMeal: { showPlannedMealSheet = true }
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
                            .font(.system(size: 22, weight: .bold))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .sheet(isPresented: $showLastMealSheet) {
                LastMealView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showPlannedMealSheet) {
                PlannedMealView()
                    .environment(\.managedObjectContext, viewContext)
            }
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
        isCalculatingPrediction = true
        
        // Run prediction on main thread (Core Data context is main queue bound)
        let result = predictionEngine.runPredictionAndSave(context: viewContext)
        
        isCalculatingPrediction = false
        
        if let _ = result {
            // Success - the FetchRequest will automatically update the UI
            showPredictionResult = true
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
                        .font(.system(size: 56, weight: .bold))
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
    }

    /// Format a date for display.
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - GlucoseTrendChartView Component
/// A chart displaying the 30-day HbA1c trend using glucose reading dates.
/// US/Japan: converts readings to NGSP % via eAG inverse (Nathan et al. 2008),
///   scale 3–11, tick marks 3,5,7,9,11, legend "NGSP %"
/// Other regions: converts readings to IFCC mmol/mol via eAG inverse then NGSP→IFCC,
///   scale 20–60, tick marks 20,40,60, legend "IFCC mmol/mol"
private struct GlucoseTrendChartView: View {
    let glucoseReadings: [GlucoseReadingEntity]

    /// True when device region is USA or Japan — display NGSP %
    private var isNgspRegion: Bool {
        let region = Locale.current.region?.identifier ?? ""
        return region == "US" || region == "JP"
    }

    /// Convert any stored glucose unit to mg/dL
    private func toMgdl(_ value: Double, unit: String?) -> Double {
        switch unit ?? "mg/dL" {
        case "mmol/L":  return value * 18.0182
        case "NGSP %":  return (value * 28.7) - 46.7
        case "mmol/mol": return (ifccToNGSP(value) * 28.7) - 46.7
        default:        return value  // already mg/dL
        }
    }

    /// Convert mg/dL to chart display value (NGSP % or IFCC mmol/mol)
    private func toDisplayValue(_ mgdl: Double) -> Double {
        let ngsp = (mgdl + 46.7) / 28.7
        return isNgspRegion ? ngsp : ngspToIFCC(ngsp)
    }

    /// Y-axis label string
    private var yAxisLabel: String { isNgspRegion ? "NGSP %" : "IFCC mmol/mol" }

    /// Y-axis domain
    private var yAxisDomain: ClosedRange<Double> { isNgspRegion ? 3.0...11.0 : 20.0...60.0 }

    /// Explicit y-axis tick values
    private var yAxisTicks: [Double] {
        isNgspRegion ? [3.0, 5.0, 7.0, 9.0, 11.0] : [20.0, 40.0, 60.0]
    }

    /// Color based on IFCC thresholds (unit-independent)
    private func lineColor(forIfcc ifcc: Double) -> Color {
        switch ifcc {
        case ..<39:   return .green
        case 39..<48: return .yellow
        case 48...58: return .orange
        default:      return .red
        }
    }

    /// Group readings by day, average within last 30 days, return as display values
    private var dailyPoints: [(day: Date, display: Double, ifcc: Double)] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var groupedByDay: [Date: [Double]] = [:]
        for reading in glucoseReadings {
            guard let date = reading.timestamp, date >= cutoff else { continue }
            let day = calendar.startOfDay(for: date)
            let mgdl = toMgdl(reading.value, unit: reading.unit)
            groupedByDay[day, default: []].append(mgdl)
        }
        return groupedByDay.map { day, mgdlValues in
            let avgMgdl = mgdlValues.reduce(0, +) / Double(mgdlValues.count)
            let ngsp = (avgMgdl + 46.7) / 28.7
            let ifcc = ngspToIFCC(ngsp)
            return (day: day, display: toDisplayValue(avgMgdl), ifcc: ifcc)
        }.sorted { $0.day < $1.day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("30-Day HbA1c Trend")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(dailyPoints, id: \.day) { item in
                    LineMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value(yAxisLabel, item.display)
                    )
                    .foregroundStyle(lineColor(forIfcc: item.ifcc))
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value(yAxisLabel, item.display)
                    )
                    .foregroundStyle(lineColor(forIfcc: item.ifcc))
                    .symbolSize(40)
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisTicks) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .font(.system(size: 9))
                }
            }
            .frame(height: 120)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(alignment: .leading) {
                VStack(spacing: 0) {
                    ForEach(Array(yAxisLabel.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .offset(x: 4)
            }
            .padding(.horizontal)
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
                // Meals Today Card - Compact layout
                NavigationLink(destination: MealLogView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon + "Meals/Meal" on same line
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(.body)
                                .foregroundColor(.orange)
                            Text(isLandscape ? "Meal" : "Meals")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        // "Today" on next line
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.semibold)
                        // Count
                        Text(String(mealsToday))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Exercise This Week Card - Compact layout
                NavigationLink(destination: ExerciseLogView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon + "Exercise/Xcise" on same line
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.body)
                                .foregroundColor(.blue)
                            Text(isLandscape ? "Xcise" : "Exercise")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        // "(Week)" on next line
                        Text("(Week)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        // Minutes with abbreviated unit
                        Text("\(exerciseMinutesWeek) min")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                // Sugar Values Card - Compact layout
                NavigationLink(destination: GlucoseLogView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon + "Sugar" on same line
                        HStack(spacing: isLandscape ? 4 : 6) {
                            Image(systemName: "drop.fill")
                                .font(isLandscape ? .caption : .body)
                                .foregroundColor(.red)
                            Text("Sugar")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        // "Values" on next line
                        Text("Values")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // User Profile Card - Compact layout
                NavigationLink(destination: UserProfileView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon + "User" on same line
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.body)
                                .foregroundColor(.green)
                            Text("User")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        // "Profile" on next line
                        Text("Profile")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
                    .padding(10)
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
/// Quick action cards for logging and planning meals
private struct MealQuickActionsView: View {
    let lastMeal: MealEntity?
    let nextPlannedMeal: MealEntity?
    let onLogLastMeal: () -> Void
    let onPlanMeal: () -> Void
    
    private var lastMealCarbs: Double {
        guard let meal = lastMeal,
              let macros = meal.macronutrients as? Set<MacronutrientEntity> else { return 0 }
        return macros.filter { $0.type == "carbohydrates" || $0.type == "carbs" }.reduce(0) { $0 + $1.amount }
    }
    
    private var plannedMealCarbs: Double {
        guard let meal = nextPlannedMeal,
              let macros = meal.macronutrients as? Set<MacronutrientEntity> else { return 0 }
        return macros.filter { $0.type == "carbohydrates" || $0.type == "carbs" }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Log Last Meal Card - Compact layout
                Button(action: onLogLastMeal) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon + "Log" on same line
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.body)
                                .foregroundColor(.orange)
                            Text("Log")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        // "Last Meal" on second line
                        Text("Last Meal")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let meal = lastMeal {
                            // Meal name + carbs on separate lines, smaller font
                            Text(meal.name ?? "Recent meal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text("\(Int(lastMealCarbs)) g carbs")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("What did you eat?")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Plan Meal Card - Compact layout
                Button(action: onPlanMeal) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon + "Plan" on same line
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.body)
                                .foregroundColor(.blue)
                            Text("Plan")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        // "Meal" on second line
                        Text("Meal")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let meal = nextPlannedMeal, let plannedDate = meal.plannedDateTime {
                            // Meal name + time on separate lines, smaller font
                            Text(meal.name ?? "Planned meal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(plannedDate, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else {
                            Text("Impact")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
                    .padding(10)
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

// MARK: - Preview
#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
