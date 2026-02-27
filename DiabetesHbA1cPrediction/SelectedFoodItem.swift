//
//  SelectedFoodItem.swift
//  DiabetesHbA1cPrediction
//
//  Represents a food item selected for a meal with quantity
//

import Foundation

/// Represents a food item that has been selected for a meal with a specified quantity
struct SelectedFoodItem: Identifiable, Equatable {
    /// Unique identifier for this selection
    let id: UUID
    
    /// The underlying food item from the database
    let foodItem: FoodItem
    
    /// Number of servings (default 1.0)
    var quantity: Double
    
    init(foodItem: FoodItem, quantity: Double = 1.0) {
        self.id = UUID()
        self.foodItem = foodItem
        self.quantity = quantity
    }
    
    // MARK: - Computed Totals (quantity × per-serving values)
    
    var totalCarbs: Double {
        foodItem.carbohydrates * quantity
    }
    
    var totalCalories: Double {
        foodItem.calories * quantity
    }
    
    var totalProtein: Double {
        foodItem.protein * quantity
    }
    
    var totalFat: Double {
        foodItem.fat * quantity
    }
    
    var totalFiber: Double {
        foodItem.fiber * quantity
    }
    
    var totalNetCarbs: Double {
        foodItem.netCarbs * quantity
    }
    
    /// Glycemic load = (GI × net carbs) / 100
    var glycemicLoad: Double {
        (Double(foodItem.glycemicIndex) * totalNetCarbs) / 100.0
    }
    
    // MARK: - Equatable
    
    static func == (lhs: SelectedFoodItem, rhs: SelectedFoodItem) -> Bool {
        lhs.id == rhs.id
    }
}
