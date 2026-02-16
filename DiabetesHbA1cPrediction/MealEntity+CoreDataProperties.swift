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

extension MealEntity : Identifiable {

}
