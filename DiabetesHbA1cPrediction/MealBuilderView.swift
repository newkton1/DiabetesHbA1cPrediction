//
//  MealBuilderView.swift
//  DiabetesHbA1cPrediction
//
//  Main view for building a meal with multiple food items
//

import SwiftUI
import CoreData
import Combine

/// Main view for building a meal with multiple food items
struct MealBuilderView: View {
    @StateObject private var mealBuilder: MealBuilder
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var isMealNameFocused: Bool
    @State private var showingFoodSearch = false
    @State private var showingError = false
    @State private var errorMessage = ""
    let mealType: MealType
    private let predictionEngine = HbA1cPredictionEngine()

    init(mealType: MealType) {
        self.mealType = mealType
        let builder = MealBuilder()
        builder.mealType = mealType
        _mealBuilder = StateObject(wrappedValue: builder)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPortrait {
                    Text(mealType == .lastMeal ? "Log Last Meal" : mealType == .feast ? "Plan a Feast" : "Plan a Meal")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }
                List {
                // Meal name section
                Section {
                    TextField("Meal Name (optional)", text: $mealBuilder.mealName)
                        .focused($isMealNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isMealNameFocused = false }
                }
                    // Feast banner
                                    if mealType == .feast {
                                        Section {
                                            FeastModeBannerView()
                                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                                .listRowBackground(Color.clear)
                                        }
                                    }
                // Add foods button
                Section {
                    Button(action: { showingFoodSearch = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                            
                            Text("Search & Add Foods")
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            if mealBuilder.foodCount > 0 {
                                Text("\(mealBuilder.foodCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Selected foods section
                if !mealBuilder.selectedFoods.isEmpty {
                    Section(header: Text("Selected Foods")) {
                        ForEach(Array(mealBuilder.selectedFoods.enumerated()), id: \.element.id) { index, selectedFood in
                            SelectedFoodRow(
                                selectedFood: selectedFood,
                                onIncrement: { mealBuilder.incrementQuantity(at: index) },
                                onDecrement: { mealBuilder.decrementQuantity(at: index) },
                                onDelete: { mealBuilder.removeFood(at: index) }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                mealBuilder.removeFood(at: index)
                            }
                        }
                    }
                    
                    // Nutrition summary section (bulleted list style)
                    Section(header: Text("Nutrition Summary")) {
                        VStack(alignment: .leading, spacing: 4) {
                            NutritionBulletRow(label: "Carbs", value: "\(Int(mealBuilder.totalCarbohydrates)) g", color: .orange)
                            NutritionBulletRow(label: "Fiber", value: "\(Int(mealBuilder.totalFiber)) g", color: .green)
                            NutritionBulletRow(label: "Protein", value: "\(Int(mealBuilder.totalProtein)) g", color: .blue)
                            NutritionBulletRow(label: "Fat", value: "\(Int(mealBuilder.totalFat)) g", color: .purple)
                            NutritionBulletRow(label: "Cal", value: "\(Int(mealBuilder.totalCalories))", color: .red)
                            NutritionBulletRow(label: "GI", value: "\(Int(mealBuilder.averageGlycemicIndex))", color: .gray)
                        }
                    }

                }

                // Estimated Impact section (planned meals only, always visible)
                    if mealType == .plannedMeal || mealType == .feast {                    Section(header: Text("Estimated Impact")) {
                        EstimatedImpactContent(
                            mealBuilder: mealBuilder,
                                                        viewContext: viewContext,
                                                        predictionEngine: predictionEngine,
                                                        mealType: mealType
                        )
                    }
                }

                // Time section (varies by meal type)
                Section(header: Text(mealType == .lastMeal ? "Time Since Meal" : "Planned Date & Time")) {
                    if mealType == .lastMeal {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How long ago did you eat this meal?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("\(mealBuilder.timeSinceLastMeal, specifier: "%.1f") h")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Stepper("", value: $mealBuilder.timeSinceLastMeal, in: 0...24, step: 0.5)
                                    .labelsHidden()
                            }
                            
                            // Quick time buttons
                            HStack(spacing: 8) {
                                QuickTimeButton(title: "Just now", hours: 0, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "1 h", hours: 1, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "2 h", hours: 2, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "3 h", hours: 3, selectedHours: $mealBuilder.timeSinceLastMeal)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When do you plan to eat this meal?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker(
                                "Date & Time",
                                selection: $mealBuilder.plannedDateTime,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Total carbs footer
                if !mealBuilder.selectedFoods.isEmpty {
                    Section {
                        HStack {
                            Text("TOTAL CARBOHYDRATES")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(mealBuilder.totalCarbohydrates)) g")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 8)
                    }
                }

            }
            .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea(.keyboard)
            .navigationTitle(isPortrait ? "" : (mealType == .lastMeal ? "Log Last Meal" : mealType == .feast ? "Plan a Feast" : "Plan a Meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { saveMeal() }) {
                        Text("Save")
                    }
                    .disabled(!mealBuilder.canSave)
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isMealNameFocused = false
                    }
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                MultiSelectFoodSearchView(mealBuilder: mealBuilder)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }

    private func saveMeal() {
        do {
            try mealBuilder.save(to: viewContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

}

/// Result of estimated meal impact calculation
struct MealImpactResult {
    let estimatedGlucoseRise: Double
    let hba1cDelta: Double
    let glycemicLoad: Double
    let glCategory: String
    let comparisonPct: Double
    let hasHistory: Bool
    let recommendation: String?
    let walkRecommendation: String?

    var glucoseColor: Color {
        if estimatedGlucoseRise < 30 { return .green }
        else if estimatedGlucoseRise < 60 { return .orange }
        else { return .red }
    }

    var hba1cColor: Color {
        if hba1cDelta < 0.05 { return .green }
        else if hba1cDelta < 0.1 { return .orange }
        else { return .red }
    }

    var glColor: Color {
        switch glCategory {
        case "Low": return .green
        case "Moderate": return .orange
        default: return .red
        }
    }

    var comparisonText: String {
        guard hasHistory else { return "No meal history" }
        let pct = Int(abs(comparisonPct))
        if abs(comparisonPct) < 10 { return "Similar" }
        else if comparisonPct > 0 { return "\(pct)% more carbs" }
        else { return "\(pct)% fewer carbs" }
    }

    var comparisonColor: Color {
        guard hasHistory else { return .secondary }
        if abs(comparisonPct) < 10 { return .green }
        else if comparisonPct > 30 { return .red }
        else if comparisonPct > 0 { return .orange }
        else { return .green }
    }
}

/// Self-contained view that computes and displays estimated meal impact
/// Observes MealBuilder directly so it updates automatically when foods change
struct EstimatedImpactContent: View {
    @ObservedObject var mealBuilder: MealBuilder
    var viewContext: NSManagedObjectContext
    var predictionEngine: HbA1cPredictionEngine
    var mealType: MealType = .plannedMeal
    
    var body: some View {
        let impact = computeImpact()
        if let impact = impact {
            // Glucose spike estimate
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(impact.glucoseColor)
                    .frame(width: 24)
                Text("Est. glucose rise")
                    .foregroundColor(.secondary)
                Spacer()
                Text("+\(Int(impact.estimatedGlucoseRise)) mg/dL")
                    .fontWeight(.semibold)
                    .foregroundColor(impact.glucoseColor)
            }

            // HbA1c impact
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(impact.hba1cColor)
                    .frame(width: 24)
                Text("HbA1c impact")
                    .foregroundColor(.secondary)
                Spacer()
                Text(impact.hba1cDelta >= 0.05 ? String(format: "+%.1f%%", impact.hba1cDelta) : "Minimal")
                    .fontWeight(.semibold)
                    .foregroundColor(impact.hba1cColor)
            }

            // Comparison with typical meals
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("vs. your typical meal")
                    .foregroundColor(.secondary)
                Spacer()
                Text(impact.comparisonText)
                    .fontWeight(.semibold)
                    .foregroundColor(impact.comparisonColor)
            }

            // Glycemic load indicator
            HStack {
                Image(systemName: impact.glCategory == "Low" ? "checkmark.circle.fill" : impact.glCategory == "Moderate" ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(impact.glColor)
                    .frame(width: 24)
                Text("Glycemic load")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(impact.glycemicLoad)) (\(impact.glCategory))")
                    .fontWeight(.semibold)
                    .foregroundColor(impact.glColor)
            }

            // Recommendation if any
            if let recommendation = impact.recommendation {
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    Text(recommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            // Walk recommendation
            if let walkRec = impact.walkRecommendation {
                           WalkRecommendationCard(recommendation: walkRec)
                               .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                               .listRowBackground(Color.clear)
                               .padding(.top, 4)
                       }
        } else {
            Text("Add foods to see estimated impact")
                .foregroundColor(.secondary)
        }
    }

    private func computeImpact() -> MealImpactResult? {
        guard !mealBuilder.selectedFoods.isEmpty else { return nil }

        let carbs = mealBuilder.totalCarbohydrates
        let gi = mealBuilder.averageGlycemicIndex
        let gl = mealBuilder.totalGlycemicLoad
        let hoursUntil = max(0, mealBuilder.plannedDateTime.timeIntervalSince(Date()) / 3600.0)

        // 1. Estimate post-meal glucose rise (~2-3 mg/dL per unit of GL)
        let estimatedGlucoseRise = min(120, gl * 2.5)

        // 2. Calculate HbA1c impact using prediction engine (read-only)
        var hba1cDelta = 0.0
        if let input = predictionEngine.gatherInputs(context: viewContext) {
            let currentResult = predictionEngine.predict(from: input)
            let adjusted = predictionEngine.predictWithPlannedMeal(
                currentPrediction: currentResult,
                plannedMealCarbs: carbs,
                plannedMealGI: gi,
                hoursUntilMeal: hoursUntil
            )
            hba1cDelta = adjusted.predictedHbA1c - currentResult.predictedHbA1c
        }

        // 3. Compare with typical meal from history
        let avgCarbs = fetchAverageCarbs()
        let comparisonPct: Double = avgCarbs > 0 ? ((carbs - avgCarbs) / avgCarbs) * 100 : 0

        // 4. Categorize glycemic load
        let glCategory: String
        if gl < 10 { glCategory = "Low" }
        else if gl < 20 { glCategory = "Moderate" }
        else { glCategory = "High" }

        // 5. Generate recommendation
                let isFeast = (mealType == .feast)
                var recommendation: String? = nil
                if gl > (isFeast ? 30 : 20) && carbs > (isFeast ? 90 : 60) {
                    recommendation = isFeast
                        ? "Very high carb feast. A brisk post-meal walk will help significantly."
                        : "High carb & glycemic load. Consider smaller portions or adding protein/fiber to slow glucose absorption."
                } else if gl > (isFeast ? 30 : 20) {
                    recommendation = "High glycemic load. Consider lower-GI alternatives to reduce glucose spike."
                } else if carbs > (isFeast ? 100 : 80) {
                    recommendation = "High carbs. Adding protein or healthy fats can help moderate blood sugar response."
                }
        // 6. Estimate post-meal walk to offset glucose rise
        let walkRec = computeWalkRecommendation(estimatedGlucoseRise: estimatedGlucoseRise)

        return MealImpactResult(
            estimatedGlucoseRise: estimatedGlucoseRise,
            hba1cDelta: hba1cDelta,
            glycemicLoad: gl,
            glCategory: glCategory,
            comparisonPct: comparisonPct,
            hasHistory: avgCarbs > 0,
            recommendation: recommendation,
            walkRecommendation: walkRec
        )
    }

    private func fetchAverageCarbs() -> Double {
        let fetchRequest: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(
            format: "timestamp >= %@ AND (mealType != %@ OR mealType == nil)",
            cutoff as NSDate, "plannedMeal"
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]

        do {
            let meals = try viewContext.fetch(fetchRequest)
            guard !meals.isEmpty else { return 0 }

            var totalCarbs = 0.0
            for meal in meals {
                if let foodItems = meal.foodItems as? Set<MealFoodItemEntity>, !foodItems.isEmpty {
                    for item in foodItems {
                        totalCarbs += item.carbsPerServing * item.quantity
                    }
                } else if let macros = meal.macronutrients as? Set<MacronutrientEntity> {
                    totalCarbs += macros
                        .filter { $0.type == "carbohydrates" || $0.type == "carbs" }
                        .reduce(0) { $0 + $1.amount }
                }
            }
            return totalCarbs / Double(meals.count)
        } catch {
            return 0
        }
    }

    /// Estimate post-meal walk duration/distance to help reduce glucose rise.
    /// Based on clinical research: a 15-min brisk post-meal walk typically reduces
    /// the glucose peak by ~20-30 mg/dL. The user's personal walking pace from
    /// exercise history is used to adjust the distance estimate.
    private func computeWalkRecommendation(estimatedGlucoseRise: Double) -> String? {
        guard estimatedGlucoseRise > 15 else { return nil } // Only suggest if meaningful rise

        // Clinical acute post-meal walking effect:
        // ~1.5 mg/dL reduction per minute of brisk walking (based on studies showing
        // 15-min walks reduce glucose peaks by 20-30 mg/dL)
        let reductionPerMinute = 1.5

        // Target reducing ~50% of the estimated glucose rise
        let targetReduction = estimatedGlucoseRise * 0.5
        let rawMinutes = targetReduction / reductionPerMinute
        let walkMinutes = min(60, max(10, rawMinutes))
        let roundedMinutes = Int((walkMinutes / 5).rounded()) * 5 // Round to nearest 5
        let hitCap = rawMinutes > 60 // True when the walk time was capped

        // Use personal walking pace if available, otherwise default 5 km/hr
        let personalPace = fetchWalkingPace() // km per minute
        let paceKmPerMin = personalPace > 0 ? personalPace : (5.0 / 60.0)
        let walkDistanceKm = Double(roundedMinutes) * paceKmPerMin
        let formattedDistance = String(format: "%.1f", walkDistanceKm)

        let duration = hitCap ? "at least \(roundedMinutes) min / \(formattedDistance) km" : "\(roundedMinutes) min / \(formattedDistance) km"
        return "If you eat this planned meal, also consider a good walk after the meal of \(duration) to help quickly reduce the estimated glucose rise."
    }

    /// Query walking exercise history to get the user's typical walking pace (km/min).
    /// Looks at walking sessions from the last 30 days that have distance data.
    private func fetchWalkingPace() -> Double {
        let fetchRequest: NSFetchRequest<ExerciseSessionEntity> = ExerciseSessionEntity.fetchRequest()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(
            format: "type == %@ AND startDate >= %@ AND distance > 0",
            "Walking", cutoff as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: false)]

        do {
            let sessions = try viewContext.fetch(fetchRequest)
            guard !sessions.isEmpty else { return 0 }

            var totalMinutes = 0.0
            var totalDistance = 0.0
            for session in sessions {
                guard session.duration > 0 else { continue }
                totalMinutes += session.duration
                totalDistance += session.distance
            }
            guard totalMinutes > 0 && totalDistance > 0 else { return 0 }

            // Return personal walking pace in km/min
            return totalDistance / totalMinutes
        } catch {
            return 0
        }
    }
}

/// Row for displaying a nutrition summary value
struct NutritionSummaryRow: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(Int(value)) \(unit)")
                .fontWeight(.medium)
        }
    }
}

/// Compact colored badge for displaying a nutrition value (matches MealLogView style)
struct NutritionBadge: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
            Text("\(Int(value))\(unit)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
        .foregroundColor(color)
    }
}

struct NutritionBulletRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(color)
                .fontWeight(.semibold)
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }
}

/// Quick time selection button
struct QuickTimeButton: View {
    let title: String
    let hours: Double
    @Binding var selectedHours: Double
    
    var isSelected: Bool {
        abs(selectedHours - hours) < 0.1
    }
    
    var body: some View {
        Button(action: { selectedHours = hours }) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Last Meal") {
    MealBuilderView(mealType: .lastMeal)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Planned Meal") {
    MealBuilderView(mealType: .plannedMeal)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
