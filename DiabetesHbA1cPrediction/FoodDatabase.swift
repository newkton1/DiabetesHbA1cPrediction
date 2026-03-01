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
struct FoodItem: Identifiable, Equatable {
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
    /// Lower GI foods have less impact on blood sugar spikes
    let glycemicIndex: Int

    /// Calculated net carbs (carbohydrates - fiber)
    /// This is important for diabetes management as fiber doesn't significantly impact blood glucose
    var netCarbs: Double {
        return max(0, carbohydrates - fiber)
    }
}

/// Singleton class that manages the comprehensive food database
/// Provides methods to search and filter foods by various criteria
class FoodDatabase {
    /// Shared singleton instance - provides global access to the food database
    static let shared = FoodDatabase()

    /// Array containing all 150 common foods with their nutritional data
    /// Data is based on USDA nutritional databases and common serving sizes
    private(set) var allFoods: [FoodItem] = []

    /// Private initializer ensures only one instance of FoodDatabase exists
    private init() {
        populateDatabase()
    }

    /// Populates the database with 150 common foods organized by category
    /// Each food entry contains realistic nutritional values per serving
    private func populateDatabase() {
        // MARK: - Grains & Cereals (15 items)

        allFoods.append(FoodItem(name: "White Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 206, carbohydrates: 45, protein: 4.3, fat: 0.4, fiber: 0.6, glycemicIndex: 73))
        allFoods.append(FoodItem(name: "Brown Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 215, carbohydrates: 45, protein: 5, fat: 1.8, fiber: 3.5, glycemicIndex: 68))
        allFoods.append(FoodItem(name: "Oatmeal", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 150, carbohydrates: 27, protein: 5, fat: 3, fiber: 4, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Quinoa", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 222, carbohydrates: 39, protein: 8, fat: 4, fiber: 5, glycemicIndex: 53))
        allFoods.append(FoodItem(name: "Corn", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup", calories: 132, carbohydrates: 29, protein: 4.7, fat: 1.7, fiber: 4.2, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Barley", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 193, carbohydrates: 44, protein: 7, fat: 1.5, fiber: 6, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Buckwheat", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 155, carbohydrates: 33, protein: 6, fat: 1, fiber: 4.5, glycemicIndex: 49))
        allFoods.append(FoodItem(name: "Couscous", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 176, carbohydrates: 36, protein: 6, fat: 0.3, fiber: 2.2, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "Millet", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 207, carbohydrates: 41, protein: 6, fat: 1.7, fiber: 2.3, glycemicIndex: 71))
        allFoods.append(FoodItem(name: "Wild Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 166, carbohydrates: 35, protein: 6.5, fat: 0.6, fiber: 2.7, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Rye", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 189, carbohydrates: 42, protein: 5.5, fat: 1.2, fiber: 3.5, glycemicIndex: 34))
        allFoods.append(FoodItem(name: "Jasmine Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 205, carbohydrates: 45, protein: 4, fat: 0.3, fiber: 0.5, glycemicIndex: 89))
        allFoods.append(FoodItem(name: "Basmati Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 191, carbohydrates: 43, protein: 4, fat: 0.4, fiber: 0.7, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Arborio Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 214, carbohydrates: 48, protein: 3.5, fat: 0.2, fiber: 0.4, glycemicIndex: 69))
        allFoods.append(FoodItem(name: "Genmai Rice", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 218, carbohydrates: 46, protein: 5, fat: 1.6, fiber: 3.5, glycemicIndex: 62))
        allFoods.append(FoodItem(name: "Bulgur", category: "Grains & Cereals", servingSize: 1, servingUnit: "cup cooked", calories: 151, carbohydrates: 34, protein: 5.6, fat: 0.4, fiber: 8.2, glycemicIndex: 48))
        allFoods.append(FoodItem(name: "Granola and Milk", category: "Grains & Cereals", servingSize: 1, servingUnit: "bowl", calories: 340, carbohydrates: 52, protein: 10, fat: 11, fiber: 4, glycemicIndex: 56))
        allFoods.append(FoodItem(name: "Porridge and Milk", category: "Grains & Cereals", servingSize: 1, servingUnit: "bowl", calories: 220, carbohydrates: 35, protein: 8, fat: 5, fiber: 4, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Cornflakes and Milk", category: "Grains & Cereals", servingSize: 1, servingUnit: "bowl", calories: 230, carbohydrates: 45, protein: 7, fat: 3, fiber: 1, glycemicIndex: 81))
        allFoods.append(FoodItem(name: "Weetabix", category: "Grains & Cereals", servingSize: 2, servingUnit: "biscuits", calories: 130, carbohydrates: 26, protein: 4, fat: 1, fiber: 4, glycemicIndex: 69))

        // MARK: - Fruits (20 items)

        allFoods.append(FoodItem(name: "Banana", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 105, carbohydrates: 27, protein: 1.3, fat: 0.4, fiber: 3.1, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Apple", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 95, carbohydrates: 25, protein: 0.5, fat: 0.3, fiber: 4.4, glycemicIndex: 39))
        allFoods.append(FoodItem(name: "Orange", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 62, carbohydrates: 15, protein: 1.2, fat: 0.3, fiber: 3.1, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Grapes", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 104, carbohydrates: 28, protein: 1.1, fat: 0.2, fiber: 1.5, glycemicIndex: 46))
        allFoods.append(FoodItem(name: "Strawberries", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 49, carbohydrates: 12, protein: 1, fat: 0.5, fiber: 3, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Blueberries", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 84, carbohydrates: 21, protein: 1.1, fat: 0.5, fiber: 3.6, glycemicIndex: 53))
        allFoods.append(FoodItem(name: "Watermelon", category: "Fruits", servingSize: 1, servingUnit: "cup diced", calories: 46, carbohydrates: 11, protein: 0.9, fat: 0.2, fiber: 0.6, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Mango", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 201, carbohydrates: 50, protein: 3, fat: 0.6, fiber: 5.4, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Pineapple", category: "Fruits", servingSize: 1, servingUnit: "cup chunks", calories: 82, carbohydrates: 22, protein: 0.9, fat: 0.2, fiber: 2.3, glycemicIndex: 66))
        allFoods.append(FoodItem(name: "Peach", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 59, carbohydrates: 14, protein: 1.4, fat: 0.4, fiber: 2.3, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Pear", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 101, carbohydrates: 27, protein: 0.6, fat: 0.2, fiber: 5.5, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Kiwi", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 42, carbohydrates: 10, protein: 0.8, fat: 0.4, fiber: 2.1, glycemicIndex: 53))
        allFoods.append(FoodItem(name: "Papaya", category: "Fruits", servingSize: 1, servingUnit: "cup cubed", calories: 55, carbohydrates: 14, protein: 0.9, fat: 0.2, fiber: 2.5, glycemicIndex: 59))
        allFoods.append(FoodItem(name: "Avocado", category: "Fruits", servingSize: 0.5, servingUnit: "fruit", calories: 120, carbohydrates: 6, protein: 1.5, fat: 11, fiber: 4.8, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Raspberries", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 64, carbohydrates: 15, protein: 1.2, fat: 0.8, fiber: 8, glycemicIndex: 32))
        allFoods.append(FoodItem(name: "Blackberries", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 62, carbohydrates: 14, protein: 2, fat: 0.6, fiber: 7.6, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Pomegranate", category: "Fruits", servingSize: 1, servingUnit: "cup arils", calories: 144, carbohydrates: 32, protein: 3, fat: 2, fiber: 7, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Grapefruit", category: "Fruits", servingSize: 0.5, servingUnit: "fruit", calories: 52, carbohydrates: 13, protein: 1, fat: 0.2, fiber: 2, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Cherries", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 87, carbohydrates: 22, protein: 1.5, fat: 0.3, fiber: 2.9, glycemicIndex: 63))
        allFoods.append(FoodItem(name: "Plum", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 30, carbohydrates: 7, protein: 0.5, fat: 0.2, fiber: 1.4, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Satsuma Orange", category: "Fruits", servingSize: 1, servingUnit: "medium", calories: 40, carbohydrates: 9, protein: 0.6, fat: 0.2, fiber: 1.4, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Canned Pears", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 140, carbohydrates: 36, protein: 0.5, fat: 0.1, fiber: 4, glycemicIndex: 44))
        allFoods.append(FoodItem(name: "Canned Fruit", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 150, carbohydrates: 39, protein: 1, fat: 0.2, fiber: 2.5, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Canned Pineapple", category: "Fruits", servingSize: 1, servingUnit: "cup", calories: 130, carbohydrates: 34, protein: 0.9, fat: 0.2, fiber: 2, glycemicIndex: 65))

        // MARK: - Vegetables (25 items)

        allFoods.append(FoodItem(name: "Broccoli", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 55, carbohydrates: 11, protein: 3.7, fat: 0.6, fiber: 2.4, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Carrots", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 52, carbohydrates: 12, protein: 1.2, fat: 0.2, fiber: 3.5, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Spinach", category: "Vegetables", servingSize: 1, servingUnit: "cup raw", calories: 7, carbohydrates: 1, protein: 1, fat: 0.1, fiber: 0.7, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cauliflower", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 29, carbohydrates: 5, protein: 2.3, fat: 0.6, fiber: 2.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Bell Pepper", category: "Vegetables", servingSize: 1, servingUnit: "cup chopped", calories: 30, carbohydrates: 7, protein: 1, fat: 0.3, fiber: 1.3, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Tomato", category: "Vegetables", servingSize: 1, servingUnit: "medium", calories: 22, carbohydrates: 5, protein: 1.1, fat: 0.2, fiber: 1.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Cucumber", category: "Vegetables", servingSize: 1, servingUnit: "cup sliced", calories: 16, carbohydrates: 4, protein: 0.8, fat: 0.2, fiber: 0.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Zucchini", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 21, carbohydrates: 4, protein: 1.5, fat: 0.4, fiber: 1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Green Beans", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 44, carbohydrates: 10, protein: 2.4, fat: 0.2, fiber: 2.7, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Lettuce", category: "Vegetables", servingSize: 1, servingUnit: "cup shredded", calories: 5, carbohydrates: 1, protein: 0.5, fat: 0.1, fiber: 0.6, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Pumpkin", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 49, carbohydrates: 12, protein: 1, fat: 0.1, fiber: 2.7, glycemicIndex: 75))
        allFoods.append(FoodItem(name: "Asparagus", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 40, carbohydrates: 7, protein: 4.3, fat: 0.2, fiber: 2.1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Corn (Sweet)", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 132, carbohydrates: 29, protein: 4.7, fat: 1.7, fiber: 4.2, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Peas", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 134, carbohydrates: 25, protein: 8.8, fat: 0.4, fiber: 8.8, glycemicIndex: 22))
        allFoods.append(FoodItem(name: "Celery", category: "Vegetables", servingSize: 1, servingUnit: "cup chopped", calories: 14, carbohydrates: 3, protein: 0.7, fat: 0.1, fiber: 0.6, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Beets", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 75, carbohydrates: 17, protein: 2.2, fat: 0.2, fiber: 2.7, glycemicIndex: 64))
        allFoods.append(FoodItem(name: "Brussels Sprouts", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 56, carbohydrates: 11, protein: 3.7, fat: 0.6, fiber: 2.4, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Kale", category: "Vegetables", servingSize: 1, servingUnit: "cup raw", calories: 33, carbohydrates: 7, protein: 2.2, fat: 0.6, fiber: 1.3, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Eggplant", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 35, carbohydrates: 8, protein: 0.8, fat: 0.2, fiber: 2.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Onion", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 92, carbohydrates: 21, protein: 1.4, fat: 0.2, fiber: 3, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Mushroom", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 44, carbohydrates: 7, protein: 3.5, fat: 0.4, fiber: 1.1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Cabbage", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 34, carbohydrates: 8, protein: 1.8, fat: 0.1, fiber: 2.2, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Leek", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 54, carbohydrates: 12, protein: 2, fat: 0.3, fiber: 1.8, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Radish", category: "Vegetables", servingSize: 1, servingUnit: "cup sliced", calories: 18, carbohydrates: 4, protein: 0.6, fat: 0.1, fiber: 0.8, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Turnip", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 36, carbohydrates: 8, protein: 1.2, fat: 0.1, fiber: 2.3, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Parsnips", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 111, carbohydrates: 27, protein: 2, fat: 0.5, fiber: 5.6, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Stuffed Paprika", category: "Vegetables", servingSize: 1, servingUnit: "pepper", calories: 185, carbohydrates: 18, protein: 10, fat: 8, fiber: 3, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "French Beans", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 44, carbohydrates: 10, protein: 2.4, fat: 0.4, fiber: 4, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Broad Beans", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 187, carbohydrates: 33, protein: 13, fat: 0.7, fiber: 9, glycemicIndex: 79))
        allFoods.append(FoodItem(name: "Aubergine", category: "Vegetables", servingSize: 1, servingUnit: "cup cooked", calories: 35, carbohydrates: 9, protein: 1, fat: 0.2, fiber: 2.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Peas (Boiled)", category: "Vegetables", servingSize: 1, servingUnit: "cup", calories: 134, carbohydrates: 25, protein: 9, fat: 0.4, fiber: 9, glycemicIndex: 48))
        allFoods.append(FoodItem(name: "Sauerkraut", category: "Vegetables", servingSize: 1, servingUnit: "cup", calories: 27, carbohydrates: 6, protein: 1.3, fat: 0.2, fiber: 4, glycemicIndex: 15))

        // MARK: - Dairy (15 items)

        allFoods.append(FoodItem(name: "Milk (Whole)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 149, carbohydrates: 12, protein: 8, fat: 8, fiber: 0, glycemicIndex: 27))
        allFoods.append(FoodItem(name: "Milk (Skim)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 83, carbohydrates: 12, protein: 8.3, fat: 0.2, fiber: 0, glycemicIndex: 27))
        allFoods.append(FoodItem(name: "Milk (2%)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 122, carbohydrates: 12, protein: 8.1, fat: 4.8, fiber: 0, glycemicIndex: 27))
        allFoods.append(FoodItem(name: "Yogurt (Plain)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 137, carbohydrates: 11, protein: 14, fat: 4, fiber: 0, glycemicIndex: 36))
        allFoods.append(FoodItem(name: "Yogurt (Greek)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 130, carbohydrates: 7, protein: 23, fat: 0.7, fiber: 0, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Cheese (Cheddar)", category: "Dairy", servingSize: 1, servingUnit: "oz", calories: 113, carbohydrates: 0.4, protein: 7, fat: 9.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cheese (Mozzarella)", category: "Dairy", servingSize: 1, servingUnit: "oz", calories: 86, carbohydrates: 1.1, protein: 6.3, fat: 6.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cheese (Feta)", category: "Dairy", servingSize: 1, servingUnit: "oz", calories: 100, carbohydrates: 1.2, protein: 5.2, fat: 8, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cottage Cheese", category: "Dairy", servingSize: 0.5, servingUnit: "cup", calories: 110, carbohydrates: 4, protein: 14, fat: 5, fiber: 0, glycemicIndex: 32))
        allFoods.append(FoodItem(name: "Butter", category: "Dairy", servingSize: 1, servingUnit: "tablespoon", calories: 102, carbohydrates: 0, protein: 0.1, fat: 11.5, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cream Cheese", category: "Dairy", servingSize: 2, servingUnit: "tablespoons", calories: 100, carbohydrates: 1, protein: 2, fat: 10, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Sour Cream", category: "Dairy", servingSize: 2, servingUnit: "tablespoons", calories: 62, carbohydrates: 1, protein: 1, fat: 6, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Milk (Almond)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 30, carbohydrates: 1, protein: 1, fat: 2.5, fiber: 0, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Milk (Oat)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 120, carbohydrates: 16, protein: 2, fat: 2.5, fiber: 2, glycemicIndex: 41))
        allFoods.append(FoodItem(name: "Milk (Soy)", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 80, carbohydrates: 1, protein: 7, fat: 4.5, fiber: 1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Egg (Boiled)", category: "Dairy", servingSize: 1, servingUnit: "large", calories: 78, carbohydrates: 0.6, protein: 6.3, fat: 5.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Egg (Fried)", category: "Dairy", servingSize: 1, servingUnit: "large", calories: 92, carbohydrates: 0.4, protein: 6.3, fat: 7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Plain Egg Omelet", category: "Dairy", servingSize: 1, servingUnit: "2-egg omelet", calories: 154, carbohydrates: 0.7, protein: 11, fat: 12, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cheese Omelet", category: "Dairy", servingSize: 1, servingUnit: "2-egg omelet", calories: 252, carbohydrates: 1.6, protein: 16, fat: 20, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Egg (Scrambled)", category: "Dairy", servingSize: 1, servingUnit: "large egg", calories: 91, carbohydrates: 1, protein: 6, fat: 7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Egg (Poached)", category: "Dairy", servingSize: 1, servingUnit: "large egg", calories: 72, carbohydrates: 0.4, protein: 6, fat: 5, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Camembert Cheese", category: "Dairy", servingSize: 1, servingUnit: "oz", calories: 85, carbohydrates: 0.1, protein: 6, fat: 7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Brie Cheese", category: "Dairy", servingSize: 1, servingUnit: "oz", calories: 95, carbohydrates: 0.1, protein: 6, fat: 8, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Stilton Cheese", category: "Dairy", servingSize: 1, servingUnit: "oz", calories: 110, carbohydrates: 0.5, protein: 6, fat: 9, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Margarine", category: "Dairy", servingSize: 1, servingUnit: "tbsp", calories: 100, carbohydrates: 0, protein: 0, fat: 11, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Strawberry Ice Cream", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 250, carbohydrates: 32, protein: 4, fat: 11, fiber: 0.5, glycemicIndex: 57))
        allFoods.append(FoodItem(name: "Chocolate Ice Cream", category: "Dairy", servingSize: 1, servingUnit: "cup", calories: 285, carbohydrates: 37, protein: 5, fat: 14, fiber: 2, glycemicIndex: 68))

        // MARK: - Meat & Poultry (20 items)

        allFoods.append(FoodItem(name: "Chicken Breast", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 165, carbohydrates: 0, protein: 31, fat: 3.6, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Chicken Thigh", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 209, carbohydrates: 0, protein: 26, fat: 11, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Turkey Breast", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 135, carbohydrates: 0, protein: 29, fat: 1.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Duck", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 337, carbohydrates: 0, protein: 19, fat: 28.6, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Beef (Lean)", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 180, carbohydrates: 0, protein: 27, fat: 8, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Beef (Ground)", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 215, carbohydrates: 0, protein: 22, fat: 13.5, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Beef (Rib Eye)", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 291, carbohydrates: 0, protein: 25, fat: 22, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Pork (Lean)", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 165, carbohydrates: 0, protein: 27, fat: 6.4, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Pork (Bacon)", category: "Meat & Poultry", servingSize: 2, servingUnit: "slices", calories: 90, carbohydrates: 0.3, protein: 6, fat: 7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Pork (Ham)", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 145, carbohydrates: 0.7, protein: 26, fat: 4, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Lamb", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 258, carbohydrates: 0, protein: 26, fat: 17, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Veal", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 172, carbohydrates: 0, protein: 29, fat: 6.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Sausage", category: "Meat & Poultry", servingSize: 1, servingUnit: "link", calories: 180, carbohydrates: 2, protein: 12, fat: 15, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Hot Dog", category: "Meat & Poultry", servingSize: 1, servingUnit: "frank", calories: 280, carbohydrates: 2, protein: 11, fat: 25, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Deli Turkey", category: "Meat & Poultry", servingSize: 2, servingUnit: "oz", calories: 60, carbohydrates: 1, protein: 12, fat: 1.5, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Deli Ham", category: "Meat & Poultry", servingSize: 2, servingUnit: "oz", calories: 100, carbohydrates: 0.5, protein: 14, fat: 5, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Ground Turkey", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 189, carbohydrates: 0, protein: 29, fat: 8, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Corned Beef", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 213, carbohydrates: 0.5, protein: 23, fat: 12, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Roast Beef", category: "Meat & Poultry", servingSize: 2, servingUnit: "oz", calories: 80, carbohydrates: 0, protein: 14, fat: 3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Venison", category: "Meat & Poultry", servingSize: 100, servingUnit: "g", calories: 158, carbohydrates: 0, protein: 30, fat: 3.5, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Roast Pork", category: "Meat & Poultry", servingSize: 3, servingUnit: "oz", calories: 180, carbohydrates: 0, protein: 23, fat: 9, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Roast Chicken", category: "Meat & Poultry", servingSize: 3, servingUnit: "oz", calories: 140, carbohydrates: 0, protein: 26, fat: 3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Roast Lamb", category: "Meat & Poultry", servingSize: 3, servingUnit: "oz", calories: 175, carbohydrates: 0, protein: 24, fat: 8, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Salami Sausage", category: "Meat & Poultry", servingSize: 1, servingUnit: "oz", calories: 110, carbohydrates: 0.5, protein: 6, fat: 10, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Crispy Bacon", category: "Meat & Poultry", servingSize: 2, servingUnit: "slices", calories: 90, carbohydrates: 0, protein: 6, fat: 7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Pork Sausages", category: "Meat & Poultry", servingSize: 2, servingUnit: "sausages", calories: 280, carbohydrates: 2, protein: 14, fat: 24, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Beef Sausages", category: "Meat & Poultry", servingSize: 2, servingUnit: "sausages", calories: 260, carbohydrates: 2, protein: 15, fat: 22, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Chorizo", category: "Meat & Poultry", servingSize: 1, servingUnit: "oz", calories: 130, carbohydrates: 1, protein: 7, fat: 11, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Grilled Steak", category: "Meat & Poultry", servingSize: 6, servingUnit: "oz", calories: 340, carbohydrates: 0, protein: 42, fat: 18, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "BBQ Steak", category: "Meat & Poultry", servingSize: 6, servingUnit: "oz", calories: 380, carbohydrates: 5, protein: 40, fat: 22, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Liver Pate", category: "Meat & Poultry", servingSize: 2, servingUnit: "tbsp", calories: 90, carbohydrates: 1, protein: 4, fat: 8, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Braised Liver", category: "Meat & Poultry", servingSize: 3, servingUnit: "oz", calories: 140, carbohydrates: 3, protein: 21, fat: 5, fiber: 0, glycemicIndex: 0))

        // MARK: - Fish & Seafood (15 items)

        allFoods.append(FoodItem(name: "Salmon", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 206, carbohydrates: 0, protein: 22, fat: 12.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Tuna", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 144, carbohydrates: 0, protein: 30, fat: 1.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Cod", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 82, carbohydrates: 0, protein: 18, fat: 0.7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Flounder", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 91, carbohydrates: 0, protein: 19, fat: 1.2, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Trout", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 148, carbohydrates: 0, protein: 20, fat: 7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Shrimp", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 99, carbohydrates: 0.2, protein: 24, fat: 0.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Crab", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 102, carbohydrates: 0, protein: 20, fat: 1.6, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Oysters", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 81, carbohydrates: 7, protein: 9, fat: 2.3, fiber: 0, glycemicIndex: 6))
        allFoods.append(FoodItem(name: "Mussels", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 86, carbohydrates: 3.7, protein: 12, fat: 2.2, fiber: 0, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Clams", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 86, carbohydrates: 3.1, protein: 15, fat: 1.5, fiber: 0, glycemicIndex: 6))
        allFoods.append(FoodItem(name: "Sardines", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 208, carbohydrates: 0, protein: 25, fat: 11, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Mackerel", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 305, carbohydrates: 0, protein: 21, fat: 25, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Halibut", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 111, carbohydrates: 0, protein: 21, fat: 2.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Tilapia", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 96, carbohydrates: 0, protein: 20, fat: 1.7, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Calamari", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 92, carbohydrates: 3.1, protein: 15.6, fat: 1.4, fiber: 0, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Prawns", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 99, carbohydrates: 0.2, protein: 24, fat: 0.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Lobster", category: "Fish & Seafood", servingSize: 100, servingUnit: "g", calories: 89, carbohydrates: 0.5, protein: 19, fat: 0.9, fiber: 0, glycemicIndex: 0))

        // MARK: - Legumes & Beans (10 items)

        allFoods.append(FoodItem(name: "Black Beans", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 227, carbohydrates: 41, protein: 15, fat: 0.9, fiber: 10, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Kidney Beans", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 225, carbohydrates: 40, protein: 15.3, fat: 0.8, fiber: 11.3, glycemicIndex: 24))
        allFoods.append(FoodItem(name: "Chickpeas", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 269, carbohydrates: 45, protein: 15, fat: 4.3, fiber: 12.5, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Lentils", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 230, carbohydrates: 40, protein: 18, fat: 0.8, fiber: 15.6, glycemicIndex: 32))
        allFoods.append(FoodItem(name: "Pinto Beans", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 245, carbohydrates: 44, protein: 15, fat: 1, fiber: 11.4, glycemicIndex: 39))
        allFoods.append(FoodItem(name: "Navy Beans", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 258, carbohydrates: 48, protein: 15.8, fat: 0.8, fiber: 10.5, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Split Peas", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 231, carbohydrates: 41, protein: 16.3, fat: 0.4, fiber: 16.3, glycemicIndex: 32))
        allFoods.append(FoodItem(name: "Edamame", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup", calories: 190, carbohydrates: 14, protein: 19, fat: 9, fiber: 8, glycemicIndex: 18))
        allFoods.append(FoodItem(name: "Peas (Dried)", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 251, carbohydrates: 45, protein: 16.4, fat: 0.4, fiber: 16.2, glycemicIndex: 22))
        allFoods.append(FoodItem(name: "Fava Beans", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 187, carbohydrates: 33, protein: 13, fat: 0.6, fiber: 8.9, glycemicIndex: 29))
        allFoods.append(FoodItem(name: "Adzuki Beans", category: "Legumes & Beans", servingSize: 1, servingUnit: "cup cooked", calories: 294, carbohydrates: 57, protein: 17, fat: 0.2, fiber: 17, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Bean Paste", category: "Legumes & Beans", servingSize: 2, servingUnit: "tbsp", calories: 80, carbohydrates: 17, protein: 2, fat: 0.1, fiber: 2, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Bean Curd", category: "Legumes & Beans", servingSize: 100, servingUnit: "g", calories: 76, carbohydrates: 1.9, protein: 8, fat: 4.8, fiber: 0.3, glycemicIndex: 15))

        // MARK: - Nuts & Seeds (15 items)

        allFoods.append(FoodItem(name: "Almonds", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz (23 nuts)", calories: 164, carbohydrates: 6, protein: 6, fat: 14, fiber: 3.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Peanuts", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 161, carbohydrates: 5.7, protein: 7.3, fat: 14, fiber: 2.5, glycemicIndex: 23))
        allFoods.append(FoodItem(name: "Walnuts", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz (14 halves)", calories: 185, carbohydrates: 4, protein: 4.3, fat: 18.5, fiber: 1.9, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Cashews", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 155, carbohydrates: 9, protein: 5, fat: 12, fiber: 0.9, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Macadamia Nuts", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 204, carbohydrates: 4, protein: 2.2, fat: 21.5, fiber: 2.4, glycemicIndex: 10))
        allFoods.append(FoodItem(name: "Pecans", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 196, carbohydrates: 4, protein: 2.6, fat: 20, fiber: 2.7, glycemicIndex: 10))
        allFoods.append(FoodItem(name: "Pistachios", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 160, carbohydrates: 8, protein: 6, fat: 13, fiber: 3, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Pumpkin Seeds", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 151, carbohydrates: 5, protein: 9, fat: 13, fiber: 1.1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Sunflower Seeds", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 165, carbohydrates: 6.5, protein: 5.5, fat: 14, fiber: 2.4, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Flax Seeds", category: "Nuts & Seeds", servingSize: 2, servingUnit: "tablespoons", calories: 150, carbohydrates: 8, protein: 5, fat: 12, fiber: 8, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Chia Seeds", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 138, carbohydrates: 12, protein: 4.7, fat: 8.7, fiber: 9.8, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Sesame Seeds", category: "Nuts & Seeds", servingSize: 1, servingUnit: "tablespoon", calories: 52, carbohydrates: 2.4, protein: 1.6, fat: 4.7, fiber: 1.1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Brazil Nuts", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 187, carbohydrates: 3, protein: 4, fat: 19, fiber: 2.1, glycemicIndex: 10))
        allFoods.append(FoodItem(name: "Pine Nuts", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 191, carbohydrates: 3.7, protein: 3.9, fat: 19, fiber: 1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Peanut Butter", category: "Nuts & Seeds", servingSize: 2, servingUnit: "tablespoons", calories: 188, carbohydrates: 7, protein: 8, fat: 16, fiber: 2.5, glycemicIndex: 23))
        allFoods.append(FoodItem(name: "Mixed Nuts", category: "Nuts & Seeds", servingSize: 1, servingUnit: "oz", calories: 172, carbohydrates: 6, protein: 5, fat: 15, fiber: 2, glycemicIndex: 20))

        // MARK: - Beverages (10 items)

        allFoods.append(FoodItem(name: "Orange Juice", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 112, carbohydrates: 26, protein: 2, fat: 0.5, fiber: 0.5, glycemicIndex: 66))
        allFoods.append(FoodItem(name: "Apple Juice", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 114, carbohydrates: 28, protein: 0.2, fat: 0.3, fiber: 0, glycemicIndex: 41))
        allFoods.append(FoodItem(name: "Cranberry Juice", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 137, carbohydrates: 34, protein: 0.3, fat: 0.2, fiber: 0.3, glycemicIndex: 68))
        allFoods.append(FoodItem(name: "Soda (Cola)", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 140, carbohydrates: 39, protein: 0, fat: 0, fiber: 0, glycemicIndex: 63))
        allFoods.append(FoodItem(name: "Coffee (Black)", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 2, carbohydrates: 0, protein: 0.3, fat: 0.1, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Milk Coffee", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 67, carbohydrates: 6, protein: 4, fat: 3.4, fiber: 0, glycemicIndex: 27))
        allFoods.append(FoodItem(name: "Tea (Black)", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 2, carbohydrates: 0.5, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Sports Drink", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 63, carbohydrates: 15, protein: 0, fat: 0, fiber: 0, glycemicIndex: 78))
        allFoods.append(FoodItem(name: "Water", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 0, carbohydrates: 0, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Beer (Light)", category: "Beverages", servingSize: 12, servingUnit: "fl oz", calories: 103, carbohydrates: 5.9, protein: 0.9, fat: 0, fiber: 0, glycemicIndex: 89))
        allFoods.append(FoodItem(name: "Wine (Red)", category: "Beverages", servingSize: 5, servingUnit: "fl oz", calories: 125, carbohydrates: 3.8, protein: 0.1, fat: 0, fiber: 0, glycemicIndex: 1))
        allFoods.append(FoodItem(name: "Bitter Beer", category: "Beverages", servingSize: 12, servingUnit: "fl oz", calories: 150, carbohydrates: 12, protein: 1.5, fat: 0, fiber: 0, glycemicIndex: 66))
        allFoods.append(FoodItem(name: "Brown Ale", category: "Beverages", servingSize: 12, servingUnit: "fl oz", calories: 160, carbohydrates: 14, protein: 1.5, fat: 0, fiber: 0, glycemicIndex: 66))
        allFoods.append(FoodItem(name: "Hot Chocolate", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 190, carbohydrates: 27, protein: 9, fat: 6, fiber: 2, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Milo Hot Chocolate", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 220, carbohydrates: 32, protein: 8, fat: 6, fiber: 1.5, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Cafe Latte", category: "Beverages", servingSize: 12, servingUnit: "fl oz", calories: 150, carbohydrates: 15, protein: 10, fat: 6, fiber: 0, glycemicIndex: 27))
        allFoods.append(FoodItem(name: "Espresso Coffee", category: "Beverages", servingSize: 1, servingUnit: "shot", calories: 3, carbohydrates: 0.5, protein: 0.1, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Milk Tea", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 60, carbohydrates: 8, protein: 2, fat: 2, fiber: 0, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Lemon Tea", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 25, carbohydrates: 6, protein: 0, fat: 0, fiber: 0, glycemicIndex: 20))
        allFoods.append(FoodItem(name: "Chai Tea", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 70, carbohydrates: 12, protein: 2, fat: 2, fiber: 0, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Herb Tea", category: "Beverages", servingSize: 1, servingUnit: "cup", calories: 2, carbohydrates: 0.5, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Whisky", category: "Beverages", servingSize: 1.5, servingUnit: "fl oz", calories: 97, carbohydrates: 0, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Gin", category: "Beverages", servingSize: 1.5, servingUnit: "fl oz", calories: 97, carbohydrates: 0, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Rum", category: "Beverages", servingSize: 1.5, servingUnit: "fl oz", calories: 97, carbohydrates: 0, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Sake Rice Wine", category: "Beverages", servingSize: 3, servingUnit: "fl oz", calories: 117, carbohydrates: 5, protein: 0.5, fat: 0, fiber: 0, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Sweet Wine", category: "Beverages", servingSize: 5, servingUnit: "fl oz", calories: 165, carbohydrates: 14, protein: 0.1, fat: 0, fiber: 0, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Port", category: "Beverages", servingSize: 3, servingUnit: "fl oz", calories: 140, carbohydrates: 12, protein: 0, fat: 0, fiber: 0, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Dry Wine", category: "Beverages", servingSize: 5, servingUnit: "fl oz", calories: 120, carbohydrates: 2, protein: 0.1, fat: 0, fiber: 0, glycemicIndex: 0))

        // MARK: - Snacks & Sweets (15 items)

        allFoods.append(FoodItem(name: "Chocolate Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "bar (43g)", calories: 235, carbohydrates: 26, protein: 4, fat: 13, fiber: 2, glycemicIndex: 70))
        allFoods.append(FoodItem(name: "Cookies", category: "Snacks & Sweets", servingSize: 3, servingUnit: "cookies", calories: 160, carbohydrates: 21, protein: 2, fat: 7, fiber: 0.5, glycemicIndex: 69))
        allFoods.append(FoodItem(name: "Donut", category: "Snacks & Sweets", servingSize: 1, servingUnit: "medium", calories: 269, carbohydrates: 30, protein: 3.7, fat: 15, fiber: 0.7, glycemicIndex: 76))
        allFoods.append(FoodItem(name: "Ice Cream", category: "Snacks & Sweets", servingSize: 0.5, servingUnit: "cup", calories: 137, carbohydrates: 16, protein: 2.3, fat: 7.3, fiber: 0, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Candy (Hard)", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 108, carbohydrates: 28, protein: 0, fat: 0, fiber: 0, glycemicIndex: 100))
        allFoods.append(FoodItem(name: "Chips", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 152, carbohydrates: 15, protein: 2, fat: 9, fiber: 1.4, glycemicIndex: 56))
        allFoods.append(FoodItem(name: "Popcorn", category: "Snacks & Sweets", servingSize: 3, servingUnit: "cups popped", calories: 93, carbohydrates: 11, protein: 3.5, fat: 4, fiber: 3.6, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Granola Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "bar", calories: 200, carbohydrates: 25, protein: 5, fat: 9, fiber: 3, glycemicIndex: 61))
        allFoods.append(FoodItem(name: "Pretzels", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 107, carbohydrates: 21, protein: 3, fat: 0.9, fiber: 0.9, glycemicIndex: 83))
        allFoods.append(FoodItem(name: "Crackers", category: "Snacks & Sweets", servingSize: 5, servingUnit: "crackers", calories: 70, carbohydrates: 10, protein: 1.5, fat: 3, fiber: 0.5, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "Cake", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 365, carbohydrates: 48, protein: 4, fat: 17, fiber: 0.3, glycemicIndex: 75))
        allFoods.append(FoodItem(name: "Pie", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 320, carbohydrates: 35, protein: 3, fat: 18, fiber: 0.8, glycemicIndex: 67))
        allFoods.append(FoodItem(name: "Honey", category: "Snacks & Sweets", servingSize: 1, servingUnit: "tablespoon", calories: 64, carbohydrates: 17, protein: 0.1, fat: 0, fiber: 0, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Jam", category: "Snacks & Sweets", servingSize: 1, servingUnit: "tablespoon", calories: 56, carbohydrates: 14, protein: 0.1, fat: 0.1, fiber: 0.3, glycemicIndex: 49))
        allFoods.append(FoodItem(name: "Marshmallows", category: "Snacks & Sweets", servingSize: 10, servingUnit: "pieces", calories: 32, carbohydrates: 8, protein: 0.5, fat: 0, fiber: 0, glycemicIndex: 74))
        allFoods.append(FoodItem(name: "Banana Split", category: "Snacks & Sweets", servingSize: 1, servingUnit: "serving", calories: 520, carbohydrates: 75, protein: 8, fat: 22, fiber: 3, glycemicIndex: 61))
        allFoods.append(FoodItem(name: "Chocolate Cake", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 350, carbohydrates: 50, protein: 4, fat: 15, fiber: 2, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Nutella", category: "Snacks & Sweets", servingSize: 2, servingUnit: "tbsp", calories: 200, carbohydrates: 22, protein: 2, fat: 12, fiber: 1, glycemicIndex: 33))
        allFoods.append(FoodItem(name: "Bitter Chocolate Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 170, carbohydrates: 13, protein: 2, fat: 12, fiber: 3, glycemicIndex: 23))
        allFoods.append(FoodItem(name: "Milk Chocolate Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 150, carbohydrates: 17, protein: 2, fat: 8, fiber: 1, glycemicIndex: 43))
        allFoods.append(FoodItem(name: "Diabetic Chocolate Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 140, carbohydrates: 15, protein: 2, fat: 9, fiber: 2, glycemicIndex: 20))
        allFoods.append(FoodItem(name: "Cherry Pie", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 325, carbohydrates: 50, protein: 3, fat: 14, fiber: 1, glycemicIndex: 63))
        allFoods.append(FoodItem(name: "Apple Pie", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 296, carbohydrates: 43, protein: 2, fat: 14, fiber: 2, glycemicIndex: 41))
        allFoods.append(FoodItem(name: "Sherry Trifle", category: "Snacks & Sweets", servingSize: 1, servingUnit: "serving", calories: 320, carbohydrates: 42, protein: 5, fat: 14, fiber: 1, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Eclair", category: "Snacks & Sweets", servingSize: 1, servingUnit: "piece", calories: 260, carbohydrates: 26, protein: 4, fat: 16, fiber: 0.5, glycemicIndex: 63))
        allFoods.append(FoodItem(name: "Sponge Cake", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 190, carbohydrates: 36, protein: 3, fat: 4, fiber: 0.3, glycemicIndex: 46))
        allFoods.append(FoodItem(name: "Fruit Cake", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 320, carbohydrates: 52, protein: 4, fat: 11, fiber: 2, glycemicIndex: 54))
        allFoods.append(FoodItem(name: "Victoria Sponge Cake", category: "Snacks & Sweets", servingSize: 1, servingUnit: "slice", calories: 290, carbohydrates: 38, protein: 4, fat: 14, fiber: 0.5, glycemicIndex: 46))
        allFoods.append(FoodItem(name: "Mince Pies", category: "Snacks & Sweets", servingSize: 1, servingUnit: "pie", calories: 230, carbohydrates: 35, protein: 2, fat: 9, fiber: 1.5, glycemicIndex: 56))
        allFoods.append(FoodItem(name: "Ice Cream Sundae", category: "Snacks & Sweets", servingSize: 1, servingUnit: "serving", calories: 450, carbohydrates: 58, protein: 7, fat: 21, fiber: 1, glycemicIndex: 61))
        allFoods.append(FoodItem(name: "Marron Glace", category: "Snacks & Sweets", servingSize: 3, servingUnit: "pieces", calories: 180, carbohydrates: 42, protein: 1, fat: 0.5, fiber: 2, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Trail Mix", category: "Snacks & Sweets", servingSize: 1, servingUnit: "oz", calories: 140, carbohydrates: 13, protein: 4, fat: 9, fiber: 2, glycemicIndex: 32))
        allFoods.append(FoodItem(name: "M&Ms", category: "Snacks & Sweets", servingSize: 1, servingUnit: "pack (45g)", calories: 220, carbohydrates: 31, protein: 2, fat: 10, fiber: 1, glycemicIndex: 47))
        allFoods.append(FoodItem(name: "Smarties", category: "Snacks & Sweets", servingSize: 1, servingUnit: "tube", calories: 170, carbohydrates: 28, protein: 2, fat: 6, fiber: 0.5, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Mars Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "bar", calories: 230, carbohydrates: 35, protein: 2, fat: 9, fiber: 0.5, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "Easter Chocolate Egg", category: "Snacks & Sweets", servingSize: 1, servingUnit: "small egg", calories: 180, carbohydrates: 20, protein: 2, fat: 10, fiber: 0.5, glycemicIndex: 49))
        allFoods.append(FoodItem(name: "Tiramisu", category: "Snacks & Sweets", servingSize: 1, servingUnit: "serving", calories: 350, carbohydrates: 32, protein: 6, fat: 22, fiber: 0.5, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Christmas Pudding", category: "Snacks & Sweets", servingSize: 1, servingUnit: "serving", calories: 330, carbohydrates: 56, protein: 4, fat: 10, fiber: 2, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Poutine", category: "Snacks & Sweets", servingSize: 1, servingUnit: "serving", calories: 740, carbohydrates: 62, protein: 24, fat: 42, fiber: 5, glycemicIndex: 70))
        allFoods.append(FoodItem(name: "Nanaimo Bar", category: "Snacks & Sweets", servingSize: 1, servingUnit: "bar", calories: 230, carbohydrates: 28, protein: 2, fat: 13, fiber: 1, glycemicIndex: 55))

        // MARK: - Condiments & Sauces (10 items)

        allFoods.append(FoodItem(name: "Ketchup", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 17, carbohydrates: 4, protein: 0.3, fat: 0.1, fiber: 0.1, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Mustard", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 4, carbohydrates: 0.4, protein: 0.3, fat: 0.3, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Mayonnaise", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 99, carbohydrates: 0, protein: 0, fat: 11, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Salad Dressing", category: "Condiments & Sauces", servingSize: 2, servingUnit: "tablespoons", calories: 145, carbohydrates: 2, protein: 0, fat: 15, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Soy Sauce", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 11, carbohydrates: 1, protein: 1.6, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Barbecue Sauce", category: "Condiments & Sauces", servingSize: 2, servingUnit: "tablespoons", calories: 70, carbohydrates: 16, protein: 0, fat: 0.5, fiber: 0, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Hot Sauce", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 3, carbohydrates: 0.7, protein: 0.1, fat: 0.1, fiber: 0.1, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Vinegar", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 3, carbohydrates: 0.1, protein: 0, fat: 0, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Olive Oil", category: "Condiments & Sauces", servingSize: 1, servingUnit: "tablespoon", calories: 120, carbohydrates: 0, protein: 0, fat: 13.5, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Tomato Sauce", category: "Condiments & Sauces", servingSize: 0.5, servingUnit: "cup", calories: 40, carbohydrates: 8, protein: 2, fat: 0.5, fiber: 2, glycemicIndex: 30))

        // MARK: - Fast Food (15 items)

        allFoods.append(FoodItem(name: "Hamburger", category: "Fast Food", servingSize: 1, servingUnit: "burger", calories: 350, carbohydrates: 30, protein: 15, fat: 17, fiber: 0.8, glycemicIndex: 66))
        allFoods.append(FoodItem(name: "Cheeseburger", category: "Fast Food", servingSize: 1, servingUnit: "burger", calories: 400, carbohydrates: 31, protein: 18, fat: 21, fiber: 0.8, glycemicIndex: 66))
        allFoods.append(FoodItem(name: "French Fries", category: "Fast Food", servingSize: 1, servingUnit: "medium order", calories: 320, carbohydrates: 41, protein: 3.4, fat: 17, fiber: 3.7, glycemicIndex: 75))
        allFoods.append(FoodItem(name: "Chicken Nuggets", category: "Fast Food", servingSize: 6, servingUnit: "pieces", calories: 280, carbohydrates: 18, protein: 16, fat: 15, fiber: 0, glycemicIndex: 46))
        allFoods.append(FoodItem(name: "Hot Dog (with bun)", category: "Fast Food", servingSize: 1, servingUnit: "hot dog", calories: 360, carbohydrates: 32, protein: 15, fat: 19, fiber: 1.5, glycemicIndex: 62))
        allFoods.append(FoodItem(name: "Pizza", category: "Fast Food", servingSize: 1, servingUnit: "slice", calories: 285, carbohydrates: 36, protein: 12, fat: 10, fiber: 2.5, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Taco", category: "Fast Food", servingSize: 1, servingUnit: "taco", calories: 170, carbohydrates: 15, protein: 8, fat: 8, fiber: 2, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Burrito", category: "Fast Food", servingSize: 1, servingUnit: "burrito", calories: 450, carbohydrates: 52, protein: 20, fat: 17, fiber: 6, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Sandwich (Deli)", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 400, carbohydrates: 42, protein: 20, fat: 15, fiber: 2, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Fried Chicken", category: "Fast Food", servingSize: 1, servingUnit: "piece", calories: 260, carbohydrates: 11, protein: 21, fat: 14, fiber: 0, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Nachos", category: "Fast Food", servingSize: 1.5, servingUnit: "cups", calories: 450, carbohydrates: 36, protein: 11, fat: 28, fiber: 4, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Quesadilla", category: "Fast Food", servingSize: 1, servingUnit: "quesadilla", calories: 370, carbohydrates: 30, protein: 14, fat: 21, fiber: 2.5, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Fish & Chips", category: "Fast Food", servingSize: 1, servingUnit: "serving", calories: 420, carbohydrates: 38, protein: 16, fat: 22, fiber: 1.5, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Milkshake", category: "Fast Food", servingSize: 1, servingUnit: "medium", calories: 420, carbohydrates: 63, protein: 11, fat: 14, fiber: 0, glycemicIndex: 63))
        allFoods.append(FoodItem(name: "Ham Sandwich", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 320, carbohydrates: 34, protein: 18, fat: 12, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Tuna Salad", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 290, carbohydrates: 10, protein: 22, fat: 19, fiber: 1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Tuna Sandwich", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 390, carbohydrates: 35, protein: 24, fat: 17, fiber: 2, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Turkey Sandwich", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 340, carbohydrates: 35, protein: 22, fat: 12, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Peanut Butter Sandwich", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 340, carbohydrates: 36, protein: 12, fat: 17, fiber: 4, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Peanut Butter and Jelly Sandwich", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 400, carbohydrates: 52, protein: 12, fat: 17, fiber: 4, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Caesar Salad", category: "Fast Food", servingSize: 1, servingUnit: "bowl", calories: 360, carbohydrates: 14, protein: 25, fat: 24, fiber: 3, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Beef Stew", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 220, carbohydrates: 15, protein: 18, fat: 10, fiber: 2, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Beef Curry", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 280, carbohydrates: 12, protein: 20, fat: 18, fiber: 2, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Lamb Curry", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 300, carbohydrates: 14, protein: 22, fat: 18, fiber: 2, glycemicIndex: 43))
        allFoods.append(FoodItem(name: "Shepherd's Pie", category: "Fast Food", servingSize: 1, servingUnit: "serving", calories: 350, carbohydrates: 28, protein: 20, fat: 18, fiber: 3, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Moussaka", category: "Fast Food", servingSize: 1, servingUnit: "serving", calories: 350, carbohydrates: 20, protein: 18, fat: 22, fiber: 4, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Soft Pretzel", category: "Fast Food", servingSize: 1, servingUnit: "pretzel", calories: 340, carbohydrates: 66, protein: 9, fat: 2, fiber: 2.5, glycemicIndex: 83))
        allFoods.append(FoodItem(name: "Chicken Broth", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 40, carbohydrates: 1, protein: 5, fat: 1.5, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Shepherds Pie", category: "Fast Food", servingSize: 1, servingUnit: "serving", calories: 380, carbohydrates: 32, protein: 20, fat: 18, fiber: 4, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Egg Mayonnaise Sandwich", category: "Fast Food", servingSize: 1, servingUnit: "sandwich", calories: 350, carbohydrates: 32, protein: 12, fat: 20, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Stuffed Tomatoes", category: "Fast Food", servingSize: 2, servingUnit: "tomatoes", calories: 180, carbohydrates: 18, protein: 8, fat: 9, fiber: 3, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Roast Potatoes", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 260, carbohydrates: 36, protein: 4, fat: 12, fiber: 3, glycemicIndex: 85))
        allFoods.append(FoodItem(name: "Salsa Sauce", category: "Fast Food", servingSize: 2, servingUnit: "tbsp", calories: 10, carbohydrates: 2, protein: 0.5, fat: 0, fiber: 0.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Tacos", category: "Fast Food", servingSize: 2, servingUnit: "tacos", calories: 340, carbohydrates: 30, protein: 16, fat: 16, fiber: 4, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Frijoles", category: "Fast Food", servingSize: 1, servingUnit: "cup", calories: 220, carbohydrates: 40, protein: 14, fat: 1, fiber: 15, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Taco Chips", category: "Fast Food", servingSize: 1, servingUnit: "oz", calories: 140, carbohydrates: 18, protein: 2, fat: 7, fiber: 1.5, glycemicIndex: 63))

        // MARK: - Breads & Bakery (15 items)

        allFoods.append(FoodItem(name: "White Bread", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 79, carbohydrates: 14, protein: 2.7, fat: 1, fiber: 0.6, glycemicIndex: 75))
        allFoods.append(FoodItem(name: "Whole Wheat Bread", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 100, carbohydrates: 19, protein: 4, fat: 1, fiber: 3, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Rye Bread", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 83, carbohydrates: 15, protein: 2.7, fat: 1.1, fiber: 1.9, glycemicIndex: 41))
        allFoods.append(FoodItem(name: "Sourdough Bread", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 80, carbohydrates: 15, protein: 2.8, fat: 0.9, fiber: 0.8, glycemicIndex: 54))
        allFoods.append(FoodItem(name: "Bagel", category: "Breads & Bakery", servingSize: 1, servingUnit: "bagel", calories: 245, carbohydrates: 48, protein: 9, fat: 1.4, fiber: 2.3, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Croissant", category: "Breads & Bakery", servingSize: 1, servingUnit: "medium", calories: 231, carbohydrates: 26, protein: 4.6, fat: 12, fiber: 1.5, glycemicIndex: 67))
        allFoods.append(FoodItem(name: "Muffin", category: "Breads & Bakery", servingSize: 1, servingUnit: "medium", calories: 367, carbohydrates: 41, protein: 5, fat: 17, fiber: 2.4, glycemicIndex: 67))
        allFoods.append(FoodItem(name: "Scone", category: "Breads & Bakery", servingSize: 1, servingUnit: "scone", calories: 180, carbohydrates: 22, protein: 3, fat: 9, fiber: 0.7, glycemicIndex: 69))
        allFoods.append(FoodItem(name: "Tortilla (Flour)", category: "Breads & Bakery", servingSize: 1, servingUnit: "tortilla", calories: 168, carbohydrates: 28, protein: 4.7, fat: 4.5, fiber: 1.6, glycemicIndex: 70))
        allFoods.append(FoodItem(name: "Tortilla (Corn)", category: "Breads & Bakery", servingSize: 1, servingUnit: "tortilla", calories: 53, carbohydrates: 11, protein: 1.4, fat: 0.8, fiber: 1.6, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Pita Bread", category: "Breads & Bakery", servingSize: 1, servingUnit: "pita", calories: 165, carbohydrates: 33, protein: 5.5, fat: 1.3, fiber: 1.3, glycemicIndex: 68))
        allFoods.append(FoodItem(name: "Naan Bread", category: "Breads & Bakery", servingSize: 1, servingUnit: "naan", calories: 261, carbohydrates: 45, protein: 8, fat: 5, fiber: 1.8, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Biscuit", category: "Breads & Bakery", servingSize: 1, servingUnit: "biscuit", calories: 180, carbohydrates: 21, protein: 4, fat: 8, fiber: 0.5, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Bread Roll", category: "Breads & Bakery", servingSize: 1, servingUnit: "roll", calories: 167, carbohydrates: 30, protein: 4.6, fat: 2.5, fiber: 1.5, glycemicIndex: 73))
        allFoods.append(FoodItem(name: "English Muffin", category: "Breads & Bakery", servingSize: 1, servingUnit: "muffin", calories: 134, carbohydrates: 26, protein: 4.4, fat: 1, fiber: 1.5, glycemicIndex: 77))
        allFoods.append(FoodItem(name: "French Baguette", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 90, carbohydrates: 18, protein: 3, fat: 0.5, fiber: 0.8, glycemicIndex: 95))
        allFoods.append(FoodItem(name: "Cheese Bagel", category: "Breads & Bakery", servingSize: 1, servingUnit: "bagel", calories: 340, carbohydrates: 52, protein: 14, fat: 8, fiber: 2, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Ham Bagel", category: "Breads & Bakery", servingSize: 1, servingUnit: "bagel", calories: 350, carbohydrates: 50, protein: 18, fat: 8, fiber: 2, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Yorkshire Pudding", category: "Breads & Bakery", servingSize: 1, servingUnit: "pudding", calories: 95, carbohydrates: 11, protein: 3, fat: 4, fiber: 0.5, glycemicIndex: 67))
        allFoods.append(FoodItem(name: "Avocado on Toast", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 280, carbohydrates: 28, protein: 7, fat: 16, fiber: 6, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Beans on Toast", category: "Breads & Bakery", servingSize: 1, servingUnit: "serving", calories: 310, carbohydrates: 52, protein: 13, fat: 4, fiber: 10, glycemicIndex: 49))
        allFoods.append(FoodItem(name: "Brioche", category: "Breads & Bakery", servingSize: 1, servingUnit: "roll", calories: 210, carbohydrates: 30, protein: 5, fat: 8, fiber: 1, glycemicIndex: 62))
        allFoods.append(FoodItem(name: "Marmite Toast", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 95, carbohydrates: 17, protein: 4, fat: 1, fiber: 1, glycemicIndex: 70))
        allFoods.append(FoodItem(name: "Jam Toast", category: "Breads & Bakery", servingSize: 1, servingUnit: "slice", calories: 150, carbohydrates: 30, protein: 3, fat: 1.5, fiber: 1, glycemicIndex: 65))

        // MARK: - Pasta & Noodles (10 items)

        allFoods.append(FoodItem(name: "Spaghetti", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 192, carbohydrates: 38, protein: 6.5, fat: 1.1, fiber: 2.2, glycemicIndex: 41))
        allFoods.append(FoodItem(name: "Penne", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 174, carbohydrates: 34, protein: 6, fat: 0.9, fiber: 1.8, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Fettuccine", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 220, carbohydrates: 43, protein: 8, fat: 1.3, fiber: 2.6, glycemicIndex: 46))
        allFoods.append(FoodItem(name: "Whole Wheat Pasta", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 174, carbohydrates: 37, protein: 7.4, fat: 0.8, fiber: 6, glycemicIndex: 37))
        allFoods.append(FoodItem(name: "Ramen Noodles", category: "Pasta & Noodles", servingSize: 1, servingUnit: "package cooked", calories: 356, carbohydrates: 52, protein: 11, fat: 14, fiber: 1.8, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Egg Noodles", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 221, carbohydrates: 40, protein: 7.3, fat: 2.4, fiber: 1.8, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Rice Noodles", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 190, carbohydrates: 44, protein: 1.8, fat: 0.3, fiber: 1.8, glycemicIndex: 54))
        allFoods.append(FoodItem(name: "Soba Noodles", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 113, carbohydrates: 24, protein: 5.8, fat: 0.4, fiber: 4, glycemicIndex: 46))
        allFoods.append(FoodItem(name: "Lasagna Noodles", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 221, carbohydrates: 42, protein: 8, fat: 1.2, fiber: 2.4, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Ravioli", category: "Pasta & Noodles", servingSize: 1, servingUnit: "cup cooked", calories: 330, carbohydrates: 48, protein: 15, fat: 8, fiber: 2, glycemicIndex: 39))
        allFoods.append(FoodItem(name: "Pot Noodles", category: "Pasta & Noodles", servingSize: 1, servingUnit: "pot", calories: 350, carbohydrates: 48, protein: 8, fat: 14, fiber: 2, glycemicIndex: 67))

        // MARK: - Soups (15 items)

        allFoods.append(FoodItem(name: "Chicken Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 86, carbohydrates: 9, protein: 8, fat: 2.6, fiber: 0.6, glycemicIndex: 22))
        allFoods.append(FoodItem(name: "Vegetable Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 74, carbohydrates: 14, protein: 3, fat: 0.8, fiber: 2.5, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Tomato Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 161, carbohydrates: 14, protein: 2, fat: 9, fiber: 1, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Beef Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 106, carbohydrates: 8, protein: 12, fat: 3, fiber: 1, glycemicIndex: 20))
        allFoods.append(FoodItem(name: "Lentil Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 130, carbohydrates: 21, protein: 9, fat: 1, fiber: 5, glycemicIndex: 21))
        allFoods.append(FoodItem(name: "Minestrone Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 83, carbohydrates: 14, protein: 5, fat: 1.5, fiber: 4, glycemicIndex: 18))
        allFoods.append(FoodItem(name: "Clam Chowder", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 193, carbohydrates: 18, protein: 9, fat: 9, fiber: 1.5, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Broccoli Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 95, carbohydrates: 10, protein: 4, fat: 4, fiber: 2, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Mushroom Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 79, carbohydrates: 8, protein: 3, fat: 3.5, fiber: 0.8, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Bean Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 142, carbohydrates: 22, protein: 8, fat: 2, fiber: 6, glycemicIndex: 26))
        allFoods.append(FoodItem(name: "Pea Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 165, carbohydrates: 28, protein: 9, fat: 2, fiber: 5, glycemicIndex: 22))
        allFoods.append(FoodItem(name: "Onion Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 87, carbohydrates: 10, protein: 4, fat: 4, fiber: 1.5, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Butternut Squash Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 110, carbohydrates: 22, protein: 2, fat: 2, fiber: 3.6, glycemicIndex: 51))
        allFoods.append(FoodItem(name: "Carrot Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 95, carbohydrates: 18, protein: 3, fat: 2, fiber: 3.5, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Miso Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 54, carbohydrates: 4, protein: 5.5, fat: 2.5, fiber: 1, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Leek Soup", category: "Soups", servingSize: 1, servingUnit: "cup", calories: 70, carbohydrates: 11, protein: 2, fat: 2, fiber: 1.5, glycemicIndex: 45))

        // MARK: - Asian & Japanese Foods (100 items)

        // Japanese Rice & Noodles
        allFoods.append(FoodItem(name: "Sushi Rice", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 298, carbohydrates: 64, protein: 5.4, fat: 0.5, fiber: 1.2, glycemicIndex: 85))
        allFoods.append(FoodItem(name: "Onigiri (Rice Ball)", category: "Asian & Japanese", servingSize: 1, servingUnit: "piece", calories: 180, carbohydrates: 39, protein: 4, fat: 0.5, fiber: 0.5, glycemicIndex: 80))
        allFoods.append(FoodItem(name: "Udon Noodles", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup cooked", calories: 228, carbohydrates: 48, protein: 7, fat: 0.6, fiber: 1.8, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Somen Noodles", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup cooked", calories: 203, carbohydrates: 42, protein: 6, fat: 0.3, fiber: 1.5, glycemicIndex: 68))
        allFoods.append(FoodItem(name: "Yakisoba Noodles", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 338, carbohydrates: 52, protein: 12, fat: 9, fiber: 2.5, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Shirataki Noodles", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 10, carbohydrates: 3, protein: 0, fat: 0, fiber: 3, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Glass Noodles (Cellophane)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup cooked", calories: 160, carbohydrates: 39, protein: 0.1, fat: 0, fiber: 0, glycemicIndex: 39))

        // Japanese Sushi & Sashimi
        allFoods.append(FoodItem(name: "Salmon Sashimi", category: "Asian & Japanese", servingSize: 3, servingUnit: "oz", calories: 177, carbohydrates: 0, protein: 17, fat: 11, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Tuna Sashimi", category: "Asian & Japanese", servingSize: 3, servingUnit: "oz", calories: 92, carbohydrates: 0, protein: 20, fat: 1, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Salmon Nigiri", category: "Asian & Japanese", servingSize: 2, servingUnit: "pieces", calories: 130, carbohydrates: 18, protein: 8, fat: 3.5, fiber: 0.3, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "Tuna Nigiri", category: "Asian & Japanese", servingSize: 2, servingUnit: "pieces", calories: 108, carbohydrates: 18, protein: 9, fat: 0.5, fiber: 0.3, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "California Roll", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 255, carbohydrates: 38, protein: 9, fat: 7, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Spicy Tuna Roll", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 290, carbohydrates: 26, protein: 11, fat: 11, fiber: 1, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Dragon Roll", category: "Asian & Japanese", servingSize: 8, servingUnit: "pieces", calories: 450, carbohydrates: 52, protein: 14, fat: 18, fiber: 3, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Tempura Roll", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 330, carbohydrates: 42, protein: 10, fat: 14, fiber: 2, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Inari Sushi", category: "Asian & Japanese", servingSize: 2, servingUnit: "pieces", calories: 140, carbohydrates: 24, protein: 5, fat: 3, fiber: 1, glycemicIndex: 70))
        allFoods.append(FoodItem(name: "Tamago (Egg Sushi)", category: "Asian & Japanese", servingSize: 2, servingUnit: "pieces", calories: 146, carbohydrates: 20, protein: 7, fat: 4, fiber: 0.3, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "California Roll Sushi", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 255, carbohydrates: 38, protein: 9, fat: 7, fiber: 2, glycemicIndex: 55))

        // Japanese Main Dishes
        allFoods.append(FoodItem(name: "Kinpira (Braised Burdock Root)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 120, carbohydrates: 22, protein: 3, fat: 3, fiber: 6, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Shrimp and Squid Fry (Kai Ebi Ika Age)", category: "Asian & Japanese", servingSize: 1, servingUnit: "serving", calories: 320, carbohydrates: 18, protein: 24, fat: 16, fiber: 0.5, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Teriyaki Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 320, carbohydrates: 16, protein: 36, fat: 12, fiber: 0.5, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Tonkatsu (Pork Cutlet)", category: "Asian & Japanese", servingSize: 1, servingUnit: "piece", calories: 450, carbohydrates: 22, protein: 32, fat: 26, fiber: 1.5, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Chicken Katsu", category: "Asian & Japanese", servingSize: 1, servingUnit: "piece", calories: 380, carbohydrates: 20, protein: 35, fat: 18, fiber: 1, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Gyudon (Beef Bowl)", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 650, carbohydrates: 85, protein: 28, fat: 20, fiber: 2, glycemicIndex: 72))
        allFoods.append(FoodItem(name: "Katsudon (Pork Cutlet Bowl)", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 750, carbohydrates: 88, protein: 38, fat: 26, fiber: 2, glycemicIndex: 70))
        allFoods.append(FoodItem(name: "Oyakodon (Chicken Egg Bowl)", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 520, carbohydrates: 72, protein: 28, fat: 12, fiber: 1.5, glycemicIndex: 68))
        allFoods.append(FoodItem(name: "Tempura Shrimp", category: "Asian & Japanese", servingSize: 4, servingUnit: "pieces", calories: 220, carbohydrates: 18, protein: 12, fat: 12, fiber: 0.5, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Vegetable Tempura", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 180, carbohydrates: 22, protein: 3, fat: 9, fiber: 2, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Kakiage", category: "Asian & Japanese", servingSize: 1, servingUnit: "piece", calories: 150, carbohydrates: 16, protein: 3, fat: 8, fiber: 1.5, glycemicIndex: 48))
        allFoods.append(FoodItem(name: "Yakitori (Chicken Skewer)", category: "Asian & Japanese", servingSize: 2, servingUnit: "skewers", calories: 180, carbohydrates: 6, protein: 22, fat: 8, fiber: 0, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Unagi (Grilled Eel)", category: "Asian & Japanese", servingSize: 3, servingUnit: "oz", calories: 236, carbohydrates: 0, protein: 24, fat: 15, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Sukiyaki", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 280, carbohydrates: 18, protein: 24, fat: 12, fiber: 2, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Shabu Shabu", category: "Asian & Japanese", servingSize: 1, servingUnit: "serving", calories: 350, carbohydrates: 12, protein: 35, fat: 18, fiber: 3, glycemicIndex: 35))

        // Japanese Ramen & Soups
        allFoods.append(FoodItem(name: "Tonkotsu Ramen", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 550, carbohydrates: 65, protein: 28, fat: 20, fiber: 3, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Shoyu Ramen", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 480, carbohydrates: 62, protein: 24, fat: 14, fiber: 2.5, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Miso Ramen", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 510, carbohydrates: 64, protein: 26, fat: 16, fiber: 3, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Shio Ramen", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 450, carbohydrates: 60, protein: 22, fat: 12, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Udon Soup", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 380, carbohydrates: 58, protein: 14, fat: 8, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Soba Soup", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 320, carbohydrates: 52, protein: 14, fat: 6, fiber: 3, glycemicIndex: 46))

        // Japanese Side Dishes
        allFoods.append(FoodItem(name: "Edamame", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup shelled", calories: 188, carbohydrates: 14, protein: 18, fat: 8, fiber: 8, glycemicIndex: 18))
        allFoods.append(FoodItem(name: "Gyoza (Pot Stickers)", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 280, carbohydrates: 30, protein: 12, fat: 12, fiber: 1.5, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Takoyaki (Octopus Balls)", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 300, carbohydrates: 36, protein: 12, fat: 12, fiber: 1, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Okonomiyaki", category: "Asian & Japanese", servingSize: 1, servingUnit: "piece", calories: 450, carbohydrates: 48, protein: 18, fat: 20, fiber: 3, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Tamagoyaki (Rolled Omelet)", category: "Asian & Japanese", servingSize: 1, servingUnit: "serving", calories: 145, carbohydrates: 3, protein: 10, fat: 10, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Chawanmushi (Egg Custard)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 85, carbohydrates: 4, protein: 8, fat: 4, fiber: 0.3, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Agedashi Tofu", category: "Asian & Japanese", servingSize: 1, servingUnit: "serving", calories: 180, carbohydrates: 12, protein: 10, fat: 10, fiber: 1, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Natto (Fermented Soybeans)", category: "Asian & Japanese", servingSize: 1, servingUnit: "pack (50g)", calories: 100, carbohydrates: 6, protein: 9, fat: 5, fiber: 3, glycemicIndex: 22))
        allFoods.append(FoodItem(name: "Pickled Ginger (Gari)", category: "Asian & Japanese", servingSize: 1, servingUnit: "oz", calories: 20, carbohydrates: 4, protein: 0.2, fat: 0, fiber: 0.2, glycemicIndex: 20))
        allFoods.append(FoodItem(name: "Tsukemono (Japanese Pickles)", category: "Asian & Japanese", servingSize: 0.25, servingUnit: "cup", calories: 15, carbohydrates: 3, protein: 0.5, fat: 0, fiber: 1, glycemicIndex: 15))

        // Chinese Dishes
        allFoods.append(FoodItem(name: "Fried Rice", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 340, carbohydrates: 52, protein: 10, fat: 10, fiber: 1.5, glycemicIndex: 68))
        allFoods.append(FoodItem(name: "Kung Pao Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 380, carbohydrates: 14, protein: 32, fat: 22, fiber: 2, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Sweet and Sour Pork", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 420, carbohydrates: 38, protein: 22, fat: 20, fiber: 1, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "General Tso's Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 490, carbohydrates: 32, protein: 28, fat: 28, fiber: 1, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Mapo Tofu", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 220, carbohydrates: 10, protein: 14, fat: 14, fiber: 2, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Chow Mein", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 290, carbohydrates: 38, protein: 12, fat: 10, fiber: 2, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Lo Mein", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 310, carbohydrates: 42, protein: 12, fat: 10, fiber: 2.5, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Beef and Broccoli", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 280, carbohydrates: 12, protein: 28, fat: 14, fiber: 2, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Mongolian Beef", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 350, carbohydrates: 18, protein: 26, fat: 20, fiber: 1, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Orange Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 460, carbohydrates: 42, protein: 26, fat: 20, fiber: 1, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Dim Sum (Har Gow)", category: "Asian & Japanese", servingSize: 4, servingUnit: "pieces", calories: 180, carbohydrates: 20, protein: 10, fat: 6, fiber: 1, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Dim Sum (Siu Mai)", category: "Asian & Japanese", servingSize: 4, servingUnit: "pieces", calories: 200, carbohydrates: 16, protein: 12, fat: 10, fiber: 0.5, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Char Siu (BBQ Pork)", category: "Asian & Japanese", servingSize: 3, servingUnit: "oz", calories: 220, carbohydrates: 12, protein: 22, fat: 10, fiber: 0, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Peking Duck", category: "Asian & Japanese", servingSize: 3, servingUnit: "oz", calories: 290, carbohydrates: 2, protein: 18, fat: 24, fiber: 0, glycemicIndex: 0))
        allFoods.append(FoodItem(name: "Hot and Sour Soup", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 95, carbohydrates: 10, protein: 6, fat: 4, fiber: 1, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Wonton Soup", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 180, carbohydrates: 20, protein: 10, fat: 6, fiber: 1, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Egg Drop Soup", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 65, carbohydrates: 4, protein: 5, fat: 3, fiber: 0.3, glycemicIndex: 20))
        allFoods.append(FoodItem(name: "Spring Roll (Fried)", category: "Asian & Japanese", servingSize: 2, servingUnit: "rolls", calories: 200, carbohydrates: 24, protein: 5, fat: 10, fiber: 1.5, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Egg Roll", category: "Asian & Japanese", servingSize: 1, servingUnit: "roll", calories: 180, carbohydrates: 20, protein: 6, fat: 8, fiber: 1, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Congee (Rice Porridge)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 120, carbohydrates: 26, protein: 3, fat: 0.5, fiber: 0.5, glycemicIndex: 78))

        // Thai Dishes
        allFoods.append(FoodItem(name: "Pad Thai", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 380, carbohydrates: 48, protein: 16, fat: 14, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Green Curry", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 320, carbohydrates: 12, protein: 22, fat: 22, fiber: 2, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Red Curry", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 310, carbohydrates: 14, protein: 20, fat: 20, fiber: 2, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Massaman Curry", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 380, carbohydrates: 22, protein: 24, fat: 22, fiber: 3, glycemicIndex: 42))
        allFoods.append(FoodItem(name: "Tom Yum Soup", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 90, carbohydrates: 6, protein: 10, fat: 3, fiber: 1, glycemicIndex: 20))
        allFoods.append(FoodItem(name: "Tom Kha Gai", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 180, carbohydrates: 8, protein: 14, fat: 12, fiber: 1, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Thai Basil Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 290, carbohydrates: 8, protein: 32, fat: 14, fiber: 1, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Papaya Salad (Som Tam)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 120, carbohydrates: 18, protein: 4, fat: 4, fiber: 3, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Thai Fried Rice", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 350, carbohydrates: 50, protein: 12, fat: 12, fiber: 2, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "Satay (Chicken Skewers)", category: "Asian & Japanese", servingSize: 3, servingUnit: "skewers", calories: 240, carbohydrates: 8, protein: 26, fat: 12, fiber: 0.5, glycemicIndex: 30))

        // Korean Dishes
        allFoods.append(FoodItem(name: "Bibimbap", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 580, carbohydrates: 78, protein: 28, fat: 16, fiber: 4, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Bulgogi (Korean BBQ Beef)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 290, carbohydrates: 12, protein: 28, fat: 14, fiber: 0.5, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Kimchi", category: "Asian & Japanese", servingSize: 0.5, servingUnit: "cup", calories: 23, carbohydrates: 4, protein: 1.5, fat: 0.5, fiber: 2, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Japchae (Glass Noodles)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 280, carbohydrates: 42, protein: 6, fat: 10, fiber: 2, glycemicIndex: 39))
        allFoods.append(FoodItem(name: "Kimchi Jjigae (Stew)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 180, carbohydrates: 12, protein: 14, fat: 10, fiber: 3, glycemicIndex: 30))
        allFoods.append(FoodItem(name: "Sundubu Jjigae (Soft Tofu Stew)", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 220, carbohydrates: 10, protein: 18, fat: 12, fiber: 2, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Korean Fried Chicken", category: "Asian & Japanese", servingSize: 4, servingUnit: "pieces", calories: 420, carbohydrates: 24, protein: 32, fat: 22, fiber: 1, glycemicIndex: 45))
        allFoods.append(FoodItem(name: "Tteokbokki (Rice Cakes)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 380, carbohydrates: 68, protein: 8, fat: 8, fiber: 2, glycemicIndex: 75))
        allFoods.append(FoodItem(name: "Kimbap", category: "Asian & Japanese", servingSize: 6, servingUnit: "pieces", calories: 280, carbohydrates: 42, protein: 10, fat: 8, fiber: 2, glycemicIndex: 55))

        // Vietnamese Dishes
        allFoods.append(FoodItem(name: "Pho (Beef Noodle Soup)", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 430, carbohydrates: 48, protein: 28, fat: 14, fiber: 2, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Banh Mi Sandwich", category: "Asian & Japanese", servingSize: 1, servingUnit: "sandwich", calories: 420, carbohydrates: 52, protein: 22, fat: 14, fiber: 3, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Fresh Spring Roll (Goi Cuon)", category: "Asian & Japanese", servingSize: 2, servingUnit: "rolls", calories: 140, carbohydrates: 22, protein: 8, fat: 2, fiber: 2, glycemicIndex: 40))
        allFoods.append(FoodItem(name: "Bun Bo Hue", category: "Asian & Japanese", servingSize: 1, servingUnit: "bowl", calories: 480, carbohydrates: 52, protein: 30, fat: 16, fiber: 2, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Com Tam (Broken Rice)", category: "Asian & Japanese", servingSize: 1, servingUnit: "plate", calories: 520, carbohydrates: 68, protein: 28, fat: 14, fiber: 2, glycemicIndex: 60))

        // Indian Dishes
        allFoods.append(FoodItem(name: "Chicken Tikka Masala", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 340, carbohydrates: 12, protein: 28, fat: 20, fiber: 2, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Butter Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 380, carbohydrates: 14, protein: 30, fat: 24, fiber: 2, glycemicIndex: 38))
        allFoods.append(FoodItem(name: "Palak Paneer", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 290, carbohydrates: 12, protein: 16, fat: 20, fiber: 4, glycemicIndex: 25))
        allFoods.append(FoodItem(name: "Dal (Lentil Curry)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 180, carbohydrates: 28, protein: 12, fat: 4, fiber: 8, glycemicIndex: 28))
        allFoods.append(FoodItem(name: "Biryani", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 380, carbohydrates: 48, protein: 18, fat: 14, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Samosa", category: "Asian & Japanese", servingSize: 2, servingUnit: "pieces", calories: 260, carbohydrates: 28, protein: 6, fat: 14, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Pakora", category: "Asian & Japanese", servingSize: 4, servingUnit: "pieces", calories: 180, carbohydrates: 18, protein: 4, fat: 10, fiber: 2, glycemicIndex: 50))
        allFoods.append(FoodItem(name: "Tandoori Chicken", category: "Asian & Japanese", servingSize: 1, servingUnit: "leg quarter", calories: 260, carbohydrates: 4, protein: 32, fat: 12, fiber: 0.5, glycemicIndex: 15))

        // Asian Tofu & Vegetables
        allFoods.append(FoodItem(name: "Tofu (Firm)", category: "Asian & Japanese", servingSize: 0.5, servingUnit: "cup", calories: 94, carbohydrates: 2, protein: 10, fat: 5, fiber: 0.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Silken Tofu", category: "Asian & Japanese", servingSize: 0.5, servingUnit: "cup", calories: 55, carbohydrates: 2, protein: 5, fat: 3, fiber: 0.2, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Bok Choy", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup cooked", calories: 20, carbohydrates: 3, protein: 2.5, fat: 0.3, fiber: 1.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Chinese Broccoli (Gai Lan)", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup cooked", calories: 25, carbohydrates: 4, protein: 2, fat: 0.4, fiber: 2.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Bean Sprouts", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 31, carbohydrates: 6, protein: 3, fat: 0.2, fiber: 2, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Water Chestnuts", category: "Asian & Japanese", servingSize: 0.5, servingUnit: "cup", calories: 60, carbohydrates: 15, protein: 1, fat: 0.1, fiber: 2, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Bamboo Shoots", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 40, carbohydrates: 8, protein: 4, fat: 0.5, fiber: 3, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Lotus Root", category: "Asian & Japanese", servingSize: 0.5, servingUnit: "cup", calories: 40, carbohydrates: 10, protein: 1, fat: 0, fiber: 2, glycemicIndex: 35))
        allFoods.append(FoodItem(name: "Daikon Radish", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 18, carbohydrates: 4, protein: 0.6, fat: 0.1, fiber: 1.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Seaweed (Nori)", category: "Asian & Japanese", servingSize: 5, servingUnit: "sheets", calories: 25, carbohydrates: 5, protein: 3, fat: 0.3, fiber: 3, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Wakame Seaweed", category: "Asian & Japanese", servingSize: 0.5, servingUnit: "cup", calories: 22, carbohydrates: 4, protein: 1.5, fat: 0.3, fiber: 2.5, glycemicIndex: 15))
        allFoods.append(FoodItem(name: "Fried Prawns in Hot Chili Sauce", category: "Asian & Japanese", servingSize: 1, servingUnit: "cup", calories: 340, carbohydrates: 18, protein: 24, fat: 18, fiber: 1.5, glycemicIndex: 45))

        // MARK: - Feast (Special Occasion Meals)

        // US Holidays
        allFoods.append(FoodItem(name: "US Thanksgiving Dinner", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1800, carbohydrates: 180, protein: 85, fat: 80, fiber: 12, glycemicIndex: 65))
        allFoods.append(FoodItem(name: "US Fourth of July BBQ", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1400, carbohydrates: 95, protein: 70, fat: 75, fiber: 6, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "US Super Bowl Party Spread", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1600, carbohydrates: 120, protein: 55, fat: 95, fiber: 5, glycemicIndex: 62))

        // UK Holidays
        allFoods.append(FoodItem(name: "UK Christmas Dinner", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1750, carbohydrates: 165, protein: 90, fat: 78, fiber: 14, glycemicIndex: 63))
        allFoods.append(FoodItem(name: "UK Sunday Roast", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1100, carbohydrates: 85, protein: 65, fat: 52, fiber: 8, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "UK Boxing Day Buffet", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1200, carbohydrates: 90, protein: 55, fat: 65, fiber: 6, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "UK Easter Lunch", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1300, carbohydrates: 110, protein: 70, fat: 60, fiber: 10, glycemicIndex: 60))

        // European Holidays
        allFoods.append(FoodItem(name: "German Christmas (Weihnachtsessen)", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1600, carbohydrates: 140, protein: 75, fat: 75, fiber: 10, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "French Christmas (Réveillon)", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1900, carbohydrates: 120, protein: 85, fat: 110, fiber: 8, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Italian Christmas Eve (La Vigilia)", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1500, carbohydrates: 145, protein: 80, fat: 60, fiber: 9, glycemicIndex: 52))
        allFoods.append(FoodItem(name: "Spanish Christmas (Nochebuena)", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1650, carbohydrates: 130, protein: 85, fat: 75, fiber: 8, glycemicIndex: 55))

        // Asian Celebrations
        allFoods.append(FoodItem(name: "Chinese New Year Feast", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1400, carbohydrates: 150, protein: 65, fat: 55, fiber: 7, glycemicIndex: 60))
        allFoods.append(FoodItem(name: "Japanese New Year (Osechi)", category: "Feast", servingSize: 1, servingUnit: "full serving", calories: 1100, carbohydrates: 130, protein: 55, fat: 40, fiber: 8, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Korean Chuseok Feast", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1300, carbohydrates: 160, protein: 50, fat: 45, fiber: 10, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Indian Diwali Feast", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1500, carbohydrates: 180, protein: 45, fat: 65, fiber: 12, glycemicIndex: 62))

        // Middle Eastern & Other
        allFoods.append(FoodItem(name: "Eid al-Fitr Feast", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1450, carbohydrates: 145, protein: 70, fat: 60, fiber: 9, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Jewish Passover Seder", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1200, carbohydrates: 120, protein: 60, fat: 50, fiber: 10, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Brazilian Christmas (Ceia de Natal)", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1550, carbohydrates: 135, protein: 80, fat: 70, fiber: 8, glycemicIndex: 58))
        allFoods.append(FoodItem(name: "Mexican Christmas (Nochebuena)", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1400, carbohydrates: 140, protein: 65, fat: 60, fiber: 12, glycemicIndex: 55))

        // Wedding & Special Events
        allFoods.append(FoodItem(name: "Wedding Reception Dinner", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1350, carbohydrates: 100, protein: 70, fat: 70, fiber: 6, glycemicIndex: 55))
        allFoods.append(FoodItem(name: "Birthday Celebration Meal", category: "Feast", servingSize: 1, servingUnit: "full plate", calories: 1250, carbohydrates: 130, protein: 50, fat: 55, fiber: 5, glycemicIndex: 60))
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
