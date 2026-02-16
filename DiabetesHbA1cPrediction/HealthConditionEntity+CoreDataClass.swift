//
//  HealthConditionEntity+CoreDataClass.swift
//  DiabetesHbA1cPrediction
//
//  NEW ENTITY — Extends the data model to capture the non-obligatory health
//  conditions the user specified: diabetes details, COPD, heart disease,
//  tobacco use, and alcohol consumption. Linked to UserDemographicsEntity
//  via a one-to-one relationship.
//

import Foundation
import CoreData

@objc(HealthConditionEntity)
public class HealthConditionEntity: NSManagedObject {
}
