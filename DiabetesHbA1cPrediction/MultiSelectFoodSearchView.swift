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

    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }
    
    private let foodDatabase = FoodDatabase.shared
    
    // Get unique categories
    private var categories: [String] {
        let allCategories = Set(foodDatabase.allFoods.map { $0.category })
        return allCategories.sorted()
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
            VStack(spacing: 0) {
                if isPortrait {
                    Text("Add Foods")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }

                // Selected count banner
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
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGroupedBackground))
                
                // Food list
                List {
                    ForEach(groupedFoods, id: \.category) { group in
                        Section(header: Text(group.category)) {
                            ForEach(group.foods) { food in
                                FoodSelectionRow(
                                    food: food,
                                    isSelected: mealBuilder.isSelected(food),
                                    onTap: {
                                        mealBuilder.addFood(food)
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(isPortrait ? "" : "Add Foods")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods...")
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

/// Row for displaying a food item with selection state
struct FoodSelectionRow: View {
    let food: FoodItem
    let isSelected: Bool
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
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
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
