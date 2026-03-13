//
//  RecentMealsProvider.swift
//  DiabetesHbA1cPrediction
//
//  Queries Core Data for previously recorded meals, deduplicates by food composition,
//  and returns the most frequently eaten meals sorted by frequency.
//

import Foundation
import CoreData

/// Represents a distinct meal composition (unique combination of foods) with frequency count
struct RecentMeal: Identifiable {
    let id: String  // Signature string used for deduplication
    let foodNames: [String]  // Sorted food names for display
    let foods: [(name: String, category: String, quantity: Double, servingSize: Double,
                  servingUnit: String, calories: Double, carbs: Double, protein: Double,
                  fat: Double, fiber: Double, glycemicIndex: Int)]
    let frequency: Int  // How many times this exact combination has been logged
    let lastUsed: Date  // Most recent timestamp for this combination

    /// Summary line: total calories and carbs
    var totalCalories: Double {
        foods.reduce(0) { $0 + $1.calories * $1.quantity }
    }

    var totalCarbs: Double {
        foods.reduce(0) { $0 + $1.carbs * $1.quantity }
    }

    /// Display-friendly description of the meal contents
    var displayName: String {
        if foodNames.count <= 3 {
            return foodNames.joined(separator: ", ")
        } else {
            let first3 = foodNames.prefix(3).joined(separator: ", ")
            return "\(first3) +\(foodNames.count - 3) more"
        }
    }
}

/// Provides deduplicated, frequency-sorted recent meals from Core Data
class RecentMealsProvider {

    /// Fetch up to `limit` distinct meals sorted by frequency (most frequent first).
    /// Meals are deduplicated by their sorted food-name signature.
    static func fetchRecentMeals(context: NSManagedObjectContext, limit: Int = 30) -> [RecentMeal] {
        let request: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]
        // Only include meals that have food items (built with meal builder)
        request.predicate = NSPredicate(format: "foodItems.@count > 0")

        guard let meals = try? context.fetch(request) else { return [] }

        // Group meals by their food composition signature
        var signatureMap: [String: (meals: [MealEntity], foods: [(name: String, category: String,
            quantity: Double, servingSize: Double, servingUnit: String, calories: Double,
            carbs: Double, protein: Double, fat: Double, fiber: Double, glycemicIndex: Int)])] = [:]

        for meal in meals {
            guard let foodItemSet = meal.foodItems as? Set<MealFoodItemEntity>,
                  !foodItemSet.isEmpty else { continue }

            // Build signature from sorted food names + quantities
            let foodEntries = foodItemSet
                .compactMap { item -> (name: String, qty: Double)? in
                    guard let name = item.foodName else { return nil }
                    return (name: name, qty: item.quantity)
                }
                .sorted { $0.name < $1.name }

            let signature = foodEntries
                .map { "\($0.name):\($0.qty)" }
                .joined(separator: "|")

            if signatureMap[signature] == nil {
                // First time seeing this combination — capture the food details
                let foods = foodItemSet.compactMap { item -> (name: String, category: String,
                    quantity: Double, servingSize: Double, servingUnit: String, calories: Double,
                    carbs: Double, protein: Double, fat: Double, fiber: Double, glycemicIndex: Int)? in
                    guard let name = item.foodName else { return nil }
                    return (name: name, category: item.foodCategory ?? "",
                            quantity: item.quantity, servingSize: item.servingSize,
                            servingUnit: item.servingUnit ?? "serving",
                            calories: item.caloriesPerServing, carbs: item.carbsPerServing,
                            protein: item.proteinPerServing, fat: item.fatPerServing,
                            fiber: item.fiberPerServing, glycemicIndex: Int(item.glycemicIndex))
                }.sorted { $0.name < $1.name }

                signatureMap[signature] = (meals: [meal], foods: foods)
            } else {
                signatureMap[signature]?.meals.append(meal)
            }
        }

        // Convert to RecentMeal array sorted by frequency then recency
        var recentMeals: [RecentMeal] = signatureMap.compactMap { signature, data in
            let sortedNames = data.foods.map { $0.name }
            let latestDate = data.meals.compactMap { $0.timestamp }.max() ?? Date.distantPast

            return RecentMeal(
                id: signature,
                foodNames: sortedNames,
                foods: data.foods,
                frequency: data.meals.count,
                lastUsed: latestDate
            )
        }

        // Sort by frequency descending, then by most recent use
        recentMeals.sort { a, b in
            if a.frequency != b.frequency {
                return a.frequency > b.frequency
            }
            return a.lastUsed > b.lastUsed
        }

        return Array(recentMeals.prefix(limit))
    }
}
