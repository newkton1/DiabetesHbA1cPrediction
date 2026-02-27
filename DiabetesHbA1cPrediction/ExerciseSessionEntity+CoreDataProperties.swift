//
//  ExerciseSessionEntity+CoreDataProperties.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData

extension ExerciseSessionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseSessionEntity> {
        return NSFetchRequest<ExerciseSessionEntity>(entityName: "ExerciseSessionEntity")
    }

    @NSManaged nonisolated public var id: UUID?
    @NSManaged nonisolated public var type: String?
    @NSManaged nonisolated public var startDate: Date?
    @NSManaged nonisolated public var endDate: Date?
    @NSManaged nonisolated public var distance: Double
    @NSManaged nonisolated public var duration: Double
    @NSManaged nonisolated public var intensity: Double
    @NSManaged nonisolated public var caloriesBurned: Double
    @NSManaged nonisolated public var notes: String?

}

extension ExerciseSessionEntity: Identifiable {

}
