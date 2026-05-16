//
//  GmiEstimateEntity+CoreDataProperties.swift
//  DiabetesHbA1cPrediction
//
//  Renamed from HbA1cPredictionEntity to remove "prediction" from
//  the compiled binary (Apple Guideline 1.4.1 terminology cleanup).
//

import Foundation
import CoreData


extension GmiEstimateEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GmiEstimateEntity> {
        return NSFetchRequest<GmiEstimateEntity>(entityName: "GmiEstimateEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var predictedValue: Double
    @NSManaged public var confidenceLevel: Double
    @NSManaged public var predictionDate: Date?
    @NSManaged public var contributingFactorsJSON: Data?
    @NSManaged public var modelVersion: String?

}

extension GmiEstimateEntity : Identifiable {

}
