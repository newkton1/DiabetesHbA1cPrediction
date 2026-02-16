import SwiftUI

/// FoodSearchView provides a searchable interface to browse and select foods from the FoodDatabase.
/// Features include:
/// - Searchable list with real-time filtering
/// - Grouped by category when not searching
/// - Color-coded glycemic index (GI) indicators
/// - Selection via binding
/// - Detailed nutritional information display
struct FoodSearchView: View {
    // MARK: - Environment & State
    @Environment(\.dismiss) var dismiss

    @Binding var selectedFood: FoodItem?

    @State private var searchText = ""
    @State private var isSearching = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                if displayedFoods.isEmpty {
                    emptyState
                } else {
                    foodListContent
                }
            }
            .navigationTitle("Search Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search foods"
            )
            .onChange(of: searchText) { _, _ in
                // Update search state
                isSearching = !searchText.isEmpty
            }
        }
    }

    // MARK: - Computed Properties

    /// Returns filtered foods based on search text, or groups by category if not searching
    private var displayedFoods: [FoodItem] {
        if searchText.isEmpty {
            return FoodDatabase.shared.allFoods
        } else {
            return FoodDatabase.shared.search(query: searchText)
        }
    }

    /// Groups displayed foods by category (only when not searching)
    private var foodsByCategory: [String: [FoodItem]] {
        guard !isSearching else { return [:] }

        var grouped: [String: [FoodItem]] = [:]

        for food in displayedFoods {
            if grouped[food.category] != nil {
                grouped[food.category]?.append(food)
            } else {
                grouped[food.category] = [food]
            }
        }

        return grouped
    }

    /// Categories sorted alphabetically
    private var sortedCategories: [String] {
        foodsByCategory.keys.sorted()
    }

    // MARK: - UI Components

    /// Main list content showing foods (grouped by category if not searching)
    @ViewBuilder
    private var foodListContent: some View {
        List {
            if isSearching {
                // Show flat list when searching
                ForEach(displayedFoods) { food in
                    foodRow(for: food)
                }
            } else {
                // Show grouped by category when not searching
                ForEach(sortedCategories, id: \.self) { category in
                    Section(header: Text(category)) {
                        ForEach(foodsByCategory[category] ?? []) { food in
                            foodRow(for: food)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Empty state view when no foods match the search
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Foods Found")
                .font(.headline)
            Text("Try searching with a different keyword")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    /// Builds a row for a single food showing name, serving info, calories, macros, and GI
    @ViewBuilder
    private func foodRow(for food: FoodItem) -> some View {
        Button(action: {
            selectedFood = food
            dismiss()
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Serving size and calories
                    HStack(spacing: 8) {
                        Text("\(String(format: "%.0f", food.servingSize)) \(food.servingUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("\(Int(food.calories)) cal")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    // Carbs and macro info
                    HStack(spacing: 12) {
                        macroBadge(
                            label: "C",
                            value: food.carbohydrates,
                            color: .blue
                        )
                        macroBadge(
                            label: "P",
                            value: food.protein,
                            color: .red
                        )
                        macroBadge(
                            label: "F",
                            value: food.fat,
                            color: .orange
                        )

                        Spacer()
                    }
                    .font(.caption2)
                }

                Spacer()

                // Glycemic Index indicator
                giIndicator(for: Double(food.glycemicIndex))
            }
            .contentShape(Rectangle())
        }
    }

    /// Small badge showing a macro value
    @ViewBuilder
    private func macroBadge(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
            Text("\(String(format: "%.0f", value))g")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(4)
        .foregroundColor(color)
    }

    /// Color-coded GI indicator: green (0-55 Low), yellow (56-69 Medium), red (70+ High)
    @ViewBuilder
    private func giIndicator(for glycemicIndex: Double) -> some View {
        VStack(alignment: .center, spacing: 4) {
            let giColor = giColor(for: glycemicIndex)
            let giLabel = giLabel(for: glycemicIndex)

            HStack(spacing: 4) {
                Circle()
                    .fill(giColor)
                    .frame(width: 8, height: 8)

                Text("\(Int(glycemicIndex))")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Text(giLabel)
                .font(.caption2)
                .foregroundColor(giColor)
                .fontWeight(.semibold)
        }
        .frame(width: 50)
    }

    // MARK: - Helper Methods

    /// Returns the color for a given glycemic index value
    private func giColor(for index: Double) -> Color {
        if index <= 55 {
            return .green
        } else if index <= 69 {
            return .yellow
        } else {
            return .red
        }
    }

    /// Returns the label for a given glycemic index value
    private func giLabel(for index: Double) -> String {
        if index <= 55 {
            return "Low"
        } else if index <= 69 {
            return "Med"
        } else {
            return "High"
        }
    }
}

#Preview {
    FoodSearchView(selectedFood: .constant(nil))
}
