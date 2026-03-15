//
//  HealthConditionEntity+CoreDataProperties.swift
//  DiabetesHbA1cPrediction
//
//  Properties for health conditions that affect HbA1c prediction accuracy.
//  These are non-obligatory user inputs (the app works without them but
//  predictions improve when they are provided).
//

import Foundation
import CoreData

extension HealthConditionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HealthConditionEntity> {
        return NSFetchRequest<HealthConditionEntity>(entityName: "HealthConditionEntity")
    }

    // --- Primary key ---
    @NSManaged public var id: UUID?

    // --- Known health problems ---
    @NSManaged public var hasDiabetes: Bool
    @NSManaged public var diabetesType: String?      // "Type 1", "Type 2", "Gestational", "Pre-diabetes"
    @NSManaged public var hasDawnEffect: Bool         // Dawn effect — elevated fasting glucose 4-8am
    @NSManaged public var hasCOPD: Bool
    @NSManaged public var hasHeartDisease: Bool
    @NSManaged public var otherConditions: String?    // Free-text for any additional conditions

    // --- Lifestyle factors ---
    @NSManaged public var tobaccoUse: String?         // "Never", "Former", "Current"
    @NSManaged public var alcoholUnitsPerWeek: Double  // Standard drinks per week

    // --- Metadata ---
    @NSManaged public var lastUpdated: Date?

    // --- Relationship back to the user profile ---
    @NSManaged public var user: UserDemographicsEntity?
}

extension HealthConditionEntity: Identifiable {
}
