//
//  SimilarImpactView.swift
//  DiabetesHbA1cPrediction
//
//  Displays the historical glucose pattern for meals with similar
//  glycaemic load (GL) to the planned feast treat. Uses
//  SimilarMealMatcher for carb+GL proximity matching, then shows a
//  glucose chart for the 60–120 min window after the best-matching
//  meal, plus the max increase over baseline. Includes a date/time
//  picker and "Eat Treat" button to save the meal and return to the
//  Dashboard.
//

import SwiftUI
import Charts
import CoreData

/// Screen showing "Your Pattern with Similar Meals" for a planned feast.
/// Reached from the Plan Feast Treat screen via the "Similar Impact Meal" button.
struct SimilarImpactView: View {
    @ObservedObject var mealBuilder: MealBuilder
    let mealType: MealType
    let onEatTreat: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: true)]
    ) private var allGlucoseReadings: FetchedResults<GlucoseReadingEntity>

    // MARK: - State

    @State private var matchResult: SimilarImpactResult? = nil
    @State private var hasComputed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        Text("Your Pattern with Similar Meals")
                            .font(.title3.bold())
                    }
                    .padding(.top, 12)

                    // Historical pattern content
                    if !hasComputed {
                        ProgressView("Searching your meal history…")
                            .padding()
                    } else if let match = matchResult {
                        // We have a matching meal with glucose data
                        matchedPatternCard(match)

                        // Planned Date & Time (only shown when history exists)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Planned Date & Time")
                                .font(.headline)
                                .padding(.horizontal)

                            HStack {
                                Text("Date and time of this treat")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)

                            HStack {
                                Spacer()
                                DatePicker(
                                    "Date & Time",
                                    selection: $mealBuilder.plannedDateTime,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Eat Treat button
                        Button(action: onEatTreat) {
                            HStack {
                                Image(systemName: "fork.knife")
                                Text("Eat Treat")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    } else {
                        // No similar meal found — show cold-start card but still
                        // allow the user to save the feast and receive exercise nudges.
                        noHistoryCard

                        // Planned Date & Time
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Planned Date & Time")
                                .font(.headline)
                                .padding(.horizontal)

                            HStack {
                                Text("Date and time of this treat")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)

                            HStack {
                                Spacer()
                                DatePicker(
                                    "Date & Time",
                                    selection: $mealBuilder.plannedDateTime,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Button(action: onEatTreat) {
                            HStack {
                                Image(systemName: "fork.knife")
                                Text("Eat Treat")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                computeMatch()
            }
        }
    }

    // MARK: - No History Card

    private var noHistoryCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your meal history at a glance")
                        .fontWeight(.semibold)
                    Text("After a week of logging meals and glucose, Diabetes Feast will match new meals to similar ones you've eaten before — so you can review how your glucose responded to those past meals and use that information however you choose.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Progress indicator
                    let daysLogged = ColdStartManager.shared.glucoseDaysLogged
                    let required = ColdStartManager.similarMealDaysRequired
                    Text(String(format: NSLocalizedString("%1$d of %2$d days of meal + glucose data", comment: "Progress label on Similar Meal Patterns cold-start screen"), daysLogged, required))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Matched Pattern Card

    @ViewBuilder
    private func matchedPatternCard(_ match: SimilarImpactResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. The answer: last rise, then what to do about it
            HStack {
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.red)
                Text("Rise after a similar meal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("+\(Int(match.maxIncrease)) mg/dL")
                    .font(.title3.bold())
                    .foregroundColor(match.maxIncrease > 50 ? .red : match.maxIncrease > 30 ? .orange : .green)
            }

            // Exercise offset recommendation
            if match.maxIncrease > 15 {
                Divider()
                exerciseOffsetSection(glucoseRise: match.maxIncrease)
            }

            // 2. The evidence: chart
            Divider()

            // Walk-offset projection: branches off the historic curve at T+90
            // (when the walk nudge fires); the x-axis extends if the walk runs past 120 min.
            let walkPlan: WalkOffsetPlan? = match.maxIncrease > 15 ? walkOffsetPlan(glucoseRise: match.maxIncrease) : nil
            let walkProjection = walkPlan.map { walkProjectionPoints(match: match, plan: $0) } ?? []
            let xMax = max(120, walkPlan.map { Self.walkStartMinute + $0.minutes } ?? 120)

            // Glucose chart 60–xMax min after the meal
            if walkPlan == nil {
                Text("Glucose 60–120 min after eating")
                    .font(.subheadline.bold())
            } else if xMax == 120 {
                Text("Glucose 60–120 min after eating & offset effect")
                    .font(.subheadline.bold())
            } else {
                Text("Glucose 60–\(xMax) min after eating & offset effect")
                    .font(.subheadline.bold())
            }

            if match.glucosePoints.count >= 2 {
                // Dynamic y-axis: narrow the range around the actual data
                // so the glucose rise looks proportionally steep.
                let dataMin = min(match.baselineValue, match.glucosePoints.map(\.value).min() ?? match.baselineValue)
                let dataMax = max(match.peakValue, match.glucosePoints.map(\.value).max() ?? match.peakValue)
                let yFloor = max(40, Double(Int((dataMin - 20) / 10) * 10))   // round down to nearest 10, min 40
                let yCeil  = Double(Int((dataMax + 20) / 10 + 1) * 10)         // round up to nearest 10
                let yRange = yCeil - yFloor
                let yStep  = yRange <= 60 ? 10.0 : 20.0                       // finer ticks for narrow ranges

                Chart {
                    // Shaded walk window
                    if let plan = walkPlan {
                        RectangleMark(
                            xStart: .value("Walk start", Self.walkStartMinute),
                            xEnd: .value("Walk end", Self.walkStartMinute + plan.minutes)
                        )
                        .foregroundStyle(Color.green.opacity(0.10))
                        .annotation(position: .overlay, alignment: .top) {
                            Text("Walk \(plan.minutes) min")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.top, 2)
                        }
                    }

                    ForEach(match.glucosePoints, id: \.minutesAfterMeal) { point in
                        LineMark(
                            x: .value("Min", point.minutesAfterMeal),
                            y: .value("mg/dL", point.value),
                            series: .value("Series", "History")
                        )
                        .foregroundStyle(Color.orange)

                        PointMark(
                            x: .value("Min", point.minutesAfterMeal),
                            y: .value("mg/dL", point.value)
                        )
                        .foregroundStyle(point.value == match.peakValue ? Color.red : Color.orange)
                        .symbolSize(point.value == match.peakValue ? 80 : 40)
                    }

                    // Estimated glucose with the walk (dashed), branching at T+90
                    ForEach(walkProjection, id: \.minutesAfterMeal) { point in
                        LineMark(
                            x: .value("Min", point.minutesAfterMeal),
                            y: .value("mg/dL", point.value),
                            series: .value("Series", "With walk")
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                    if let last = walkProjection.last {
                        PointMark(
                            x: .value("Min", last.minutesAfterMeal),
                            y: .value("mg/dL", last.value)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(50)
                    }

                    // Baseline reference
                    RuleMark(y: .value("Baseline", match.baselineValue))
                        .foregroundStyle(Color.green.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .overlay, alignment: .topLeading, spacing: 0) {
                            Text("Baseline")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .offset(y: 4)
                        }
                }
                .chartXScale(domain: 60...xMax)
                .chartXAxis {
                    AxisMarks(values: xAxisTicks(upTo: xMax)) { value in
                        AxisGridLine()
                        // Anchor the last label to the trailing edge so it isn't clipped
                        AxisValueLabel(anchor: value.as(Int.self) == xMax ? .topTrailing
                                             : value.as(Int.self) == 60 ? .topLeading : .top) {
                            if let mins = value.as(Int.self) {
                                Text("\(mins) min")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: yFloor...yCeil)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: yStep)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxisLabel(position: .leading) {
                    Text("Glucose Level mg/dL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(180))
                }
                .frame(height: 200)
                .padding(.vertical, 4)
                .accessibilityLabel("Glucose chart showing readings 60 to 120 minutes after a similar meal. Baseline: \(Int(match.baselineValue)) mg/dL. Peak: \(Int(match.peakValue)) mg/dL. Maximum increase: \(Int(match.maxIncrease)) mg/dL.")
                .accessibilityValue(walkProjection.last.map { "With a \(walkPlan?.minutes ?? 0)-minute walk from 90 minutes, estimated \(Int($0.value)) mg/dL at \($0.minutesAfterMeal) minutes." } ?? "")

                if !walkProjection.isEmpty {
                    HStack(spacing: 14) {
                        legendSwatch(color: .orange, dashed: false, label: "Last time")
                        legendSwatch(color: .green, dashed: true, label: "With walk (estimate)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            } else {
                Text("Not enough glucose readings in this window to show a chart.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 3. Details: which past meal the chart is based on
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Most recent similar meal")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let name = match.mealName, !name.isEmpty {
                // Generated names ("Snack", "Late Night Snack"…) are stored in English;
                // look them up so they show in the user's language. Custom names pass through.
                Text(LocalizedStringKey(name))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let ts = match.mealTimestamp {
                Text(dateString(ts))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("GL: \(Int(match.mealGL)) · Carbs: \(Int(match.mealCarbs)) g")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)

        // GMI trend + feast frequency card
        gmiTrendCard
    }

    // MARK: - Exercise Offset Section

    @ViewBuilder
    private func exerciseOffsetSection(glucoseRise: Double) -> some View {
        let exerciseType = ExerciseOffsetType.current

        // Same clinical model as MealBuilderView.computeWalkRecommendation:
        // 1.5 mg/dL reduction per minute of brisk walking (3.5 METs), scaled by MET.
        // Target: offset ~50% of expected rise.
        let plan = walkOffsetPlan(glucoseRise: glucoseRise)
        let targetReduction = plan.targetReduction
        let roundedMinutes = plan.minutes

        // Personal pace from last 30 days, or type default
        let personalPace = fetchExercisePace(for: exerciseType)
        let pace = personalPace > 0 ? personalPace : exerciseType.defaultPace
        let rawDistance = Double(roundedMinutes) * pace
        let hitCap = plan.hitCap

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: exerciseType.iconName)
                    .foregroundColor(.blue)
                Text("Personalised exercise offset")
                    .font(.subheadline.bold())
            }

            Text("Based on previous logged activity and targeting halved glucose increase calculated at 1.5 mg/dL per minute, the following post-meal activity could help reduce your glucose increase.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                // Duration
                VStack(spacing: 2) {
                    Text(hitCap ? "\(roundedMinutes)+" : "\(roundedMinutes)")
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                    Text("minutes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Distance — only shown for activities where pace/distance is meaningful
                if exerciseType.showsDistance {
                    let metres = Int((rawDistance / 50).rounded()) * 50
                    VStack(spacing: 2) {
                        Text(exerciseType == .swim
                             ? "\(metres)"
                             : String(format: "%.1f", rawDistance))
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                        Text(exerciseType.distanceUnit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Target reduction
                VStack(spacing: 2) {
                    Text("-\(Int(targetReduction))")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("mg/dL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            if personalPace > 0 {
                Text("Distance based on your personal pace from the last 30 days.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Walk Offset Model (shared by chart and offset card)

    /// Minute after eating when the walk starts — matches the T+90 nudge.
    static let walkStartMinute = 90

    private struct WalkOffsetPlan {
        let minutes: Int              // rounded to nearest 5, clamped 5…60
        let targetReduction: Double   // mg/dL the walk aims to remove (50% of rise)
        let reductionPerMinute: Double
        let hitCap: Bool
    }

    /// Same clinical model as MealBuilderView.computeWalkRecommendation:
    /// 1.5 mg/dL reduction per minute of brisk walking (3.5 METs), scaled by MET.
    /// Target: offset ~50% of expected rise.
    private func walkOffsetPlan(glucoseRise: Double) -> WalkOffsetPlan {
        let exerciseType = ExerciseOffsetType.current
        let walkMET = 3.5
        let reductionPerMinute = 1.5 * (exerciseType.metValue / walkMET)
        let targetReduction = glucoseRise * 0.5
        let rawMinutes = targetReduction / reductionPerMinute
        let exerciseMinutes = min(60, max(5, rawMinutes))
        let roundedMinutes = Int((exerciseMinutes / 5).rounded()) * 5
        return WalkOffsetPlan(minutes: roundedMinutes,
                              targetReduction: targetReduction,
                              reductionPerMinute: reductionPerMinute,
                              hitCap: rawMinutes > 60)
    }

    /// No-walk glucose at minute `t`, linearly interpolated from the historic readings.
    /// Beyond the last reading the value is held flat (conservative).
    private func historicValue(at t: Int, in points: [SimilarImpactGlucosePoint]) -> Double {
        let sorted = points.sorted { $0.minutesAfterMeal < $1.minutesAfterMeal }
        guard let first = sorted.first, let last = sorted.last else { return 0 }
        if t <= first.minutesAfterMeal { return first.value }
        if t >= last.minutesAfterMeal { return last.value }
        for i in 1..<sorted.count where t <= sorted[i].minutesAfterMeal {
            let a = sorted[i - 1], b = sorted[i]
            let span = Double(b.minutesAfterMeal - a.minutesAfterMeal)
            guard span > 0 else { return b.value }
            return a.value + (b.value - a.value) * Double(t - a.minutesAfterMeal) / span
        }
        return last.value
    }

    /// Estimated curve with the walk: historic curve minus the walk's effect,
    /// which builds linearly over the walk and then holds. Never below baseline.
    private func walkProjectionPoints(match: SimilarImpactResult, plan: WalkOffsetPlan) -> [SimilarImpactGlucosePoint] {
        let start = Self.walkStartMinute
        let end = max(120, start + plan.minutes)
        let totalDrop = plan.hitCap ? Double(plan.minutes) * plan.reductionPerMinute : plan.targetReduction
        return stride(from: start, through: end, by: 5).map { t in
            let progress = min(1.0, Double(t - start) / Double(max(plan.minutes, 1)))
            let projected = historicValue(at: t, in: match.glucosePoints) - totalDrop * progress
            return SimilarImpactGlucosePoint(minutesAfterMeal: t, value: max(match.baselineValue, projected))
        }
    }

    /// 60, 90, 120 … plus the axis end; merges the end into the last tick if they'd crowd.
    private func xAxisTicks(upTo xMax: Int) -> [Int] {
        var ticks = Array(stride(from: 60, through: xMax, by: 30))
        if let last = ticks.last, last != xMax {
            if xMax - last < 15 { ticks[ticks.count - 1] = xMax } else { ticks.append(xMax) }
        }
        return ticks
    }

    private func legendSwatch(color: Color, dashed: Bool, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: 16, y: 1))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
            .frame(width: 16, height: 2)
            Text(label)
        }
    }

    /// Query exercise history to get the user's typical pace for a given exercise type.
    private func fetchExercisePace(for exerciseType: ExerciseOffsetType) -> Double {
        let fetchRequest: NSFetchRequest<ExerciseSessionEntity> = ExerciseSessionEntity.fetchRequest()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(
            format: "type == %@ AND startDate >= %@ AND distance > 0",
            exerciseType.coreDataType, cutoff as NSDate
        )
        do {
            let sessions = try viewContext.fetch(fetchRequest)
            guard !sessions.isEmpty else { return 0 }
            var totalMinutes = 0.0
            var totalDistanceKm = 0.0
            for session in sessions {
                guard session.duration > 0 else { continue }
                totalMinutes += session.duration / 60.0   // seconds → minutes
                totalDistanceKm += session.distance / 1000.0  // metres → km
            }
            guard totalMinutes > 0 && totalDistanceKm > 0 else { return 0 }
            return totalDistanceKm / totalMinutes   // km per minute
        } catch {
            return 0
        }
    }

    // MARK: - GMI Trend + Feast Frequency Card

    private var gmiTrendCard: some View {
        let gmiEntries = fetchRecentGmiEstimates()
        let feastCount = fetchFeastCountThisWeek()
        let rollingGmi = computeRollingGmi()

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("14-day GMI trend")
                    .font(.subheadline.bold())
                Spacer()
            }

            if gmiEntries.count >= 2 {
                // GMI trend chart — dynamic y-axis scaling
                let gmiMin = gmiEntries.map(\.value).min() ?? 4.0
                let gmiMax = gmiEntries.map(\.value).max() ?? 8.0
                let defaultFloor = 4.0
                let defaultCeil  = 8.0
                let effectiveFloor = gmiMin < defaultFloor
                    ? floor(gmiMin - 0.5)            // pad 0.5% below lowest point
                    : defaultFloor
                let effectiveCeil = gmiMax > defaultCeil
                    ? ceil(gmiMax + 0.5)             // pad 0.5% above highest point
                    : defaultCeil

                Chart {
                    ForEach(gmiEntries, id: \.date) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("GMI %", entry.value)
                        )
                        .foregroundStyle(Color.purple)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("GMI %", entry.value)
                        )
                        .foregroundStyle(gmiColor(entry.value))
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: effectiveFloor...effectiveCeil)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: 1.0)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f%%", v))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(shortDateString(date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 140)
                .padding(.vertical, 4)

                // Current GMI value — 14-day rolling mean, same as Dashboard
                if let gmi = rollingGmi {
                    HStack {
                        Text("Current GMI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", gmi))
                            .font(.title3.bold())
                            .foregroundColor(gmiColor(gmi))
                    }
                }
            } else if gmiEntries.count == 1 {
                if let gmi = rollingGmi {
                    HStack {
                        Text("Current GMI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", gmi))
                            .font(.title3.bold())
                            .foregroundColor(gmiColor(gmi))
                    }
                }
                Text("Log more glucose readings over the next few days to see a trend chart.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Not enough glucose data yet to calculate GMI. Keep logging daily readings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Feast frequency — bottom of this card
            Divider()
            HStack {
                Image(systemName: "party.popper.fill")
                    .foregroundColor(feastCount >= 3 ? .red : feastCount >= 2 ? .orange : .green)
                Text("Feast treats this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(feastCount)")
                    .font(.title3.bold())
                    .foregroundColor(feastCount >= 3 ? .red : feastCount >= 2 ? .orange : .green)
            }
            if feastCount >= 2 {
                Text(feastCount >= 3
                     ? "You have logged 3 or more feast treats this week."
                     : "You have logged \(feastCount) feast treats so far this week.")
                    .font(.caption)
                    .foregroundColor(feastCount >= 3 ? .red : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// Compute daily GMI values from glucose readings over the last 14 days
    /// using the Bergenstal 2018 formula: GMI (%) = 3.31 + 0.02392 × mean mg/dL.
    /// This matches the Dashboard GMI calculation exactly.
    private func fetchRecentGmiEstimates() -> [GmiTrendEntry] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        // Filter glucose readings in the 14-day window (mg/dL and mmol/L)
        let windowReadings = allGlucoseReadings.filter { reading in
            guard let ts = reading.timestamp,
                  let unit = reading.unit,
                  (unit == "mg/dL" || unit == "mmol/L") else { return false }
            return ts >= cutoff
        }

        // Group readings by calendar day, normalising to mg/dL
        var dailyReadings: [Date: [Double]] = [:]
        for reading in windowReadings {
            guard let ts = reading.timestamp else { continue }
            let dayStart = calendar.startOfDay(for: ts)
            let valueMgDl = reading.unit == "mmol/L" ? reading.value * 18.0 : reading.value
            dailyReadings[dayStart, default: []].append(valueMgDl)
        }

        // Compute GMI for each day that has at least 2 readings
        return dailyReadings.compactMap { (day, values) -> GmiTrendEntry? in
            guard values.count >= 2 else { return nil }
            let meanMgDl = values.reduce(0, +) / Double(values.count)
            let gmiPercent = 3.31 + 0.02392 * meanMgDl
            return GmiTrendEntry(date: day, value: gmiPercent)
        }
        .sorted { $0.date < $1.date }
    }

    /// Compute the 14-day rolling GMI from ALL glucose readings in the window,
    /// exactly matching the Dashboard GMICardView calculation.
    /// Bergenstal 2018: GMI (%) = 3.31 + 0.02392 × mean mg/dL
    private func computeRollingGmi() -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let windowReadings = allGlucoseReadings.filter { reading in
            guard let ts = reading.timestamp,
                  let unit = reading.unit,
                  (unit == "mg/dL" || unit == "mmol/L") else { return false }
            return ts >= cutoff
        }
        guard windowReadings.count >= 20 else { return nil }
        let sumMgDl = windowReadings.reduce(0.0) { total, reading in
            let valueMgDl = reading.unit == "mmol/L" ? reading.value * 18.0 : reading.value
            return total + valueMgDl
        }
        let mean = sumMgDl / Double(windowReadings.count)
        return 3.31 + 0.02392 * mean
    }

    /// Count feast meals in the last 7 days
    private func fetchFeastCountThisWeek() -> Int {
        let request: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "mealType == %@", "feast"),
            NSPredicate(format: "timestamp >= %@", weekAgo as NSDate)
        ])
        return (try? viewContext.count(for: request)) ?? 0
    }

    /// Color for GMI value based on clinical thresholds
    private func gmiColor(_ value: Double) -> Color {
        if value < 5.7 { return .green }
        if value < 6.5 { return .yellow }
        if value <= 7.5 { return .orange }
        return .red
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Compute Match (via SimilarMealMatcher)

    private func computeMatch() {
        let plannedCarbs = mealBuilder.totalCarbohydrates
        let plannedGL = mealBuilder.totalGlycemicLoad

        // Use the shared matcher — scores by carb proximity (70%) + GL proximity (30%)
        let matches = SimilarMealMatcher.findSimilar(
            plannedCarbs: plannedCarbs,
            plannedGL: plannedGL,
            context: viewContext
        )

        // Walk the ranked matches and find the first one with enough glucose data
        for match in matches {
            let meal = match.meal
            guard let mealTime = meal.timestamp else { continue }

            let windowStart = mealTime.addingTimeInterval(60 * 60)    // 60 min
            let windowEnd   = mealTime.addingTimeInterval(120 * 60)   // 120 min
            let baselineStart = mealTime.addingTimeInterval(-45 * 60) // up to 45 min before
            let baselineEnd = mealTime

            // Glucose readings in the 60–120 min window (normalised to mg/dL)
            let windowReadings = allGlucoseReadings.filter { reading in
                guard let ts = reading.timestamp,
                      let unit = reading.unit,
                      (unit == "mg/dL" || unit == "mmol/L") else { return false }
                return ts >= windowStart && ts <= windowEnd
            }

            // Baseline reading (closest to meal time, up to 45 min before — covers T-30
            // readings from CGM data and cases where the user logs a meal mid-way through eating)
            let baselineReadings = allGlucoseReadings.filter { reading in
                guard let ts = reading.timestamp,
                      let unit = reading.unit,
                      (unit == "mg/dL" || unit == "mmol/L") else { return false }
                return ts >= baselineStart && ts <= baselineEnd
            }

            guard windowReadings.count >= 2 else { continue }

            let baselineReading = baselineReadings.last
            let baselineRaw = baselineReading.map { $0.unit == "mmol/L" ? $0.value * 18.0 : $0.value }
            let firstWindowMgDl = windowReadings.first!.unit == "mmol/L" ? windowReadings.first!.value * 18.0 : windowReadings.first!.value
            let baseline = baselineRaw ?? firstWindowMgDl
            let points = windowReadings.compactMap { reading -> SimilarImpactGlucosePoint? in
                guard let ts = reading.timestamp else { return nil }
                let mins = Int(ts.timeIntervalSince(mealTime) / 60)
                let valueMgDl = reading.unit == "mmol/L" ? reading.value * 18.0 : reading.value
                return SimilarImpactGlucosePoint(minutesAfterMeal: mins, value: valueMgDl)
            }

            let peakValue = points.map(\.value).max() ?? baseline
            let maxIncrease = peakValue - baseline

            matchResult = SimilarImpactResult(
                mealName: meal.name,
                mealTimestamp: meal.timestamp,
                mealGL: match.glycaemicLoad,
                mealCarbs: match.totalCarbs,
                baselineValue: baseline,
                peakValue: peakValue,
                maxIncrease: max(0, maxIncrease),
                glucosePoints: points
            )
            hasComputed = true
            return
        }

        // No match with glucose data found
        matchResult = nil
        hasComputed = true
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Local Data Types

/// Snapshot of a matched meal's glucose pattern, used only by SimilarImpactView.
struct SimilarImpactResult {
    let mealName: String?
    let mealTimestamp: Date?
    let mealGL: Double
    let mealCarbs: Double
    let baselineValue: Double
    let peakValue: Double
    let maxIncrease: Double
    let glucosePoints: [SimilarImpactGlucosePoint]
}

struct SimilarImpactGlucosePoint {
    let minutesAfterMeal: Int
    let value: Double
}

/// A single point in the 14-day GMI trend, used by SimilarImpactView.
struct GmiTrendEntry {
    let date: Date
    let value: Double   // NGSP percentage (e.g. 6.5%)
}
