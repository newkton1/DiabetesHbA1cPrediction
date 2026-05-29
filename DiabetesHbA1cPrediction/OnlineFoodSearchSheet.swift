//
//  OnlineFoodSearchSheet.swift
//  DiabetesHbA1cPrediction
//
//  Sheet view that searches for foods online when not found in the local database.
//  Shows 3-5 results from the USDA FoodData Central API with an option to
//  add them to the user's Favorites for future offline use.
//

import SwiftUI

/// Sheet presented when a food search returns no local results.
/// Offers to search the USDA database online and display matches.
struct OnlineFoodSearchSheet: View {
    /// The search term that had no local results
    let searchQuery: String

    /// Called when the user selects a food to add to favorites and use
    var onFoodSelected: ((FoodItem) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var searchState: SearchState = .prompt
    @State private var results: [FoodItem] = []
    @State private var errorMessage: String?
    @State private var addedItems: Set<String> = []

    private enum SearchState {
        case prompt       // Initial state — asking if user wants to search online
        case searching    // Loading indicator
        case results      // Showing 3-5 matches
        case error        // Something went wrong
        case noResults    // API returned nothing
    }

    var body: some View {
        NavigationStack {
            Group {
                switch searchState {
                case .prompt:
                    promptView
                case .searching:
                    searchingView
                case .results:
                    resultsView
                case .error:
                    errorView
                case .noResults:
                    noResultsView
                }
            }
            .navigationTitle("Online Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - State Views

    /// Initial prompt asking if the user wants to search online
    private var promptView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.7))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Search Online?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\"\(searchQuery)\" wasn't found in your local database.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("We can look it up in the USDA nutrition database.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    performSearch()
                } label: {
                    Label("Search Online", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Button("No thanks") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    /// Loading state while querying the API
    private var searchingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching for \"\(searchQuery)\"...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    /// Results list showing 3-5 food matches with nutrition info
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Found \(results.count) match\(results.count == 1 ? "" : "es") for \"\(searchQuery)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 12)

            // Results list
            List {
                ForEach(results) { food in
                    OnlineFoodResultRow(
                        food: food,
                        isAdded: addedItems.contains(food.id),
                        onAdd: {
                            addToFavorites(food)
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)

            // Attribution
            Text("Data: USDA FoodData Central")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
    }

    /// Error state
    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text("Search Failed")
                .font(.headline)

            Text(errorMessage ?? "Please check your connection and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
    }

    /// No results from the API
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .accessibilityHidden(true)

            Text("No Matches Found")
                .font(.headline)

            Text("The USDA database didn't have results for \"\(searchQuery)\". Try a more specific name like \"chicken pad thai\" instead of just \"pad thai\".")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Actions

    /// Kicks off the online search
    private func performSearch() {
        searchState = .searching

        Task {
            do {
                let foods = try await FoodAPIService.shared.search(query: searchQuery)
                await MainActor.run {
                    if foods.isEmpty {
                        searchState = .noResults
                    } else {
                        results = foods
                        searchState = .results
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    searchState = .error
                }
            }
        }
    }

    /// Adds a food to the user's local favorites and notifies the parent
    private func addToFavorites(_ food: FoodItem) {
        // Save to local favorites JSON
        FoodDatabase.shared.addFavorite(food)

        // Mark as added in the UI
        _ = withAnimation {
            addedItems.insert(food.id)
        }

        // Notify parent view
        onFoodSelected?(food)
    }
}

// MARK: - Result Row

/// A single food result row showing name, serving, macros, GI, and an Add button
private struct OnlineFoodResultRow: View {
    let food: FoodItem
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Serving and calories
                Text("\(String(format: "%.0f", food.servingSize)) \(food.servingUnit) · \(Int(food.calories)) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Macros — single concatenated Text so labels can't jumble on narrow screens
                macrosText(carbs: food.carbohydrates, protein: food.protein,
                           fat: food.fat, fiber: food.fiber)

                // Glycemic index
                HStack(spacing: 4) {
                    Text("GI: \(food.glycemicIndex)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(giLabel(food.glycemicIndex))
                        .font(.caption)
                        .foregroundColor(giColor(food.glycemicIndex))
                }
            }

            Spacer()

            // Add button
            if isAdded {
                Label("Added", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .labelStyle(.iconOnly)
                    .font(.title2)
            } else {
                Button(action: onAdd) {
                    Text("+ Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private func macrosText(carbs: Double, protein: Double, fat: Double, fiber: Double) -> some View {
        (Text("C: ").foregroundColor(.orange).fontWeight(.medium) +
         Text("\(Int(carbs)) g").foregroundColor(.secondary) +
         Text("  P: ").foregroundColor(.blue).fontWeight(.medium) +
         Text("\(Int(protein)) g").foregroundColor(.secondary) +
         Text("  F: ").foregroundColor(.purple).fontWeight(.medium) +
         Text("\(Int(fat)) g").foregroundColor(.secondary) +
         Text("  Fib: ").foregroundColor(.green).fontWeight(.medium) +
         Text("\(Int(fiber)) g").foregroundColor(.secondary))
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private func giLabel(_ gi: Int) -> String {
        if gi <= 55 { return "Low" }
        if gi <= 69 { return "Med" }
        return "High"
    }

    private func giColor(_ gi: Int) -> Color {
        if gi > 69 { return .red }
        return .gray
    }
}

// MARK: - Preview

#Preview {
    OnlineFoodSearchSheet(searchQuery: "pad thai")
}
