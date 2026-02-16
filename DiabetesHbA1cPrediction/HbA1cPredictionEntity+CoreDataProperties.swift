//
//  HbA1cPredictionEntity+CoreDataProperties.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData


extension HbA1cPredictionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HbA1cPredictionEntity> {
        return NSFetchRequest<HbA1cPredictionEntity>(entityName: "HbA1cPredictionEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var predictedValue: Double
    @NSManaged public var confidenceLevel: Double
    @NSManaged public var predictionDate: Date?
    @NSManaged public var contributingFactorsJSON: Data?
    @NSManaged public var modelVersion: String?

}

extension HbA1cPredictionEntity : Identifiable {

}
