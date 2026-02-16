//
//  UserDemographicsEntity+CoreDataProperties.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData


extension UserDemographicsEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserDemographicsEntity> {
        return NSFetchRequest<UserDemographicsEntity>(entityName: "UserDemographicsEntity")
    }

    @NSManaged public var age: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var sex: String?
    @NSManaged public var dateOfBirth: Date?
    @NSManaged public var height: Double
    @NSManaged public var weight: Double
    @NSManaged public var diabetesType: String?
    @NSManaged public var menopausalStatus: String?
    @NSManaged public var lastUpdated: Date?

}

extension UserDemographicsEntity : Identifiable {

}
