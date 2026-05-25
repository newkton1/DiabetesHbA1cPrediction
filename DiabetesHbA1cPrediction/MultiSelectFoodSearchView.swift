//
//  MultiSelectFoodSearchView.swift
//  DiabetesHbA1cPrediction
//
//  Search view for selecting multiple food items for a meal
//

import SwiftUI
import CoreData

/// Sentinel value for the "Recent" pseudo-category
private let recentCategoryKey = "__recent__"

/// View for searching and selecting multiple food items
struct MultiSelectFoodSearchView: View {
    @ObservedObject var mealBuilder: MealBuilder
    var mealType: MealType = .lastMeal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
    @State private var committedSearchText = ""
    @State private var selectedCategory: String? = nil
    @State private var recentMeals: [RecentMeal] = []
    @State private var showFoodDbError = false

    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }

    /// In landscape, only filter after user taps Search to dismiss keyboard;
    /// in portrait, live-filter as the user types.
    private var activeSearchText: String {
        isPortrait ? searchText : committedSearchText
    }

    private let foodDatabase = FoodDatabase.shared

    /// Short labels for category filter chips to save horizontal space
    private static let categoryChipLabels: [String: String] = [
        "Asian & Japanese": "Asian",
        "Baked Goods": "Baked",
        "Breads & Bakery": "Bakery",
        "Breakfast Dishes": "Breakfasts",
        "British Foods": "British",
        "Burgers & Hot Dogs": "Burgers/Dogs",
        "Deli & Charcuterie": "Deli",
        "European Foods": "European",
        "Fast Food": "Fast",
        "Fish & Seafood": "Sea",
        "Frozen & Prepared Meals": "Frozen",
        "Grains & Cereals": "Grains",
        "Legumes & Beans": "Beans",
        "Meat & Poultry": "Meat",
        "Nuts & Seeds": "Nuts",
        "Pasta & Italian": "Italian",
        "Pasta & Noodles": "Noodles",
        "Roasts & Casseroles": "Oven",
        "Sandwiches & Wraps": "Finger Food",
        "Snacks & Sweets": "Sweets/Candies",
        "Soups & Stews": "Soups",
        "Steaks & Grills": "Grills"
    ]

    /// Returns the short chip label for a category, or the category name itself if no mapping exists
    static func chipLabel(for category: String) -> String {
        categoryChipLabels[category] ?? category
    }

    // Get unique categories sorted alphabetically by chip label
    // "My Meals" is excluded here because it gets its own pinned chip
    private var categories: [String] {
        let allCategories = Set(foodDatabase.allFoods.map { $0.category })
        return allCategories
            .filter { $0 != "My Meals" }
            .sorted { MultiSelectFoodSearchView.chipLabel(for: $0) < MultiSelectFoodSearchView.chipLabel(for: $1) }
    }

    /// Whether the user has any saved "My Meals" items
    private var hasMyMeals: Bool {
        foodDatabase.allFoods.contains { $0.category == "My Meals" }
    }

    // Filtered foods based on search and category
    private var filteredFoods: [FoodItem] {
        var foods = foodDatabase.allFoods

        // Filter by category if selected (skip for the Recent pseudo-category)
        if let category = selectedCategory, category != recentCategoryKey {
            foods = foods.filter { $0.category == category }
        }

        // Filter by search text (live in portrait, on-submit in landscape)
        if !activeSearchText.isEmpty {
            foods = foods.filter { food in
                food.name.localizedCaseInsensitiveContains(activeSearchText) ||
                food.category.localizedCaseInsensitiveContains(activeSearchText)
            }
        }

        return foods
    }

    // Group foods by category for display
    private var groupedFoods: [(category: String, foods: [FoodItem])] {
        let grouped = Dictionary(grouping: filteredFoods) { $0.category }
        return grouped.map { (category: $0.key, foods: $0.value) }
            .sorted { $0.category < $1.category }
    }

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom search bar with + button instead of system X
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        TextField("Search foods...", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .focused($isSearchFieldFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                committedSearchText = searchText
                                isSearchFieldFocused = false
                            }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                committedSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .accessibilityLabel("Clear search")
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)

                    // Large + button replaces the system Cancel X
                    Button {
                        if isSearchFieldFocused {
                            isSearchFieldFocused = false
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .accessibilityLabel("Done adding foods")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                FoodSearchContentDirect(
                    mealBuilder: mealBuilder,
                    searchText: $searchText,
                    selectedCategory: $selectedCategory,
                    isSearchFieldFocused: _isSearchFieldFocused,
                    isPortrait: isPortrait,
                    mealType: mealType,
                    categories: categories,
                    groupedFoods: groupedFoods,
                    recentMeals: recentMeals,
                    hasMyMeals: hasMyMeals
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                recentMeals = RecentMealsProvider.fetchRecentMeals(context: viewContext, limit: 30)
                if FoodDatabase.shared.loadError != nil {
                    showFoodDbError = true
                }
            }
            .alert("Food Database Error", isPresented: $showFoodDbError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(FoodDatabase.shared.loadError ?? "The food database could not be loaded.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mealType == .feast ? "Plan" : "Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: activeSearchText) { _, newValue in
                // Reset category filter when user searches
                if !newValue.isEmpty {
                    selectedCategory = nil
                }
            }
        }
    }
}

/// Inner content view using custom search bar (no .searchable dependency)
private struct FoodSearchContentDirect: View {
    @ObservedObject var mealBuilder: MealBuilder
    @Binding var searchText: String
    @Binding var selectedCategory: String?
    @FocusState var isSearchFieldFocused: Bool
    let isPortrait: Bool
    let mealType: MealType
    let categories: [String]
    let groupedFoods: [(category: String, foods: [FoodItem])]
    let recentMeals: [RecentMeal]
    let hasMyMeals: Bool

    @State private var showOnlineSearch = false

    /// Whether the "Recent" pseudo-category is active
    private var isRecentSelected: Bool {
        selectedCategory == recentCategoryKey
    }

    /// Show category chips when search text is empty and field is not focused
    private var showCategoryChips: Bool {
        searchText.isEmpty && !isSearchFieldFocused
    }

    var body: some View {
        VStack(spacing: 0) {
            // Show headline and category chips when not actively searching
            if showCategoryChips {
                if isPortrait {
                    Text(mealType == .feast ? "Add Treat" : "Add Foods")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        // My Meals chip — always visible for discoverability
                        CategoryFilterChip(
                            title: "My Meals",
                            isSelected: selectedCategory == "My Meals",
                            action: { selectedCategory = "My Meals" }
                        )

                        // Recent meals chip — only show if there are saved meals
                        if !recentMeals.isEmpty {
                            CategoryFilterChip(
                                title: "Recent",
                                isSelected: isRecentSelected,
                                action: { selectedCategory = recentCategoryKey }
                            )
                        }

                        ForEach(categories, id: \.self) { category in
                            CategoryFilterChip(
                                title: MultiSelectFoodSearchView.chipLabel(for: category),
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGroupedBackground))
            }

            // Selected count banner (always visible)
            if mealBuilder.foodCount > 0 {
                HStack {
                    Image(systemName: "cart.fill")
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)

                    Text("\(mealBuilder.foodCount) item\(mealBuilder.foodCount == 1 ? "" : "s") selected")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(mealBuilder.totalCarbohydrates)) g carbs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
            }

            if isRecentSelected {
                // Recent meals list
                RecentMealsList(recentMeals: recentMeals, mealBuilder: mealBuilder)
            } else if selectedCategory == "My Meals" && !hasMyMeals {
                // Empty My Meals — show helpful onboarding message
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.blue.opacity(0.6))
                        .accessibilityHidden(true)
                    Text("No Meals Yet")
                        .font(.headline)
                    Text("Long-press any food to add it to My Meals for quick access.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if groupedFoods.isEmpty && !searchText.isEmpty {
                // No local results — offer online search
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                    Text("No Foods Found")
                        .font(.headline)
                    Text("Try a different keyword, or search online")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        showOnlineSearch = true
                    } label: {
                        Label("Search Online", systemImage: "globe")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .sheet(isPresented: $showOnlineSearch) {
                    OnlineFoodSearchSheet(searchQuery: searchText) { food in
                        // Add the online result directly to the meal builder
                        mealBuilder.addFood(food)
                    }
                }
            } else {
                // Food list
                List {
                    ForEach(groupedFoods, id: \.category) { group in
                        Section(header: Text(MultiSelectFoodSearchView.chipLabel(for: group.category))) {
                            ForEach(group.foods) { food in
                                FoodSelectionRow(
                                    food: food,
                                    quantity: mealBuilder.quantityFor(food),
                                    onTap: {
                                        mealBuilder.addFood(food)
                                    },
                                    onIncrement: {
                                        if let index = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == food.id }) {
                                            mealBuilder.incrementQuantity(at: index)
                                        }
                                    },
                                    onDecrement: {
                                        if let index = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == food.id }) {
                                            mealBuilder.decrementQuantity(at: index)
                                        }
                                    }
                                )
                                .contextMenu {
                                    if FoodDatabase.shared.isFavorite(named: food.name) {
                                        Button(role: .destructive) {
                                            FoodDatabase.shared.removeFavorite(named: food.name)
                                        } label: {
                                            Label("Remove from My Meals", systemImage: "heart.slash")
                                        }
                                    } else {
                                        Button {
                                            FoodDatabase.shared.addFavorite(food)
                                        } label: {
                                            Label("Add to My Meals", systemImage: "heart")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }
}

/// Displays the list of recent meals as tappable cards
private struct RecentMealsList: View {
    let recentMeals: [RecentMeal]
    @ObservedObject var mealBuilder: MealBuilder
    @State private var loadedMealId: String? = nil

    var body: some View {
        List {
            Section(header: Text("Tap a meal to add all its foods")) {
                ForEach(recentMeals) { meal in
                    RecentMealRow(
                        meal: meal,
                        isLoaded: loadedMealId == meal.id,
                        onTap: {
                            loadRecentMeal(meal)
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Load all foods from a recent meal into the MealBuilder
    private func loadRecentMeal(_ meal: RecentMeal) {
        let foodDatabase = FoodDatabase.shared
        for food in meal.foods {
            // Try to match against the live FoodDatabase for full FoodItem data
            if let dbFood = foodDatabase.allFoods.first(where: {
                $0.name == food.name && $0.category == food.category
            }) {
                // Add with the original quantity from the saved meal
                for _ in 0..<max(1, Int(food.quantity)) {
                    if !mealBuilder.isSelected(dbFood) {
                        mealBuilder.addFood(dbFood)
                        // Set quantity to match the original (addFood starts at 1)
                        if food.quantity > 1,
                           let idx = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == dbFood.id }) {
                            mealBuilder.updateQuantity(at: idx, quantity: food.quantity)
                        }
                        break  // Only add once, then set quantity
                    } else {
                        // Already selected — just set the quantity from the recent meal
                        if let idx = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == dbFood.id }) {
                            mealBuilder.updateQuantity(at: idx, quantity: food.quantity)
                        }
                        break
                    }
                }
            } else {
                // Food not found in current database — build a FoodItem from stored data
                let reconstructed = FoodItem(
                    name: food.name, category: food.category,
                    servingSize: food.servingSize, servingUnit: food.servingUnit,
                    calories: food.calories, carbohydrates: food.carbs,
                    protein: food.protein, fat: food.fat,
                    fiber: food.fiber, glycemicIndex: food.glycemicIndex
                )
                mealBuilder.addFood(reconstructed)
                if food.quantity > 1,
                   let idx = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == reconstructed.id }) {
                    mealBuilder.updateQuantity(at: idx, quantity: food.quantity)
                }
            }
        }
        // Brief visual feedback
        withAnimation { loadedMealId = meal.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { loadedMealId = nil }
        }
    }
}

/// Row displaying a recent meal with its food composition and frequency
private struct RecentMealRow: View {
    let meal: RecentMeal
    let isLoaded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Food names
                    Text(meal.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text("\(Int(meal.totalCarbs)) g carbs")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("\(Int(meal.totalCalories)) cal")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(meal.foods.count) item\(meal.foods.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Frequency badge
                    Text("Eaten \(meal.frequency) time\(meal.frequency == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                Spacer()

                if isLoaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                        .accessibilityLabel("Already added")
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .accessibilityLabel("Add this meal")
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Row for displaying a food item with quantity and up/down stepper
struct FoodSelectionRow: View {
    let food: FoodItem
    let quantity: Double
    let onTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    /// Display carbs adjusted for quantity
    private var displayCarbs: Int {
        if quantity > 0 {
            return Int(food.carbohydrates * quantity)
        }
        return Int(food.carbohydrates)
    }

    /// The food info column (name, carbs, GI, serving)
    private var foodInfoColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(food.name)
                .font(.body)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Text("\(displayCarbs) g carbs")
                    .font(.caption)
                    .foregroundColor(.orange)

                Text("GI: \(food.glycemicIndex)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(food.servingSize, specifier: "%.0f") \(food.servingUnit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// The vertical stepper control (+ on top, – on bottom)
    private var servingStepper: some View {
        VStack(spacing: 0) {
            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .frame(width: 36, height: 28)
                    .foregroundColor(quantity >= 4.0 ? .gray : .blue)
                    .accessibilityLabel("Increase serving")
            }
            .buttonStyle(.borderless)
            .disabled(quantity >= 4.0)

            Divider()
                .frame(width: 36)

            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .frame(width: 36, height: 28)
                    .foregroundColor(quantity <= 0.25 ? .gray : .blue)
                    .accessibilityLabel("Decrease serving")
            }
            .buttonStyle(.borderless)
            .disabled(quantity <= 0.25)
        }
        .background(Color(.systemGray5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray3), lineWidth: 0.5)
        )
    }

    var body: some View {
        HStack {
            // Food info area — tappable to add when not yet selected.
            // onTapGesture is scoped here so it never competes with
            // the stepper Buttons on the trailing side.
            foodInfoColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if quantity <= 0 {
                        onTap()
                    }
                }

            if quantity > 0 {
                HStack(spacing: 8) {
                    // Green serving size display
                    Text(ServingFormatter.displayString(for: quantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)

                    servingStepper
                }
            } else {
                Button(action: onTap) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .accessibilityLabel("Add food")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// Shared utility for formatting serving quantities as fractions
enum ServingFormatter {
    /// Returns a display string like "1/4x", "1/2x", "3/4x", "1x", "2x", etc.
    static func displayString(for quantity: Double) -> String {
        // Handle common fractional values
        if abs(quantity - 0.25) < 0.01 { return "¼x" }
        if abs(quantity - 0.50) < 0.01 { return "½x" }
        if abs(quantity - 0.75) < 0.01 { return "¾x" }
        // Whole numbers
        if abs(quantity - quantity.rounded()) < 0.01 {
            return "\(Int(quantity.rounded()))x"
        }
        // Fallback for unexpected values
        return String(format: "%.2gx", quantity)
    }
}

/// Category filter chip button
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

#Preview {
    MultiSelectFoodSearchView(mealBuilder: MealBuilder())
}
