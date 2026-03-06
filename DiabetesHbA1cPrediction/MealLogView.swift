import SwiftUI
import CoreData

/// Segment options for meal log view
enum MealLogSegment: String, CaseIterable {
    case logged = "Logged"
    case planned = "Planned"
}

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

    @State private var showAddMealSheet = false
    @State private var showLastMealSheet = false
    @State private var showPlannedMealSheet = false
    @State private var selectedFood: FoodItem?
    @State private var selectedSegment: MealLogSegment = .logged
    @State private var expandedMealId: UUID? = nil

    // MARK: - Filtered Meals
    
    /// Meals filtered by segment (logged vs planned)
    private var filteredMeals: [MealEntity] {
        switch selectedSegment {
        case .logged:
            return allMeals.filter { $0.mealType != "plannedMeal" }
        case .planned:
            return allMeals.filter { $0.mealType == "plannedMeal" }
        }
    }
    
    /// Groups filtered meals by date
    private var filteredMealsByDate: [Date: [MealEntity]] {
        var grouped: [Date: [MealEntity]] = [:]
        let calendar = Calendar.current

        for meal in filteredMeals {
            let dateToUse: Date
            if selectedSegment == .planned, let plannedDate = meal.plannedDateTime {
                dateToUse = plannedDate
            } else if let timestamp = meal.timestamp {
                dateToUse = timestamp
            } else {
                continue
            }
            
            let dateComponent = calendar.startOfDay(for: dateToUse)

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
            // Segmented control as first row
            Section {
                segmentPicker
            }

            if filteredMeals.isEmpty {
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
                Text("Meal Builder")
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: true, vertical: false)
            }
            toolbarContent
        }
        .sheet(isPresented: $showAddMealSheet) {
            AddMealSheetView(selectedFood: $selectedFood)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showLastMealSheet) {
            LastMealView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showPlannedMealSheet) {
            PlannedMealView(selectedTab: .constant(.meals))
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Landscape Layout (ScrollView-based for proper scrolling)
    private var landscapeBody: some View {
        VStack(spacing: 0) {
            // Header: title on left, + button on right
            HStack {
                Text("Meal Builder")
                    .font(.system(size: 22, weight: .bold))

                Spacer()

                Menu {
                    Button(action: { showLastMealSheet = true }) {
                        Label("Log Last Meal", systemImage: "clock.arrow.circlepath")
                    }
                    Button(action: { showPlannedMealSheet = true }) {
                        Label("Plan Meal/Feast", systemImage: "calendar.badge.plus")
                    }
                    Divider()
                    Button(action: { showAddMealSheet = true }) {
                        Label("Quick Add (Manual)", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Segmented control pinned at top
            segmentPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // Scrollable meal content
            ScrollView {
                if filteredMeals.isEmpty {
                    emptyStateView
                        .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredMealsByDate.keys.sorted(by: selectedSegment == .planned ? (<) : (>)), id: \.self) { date in
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
                            ForEach(filteredMealsByDate[date] ?? []) { meal in
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
                                        try? viewContext.save()
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
        .sheet(isPresented: $showAddMealSheet) {
            AddMealSheetView(selectedFood: $selectedFood)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showLastMealSheet) {
            LastMealView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showPlannedMealSheet) {
            PlannedMealView(selectedTab: .constant(.meals))
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Shared Components

    private var segmentPicker: some View {
        Picker("Meal Type", selection: $selectedSegment) {
            ForEach(MealLogSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedSegment == .logged ? "fork.knife" : "calendar")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text(selectedSegment == .logged ? "No Meals Logged" : "No Planned Meals")
                .font(.headline)
            Text(selectedSegment == .logged ? "Log your meals to track nutrition" : "Plan future meals to see their impact")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                if selectedSegment == .logged {
                    showLastMealSheet = true
                } else {
                    showPlannedMealSheet = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedSegment == .logged ? "Build Meal" : "Plan Meal/Feast")
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var mealSections: some View {
        ForEach(filteredMealsByDate.keys.sorted(by: selectedSegment == .planned ? (<) : (>)), id: \.self) { date in
            Section(header: Text(sectionHeader(for: date))) {
                ForEach(filteredMealsByDate[date] ?? []) { meal in
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: { showLastMealSheet = true }) {
                    Label("Log Last Meal", systemImage: "clock.arrow.circlepath")
                }
                Button(action: { showPlannedMealSheet = true }) {
                    Label("Plan Meal/Feast", systemImage: "calendar.badge.plus")
                }
                Divider()
                Button(action: { showAddMealSheet = true }) {
                    Label("Quick Add (Manual)", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
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
        guard let mealsForDate = filteredMealsByDate[date] else { return }

        for index in offsets {
            let mealToDelete = mealsForDate[index]
            viewContext.delete(mealToDelete)
        }

        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            print("Error deleting meal: \(error.localizedDescription)")
            #endif
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
                            
                            Text("\(Int(item.quantity))x")
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
            #if DEBUG
            print("Error saving meal: \(error.localizedDescription)")
            #endif
        }
    }
}

#Preview {
    MealLogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
