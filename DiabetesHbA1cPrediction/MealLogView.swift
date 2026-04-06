import SwiftUI
import CoreData

// MealLogView — displays chronological meal history

/// MealLogView displays a chronological list of logged meals grouped by date.
/// Users can add new meals, delete existing ones, and view nutritional summaries.
/// The view integrates with CoreData (MealEntity) and allows food selection from a database.
struct MealLogView: View {
    // MARK: - Environment & State
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    /// Fetch all meals from CoreData, sorted by timestamp (most recent first)
    @FetchRequest(
        entity: MealEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)
        ]
    ) private var allMeals: FetchedResults<MealEntity>

    @State private var expandedMealId: UUID? = nil
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    // MARK: - Meals (logged only, excludes planned/feast)

    /// All logged meals (not planned meals — feasts appear after they are saved)
    private var loggedMeals: [MealEntity] {
        allMeals.filter { $0.mealType != "plannedMeal" }
    }

    /// Groups logged meals by date
    private var mealsByDate: [Date: [MealEntity]] {
        var grouped: [Date: [MealEntity]] = [:]
        let calendar = Calendar.current

        for meal in loggedMeals {
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

    // MARK: - Body
    var body: some View {
        NavigationStack {
            if isPortrait {
                portraitBody
            } else {
                landscapeBody
            }
        }
    }

    // MARK: - Portrait Layout (List-based)
    private var portraitBody: some View {
        List {
            if loggedMeals.isEmpty {
                Section {
                    emptyStateView
                }
            } else {
                mealSections
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Meals")
                    .font(.title3.bold())
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    // MARK: - Landscape Layout (ScrollView-based for proper scrolling)
    private var landscapeBody: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Meals")
                    .font(.title3.bold())

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Scrollable meal content
            ScrollView {
                if loggedMeals.isEmpty {
                    emptyStateView
                        .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(mealsByDate.keys.sorted(by: >), id: \.self) { date in
                            // Section header
                            HStack {
                                Text(sectionHeader(for: date))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                            // Meal rows
                            ForEach(mealsByDate[date] ?? []) { meal in
                                MealRowView(
                                    meal: meal,
                                    isExpanded: expandedMealId == meal.id,
                                    onTap: {
                                        withAnimation {
                                            if expandedMealId == meal.id {
                                                expandedMealId = nil
                                            } else {
                                                expandedMealId = meal.id
                                            }
                                        }
                                    },
                                    timeFormatter: timeFormatter
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewContext.delete(meal)
                                        do {
                                            try viewContext.save()
                                        } catch {
                                            saveErrorMessage = "Could not delete meal. Please try again."
                                            showSaveError = true
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 2)

                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    // MARK: - Shared Components

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            Text("No Meals Logged")
                .font(.headline)
            Text("Use the Add Meal card on the Dashboard to log meals")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var mealSections: some View {
        ForEach(mealsByDate.keys.sorted(by: >), id: \.self) { date in
            Section(header: Text(sectionHeader(for: date))) {
                ForEach(mealsByDate[date] ?? []) { meal in
                    MealRowView(
                        meal: meal,
                        isExpanded: expandedMealId == meal.id,
                        onTap: {
                            withAnimation {
                                if expandedMealId == meal.id {
                                    expandedMealId = nil
                                } else {
                                    expandedMealId = meal.id
                                }
                            }
                        },
                        timeFormatter: timeFormatter
                    )
                }
                .onDelete { indices in
                    deleteMeals(at: indices, for: date)
                }
            }
        }
    }

    /// Generate section header text
    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }

    // MARK: - Computed Properties

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

            // Macro summary — portrait: bulleted vertical list; landscape: horizontal badges
            if isPortrait {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 0) {
                        MacroBulletRow(label: "Carbs", value: getTotalMacro(from: meal, type: "carbs"), color: .orange)
                        Spacer()
                        MacroBulletRow(label: "Proteins", value: getTotalMacro(from: meal, type: "protein"), color: .blue)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        MacroBulletRow(label: "Fiber", value: getTotalMacroOptional(from: meal, type: "fiber") ?? 0, color: .green)
                        Spacer()
                        MacroBulletRow(label: "Fats", value: getTotalMacro(from: meal, type: "fat"), color: .purple)
                        Spacer()
                    }
                }
                .font(.caption)
            } else {
                HStack(spacing: 6) {
                    MacroBadge(label: "Carbs", value: getTotalMacro(from: meal, type: "carbs"), color: .orange)
                    MacroBadge(label: "Fiber", value: getTotalMacroOptional(from: meal, type: "fiber") ?? 0, color: .green)
                    MacroBadge(label: "Protein", value: getTotalMacro(from: meal, type: "protein"), color: .blue)
                    MacroBadge(label: "Fat", value: getTotalMacro(from: meal, type: "fat"), color: .purple)
                    Spacer()
                }
                .font(.caption)
            }
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
            saveErrorMessage = "Could not delete meal. Please try again."
            showSaveError = true
        }
    }
}

// MARK: - Meal Row View

/// A row view for displaying a meal with expandable food items
struct MealRowView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let meal: MealEntity
    let isExpanded: Bool
    let onTap: () -> Void
    let timeFormatter: DateFormatter

    /// True when the device is in portrait orientation
    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    /// Get food items from the meal
    private var foodItems: [MealFoodItemEntity] {
        guard let items = meal.foodItems as? Set<MealFoodItemEntity> else { return [] }
        return items.sorted { ($0.foodName ?? "") < ($1.foodName ?? "") }
    }
    
    /// Get total carbs from macronutrients
    private var totalCarbs: Double {
        guard let macros = meal.macronutrients as? Set<MacronutrientEntity> else { return 0 }
        return macros.filter { $0.type == "carbohydrates" || $0.type == "carbs" }.reduce(0) { $0 + $1.amount }
    }
    
    /// Get total protein
    private var totalProtein: Double {
        guard let macros = meal.macronutrients as? Set<MacronutrientEntity> else { return 0 }
        return macros.filter { $0.type == "protein" }.reduce(0) { $0 + $1.amount }
    }
    
    /// Get total fat
    private var totalFat: Double {
        guard let macros = meal.macronutrients as? Set<MacronutrientEntity> else { return 0 }
        return macros.filter { $0.type == "fat" }.reduce(0) { $0 + $1.amount }
    }
    
    /// Get total fiber
    private var totalFiber: Double {
        guard let macros = meal.macronutrients as? Set<MacronutrientEntity> else { return 0 }
        return macros.filter { $0.type == "fiber" }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row (tappable)
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(meal.name ?? "Meal")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if !foodItems.isEmpty {
                                Text("(\(foodItems.count) item\(foodItems.count == 1 ? "" : "s"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let timestamp = meal.timestamp {
                            HStack(spacing: 4) {
                                Text(timeFormatter.string(from: timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if meal.mealType == "lastMeal" && meal.timeSinceLastMeal > 0 {
                                    Text("• \(meal.timeSinceLastMeal, specifier: "%.1f") h ago")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if meal.mealType == "plannedMeal", let plannedDate = meal.plannedDateTime {
                            Text("Planned: \(plannedDate, style: .date) at \(plannedDate, style: .time)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    if !foodItems.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Macro summary — portrait: single-column bulleted list; landscape: horizontal badges
            if isPortrait {
                VStack(alignment: .leading, spacing: 4) {
                    MacroBulletRow(label: "Carbs", value: totalCarbs, color: .orange)
                    MacroBulletRow(label: "Fiber", value: totalFiber, color: .green)
                    MacroBulletRow(label: "Proteins", value: totalProtein, color: .blue)
                    MacroBulletRow(label: "Fats", value: totalFat, color: .purple)
                }
                .font(.caption)
            } else {
                HStack(spacing: 6) {
                    MacroBadge(label: "Carbs", value: totalCarbs, color: .orange)
                    MacroBadge(label: "Fiber", value: totalFiber, color: .green)
                    MacroBadge(label: "Protein", value: totalProtein, color: .blue)
                    MacroBadge(label: "Fat", value: totalFat, color: .purple)
                    Spacer()
                }
                .font(.caption)
            }
            
            // Expanded food items
            if isExpanded && !foodItems.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Food Items:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(foodItems, id: \.id) { item in
                        HStack {
                            Text(item.foodName ?? "Unknown")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(ServingFormatter.displayString(for: item.quantity))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(item.carbsPerServing * item.quantity)) g")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Small macro badge component (used in landscape mode)
struct MacroBadge: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.medium)
            Text("\(Int(value)) g")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}

/// Bulleted macro row component (used in portrait mode)
struct MacroBulletRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\u{2022}")
                .foregroundColor(color)
                .fontWeight(.bold)
            Text(label)
                .foregroundColor(color)
                .fontWeight(.medium)
            Text("\(Int(value)) g")
                .foregroundColor(color)
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
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

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
                        Text("Carbohydrates (g)")
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Calories")
                        TextField("0", text: $calories)
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
            .alert("Save Error", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
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
            saveErrorMessage = "Could not save meal. Please try again."
            showSaveError = true
        }
    }
}

#Preview {
    MealLogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
