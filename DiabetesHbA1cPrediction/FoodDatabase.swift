//
//  FoodDatabase.swift
//  DiabetesHbA1cApp
//
//  Created by iOS Developer
//  Copyright © 2024. All rights reserved.
//

import Foundation
import Combine

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

/// Decodable entry from FoodDatabase_Western_JP.json.
/// Contains only the English name (for nutritional data lookup), the Japanese
/// display name, and the Japanese category. Nutritional values are joined at
/// load time from the original FoodDatabase.json entries.
private struct WesternJPEntry: Decodable {
    let nameEN: String
    let nameJP: String
    let category: String
}

/// Singleton class that manages the comprehensive food database
/// Provides methods to search and filter foods by various criteria
///
/// Conforms to `ObservableObject` so SwiftUI views that hold it via
/// `@ObservedObject` re-render automatically whenever a lazy-loaded
/// database finishes loading or a favorite is added/removed. Previously
/// this was a plain class, which meant views mutating it directly (e.g.
/// `loadWesternJapaneseDatabaseIfNeeded()`, `removeFavorite(named:)`) had
/// no reliable way to tell SwiftUI a re-render was needed — symptoms
/// included the 洋食 category chip row staying empty until an unrelated
/// state change forced a refresh, and removed My Menu items lingering in
/// the list until the sheet was closed and reopened.
class FoodDatabase: ObservableObject {
    /// Shared singleton instance - provides global access to the food database
    static let shared = FoodDatabase()

    /// Array containing all common foods with their nutritional data
    /// Data is loaded from FoodDatabase.json bundled with the app
    @Published private(set) var allFoods: [FoodItem] = []

    /// User's favorite foods added from online searches
    /// Stored separately in the Documents directory so they persist across app updates
    @Published private(set) var favorites: [FoodItem] = []

    /// Error message if the food database failed to load
    private(set) var loadError: String?

    /// URL for the user's favorites file in Documents directory
    private var favoritesFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("UserFavorites.json")
    }

    /// Whether the Japanese database has been loaded into allFoods yet
    private var japaneseDatabaseLoaded = false

    /// Japanese food items with their original sub-categories preserved (mapped to Japanese labels).
    /// Populated alongside allFoods in loadJapaneseDatabaseIfNeeded().
    /// Used in 和食 mode to provide sub-category chip filtering.
    @Published private(set) var japaneseFoodItems: [FoodItem] = []

    /// Ordered category list for 和食 chip row.
    let japaneseCategories: [String] = [
        "米/穀類", "野菜", "果物", "肉類", "魚介類", "豆類",
        "乳製品", "和食・アジア", "惣菜", "飲み物", "調味料",
        "お菓子", "ナッツ類", "冷凍・調理品"
    ]

    /// Maps the English category names from FoodDatabase_JP.json to Japanese display labels.
    static func jpCategoryLabel(for englishCategory: String) -> String {
        switch englishCategory {
        case "Asian & Japanese":       return "和食・アジア"
        case "Beverages":              return "飲み物"
        case "Dairy":                  return "乳製品"
        case "Fish & Seafood":         return "魚介類"
        case "Flavorings":             return "調味料"
        case "Frozen & Prepared Meals": return "冷凍・調理品"
        case "Fruits":                 return "果物"
        case "Grains & Cereals":       return "米/穀類"
        case "Legumes & Beans":        return "豆類"
        case "Meat & Poultry":         return "肉類"
        case "Nuts & Seeds":           return "ナッツ類"
        case "Side Dishes":            return "惣菜"
        case "Snacks & Sweets":        return "お菓子"
        case "Vegetables":             return "野菜"
        default:                       return englishCategory
        }
    }

    /// Western foods with Japanese display names and categories.
    /// Populated lazily by loadWesternJapaneseDatabaseIfNeeded().
    @Published private(set) var westernJapaneseFoodItems: [FoodItem] = []
    private var westernJapaneseDatabaseLoaded = false

    /// Ordered category list for 洋食 chip row (user-defined display order).
    let westernJapaneseCategories: [String] = [
        "米/穀類", "朝ご飯", "果物", "野菜", "乳製品", "惣菜",
        "肉", "魚介類", "豆類", "ナッツ類", "飲み物", "お菓子",
        "調味料", "軽食", "オーブン", "パン類", "麺類", "スープ",
        "シチュー", "和食", "アジア", "行事食", "サラダ", "サンド", "バーガー"
    ]

    /// Private initializer ensures only one instance of FoodDatabase exists
    private init() {
        populateDatabase()
        loadFavorites()
        // Japanese database is loaded lazily via loadJapaneseDatabaseIfNeeded()
    }

    /// Loads the food database from the bundled JSON file
    /// The JSON file contains 1,576 food items across 34 categories
    private func populateDatabase() {
        guard let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json") else {
            loadError = "Food database file is missing. Please reinstall the app."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allFoods = try JSONDecoder().decode([FoodItem].self, from: data)
        } catch {
            loadError = "Food database could not be loaded. Please reinstall the app."
        }
    }

    /// Loads the Japanese government food database (2,538 items) on first demand.
    /// Called when the user taps the 日本食 chip — not at app launch — to save memory.
    func loadJapaneseDatabaseIfNeeded() {
        guard !japaneseDatabaseLoaded else { return }
        guard let url = Bundle.main.url(forResource: "FoodDatabase_JP", withExtension: "json") else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([FoodItem].self, from: data)

            // allFoods gets items tagged "日本食" for backward-compat with the non-JP locale chip
            let tagged = raw.map { item in
                FoodItem(
                    name: item.name,
                    category: "日本食",
                    servingSize: item.servingSize,
                    servingUnit: item.servingUnit,
                    calories: item.calories,
                    carbohydrates: item.carbohydrates,
                    protein: item.protein,
                    fat: item.fat,
                    fiber: item.fiber,
                    glycemicIndex: item.glycemicIndex
                )
            }
            allFoods.append(contentsOf: tagged)

            // japaneseFoodItems preserves the original category, mapped to Japanese labels,
            // so the 和食 mode chip row can show meaningful sub-categories.
            japaneseFoodItems = raw.map { item in
                FoodItem(
                    name: item.name,
                    category: FoodDatabase.jpCategoryLabel(for: item.category),
                    servingSize: item.servingSize,
                    servingUnit: item.servingUnit,
                    calories: item.calories,
                    carbohydrates: item.carbohydrates,
                    protein: item.protein,
                    fat: item.fat,
                    fiber: item.fiber,
                    glycemicIndex: item.glycemicIndex
                )
            }
            japaneseDatabaseLoaded = true
        } catch {
            print("FoodDatabase: Could not load Japanese database — \(error.localizedDescription)")
        }
    }

    /// Loads the western-foods-in-Japanese database (FoodDatabase_Western_JP.json) on first demand.
    /// Each entry's nutritional data is joined from the matching English-named item already in
    /// allFoods, so both JSON files must be present in the app bundle.
    func loadWesternJapaneseDatabaseIfNeeded() {
        guard !westernJapaneseDatabaseLoaded else { return }
        guard let url = Bundle.main.url(forResource: "FoodDatabase_Western_JP", withExtension: "json") else {
            print("FoodDatabase: FoodDatabase_Western_JP.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([WesternJPEntry].self, from: data)

            // Build a fast lookup from English food name → FoodItem (western DB only)
            let lookup: [String: FoodItem] = Dictionary(
                allFoods
                    .filter { $0.category != "日本食" && $0.category != "My Menu" }
                    .map { ($0.name, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            westernJapaneseFoodItems = entries.compactMap { entry in
                guard let original = lookup[entry.nameEN] else { return nil }
                return FoodItem(
                    name: entry.nameJP,
                    category: entry.category,
                    servingSize: original.servingSize,
                    servingUnit: original.servingUnit,
                    calories: original.calories,
                    carbohydrates: original.carbohydrates,
                    protein: original.protein,
                    fat: original.fat,
                    fiber: original.fiber,
                    glycemicIndex: original.glycemicIndex
                )
            }
            westernJapaneseDatabaseLoaded = true
            print("FoodDatabase: Loaded \(westernJapaneseFoodItems.count) 洋食 items")
        } catch {
            print("FoodDatabase: Could not load western Japanese database — \(error.localizedDescription)")
        }
    }

    // MARK: - Favorites Management

    /// Loads user favorites from the Documents directory
    private func loadFavorites() {
        guard let url = favoritesFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            favorites = try JSONDecoder().decode([FoodItem].self, from: data)
            // Migrate legacy "Favorites" and "My Meals" entries to "My Menu"
            var needsSave = false
            favorites = favorites.map { item in
                guard item.category == "Favorites" || item.category == "My Meals" else { return item }
                needsSave = true
                return FoodItem(
                    name: item.name, category: "My Menu",
                    servingSize: item.servingSize, servingUnit: item.servingUnit,
                    calories: item.calories, carbohydrates: item.carbohydrates,
                    protein: item.protein, fat: item.fat,
                    fiber: item.fiber, glycemicIndex: item.glycemicIndex
                )
            }
            // Persist migrated data so the rename sticks
            if needsSave { saveFavorites() }
            // Merge favorites into allFoods so they appear in searches
            allFoods.append(contentsOf: favorites)
        } catch {
            // Silently fail — favorites are a convenience, not critical
            print("FoodDatabase: Could not load favorites — \(error.localizedDescription)")
        }
    }

    /// Saves the current favorites array to disk
    private func saveFavorites() {
        guard let url = favoritesFileURL else { return }
        do {
            let data = try JSONEncoder().encode(favorites)
            try data.write(to: url, options: .atomic)
        } catch {
            print("FoodDatabase: Could not save favorites — \(error.localizedDescription)")
        }
    }

    /// Adds a food item to the user's favorites and persists to disk.
    /// The food is also immediately available in searches via allFoods.
    ///
    /// - Parameter food: The FoodItem to save (typically from an online search)
    func addFavorite(_ food: FoodItem) {
        // Avoid duplicates — check by name since the original may have a different category
        guard !favorites.contains(where: { $0.name == food.name }) else { return }

        // Store with "My Menu" category so it groups nicely in category filters
        let favoriteFood = FoodItem(
            name: food.name,
            category: "My Menu",
            servingSize: food.servingSize,
            servingUnit: food.servingUnit,
            calories: food.calories,
            carbohydrates: food.carbohydrates,
            protein: food.protein,
            fat: food.fat,
            fiber: food.fiber,
            glycemicIndex: food.glycemicIndex
        )

        favorites.append(favoriteFood)
        allFoods.append(favoriteFood)
        saveFavorites()
    }

    /// Removes a food from favorites by name
    ///
    /// - Parameter name: The name of the food to remove
    func removeFavorite(named name: String) {
        favorites.removeAll { $0.name == name }
        allFoods.removeAll { $0.name == name && $0.category == "My Menu" }
        saveFavorites()
    }

    /// Whether a food with the given name exists in favorites
    func isFavorite(named name: String) -> Bool {
        favorites.contains { $0.name == name }
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
