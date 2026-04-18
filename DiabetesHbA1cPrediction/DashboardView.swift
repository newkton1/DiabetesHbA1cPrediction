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
    @State private var showLastMealSheet = false

    // Timer-driven state for stale data detection
    @State private var currentTime = Date()
    private let staleDataTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// True when glucose readings exist but the most recent is older than 30 minutes
    private var isGlucoseDataStale: Bool {
        guard let latestTimestamp = glucoseReadings.first?.timestamp else { return false }
        return currentTime.timeIntervalSince(latestTimestamp) > 30 * 60
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

                        // Top section: GMI card (from glucose data), notices and disclaimer
                        GMICardView(glucoseReadings: Array(glucoseReadings))

                        if isGlucoseDataStale {
                            StaleDataWarningBanner()
                        }

                        MedicalDisclaimerBanner()

                        // Action cards side by side in landscape
                        HStack(alignment: .top, spacing: 8) {
                            MealQuickActionsView(
                                onAddMeal: { showLastMealSheet = true },
                                onPlanFeast: { selectedTab = .meals }
                            )
                            .frame(maxWidth: .infinity)

                            QuickStatsView(
                                mealsToday: mealsLoggedToday(),
                                exerciseMinutesWeek: exerciseMinutesThisWeek(),
                                lastGlucoseReading: glucoseReadings.first
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical)
                } else {
                    // MARK: - Portrait Layout (Original)
                    VStack(spacing: 20) {
                        // MARK: - GMI (Glucose Management Indicator) Card
                        GMICardView(glucoseReadings: Array(glucoseReadings))

                        if isGlucoseDataStale {
                            StaleDataWarningBanner()
                        }

                        MedicalDisclaimerBanner()

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
    @ObservedObject private var profile = HbA1cUserProfile.shared

    /// Rolling window length used for GMI computation.
    /// Bergenstal 2018 validates the formula on 10–14 day CGM windows.
    private static let windowDays: Int = 14

    /// Minimum reading count before we consider GMI informative.
    /// Below this we render a "not enough data" placeholder instead.
    private static let minReadings: Int = 20

    /// Lab HbA1c lookback window — matches the 90-day red-cell pool biology.
    private static let labWindowDays: Int = 90

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

    // MARK: - Lab HbA1c helpers

    /// Lab HbA1c results recorded in the last 90 days, sorted oldest → newest.
    /// Each value is converted to the canonical IFCC mmol/mol for comparison,
    /// then to the user's display unit when rendered.
    private var labResults: [(date: Date, ifcc: Double)] {
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

    /// Short date string, e.g. "02 Apr".
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
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
            if let gmi = gmi {
                return "Glucose Management Indicator: \(formatDisplayValue(gmi)) \(unitSuffix), based on \(gmi.readingCount) readings over the last \(gmi.windowDays) days."
            } else {
                return "Not enough glucose data yet to compute Glucose Management Indicator."
            }
        }())
    }

    // MARK: - Lab HbA1c row

    @ViewBuilder
    private var labHbA1cRow: some View {
        let labs = labResults

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
            Text(formatLab(lab.ifcc))
                .font(.largeTitle.bold())
                .foregroundColor(rangeColor(forIfcc: lab.ifcc))

            Text("\(shortDate(lab.date))")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            let minIfcc = labs.map(\.ifcc).min()!
            let maxIfcc = labs.map(\.ifcc).max()!
            let latest = labs.last!

            if abs(minIfcc - maxIfcc) < 0.5 {
                // Values essentially identical — show single value
                Text(formatLab(latest.ifcc))
                    .font(.largeTitle.bold())
                    .foregroundColor(rangeColor(forIfcc: latest.ifcc))
            } else {
                Text("\(formatLab(minIfcc)) – \(formatLab(maxIfcc))")
                    .font(.largeTitle.bold())
                    .foregroundColor(rangeColor(forIfcc: latest.ifcc))
            }

            Text("\(labs.count) results · \(shortDate(labs.first!.date)) – \(shortDate(latest.date))")
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
