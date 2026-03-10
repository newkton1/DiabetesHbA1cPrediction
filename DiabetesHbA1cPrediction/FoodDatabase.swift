//
//  FoodDatabase.swift
//  DiabetesHbA1cApp
//
//  Created by iOS Developer
//  Copyright © 2024. All rights reserved.
//

import Foundation

/// Represents a single food item with comprehensive nutritional information per serving
/// This struct is used to store and retrieve nutritional data for foods in the diabetes app
struct FoodItem: Identifiable, Equatable, Codable {
    /// Unique identifier for the food item
    var id: String { name + category }

    /// The name of the food item
    let name: String

    /// The category the food belongs to (e.g., "Fruits", "Vegetables", "Meat & Poultry")
    let category: String

    /// The size of a single serving (e.g., 1, 100, 1.5)
    let servingSize: Double

    /// The unit of measurement for the serving (e.g., "medium", "cup", "100g", "oz")
    let servingUnit: String

    /// Total calories per serving
    let calories: Double

    /// Carbohydrates in grams per serving (important for glucose impact)
    let carbohydrates: Double

    /// Protein in grams per serving
    let protein: Double

    /// Fat in grams per serving
    let fat: Double

    /// Dietary fiber in grams per serving (impacts net carbs)
    let fiber: Double

    /// Glycemic Index (0-100 scale, indicates how quickly the food raises blood glucose)
    /// Lower GI foods have less impact on blood glucose spikes
    let glycemicIndex: Int

    /// Calculated net carbs (carbohydrates - fiber)
    /// This is important for diabetes management as fiber doesn't significantly impact blood glucose
    var netCarbs: Double {
        return max(0, carbohydrates - fiber)
    }

    /// Exclude computed properties from Codable
    private enum CodingKeys: String, CodingKey {
        case name, category, servingSize, servingUnit
        case calories, carbohydrates, protein, fat, fiber, glycemicIndex
    }
}

/// Singleton class that manages the comprehensive food database
/// Provides methods to search and filter foods by various criteria
class FoodDatabase {
    /// Shared singleton instance - provides global access to the food database
    static let shared = FoodDatabase()

    /// Array containing all common foods with their nutritional data
    /// Data is loaded from FoodDatabase.json bundled with the app
    private(set) var allFoods: [FoodItem] = []

    /// Private initializer ensures only one instance of FoodDatabase exists
    private init() {
        populateDatabase()
    }

    /// Loads the food database from the bundled JSON file
    /// The JSON file contains 1,576 food items across 34 categories
    private func populateDatabase() {
        guard let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json") else {
            print("FoodDatabase.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allFoods = try JSONDecoder().decode([FoodItem].self, from: data)
        } catch {
            print("Failed to load food database: \(error)")
        }
    }

    /// Searches for foods by name using case-insensitive matching
    /// Useful for finding specific foods the user is looking for
    ///
    /// - Parameter query: The search term (name or partial name of the food)
    /// - Returns: Array of FoodItem objects matching the search term
    func search(query: String) -> [FoodItem] {
        let lowercaseQuery = query.lowercased()
        return allFoods.filter { $0.name.lowercased().contains(lowercaseQuery) }
    }

    /// Retrieves all foods in a specific category
    /// Helps users browse foods by category for meal planning
    ///
    /// - Parameter category: The name of the category to filter by
    /// - Returns: Array of FoodItem objects in the specified category
    func foods(inCategory category: String) -> [FoodItem] {
        return allFoods.filter { $0.category == category }
    }

    /// Computed property that returns all unique food categories in alphabetical order
    /// Useful for displaying available categories to the user for browsing
    var categories: [String] {
        let uniqueCategories = Set(allFoods.map { $0.category })
        return Array(uniqueCategories).sorted()
    }
}
