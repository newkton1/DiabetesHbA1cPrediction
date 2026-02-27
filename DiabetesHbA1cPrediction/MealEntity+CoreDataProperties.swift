//
//  MealEntity+CoreDataProperties.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData


extension MealEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealEntity> {
        return NSFetchRequest<MealEntity>(entityName: "MealEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var calories: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var unitString: String?
    @NSManaged public var macronutrients: NSSet?
    
    // New attributes for meal builder
    @NSManaged public var mealType: String?
    @NSManaged public var timeSinceLastMeal: Double
    @NSManaged public var plannedDateTime: Date?
    @NSManaged public var foodItems: NSSet?

}

// MARK: Generated accessors for macronutrients
extension MealEntity {

    @objc(addMacronutrientsObject:)
    @NSManaged public func addToMacronutrients(_ value: MacronutrientEntity)

    @objc(removeMacronutrientsObject:)
    @NSManaged public func removeFromMacronutrients(_ value: MacronutrientEntity)

    @objc(addMacronutrients:)
    @NSManaged public func addToMacronutrients(_ values: NSSet)

    @objc(removeMacronutrients:)
    @NSManaged public func removeFromMacronutrients(_ values: NSSet)

}

// MARK: Generated accessors for foodItems
extension MealEntity {

    @objc(addFoodItemsObject:)
    @NSManaged public func addToFoodItems(_ value: MealFoodItemEntity)

    @objc(removeFoodItemsObject:)
    @NSManaged public func removeFromFoodItems(_ value: MealFoodItemEntity)

    @objc(addFoodItems:)
    @NSManaged public func addToFoodItems(_ values: NSSet)

    @objc(removeFoodItems:)
    @NSManaged public func removeFromFoodItems(_ values: NSSet)

}

extension MealEntity : Identifiable {

}
