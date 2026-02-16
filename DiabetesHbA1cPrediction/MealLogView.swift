import SwiftUI
import CoreData

/// MealLogView displays a chronological list of logged meals grouped by date.
/// Users can add new meals, delete existing ones, and view nutritional summaries.
/// The view integrates with CoreData (MealEntity) and allows food selection from a database.
struct MealLogView: View {
    // MARK: - Environment & State
    @Environment(\.managedObjectContext) private var viewContext

    /// Fetch all meals from CoreData, sorted by timestamp (most recent first)
    @FetchRequest(
        entity: MealEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)
        ]
    ) private var allMeals: FetchedResults<MealEntity>

    @State private var showAddMealSheet = false
    @State private var selectedFood: FoodItem?

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                if allMeals.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Meals Logged")
                            .font(.headline)
                        Text("Add your first meal to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        // Group meals by date
                        ForEach(mealsByDate.keys.sorted(by: >), id: \.self) { date in
                            Section(header: Text(dateFormatter.string(from: date))) {
                                ForEach(mealsByDate[date] ?? []) { meal in
                                    mealRow(for: meal)
                                }
                                .onDelete { indices in
                                    deleteMeals(at: indices, for: date)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Meal Log")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddMealSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(.body, design: .rounded))
                    }
                }
            }
            .sheet(isPresented: $showAddMealSheet) {
                AddMealSheetView(selectedFood: $selectedFood)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Computed Properties

    /// Groups meals by calendar date (ignoring time component)
    private var mealsByDate: [Date: [MealEntity]] {
        var grouped: [Date: [MealEntity]] = [:]
        let calendar = Calendar.current

        for meal in allMeals {
            guard let timestamp = meal.timestamp else { continue }
            let dateComponent = calendar.startOfDay(for: timestamp)

            if grouped[dateComponent] != nil {
                grouped[dateComponent]?.append(meal)
            } else {
                grouped[dateComponent] = [meal]
            }
        }

        return grouped
    }

    /// Date formatter for section headers (e.g., "Today", "December 15, 2024")
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    /// Time formatter for displaying meal time (e.g., "2:30 PM")
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    // MARK: - UI Components

    /// Builds a row for a single meal showing name, time, calories, and macro summary
    @ViewBuilder
    private func mealRow(for meal: MealEntity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name ?? "Unknown Meal")
                        .font(.headline)
                    if let timestamp = meal.timestamp {
                        Text(timeFormatter.string(from: timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(getTotalMacro(from: meal, type: "carbs"))) g")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // Macro summary: Carbs, Protein, Fat, Fiber
            HStack(spacing: 8) {
                macroSummaryBadge(
                    label: "Carbs",
                    value: getTotalMacro(from: meal, type: "carbs"),
                    unit: " g",
                    color: .blue
                )
                macroSummaryBadge(
                    label: "Protein",
                    value: getTotalMacro(from: meal, type: "protein"),
                    unit: " g",
                    color: .red
                )
                macroSummaryBadge(
                    label: "Fats",
                    value: getTotalMacro(from: meal, type: "fat"),
                    unit: " g",
                    color: .orange
                )
                if let fiber = getTotalMacroOptional(from: meal, type: "fiber") {
                    macroSummaryBadge(
                        label: "Fiber",
                        value: fiber,
                        unit: " g",
                        color: .green
                    )
                }
                Spacer()
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    /// Small colored badge showing a macro nutrient
    @ViewBuilder
    private func macroSummaryBadge(
        label: String,
        value: Double,
        unit: String,
        color: Color
    ) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
            Text("\(String(format: "%.0f", value))\(unit)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
        .foregroundColor(color)
    }

    // MARK: - Helper Methods

    /// Extracts the total value of a macronutrient from a meal
    private func getTotalMacro(from meal: MealEntity, type: String) -> Double {
        guard let macros = meal.macronutrients as? Set<MacronutrientEntity> else {
            return 0
        }
        return macros
            .filter { $0.type == type }
            .reduce(0) { $0 + $1.amount }
    }

    /// Extracts the total value of a macronutrient from a meal, returning optional
    private func getTotalMacroOptional(from meal: MealEntity, type: String) -> Double? {
        guard let macros = meal.macronutrients as? Set<MacronutrientEntity> else {
            return nil
        }
        let total = macros
            .filter { $0.type == type }
            .reduce(0) { $0 + $1.amount }
        return total > 0 ? total : nil
    }

    /// Deletes meals at specified indices for a given date
    private func deleteMeals(at offsets: IndexSet, for date: Date) {
        guard let mealsForDate = mealsByDate[date] else { return }

        for index in offsets {
            let mealToDelete = mealsForDate[index]
            viewContext.delete(mealToDelete)
        }

        do {
            try viewContext.save()
        } catch {
            print("Error deleting meal: \(error.localizedDescription)")
        }
    }
}

// MARK: - Add Meal Sheet

/// A sheet view for adding a new meal.
/// Allows users to search the food database or manually enter meal details.
struct AddMealSheetView: View {
    // MARK: - Environment & State
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @Binding var selectedFood: FoodItem?

    @State private var mealName = ""
    @State private var calories = ""
    @State private var carbs = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var servingMultiplier: Int = 1
    @State private var selectedDate = Date()
    @State private var showFoodSearchView = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Meal Name Section
                Section(header: Text("Meal Details")) {
                    TextField("Meal name (e.g., Breakfast)", text: $mealName)
                }

                // MARK: Food Database Section
                Section(header: Text("Food Search")) {
                    NavigationLink(destination: FoodSearchView(selectedFood: $selectedFood)) {
                        Text("Search Food Database")
                    }

                    if let selected = selectedFood {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected: \(selected.name)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(Int(selected.servingSize)) \(selected.servingUnit) • \(Int(selected.calories)) cal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Nutrition Section
                Section(header: Text("Nutrition")) {
                    HStack {
                        Text("Calories")
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Carbohydrates (g)")
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Protein (g)")
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Fat (g)")
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Fiber (g)")
                        TextField("0", text: $fiber)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // MARK: Serving Multiplier Section
                Section(header: Text("Serving Size")) {
                    HStack {
                        Text("Multiplier")
                        Spacer()
                        Stepper(
                            value: $servingMultiplier,
                            in: 1...10,
                            step: 1
                        ) {
                            Text("\(servingMultiplier)x")
                        }
                        .fixedSize()
                    }
                }

                // MARK: Timestamp Section
                Section(header: Text("When")) {
                    DatePicker(
                        "Date & Time",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeal()
                    }
                    .disabled(mealName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedFood) { _, newFood in
                // Auto-populate fields when a food is selected from the database
                if let food = newFood {
                    if calories.isEmpty {
                        calories = String(Int(food.calories * Double(servingMultiplier)))
                    }
                    if carbs.isEmpty {
                        carbs = String(Int(food.carbohydrates * Double(servingMultiplier)))
                    }
                    if protein.isEmpty {
                        protein = String(Int(food.protein * Double(servingMultiplier)))
                    }
                    if fat.isEmpty {
                        fat = String(Int(food.fat * Double(servingMultiplier)))
                    }
                    if fiber.isEmpty {
                        fiber = String(Int(food.fiber * Double(servingMultiplier)))
                    }

                    // Auto-fill meal name if empty
                    if mealName.isEmpty {
                        mealName = food.name
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Creates a MealEntity and associated MacronutrientEntities, then saves to CoreData
    private func saveMeal() {
        let newMeal = MealEntity(context: viewContext)
        newMeal.id = UUID()
        newMeal.name = mealName.trimmingCharacters(in: .whitespaces)
        newMeal.calories = Double(calories) ?? 0
        newMeal.timestamp = selectedDate
        newMeal.unitString = "g"

        // Create MacronutrientEntity for each macro if value is provided
        let macroData: [(type: String, value: String)] = [
            ("carbs", carbs),
            ("protein", protein),
            ("fat", fat),
            ("fiber", fiber)
        ]

        for (type, value) in macroData {
            if !value.isEmpty, let amount = Double(value), amount > 0 {
                let macro = MacronutrientEntity(context: viewContext)
                macro.type = type
                macro.amount = amount * Double(servingMultiplier)
                macro.unit = "g"
                macro.meal = newMeal
            }
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving meal: \(error.localizedDescription)")
        }
    }
}

#Preview {
    MealLogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
