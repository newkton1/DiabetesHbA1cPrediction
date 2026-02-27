//
//  MealFoodItemEntity+CoreDataProperties.swift
//  DiabetesHbA1cPrediction
//
//

import Foundation
import CoreData


extension MealFoodItemEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealFoodItemEntity> {
        return NSFetchRequest<MealFoodItemEntity>(entityName: "MealFoodItemEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var foodName: String?
    @NSManaged public var foodCategory: String?
    @NSManaged public var quantity: Double
    @NSManaged public var servingSize: Double
    @NSManaged public var servingUnit: String?
    @NSManaged public var caloriesPerServing: Double
    @NSManaged public var carbsPerServing: Double
    @NSManaged public var proteinPerServing: Double
    @NSManaged public var fatPerServing: Double
    @NSManaged public var fiberPerServing: Double
    @NSManaged public var glycemicIndex: Int16
    @NSManaged public var meal: MealEntity?

}

extension MealFoodItemEntity : Identifiable {

}
