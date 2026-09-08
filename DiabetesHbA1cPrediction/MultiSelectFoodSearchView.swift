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

/// Top-level database selector shown in Japanese locale
private enum DatabaseMode { case washoku, yoshoku }

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
    @State private var databaseMode: DatabaseMode = .washoku

    /// Recently-added individual food item names (JP locale), persisted in UserDefaults.
    @State private var recentFoodItemNames: [String] = []

    private static let recentFoodItemsKey = "recentFoodItemNames_JP"
    private static let recentFoodItemsMax = 10

    /// Remove a food from the recently-added list and update UserDefaults.
    /// If the list becomes empty, deselects the 最近 category automatically.
    private func removeRecentFood(_ food: FoodItem) {
        var names = recentFoodItemNames
        names.removeAll { $0 == food.name }
        recentFoodItemNames = names
        UserDefaults.standard.set(names, forKey: Self.recentFoodItemsKey)
        if names.isEmpty {
            selectedCategory = nil
        }
    }

    /// Prepend a food to the recently-added list, capped at max 10, most-recent first.
    private func recordRecentFood(_ food: FoodItem) {
        guard isJapaneseLocale else { return }
        var names = recentFoodItemNames
        names.removeAll { $0 == food.name }
        names.insert(food.name, at: 0)
        if names.count > Self.recentFoodItemsMax { names = Array(names.prefix(Self.recentFoodItemsMax)) }
        recentFoodItemNames = names
        UserDefaults.standard.set(names, forKey: Self.recentFoodItemsKey)
    }

    /// True when the app is running in the Japanese locale
    private var isJapaneseLocale: Bool {
        Locale.current.language.languageCode?.identifier == "ja"
    }

    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }

    /// In landscape, only filter after user taps Search to dismiss keyboard;
    /// in portrait, live-filter as the user types.
    private var activeSearchText: String {
        isPortrait ? searchText : committedSearchText
    }

    @ObservedObject private var foodDatabase = FoodDatabase.shared

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

    // Category chips list — locale and mode aware.
    // In Japanese locale, 洋食 mode returns the user-ordered 26 Japanese categories;
    // 和食 mode returns [] because FoodDatabase_JP.json has no sub-categories.
    // In non-Japanese locale, original English category list.
    private var categories: [String] {
        if isJapaneseLocale {
            switch databaseMode {
            case .washoku:
                let available = Set(foodDatabase.japaneseFoodItems.map { $0.category })
                return foodDatabase.japaneseCategories.filter { available.contains($0) }
            case .yoshoku:
                let available = Set(foodDatabase.westernJapaneseFoodItems.map { $0.category })
                return foodDatabase.westernJapaneseCategories.filter { available.contains($0) }
            }
        }
        // Non-Japanese: original alphabetical chip list (My Menu and 日本食 get pinned chips)
        let allCategories = Set(foodDatabase.allFoods.map { $0.category })
        return allCategories
            .filter { $0 != "My Menu" && $0 != "日本食" }
            .sorted { MultiSelectFoodSearchView.chipLabel(for: $0) < MultiSelectFoodSearchView.chipLabel(for: $1) }
    }

    /// Whether the user has any saved "My Menu" items
    private var hasMyMeals: Bool {
        foodDatabase.allFoods.contains { $0.category == "My Menu" }
    }


    // Filtered foods based on locale, database mode, category selection, and search text
    private var filteredFoods: [FoodItem] {
        var foods: [FoodItem]

        if isJapaneseLocale {
            switch databaseMode {
            case .washoku:
                // 和食: use japaneseFoodItems (original JP sub-categories) + My Menu
                let myMenu = foodDatabase.allFoods.filter { $0.category == "My Menu" }
                foods = foodDatabase.japaneseFoodItems + myMenu
            case .yoshoku:
                // 洋食: western items with Japanese names + My Menu
                let myMenu = foodDatabase.allFoods.filter { $0.category == "My Menu" }
                foods = foodDatabase.westernJapaneseFoodItems + myMenu
            }
        } else {
            foods = foodDatabase.allFoods
        }

        // Filter by category if selected.
        // In JP locale the 最近 pseudo-category shows recently added individual food items.
        // In non-JP locale the 最近/Recent pseudo-category is handled by RecentMealsList.
        if let category = selectedCategory {
            if category == recentCategoryKey {
                if isJapaneseLocale {
                    let recentSet = Set(recentFoodItemNames)
                    foods = foods.filter { recentSet.contains($0.name) }
                }
                // non-JP: no filtering — RecentMealsList is shown instead of the food list
            } else {
                foods = foods.filter { $0.category == category }
            }
        }

        // Filter by search text — scoped to the active database.
        // In 洋食 mode, also check the English name (via lookup) so "Tiramisu" finds "ティラミス".
        if !activeSearchText.isEmpty {
            let enLookup = (isJapaneseLocale && databaseMode == .yoshoku)
                ? foodDatabase.westernJapaneseNameEN
                : [String: String]()
            foods = foods.filter { food in
                food.name.localizedCaseInsensitiveContains(activeSearchText) ||
                food.category.localizedCaseInsensitiveContains(activeSearchText) ||
                (enLookup[food.name]?.localizedCaseInsensitiveContains(activeSearchText) ?? false)
            }
        }

        return foods
    }

    // Group foods by category; in 洋食 mode preserve the user-defined category order
    private var groupedFoods: [(category: String, foods: [FoodItem])] {
        let grouped = Dictionary(grouping: filteredFoods) { $0.category }
        let pairs = grouped.map { (category: $0.key, foods: $0.value) }
        if isJapaneseLocale {
            let order = databaseMode == .washoku
                ? foodDatabase.japaneseCategories
                : foodDatabase.westernJapaneseCategories
            return pairs.sorted {
                let i1 = order.firstIndex(of: $0.category) ?? Int.max
                let i2 = order.firstIndex(of: $1.category) ?? Int.max
                return i1 < i2
            }
        }
        return pairs.sorted { $0.category < $1.category }
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
                    recentFoodItemNames: recentFoodItemNames,
                    hasMyMeals: hasMyMeals,
                    isJapaneseLocale: isJapaneseLocale,
                    databaseMode: $databaseMode,
                    onFoodAdded: recordRecentFood,
                    onRemoveFromRecent: removeRecentFood
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                recentMeals = RecentMealsProvider.fetchRecentMeals(context: viewContext, limit: 30)
                if FoodDatabase.shared.loadError != nil {
                    showFoodDbError = true
                }
                // In Japanese locale, pre-load the 和食 DB so it shows immediately
                if isJapaneseLocale {
                    FoodDatabase.shared.loadJapaneseDatabaseIfNeeded()
                    recentFoodItemNames = UserDefaults.standard.stringArray(forKey: Self.recentFoodItemsKey) ?? []
                }
            }
            .onChange(of: databaseMode) { _, newMode in
                // Reset search and category when the user switches databases
                selectedCategory = nil
                searchText = ""
                committedSearchText = ""
                switch newMode {
                case .washoku:
                    FoodDatabase.shared.loadJapaneseDatabaseIfNeeded()
                case .yoshoku:
                    FoodDatabase.shared.loadWesternJapaneseDatabaseIfNeeded()
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
    /// Recently added individual food item names (JP locale only), most-recent first.
    let recentFoodItemNames: [String]
    let hasMyMeals: Bool
    let isJapaneseLocale: Bool
    @Binding var databaseMode: DatabaseMode
    /// Called whenever a food item is added so the parent can record it as recently used.
    let onFoodAdded: (FoodItem) -> Void
    /// Called when the user long-presses a food in the 最近 list to remove it.
    let onRemoveFromRecent: (FoodItem) -> Void

    @State private var showOnlineSearch = false

    /// Whether the "Recent" pseudo-category is active
    private var isRecentSelected: Bool {
        selectedCategory == recentCategoryKey
    }

    /// Show category chips while no search text has been entered.
    /// Chips remain visible even when the keyboard is open so the user can
    /// always see which database / category filter is active.
    private var showCategoryChips: Bool {
        searchText.isEmpty
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

                // 和食 / 洋食 top-level selector — Japanese locale only
                if isJapaneseLocale {
                    HStack(spacing: 16) {
                        DatabaseModePill(title: "和食", isSelected: databaseMode == .washoku) {
                            databaseMode = .washoku
                        }
                        DatabaseModePill(title: "洋食", isSelected: databaseMode == .yoshoku) {
                            databaseMode = .yoshoku
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                }

                // Category chip row — content depends on locale and database mode
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if isJapaneseLocale {
                            // "All" chip label changes with active database
                            CategoryFilterChip(
                                title: LocalizedStringKey(databaseMode == .washoku ? "全和食" : "全洋食"),
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )

                            CategoryFilterChip(
                                title: "マイメニュー",
                                isSelected: selectedCategory == "My Menu",
                                action: { selectedCategory = "My Menu" }
                            )

                            if !recentFoodItemNames.isEmpty {
                                CategoryFilterChip(
                                    title: "最近",
                                    isSelected: isRecentSelected,
                                    action: { selectedCategory = recentCategoryKey }
                                )
                            }

                            // In 洋食 mode, show the 26 Japanese category chips
                            ForEach(categories, id: \.self) { category in
                                CategoryFilterChip(
                                    title: LocalizedStringKey(category),
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        } else {
                            // Non-Japanese: original chip layout
                            CategoryFilterChip(
                                title: "All",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )

                            CategoryFilterChip(
                                title: "My Menu",
                                isSelected: selectedCategory == "My Menu",
                                action: { selectedCategory = "My Menu" }
                            )

                            if Bundle.main.url(forResource: "FoodDatabase_JP", withExtension: "json") != nil {
                                CategoryFilterChip(
                                    title: "日本食",
                                    isSelected: selectedCategory == "日本食",
                                    action: {
                                        FoodDatabase.shared.loadJapaneseDatabaseIfNeeded()
                                        selectedCategory = "日本食"
                                    }
                                )
                            }

                            if !recentMeals.isEmpty {
                                CategoryFilterChip(
                                    title: "Recent",
                                    isSelected: isRecentSelected,
                                    action: { selectedCategory = recentCategoryKey }
                                )
                            }

                            ForEach(categories, id: \.self) { category in
                                CategoryFilterChip(
                                    title: LocalizedStringKey(MultiSelectFoodSearchView.chipLabel(for: category)),
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
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

                    Text(String(format: NSLocalizedString("%lld item(s) selected", comment: ""), Int64(mealBuilder.foodCount)))
                        .font(.subheadline)

                    Spacer()

                    Text(String(format: NSLocalizedString("%lld g carbs", comment: ""), Int64(mealBuilder.totalCarbohydrates)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
            }

            if isRecentSelected && !isJapaneseLocale {
                // Non-JP locale: recent whole-meal sessions from CoreData
                RecentMealsList(recentMeals: recentMeals, mealBuilder: mealBuilder)
            } else if selectedCategory == "My Menu" && !hasMyMeals {
                // Empty My Menu — show helpful onboarding message
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.blue.opacity(0.6))
                        .accessibilityHidden(true)
                    Text("No Meals Yet")
                        .font(.headline)
                    Text("Long-press any food to add it to My Menu for quick access.")
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
                        Section(header: Text(LocalizedStringKey(MultiSelectFoodSearchView.chipLabel(for: group.category)))) {
                            ForEach(group.foods) { food in
                                FoodSelectionRow(
                                    mealBuilder: mealBuilder,
                                    food: food,
                                    onFoodAdded: onFoodAdded
                                )
                                .contextMenu {
                                    // My Menu add/remove — available in all categories.
                                    if FoodDatabase.shared.isFavorite(named: food.name) {
                                        Button(role: .destructive) {
                                            FoodDatabase.shared.removeFavorite(named: food.name)
                                        } label: {
                                            Label("マイメニューから削除", systemImage: "heart.slash")
                                        }
                                    } else {
                                        Button {
                                            FoodDatabase.shared.addFavorite(food)
                                        } label: {
                                            Label("マイメニューに追加", systemImage: "heart")
                                        }
                                    }
                                    // 最近 mode: also offer removal from the recent list.
                                    if isRecentSelected {
                                        Button(role: .destructive) {
                                            onRemoveFromRecent(food)
                                        } label: {
                                            Label("最近から削除", systemImage: "clock.badge.xmark")
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
                        Text(String(format: NSLocalizedString("%lld g carbs", comment: ""), Int64(meal.totalCarbs)))
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

/// Row for displaying a food item with quantity and up/down stepper.
/// Holds a direct `@ObservedObject` reference to `mealBuilder` so the row
/// re-renders immediately when any food is added/removed — without depending
/// on the parent view passing a new `quantity` value through a re-render.
struct FoodSelectionRow: View {
    @ObservedObject var mealBuilder: MealBuilder
    let food: FoodItem
    /// Called after a food is added so the parent can record it as recently used.
    let onFoodAdded: (FoodItem) -> Void

    private var quantity: Double { mealBuilder.quantityFor(food) }

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
                Text(String(format: NSLocalizedString("%lld g carbs", comment: ""), Int64(displayCarbs)))
                    .font(.caption)
                    .foregroundColor(.orange)

                Text("GI: \(food.glycemicIndex)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // `%.0f` uses round-half-to-even (banker's rounding), so a
                // servingSize of exactly 0.5 (e.g. Avocado, Grapefruit — half
                // a fruit is one serving) printed as "0", not "1". Int(...
                // .rounded()) uses round-half-away-from-zero instead, so 0.5
                // now correctly displays as "1".
                Text("\(Int(food.servingSize.rounded())) ") + Text(LocalizedStringKey(food.servingUnit))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// The vertical stepper control (+ on top, – on bottom)
    private var servingStepper: some View {
        VStack(spacing: 0) {
            Button {
                if let index = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == food.id }) {
                    mealBuilder.incrementQuantity(at: index)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .frame(width: 36, height: 28)
                    .foregroundColor(quantity >= 4.0 ? .gray : .blue)
                    .accessibilityLabel("Increase serving")
            }
            .buttonStyle(.plain)
            .disabled(quantity >= 4.0)

            Divider()
                .frame(width: 36)

            Button {
                if let index = mealBuilder.selectedFoods.firstIndex(where: { $0.foodItem.id == food.id }) {
                    mealBuilder.decrementQuantity(at: index)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .frame(width: 36, height: 28)
                    .foregroundColor(quantity <= 0.25 ? .gray : .blue)
                    .accessibilityLabel("Decrease serving")
            }
            .buttonStyle(.plain)
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
                        mealBuilder.addFood(food)
                        onFoodAdded(food)
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
                Button {
                    mealBuilder.addFood(food)
                    onFoodAdded(food)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .accessibilityLabel("Add food")
                }
                .buttonStyle(.plain)
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

/// Large pill for switching between 和食 and 洋食 databases (Japanese locale only)
private struct DatabaseModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(isSelected ? .bold : .medium)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(22)
        }
    }
}

/// Category filter chip button
struct CategoryFilterChip: View {
    let title: LocalizedStringKey
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
