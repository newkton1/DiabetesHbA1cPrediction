//
//  MacronutrientEntity+CoreDataProperties.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData


extension MacronutrientEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MacronutrientEntity> {
        return NSFetchRequest<MacronutrientEntity>(entityName: "MacronutrientEntity")
    }

    @NSManaged public var type: String?
    @NSManaged public var amount: Double
    @NSManaged public var unit: String?
    @NSManaged public var meal: MealEntity?

}

extension MacronutrientEntity : Identifiable {

}
