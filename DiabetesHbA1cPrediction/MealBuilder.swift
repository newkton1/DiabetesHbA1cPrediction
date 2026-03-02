//
//  MealBuilder.swift
//  DiabetesHbA1cPrediction
//
//  Observable model for building meals with multiple food items
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// Type of meal being built
enum MealType: String, CaseIterable {
    case lastMeal = "lastMeal"
    case plannedMeal = "plannedMeal"
    case feast = "feast"
    
    var displayName: String {
        switch self {
        case .lastMeal: return "Last Meal"
        case .plannedMeal: return "Planned Meal"
        case .feast: return "Feast"
        }
    }
}

/// Observable model for building a meal with multiple food items
class MealBuilder: ObservableObject {
    /// Name of the meal
    @Published var mealName: String = ""
    
    /// Selected food items with quantities
    @Published var selectedFoods: [SelectedFoodItem] = []
    
    /// Type of meal (last meal or planned meal)
    @Published var mealType: MealType = .lastMeal
    
    /// Hours since last meal (for lastMeal type)
    @Published var timeSinceLastMeal: Double = 0
    
    /// Planned date and time (for plannedMeal type)
    @Published var plannedDateTime: Date = Date().addingTimeInterval(3600) // 1 hour from now
    
    // MARK: - Computed Totals
    
    var totalCarbohydrates: Double {
        selectedFoods.reduce(0) { $0 + $1.totalCarbs }
    }
    
    var totalCalories: Double {
        selectedFoods.reduce(0) { $0 + $1.totalCalories }
    }
    
    var totalProtein: Double {
        selectedFoods.reduce(0) { $0 + $1.totalProtein }
    }
    
    var totalFat: Double {
        selectedFoods.reduce(0) { $0 + $1.totalFat }
    }
    
    var totalFiber: Double {
        selectedFoods.reduce(0) { $0 + $1.totalFiber }
    }
    
    var totalNetCarbs: Double {
        selectedFoods.reduce(0) { $0 + $1.totalNetCarbs }
    }
    
    var totalGlycemicLoad: Double {
        selectedFoods.reduce(0) { $0 + $1.glycemicLoad }
    }
    
    /// Weighted average glycemic index
    var averageGlycemicIndex: Double {
        guard totalCarbohydrates > 0 else { return 0 }
        let weightedSum = selectedFoods.reduce(0.0) { sum, item in
            sum + (Double(item.foodItem.glycemicIndex) * item.totalCarbs)
        }
        return weightedSum / totalCarbohydrates
    }
    
    var foodCount: Int {
        selectedFoods.count
    }
    
    var canSave: Bool {
        !selectedFoods.isEmpty
    }
    
    // MARK: - Actions
    
    /// Add a food item to the meal
    func addFood(_ food: FoodItem) {
        // Check if food already exists, if so increment quantity
        if let index = selectedFoods.firstIndex(where: { $0.foodItem.id == food.id }) {
            selectedFoods[index].quantity += 1
        } else {
            selectedFoods.append(SelectedFoodItem(foodItem: food))
        }
    }
    
    /// Remove a food item at the specified index
    func removeFood(at index: Int) {
        guard index >= 0 && index < selectedFoods.count else { return }
        selectedFoods.remove(at: index)
    }
    
    /// Remove a food item by ID
    func removeFood(id: UUID) {
        selectedFoods.removeAll { $0.id == id }
    }
    
    /// Update the quantity of a food item at the specified index
    func updateQuantity(at index: Int, quantity: Double) {
        guard index >= 0 && index < selectedFoods.count else { return }
        let newQuantity = max(1, quantity) // Minimum 1 serving
        selectedFoods[index].quantity = newQuantity
    }

    /// Increment quantity by 1
    func incrementQuantity(at index: Int) {
        guard index >= 0 && index < selectedFoods.count else { return }
        selectedFoods[index].quantity += 1
    }

    /// Decrement quantity by 1 (minimum 1)
    func decrementQuantity(at index: Int) {
        guard index >= 0 && index < selectedFoods.count else { return }
        let newQuantity = max(1, selectedFoods[index].quantity - 1)
        selectedFoods[index].quantity = newQuantity
    }
    
    /// Check if a food item is already selected
    func isSelected(_ food: FoodItem) -> Bool {
        selectedFoods.contains { $0.foodItem.id == food.id }
    }
    
    /// Clear all selected foods
    func clearAll() {
        selectedFoods.removeAll()
        mealName = ""
        timeSinceLastMeal = 0
        plannedDateTime = Date().addingTimeInterval(3600)
    }
    
    // MARK: - Core Data Persistence
    
    /// Save the meal to Core Data
    func save(to context: NSManagedObjectContext) throws {
        let mealEntity = MealEntity(context: context)
        mealEntity.id = UUID()
        mealEntity.name = mealName.isEmpty ? generateMealName() : mealName
        mealEntity.calories = totalCalories
        mealEntity.timestamp = Date()
        mealEntity.mealType = mealType.rawValue
        mealEntity.timeSinceLastMeal = timeSinceLastMeal
        mealEntity.plannedDateTime = mealType == .plannedMeal ? plannedDateTime : nil
        
        // Create food item entities
        for selectedFood in selectedFoods {
            let foodEntity = MealFoodItemEntity(context: context)
            foodEntity.id = UUID()
            foodEntity.foodName = selectedFood.foodItem.name
            foodEntity.foodCategory = selectedFood.foodItem.category
            foodEntity.quantity = selectedFood.quantity
            foodEntity.servingSize = selectedFood.foodItem.servingSize
            foodEntity.servingUnit = selectedFood.foodItem.servingUnit
            foodEntity.caloriesPerServing = selectedFood.foodItem.calories
            foodEntity.carbsPerServing = selectedFood.foodItem.carbohydrates
            foodEntity.proteinPerServing = selectedFood.foodItem.protein
            foodEntity.fatPerServing = selectedFood.foodItem.fat
            foodEntity.fiberPerServing = selectedFood.foodItem.fiber
            foodEntity.glycemicIndex = Int16(selectedFood.foodItem.glycemicIndex)
            foodEntity.meal = mealEntity
            
            mealEntity.addToFoodItems(foodEntity)
        }
        
        // Create macronutrient entities for backward compatibility
        let carbEntity = MacronutrientEntity(context: context)
        carbEntity.type = "carbohydrates"
        carbEntity.amount = totalCarbohydrates
        carbEntity.unit = "g"
        carbEntity.meal = mealEntity
        mealEntity.addToMacronutrients(carbEntity)
        
        let proteinEntity = MacronutrientEntity(context: context)
        proteinEntity.type = "protein"
        proteinEntity.amount = totalProtein
        proteinEntity.unit = "g"
        proteinEntity.meal = mealEntity
        mealEntity.addToMacronutrients(proteinEntity)
        
        let fatEntity = MacronutrientEntity(context: context)
        fatEntity.type = "fat"
        fatEntity.amount = totalFat
        fatEntity.unit = "g"
        fatEntity.meal = mealEntity
        mealEntity.addToMacronutrients(fatEntity)
        
        let fiberEntity = MacronutrientEntity(context: context)
        fiberEntity.type = "fiber"
        fiberEntity.amount = totalFiber
        fiberEntity.unit = "g"
        fiberEntity.meal = mealEntity
        mealEntity.addToMacronutrients(fiberEntity)
        
        try context.save()
    }
    
    /// Generate a default meal name based on time of day
    private func generateMealName() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Breakfast"
        case 11..<14: return "Lunch"
        case 14..<17: return "Snack"
        case 17..<21: return "Dinner"
        default: return "Late Night Snack"
        }
    }
}
