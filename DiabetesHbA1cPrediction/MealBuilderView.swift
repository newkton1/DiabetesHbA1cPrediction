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
    @State private var isReady = false          // defer heavy content until sheet animates in
    @State private var showResults = false       // after save, show impact results instead of form
    // savedImpact removed — post-save screen no longer shows impact block (Option B)
    @State private var showGlycemicWarning = false      // auto-dismissing high GL warning
    @State private var showGlucoseElevatedWarning = false  // auto-dismissing warning for regular meals
    @State private var glBeforeFoodSearch: Double = 0      // GL snapshot before opening food search
    @State private var showSimilarImpact = false           // navigate to Similar Impact screen (feast only)
    @State private var showSaveConfirmation = false        // 2-second toast after regular meal save
    @State private var saveConfirmationText = ""           // e.g. "Lunch saved — 45 g carbs"
    let mealType: MealType
    // predictionEngine removed — historical pattern mode uses HistoricalPatternSummary instead

    init(mealType: MealType) {
        self.mealType = mealType
        let builder = MealBuilder()
        builder.mealType = mealType
        _mealBuilder = StateObject(wrappedValue: builder)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if showResults {
                    resultsContent
                } else if isReady {
                    formContent
                } else {
                    // Lightweight placeholder while sheet animates in
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showResults {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: { dismiss() }) {
                            Text("Done")
                        }
                        .fontWeight(.semibold)
                    }
                } else if !showSaveConfirmation {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if mealType == .feast && mealBuilder.canSave {
                            Button(action: { showSimilarImpact = true }) {
                                // Ternary of two literals inside a Text() call can resolve
                                // to the plain-String initializer rather than
                                // LocalizedStringKey depending on inference — wrap
                                // explicitly so both branches always hit the catalog.
                                Text(LocalizedStringKey(isPortrait ? "Similar Meal" : "Similar Impact Meal"))
                                    .font(isPortrait ? .caption : .callout)
                            }
                            .fontWeight(.semibold)
                        } else if mealType != .feast && mealBuilder.canSave {
                            Button(action: { saveMeal() }) {
                                Text("Save")
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                // Keyboard dismiss handled by .scrollDismissesKeyboard and .onSubmit on the text field
            }
            .sheet(isPresented: $showingFoodSearch, onDismiss: {
                checkGlucoseElevation()
            }) {
                MultiSelectFoodSearchView(mealBuilder: mealBuilder, mealType: mealType)
            }
            .fullScreenCover(isPresented: $showSimilarImpact) {
                SimilarImpactView(
                    mealBuilder: mealBuilder,
                    mealType: mealType,
                    onEatTreat: {
                        saveMeal()
                        showSimilarImpact = false
                        dismiss()
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if showGlycemicWarning {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("High Carb Impact")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("This wellness feature shows exercise options based on your activity history. These are for personal tracking only — not medical diagnoses or treatment advice.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Note: High carb impact. View exercise options based on your activity history.")
                }
                if showGlucoseElevatedWarning {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("Elevated Blood Glucose")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Adding this food significantly increases the meal's estimated glucose impact. Some people choose to pair high-GI foods with lower-GI options.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Warning: Elevated blood glucose. Adding this food significantly increases glucose impact.")
                }
                if showSaveConfirmation {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text(saveConfirmationText)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(saveConfirmationText)
                }
            }
            .onAppear {
                // Defer heavy form rendering until after the sheet animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isReady = true
                }
            }
        }
    }

    // MARK: - Results Content (shown after save)

    @ViewBuilder
    private var resultsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: mealType == .feast ? "party.popper.fill" : "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(mealType == .feast ? .feastAccent : .green)
                        .accessibilityHidden(true)
                    Text(mealType == .feast ? "Feast Saved" : "Meal Saved")
                        .font(.title2).fontWeight(.bold)
                    if !mealBuilder.mealName.isEmpty {
                        Text(mealBuilder.mealName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)

                // Glycemic load summary — descriptive property of the
                // saved meal. No forward projections on the post-save
                // screen (historical pattern is shown pre-save only).
                if !mealBuilder.selectedFoods.isEmpty {
                    let gl = mealBuilder.totalGlycemicLoad
                    let glCategory = gl < 10 ? "Low" : gl < 20 ? "Moderate" : "High"
                    let glColor: Color = glCategory == "Low" ? .green : glCategory == "Moderate" ? .orange : .red
                    let glIcon = glCategory == "Low" ? "checkmark.circle.fill" : glCategory == "Moderate" ? "exclamationmark.circle.fill" : "xmark.circle.fill"

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: glIcon)
                                .foregroundColor(glColor)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text("Carb impact")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(gl)) (\(glCategory))")
                                .fontWeight(.semibold)
                                .foregroundColor(glColor)
                        }

                        Text("Log glucose readings over the next 2 hours to build your historical pattern for similar meals.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Form Content (deferred)

    @ViewBuilder
    private var formContent: some View {
        Form {
            // Meal name section — title used as section header so it sits tight
            Section(header:
                Text(LocalizedStringKey(mealType == .lastMeal ? "Last Meal" : mealType == .feast ? "Plan Feast Treat" : "Plan Meal"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textCase(nil)
            ) {
                TextField(mealType == .feast ? "Treat Name (optional)" : "Meal Name (optional)", text: $mealBuilder.mealName)
                    .focused($isMealNameFocused)
                    .submitLabel(.done)
                    .onSubmit { isMealNameFocused = false }
            }

            // Add foods button
            Section {
                Button(action: {
                    glBeforeFoodSearch = mealBuilder.totalGlycemicLoad
                    showingFoodSearch = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
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

                // Nutrition summary section — 2-column for feast, single column for other types
                if mealType == .feast {
                    Section(header: Text("Nutrition Summary")) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                NutritionBulletRow(label: "GL", value: "\(Int(mealBuilder.totalGlycemicLoad))", color: .gray)
                                NutritionBulletRow(label: "Carbs", value: "\(Int(mealBuilder.totalCarbohydrates)) g", color: .orange)
                                NutritionBulletRow(label: "Fiber", value: "\(Int(mealBuilder.totalFiber)) g", color: .green)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                NutritionBulletRow(label: "Protein", value: "\(Int(mealBuilder.totalProtein)) g", color: .blue)
                                NutritionBulletRow(label: "Fat", value: "\(Int(mealBuilder.totalFat)) g", color: .purple)
                                NutritionBulletRow(label: "Cal", value: "\(Int(mealBuilder.totalCalories))", color: .red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Section(header: Text("Nutrition Summary")) {
                        VStack(alignment: .leading, spacing: 4) {
                            NutritionBulletRow(label: "Carbs", value: "\(Int(mealBuilder.totalCarbohydrates)) g", color: .orange)
                            NutritionBulletRow(label: "Fiber", value: "\(Int(mealBuilder.totalFiber)) g", color: .green)
                            NutritionBulletRow(label: "Protein", value: "\(Int(mealBuilder.totalProtein)) g", color: .blue)
                            NutritionBulletRow(label: "Fat", value: "\(Int(mealBuilder.totalFat)) g", color: .purple)
                            NutritionBulletRow(label: "Cal", value: "\(Int(mealBuilder.totalCalories))", color: .red)
                            NutritionBulletRow(label: "GL", value: "\(Int(mealBuilder.totalGlycemicLoad))", color: .gray)
                        }
                    }
                }
            }

            // Historical pattern section removed from feast — now on SimilarImpactView
            // Keep for non-feast planned meals if needed in future

            // Time section — only for non-feast types (feast uses SimilarImpactView)
            if mealType != .feast {
            Section(header: Text(LocalizedStringKey(mealType == .lastMeal ? "Time Since Meal" : "Planned Date & Time"))) {
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
                            Stepper("", value: $mealBuilder.timeSinceLastMeal, in: 0...48, step: 0.5)
                                .labelsHidden()
                        }
                        if isPortrait {
                            // Portrait: 5 equal-width buttons (3 h removed to fit one line)
                            HStack(spacing: 6) {
                                ForEach([
                                    ("Now", 0.0), ("1 h", 1.0), ("2 h", 2.0), ("24 h", 24.0), ("48 h", 48.0)
                                ], id: \.0) { label, hours in
                                    QuickTimeButton(title: LocalizedStringKey(label), hours: hours, selectedHours: $mealBuilder.timeSinceLastMeal)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        } else {
                            // Landscape: all 6 buttons, natural sizing
                            HStack(spacing: 8) {
                                QuickTimeButton(title: "Now", hours: 0, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "1 h", hours: 1, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "2 h", hours: 2, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "3 h", hours: 3, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "24 h", hours: 24, selectedHours: $mealBuilder.timeSinceLastMeal)
                                QuickTimeButton(title: "48 h", hours: 48, selectedHours: $mealBuilder.timeSinceLastMeal)
                            }
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
            } // end if mealType != .feast

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
        .contentMargins(.top, 0, for: .scrollContent)
    }

    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }

    private func saveMeal() {
        do {
            if mealType == .feast {
                try mealBuilder.save(to: viewContext)

                // Schedule offset exercise nudge notifications (T+90 and T+150 min)
                ExerciseReminderManager.shared.scheduleReminders()

                // Show auto-dismissing warning for high glycemic load feasts
                if mealBuilder.totalGlycemicLoad >= 50 {
                    withAnimation(.easeInOut(duration: 0.3)) { showGlycemicWarning = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation(.easeInOut(duration: 0.3)) { showGlycemicWarning = false }
                        withAnimation { showResults = true }
                    }
                } else {
                    withAnimation { showResults = true }
                }
            } else {
                // Regular meals: save, show 2-second confirmation toast, then dismiss
                try mealBuilder.save(to: viewContext)

                // Build confirmation text: "Meal saved — 45 g carbs" or "Lunch saved — 45 g carbs"
                let carbs = Int(mealBuilder.totalCarbohydrates)
                if mealBuilder.mealName.trimmingCharacters(in: .whitespaces).isEmpty {
                    saveConfirmationText = "Meal saved — \(carbs) g carbs"
                } else {
                    saveConfirmationText = "\(mealBuilder.mealName) saved — \(carbs) g carbs"
                }
                withAnimation(.easeInOut(duration: 0.3)) { showSaveConfirmation = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.3)) { showSaveConfirmation = false }
                    dismiss()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    /// Checks if adding foods during the search significantly elevated the meal's glycemic load.
    /// Only triggers for non-feast meals when GL jumps by ≥15 and the newest item has GI ≥55.
    private func checkGlucoseElevation() {
        guard mealType != .feast else { return }  // Feast has its own warning on Save

        let currentGL = mealBuilder.totalGlycemicLoad
        let delta = currentGL - glBeforeFoodSearch

        // Check if the most recently added food has a high GI
        let hasHighGIItem = mealBuilder.selectedFoods.contains { $0.foodItem.glycemicIndex >= 55 }

        if delta >= 15 && hasHighGIItem {
            withAnimation(.easeInOut(duration: 0.3)) { showGlucoseElevatedWarning = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeInOut(duration: 0.3)) { showGlucoseElevatedWarning = false }
            }
        }
    }

}


/// UI-side result of the historical pattern lookup for the currently
/// planned meal. Carries the raw `HistoricalPatternSummary` plus a few
/// derived fields (glycaemic load of *this* planned meal, recommendation
/// text, optional walk recommendation) that aren't part of the summary
/// itself.
///
/// Named with the neutral "ImpactResult" suffix so the surrounding view
/// struct can be renamed to `HistoricalPatternContent` later (Step G.6)
/// without churn here.
fileprivate struct HistoricalImpactResult {
    let summary: HistoricalPatternSummary
    let glycemicLoad: Double
    let glCategory: String
    let recommendation: String?
    let walkRecommendation: String?

    /// True when we have enough analysed matches to show numeric aggregates.
    var hasAggregates: Bool {
        summary.confidence != .insufficient && summary.medianPeakDelta != nil
    }

    var peakDeltaColor: Color {
        guard let delta = summary.medianPeakDelta else { return .secondary }
        if delta < 30 { return .green }
        else if delta < 60 { return .orange }
        else { return .red }
    }

    var glColor: Color {
        switch glCategory {
        case "Low": return .green
        case "Moderate": return .orange
        default: return .red
        }
    }

    /// Median peak delta formatted for the user's effective unit system.
    /// Internal value is stored in mg/dL; converts to mmol/L for IFCC users.
    var formattedMedianPeakDelta: String? {
        guard let delta = summary.medianPeakDelta else { return nil }
        switch HbA1cUserProfile.shared.effectiveUnit {
        case .ngsp:
            return "+\(Int(delta)) mg/dL"
        case .ifcc:
            let mmolL = delta / 18.0182
            return String(format: "+%.1f mmol/L", mmolL)
        }
    }

    /// Peak delta range formatted similarly. Nil when no range is available.
    var formattedPeakDeltaRange: String? {
        guard let range = summary.peakDeltaRange else { return nil }
        switch HbA1cUserProfile.shared.effectiveUnit {
        case .ngsp:
            return "+\(Int(range.lowerBound)) to +\(Int(range.upperBound)) mg/dL"
        case .ifcc:
            let lo = range.lowerBound / 18.0182
            let hi = range.upperBound / 18.0182
            return String(format: "+%.1f to +%.1f mmol/L", lo, hi)
        }
    }

    /// Lab HbA1c bracket text ("first → last") in the user's effective
    /// unit. Nil when either endpoint is missing.
    var formattedHbA1cBracket: String? {
        guard let first = summary.hba1cAtFirstMatch,
              let last = summary.hba1cAtLastMatch else { return nil }
        let profile = HbA1cUserProfile.shared
        return "\(profile.formatHbA1c(first)) → \(profile.formatHbA1c(last))"
    }

    /// Copy for the empty state, tailored by how many matches were found
    /// and how many had usable glucose data around them.
    var emptyStateMessage: String {
        let needed = HistoricalPatternSummary.minAnalysedForAggregates
        if summary.matchCount == 0 {
            return "No similar meals in the last 90 days yet. Log \(needed) meals with similar carbs to see how your glucose usually responds."
        }
        if summary.analysedCount == 0 {
            return "Found \(summary.matchCount) similar meals, but none had enough glucose data around them to show a pattern."
        }
        let remaining = max(1, needed - summary.analysedCount)
        return "Found \(summary.matchCount) similar meals — \(summary.analysedCount) with usable glucose data. Log \(remaining) more similar meal\(remaining == 1 ? "" : "s") with glucose readings to see your pattern."
    }
}

/// Self-contained view that computes and displays a historical pattern
/// for the currently planned meal. Observes MealBuilder directly so it
/// updates automatically when foods change.
///
/// Self-contained view that computes and displays a historical pattern
/// for the currently planned meal. Observes MealBuilder directly so it
/// updates automatically when foods change.
struct HistoricalPatternContent: View {
    @ObservedObject var mealBuilder: MealBuilder
    var viewContext: NSManagedObjectContext
    var mealType: MealType = .plannedMeal

    @State private var cachedImpact: HistoricalImpactResult?
    @State private var computeTask: Task<Void, Never>?

    var body: some View {
        Group {
            if mealBuilder.selectedFoods.isEmpty {
                Text("Add foods to see your pattern with similar meals.")
                    .foregroundColor(.secondary)
            } else if let impact = cachedImpact {
                if impact.hasAggregates {
                    aggregatesView(impact)
                } else {
                    emptyHistoryView(impact)
                }
            } else {
                // Computing / no result yet — show a muted placeholder.
                Text("Looking for similar meals in your history…")
                    .foregroundColor(.secondary)
            }
        }
        // Compute on first appearance (handles lazy loading in landscape)
        .onAppear { scheduleCompute() }
        // Recompute asynchronously when foods or planned time change
        .onChange(of: mealBuilder.foodCount) { _, _ in scheduleCompute() }
        .onChange(of: mealBuilder.plannedDateTime) { _, _ in scheduleCompute() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func aggregatesView(_ impact: HistoricalImpactResult) -> some View {
        // How many similar meals underpin the aggregates
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.blue)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text("Based on")
                .foregroundColor(.secondary)
            Spacer()
            Text("\(impact.summary.analysedCount) similar meals")
                .fontWeight(.semibold)
        }

        // Typical (median) post-meal glucose rise across those meals
        if let formatted = impact.formattedMedianPeakDelta {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(impact.peakDeltaColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("Typical rise after similar meals")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatted)
                    .fontWeight(.semibold)
                    .foregroundColor(impact.peakDeltaColor)
            }
        }

        // Range across matches (min..max peak delta)
        if let rangeText = impact.formattedPeakDeltaRange {
            HStack {
                Image(systemName: "arrow.up.and.down")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("Range across meals")
                    .foregroundColor(.secondary)
                Spacer()
                Text(rangeText)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }

        // Lab HbA1c bracket (only if we have lab data spanning the window)
        if let bracket = impact.formattedHbA1cBracket {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("Your lab HbA1c in this window")
                    .foregroundColor(.secondary)
                Spacer()
                Text(bracket)
                    .fontWeight(.semibold)
            }
        }

        // Glycemic load of the *current* planned meal — still useful as a
        // descriptive property of what they're about to eat.
        HStack {
            Image(systemName: impact.glCategory == "Low" ? "checkmark.circle.fill" : impact.glCategory == "Moderate" ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(impact.glColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text("Carb impact of this meal")
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(impact.glycemicLoad)) (\(impact.glCategory))")
                .fontWeight(.semibold)
                .foregroundColor(impact.glColor)
        }

        if let recommendation = impact.recommendation {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }

        if let walkRec = impact.walkRecommendation {
            WalkRecommendationCard(recommendation: walkRec)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func emptyHistoryView(_ impact: HistoricalImpactResult) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "clock.badge.questionmark")
                .foregroundColor(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Not enough history yet")
                    .fontWeight(.semibold)
                Text(impact.emptyStateMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        // Still show the glycaemic load of this planned meal even when
        // we can't surface a historical pattern — it's descriptive of
        // the current meal, not a projection.
        HStack {
            Image(systemName: impact.glCategory == "Low" ? "checkmark.circle.fill" : impact.glCategory == "Moderate" ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(impact.glColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text("Carb impact of this meal")
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(impact.glycemicLoad)) (\(impact.glCategory))")
                .fontWeight(.semibold)
                .foregroundColor(impact.glColor)
        }
    }

    // MARK: - Compute

    /// Debounced async computation — avoids blocking the main thread
    private func scheduleCompute() {
        computeTask?.cancel()
        computeTask = Task { @MainActor in
            // Small delay to debounce rapid changes
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            guard !Task.isCancelled else { return }
            cachedImpact = computeImpact()
        }
    }

    /// Build the historical-pattern result for the currently planned meal.
    /// All forward-projection logic has been removed — the summary is
    /// descriptive retrospective analysis on the user's own data.
    private func computeImpact() -> HistoricalImpactResult? {
        guard !mealBuilder.selectedFoods.isEmpty else { return nil }

        let carbs = mealBuilder.totalCarbohydrates
        let gl = mealBuilder.totalGlycemicLoad

        // 1. Look up past meals similar to this one and aggregate their
        //    actual glucose excursions. No forward projection.
        let summary = HistoricalPatternSummary.build(
            plannedCarbs: carbs,
            plannedGL: gl,
            context: viewContext
        )

        // 2. Categorize glycemic load of *this* planned meal (descriptive
        //    property of what's about to be eaten).
        let glCategory: String
        if gl < 10 { glCategory = "Low" }
        else if gl < 20 { glCategory = "Moderate" }
        else { glCategory = "High" }

        // 3. Generic recommendation based on the planned meal's profile.
        //    This is advice about the meal itself, not a prediction of
        //    what will happen.
        let isFeast = (mealType == .feast)
        var recommendation: String? = nil
        if gl > (isFeast ? 30 : 20) && carbs > (isFeast ? 90 : 60) {
            recommendation = isFeast
                ? "Very high carb feast. Some people find a post-meal \(ExerciseOffsetType.current.actionVerb) helpful after meals like this."
                : "High carb impact. Some people choose smaller portions or pair with protein/fiber."
        } else if gl > (isFeast ? 30 : 20) {
            recommendation = "High carb impact. Lower-GI alternatives tend to produce a smaller glucose response."
        } else if carbs > (isFeast ? 100 : 80) {
            recommendation = "High carbs. Protein or healthy fats are sometimes paired with high-carb meals."
        }

        // 4. Walk recommendation — now driven off the *historical* median
        //    peak delta rather than a formula-based projection. Falls back
        //    to nil when we don't have enough history to know.
        let walkRec: String? = {
            guard let medianDelta = summary.medianPeakDelta else { return nil }
            return computeWalkRecommendation(estimatedGlucoseRise: medianDelta)
        }()

        return HistoricalImpactResult(
            summary: summary,
            glycemicLoad: gl,
            glCategory: glCategory,
            recommendation: recommendation,
            walkRecommendation: walkRec
        )
    }

    /// Estimate post-meal exercise duration/distance to help reduce glucose rise.
    ///
    /// Uses the user's preferred exercise type (Walk/Run/Cycle/Swim) set in the
    /// User view. The calculation is MET-based: higher MET activities burn glucose
    /// faster, so running needs fewer minutes than walking for the same offset.
    ///
    /// Clinical basis: a brisk 15-min walk (~3.5 METs) typically reduces the
    /// glucose peak by ~20-30 mg/dL. We scale this for other exercise types
    /// proportionally to their MET values.
    private func computeWalkRecommendation(estimatedGlucoseRise: Double) -> String? {
        guard estimatedGlucoseRise > 15 else { return nil } // Only suggest if meaningful rise

        let exerciseType = ExerciseOffsetType.current

        // Base clinical effect: ~1.5 mg/dL reduction per minute of brisk walking (3.5 METs).
        // Scale for other activities: reductionPerMin = 1.5 × (activityMET / 3.5)
        let walkMET = 3.5
        let reductionPerMinute = 1.5 * (exerciseType.metValue / walkMET)

        // Target reducing ~50% of the estimated glucose rise
        let targetReduction = estimatedGlucoseRise * 0.5
        let rawMinutes = targetReduction / reductionPerMinute
        let exerciseMinutes = min(60, max(5, rawMinutes))
        let roundedMinutes = Int((exerciseMinutes / 5).rounded()) * 5 // Round to nearest 5
        let hitCap = rawMinutes > 60

        // Use personal pace if available, otherwise fall back to type default
        let personalPace = fetchExercisePace(for: exerciseType)
        let pace = personalPace > 0 ? personalPace : exerciseType.defaultPace

        // Calculate distance
        let rawDistance = Double(roundedMinutes) * pace
        let formattedDistance: String
        if exerciseType == .swim {
            // Swim: display in whole metres
            let metres = Int((rawDistance / 50).rounded()) * 50  // Round to nearest 50 m
            formattedDistance = "\(metres) \(exerciseType.distanceUnit)"
        } else {
            formattedDistance = String(format: "%.1f \(exerciseType.distanceUnit)", rawDistance)
        }

        let durationText: String
        if exerciseType.showsDistance && exerciseType != .swim {
            // Walk/Run/Cycle: show duration + km distance
            durationText = hitCap
                ? "at least \(roundedMinutes) min / \(formattedDistance)"
                : "\(roundedMinutes) min / \(formattedDistance)"
        } else {
            // Swim, Gardening, or any other non-distance activity: duration only
            durationText = hitCap
                ? "at least \(roundedMinutes) min"
                : "\(roundedMinutes) min"
        }

        return "For reference, a \(exerciseType.actionVerb) of \(durationText) after a meal like this is sometimes associated with a smaller glucose response."
    }

    /// Query exercise history to get the user's typical pace for a given exercise type.
    /// Returns pace in km/min for walk/run/cycle, or metres/min for swim.
    /// Looks at sessions from the last 30 days that have distance data.
    private func fetchExercisePace(for exerciseType: ExerciseOffsetType) -> Double {
        let fetchRequest: NSFetchRequest<ExerciseSessionEntity> = ExerciseSessionEntity.fetchRequest()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(
            format: "type == %@ AND startDate >= %@ AND distance > 0",
            exerciseType.coreDataType, cutoff as NSDate
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

            // Return personal pace (km/min for walk/run/cycle, m/min for swim)
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
            // `label` is a String parameter (different literal at each call
            // site: "GL", "Carbs", "Fiber", "Protein", "Fat", "Cal") — wrap
            // once here so every call site becomes localizable.
            Text(LocalizedStringKey(label))
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
    let title: LocalizedStringKey
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
                .frame(maxWidth: .infinity)
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
