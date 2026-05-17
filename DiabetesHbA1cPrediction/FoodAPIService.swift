//
//  FoodAPIService.swift
//  DiabetesHbA1cPrediction
//
//  Async service to search the USDA FoodData Central API
//  and map results to the app's FoodItem struct.
//

import Foundation

/// Service that queries the USDA FoodData Central API for food nutrition data.
/// Uses the free "Search" endpoint which requires no API key for basic usage.
/// Falls back gracefully if the network is unavailable.
actor FoodAPIService {

    /// Shared instance for convenience
    static let shared = FoodAPIService()

    // MARK: - USDA API Configuration

    /// USDA FoodData Central API key (free demo key — works for moderate usage)
    /// Users can replace this with their own key from https://fdc.nal.usda.gov/api-key-signup.html
    private let apiKey = "DEMO_KEY"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    // MARK: - Response Models (USDA JSON shape)

    private struct SearchResponse: Decodable {
        let foods: [USDAFood]?
        let totalHits: Int?
    }

    private struct USDAFood: Decodable {
        let fdcId: Int
        let description: String
        let brandName: String?
        let foodCategory: String?
        let foodNutrients: [USDANutrient]?
        let servingSize: Double?
        let servingSizeUnit: String?
    }

    private struct USDANutrient: Decodable {
        let nutrientId: Int?
        let nutrientName: String?
        let value: Double?
        let unitName: String?
    }

    // MARK: - USDA Nutrient IDs

    private enum NutrientID {
        static let energy = 1008        // kcal
        static let protein = 1003       // g
        static let totalFat = 1004      // g
        static let carbohydrate = 1005  // g
        static let fiber = 1079         // g
    }

    // MARK: - Public API

    /// Searches the USDA database for foods matching the query.
    /// Returns up to 5 results mapped to the app's FoodItem format.
    ///
    /// - Parameter query: The food name to search for (e.g., "pad thai")
    /// - Returns: Array of FoodItem results (0-5 items)
    /// - Throws: `FoodAPIError` if network or parsing fails
    func search(query: String) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy")
        ]

        guard let url = components.url else {
            throw FoodAPIError.invalidURL
        }

        // Make the request
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAPIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw FoodAPIError.serverError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)

        guard let usdaFoods = decoded.foods, !usdaFoods.isEmpty else {
            return []
        }

        // Map USDA results to our FoodItem format
        return usdaFoods.compactMap { mapToFoodItem($0) }
    }

    // MARK: - Mapping

    /// Maps a USDA food result to our app's FoodItem struct
    private func mapToFoodItem(_ usdaFood: USDAFood) -> FoodItem? {
        let nutrients = usdaFood.foodNutrients ?? []

        // Extract nutrient values by ID
        let calories = nutrientValue(from: nutrients, id: NutrientID.energy)
        let protein = nutrientValue(from: nutrients, id: NutrientID.protein)
        let fat = nutrientValue(from: nutrients, id: NutrientID.totalFat)
        let carbs = nutrientValue(from: nutrients, id: NutrientID.carbohydrate)
        let fiber = nutrientValue(from: nutrients, id: NutrientID.fiber)

        // Clean up the food name (USDA names are often ALL CAPS or overly detailed)
        let cleanName = cleanFoodName(usdaFood.description)

        // Determine category from USDA's foodCategory field
        let category = mapCategory(usdaFood.foodCategory)

        // Determine serving size — USDA often reports per 100g
        let servingSize: Double
        let servingUnit: String
        if let size = usdaFood.servingSize, size > 0, let unit = usdaFood.servingSizeUnit {
            servingSize = size
            servingUnit = unit.lowercased()
        } else {
            // Default to 100g when USDA doesn't specify
            servingSize = 100
            servingUnit = "g"
        }

        // Estimate glycemic index based on carb/fiber ratio and food type
        let gi = estimateGlycemicIndex(
            name: cleanName,
            carbs: carbs,
            fiber: fiber,
            category: category
        )

        return FoodItem(
            name: cleanName,
            category: category,
            servingSize: servingSize,
            servingUnit: servingUnit,
            calories: calories,
            carbohydrates: carbs,
            protein: protein,
            fat: fat,
            fiber: fiber,
            glycemicIndex: gi
        )
    }

    /// Extracts a nutrient value by its USDA nutrient ID
    private func nutrientValue(from nutrients: [USDANutrient], id: Int) -> Double {
        nutrients.first(where: { $0.nutrientId == id })?.value ?? 0.0
    }

    /// Cleans up USDA food names which are often overly verbose or ALL CAPS
    private func cleanFoodName(_ raw: String) -> String {
        // If entirely uppercase, convert to title case
        var name = raw
        if name == name.uppercased() && name.count > 3 {
            name = name.capitalized
        }

        // Remove trailing commas and clean up
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasSuffix(",") {
            name = String(name.dropLast())
        }

        // Truncate overly long names (keep first meaningful portion)
        if name.count > 60 {
            let parts = name.components(separatedBy: ",")
            if parts.count > 2 {
                name = parts.prefix(2).joined(separator: ", ")
            }
        }

        return name
    }

    /// Maps USDA food category string to one of our app's 34 categories
    private func mapCategory(_ usdaCategory: String?) -> String {
        guard let cat = usdaCategory?.lowercased() else { return "Online Search" }

        // Map common USDA categories to our app's categories
        let mapping: [(keywords: [String], appCategory: String)] = [
            (["grain", "cereal", "bread", "rice", "wheat"], "Grains & Cereals"),
            (["fruit"], "Fruits"),
            (["vegetable", "veggie"], "Vegetables"),
            (["beef", "pork", "lamb", "poultry", "chicken", "turkey", "meat"], "Meat & Poultry"),
            (["fish", "seafood", "shrimp", "salmon"], "Fish & Seafood"),
            (["dairy", "milk", "cheese", "yogurt"], "Dairy"),
            (["nut", "seed"], "Nuts & Seeds"),
            (["legume", "bean", "lentil", "pea"], "Legumes & Beans"),
            (["snack", "candy", "sweet", "chocolate"], "Snacks & Sweets"),
            (["beverage", "drink", "juice", "soda"], "Beverages"),
            (["soup", "stew"], "Soups & Stews"),
            (["pasta", "noodle", "spaghetti"], "Pasta & Noodles"),
            (["baked", "cake", "cookie", "pie"], "Baked Goods"),
            (["fast food", "restaurant"], "Fast Food"),
            (["egg"], "Eggs"),
            (["oil", "fat", "butter"], "Oils & Fats"),
            (["spice", "herb", "condiment", "sauce"], "Condiments & Sauces")
        ]

        for entry in mapping {
            if entry.keywords.contains(where: { cat.contains($0) }) {
                return entry.appCategory
            }
        }

        return "Online Search"
    }

    /// Estimates glycemic index when USDA doesn't provide it directly.
    /// Uses heuristics based on food type and carb/fiber content.
    private func estimateGlycemicIndex(name: String, carbs: Double, fiber: Double, category: String) -> Int {
        let lowerName = name.lowercased()

        // Known high-GI foods
        let highGI = ["white rice", "white bread", "potato", "corn flakes", "watermelon", "glucose"]
        if highGI.contains(where: { lowerName.contains($0) }) { return 72 }

        // Known low-GI foods
        let lowGI = ["lentil", "chickpea", "bean", "nut", "almond", "walnut",
                     "barley", "quinoa", "oat", "apple", "pear", "cherry"]
        if lowGI.contains(where: { lowerName.contains($0) }) { return 35 }

        // Medium-GI indicators
        let medGI = ["brown rice", "whole wheat", "banana", "mango", "pineapple", "pasta"]
        if medGI.contains(where: { lowerName.contains($0) }) { return 55 }

        // Heuristic: high fiber relative to carbs → lower GI
        if carbs > 0 {
            let fiberRatio = fiber / carbs
            if fiberRatio > 0.15 { return 35 }
            if fiberRatio > 0.08 { return 50 }
        }

        // Category-based defaults
        switch category {
        case "Fruits": return 50
        case "Vegetables": return 35
        case "Meat & Poultry", "Fish & Seafood", "Eggs": return 0
        case "Nuts & Seeds": return 20
        case "Legumes & Beans": return 32
        case "Dairy": return 35
        case "Grains & Cereals": return 60
        case "Snacks & Sweets": return 65
        case "Beverages": return 55
        default: return 50
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during food API searches
enum FoodAPIError: LocalizedError {
    case invalidURL
    case networkError
    case serverError(statusCode: Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build the search URL."
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        case .serverError(let code):
            return "Server returned an error (code \(code)). Please try again."
        case .noResults:
            return "No matching foods found online."
        }
    }
}
