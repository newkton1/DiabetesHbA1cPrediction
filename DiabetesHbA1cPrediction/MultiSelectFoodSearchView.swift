//
//  MultiSelectFoodSearchView.swift
//  DiabetesHbA1cPrediction
//
//  Search view for selecting multiple food items for a meal
//

import SwiftUI

/// View for searching and selecting multiple food items
struct MultiSelectFoodSearchView: View {
    @ObservedObject var mealBuilder: MealBuilder
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var isSearchActive = false

    private var isPortrait: Bool {
        verticalSizeClass != .compact
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
    private var categories: [String] {
        let allCategories = Set(foodDatabase.allFoods.map { $0.category })
        return allCategories.sorted { MultiSelectFoodSearchView.chipLabel(for: $0) < MultiSelectFoodSearchView.chipLabel(for: $1) }
    }

    // Filtered foods based on search and category
    private var filteredFoods: [FoodItem] {
        var foods = foodDatabase.allFoods

        // Filter by category if selected
        if let category = selectedCategory {
            foods = foods.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            foods = foods.filter { food in
                food.name.localizedCaseInsensitiveContains(searchText) ||
                food.category.localizedCaseInsensitiveContains(searchText)
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

    var body: some View {
        NavigationStack {
            FoodSearchContent(
                mealBuilder: mealBuilder,
                searchText: $searchText,
                selectedCategory: $selectedCategory,
                isSearchActive: $isSearchActive,
                isPortrait: isPortrait,
                categories: categories,
                groupedFoods: groupedFoods
            )
            .navigationTitle(!isSearchActive ? (isPortrait ? "" : "Add Foods") : "")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search foods..."
            )
            .onChange(of: searchText) { _, newValue in
                // Reset category filter when user starts searching
                if !newValue.isEmpty {
                    selectedCategory = nil
                }
            }
            .onSubmit(of: .search) {
                // Dismiss keyboard when Search key is tapped
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Inner content view that can read @Environment(\.isSearching)
private struct FoodSearchContent: View {
    @ObservedObject var mealBuilder: MealBuilder
    @Binding var searchText: String
    @Binding var selectedCategory: String?
    @Binding var isSearchActive: Bool
    let isPortrait: Bool
    let categories: [String]
    let groupedFoods: [(category: String, foods: [FoodItem])]

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            // Hide headline and category chips when search is active
            if !isSearching {
                if isPortrait {
                    Text("Add Foods")
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
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: isSearching) { _, newValue in
            isSearchActive = newValue
        }
    }
}

/// Row for displaying a food item with quantity and +1 action
struct FoodSelectionRow: View {
    let food: FoodItem
    let quantity: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Text("\(Int(food.carbohydrates)) g carbs")
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

                Spacer()

                if quantity > 0 {
                    HStack(spacing: 6) {
                        Text("\(quantity)x")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("+1")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
        }
        .buttonStyle(.plain)
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
