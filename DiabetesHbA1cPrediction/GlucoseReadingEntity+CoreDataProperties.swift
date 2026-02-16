//
//  GlucoseReadingEntity+CoreDataProperties.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData

extension GlucoseReadingEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GlucoseReadingEntity> {
        return NSFetchRequest<GlucoseReadingEntity>(entityName: "GlucoseReadingEntity")
    }

    @NSManaged nonisolated public var id: UUID?
    @NSManaged nonisolated public var timestamp: Date?
    @NSManaged nonisolated public var value: Double
    @NSManaged nonisolated public var unit: String?
    @NSManaged nonisolated public var trend: String?
    @NSManaged nonisolated public var source: String?

}

extension GlucoseReadingEntity: Identifiable {

}
