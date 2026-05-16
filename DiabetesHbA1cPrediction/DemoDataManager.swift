//
//  DemoDataManager.swift
//  DiabetesHbA1cPrediction
//
//  Manages loading and wiping of bundled demo data.
//  Demo data lets App Reviewers and new users explore the app
//  with realistic (anonymized) glucose, meal, and exercise data
//  before they start logging their own.
//

import Foundation
import CoreData

enum DemoDataManager {

    // MARK: - UserDefaults Keys

    private static let demoDataLoadedKey = "demoDataIsLoaded"

    /// Whether demo data is currently loaded in the app.
    static var isDemoDataLoaded: Bool {
        get { UserDefaults.standard.bool(forKey: demoDataLoadedKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoDataLoadedKey) }
    }

    // MARK: - Load Demo Data

    /// Loads the bundled demo JSON into Core Data using the existing
    /// DataImportEngine. Returns the import result summary.
    ///
    /// - Throws: If the bundled file is missing or import fails.
    static func loadDemoData(
        into context: NSManagedObjectContext
    ) throws -> DataImportResult {
        guard let url = Bundle.main.url(
            forResource: "DemoData",
            withExtension: "json"
        ) else {
            throw DemoDataError.bundleFileNotFound
        }

        let result = try DataImportEngine.importJSON(from: url, into: context)
        isDemoDataLoaded = true
        return result
    }

    // MARK: - Wipe All Data

    /// Deletes every record from all Core Data entity types.
    /// This is used to clear demo data before the user starts
    /// logging their own real data.
    ///
    /// - Returns: The total number of records deleted.
    @discardableResult
    static func wipeAllData(
        from context: NSManagedObjectContext
    ) throws -> Int {
        let entityNames = [
            "GlucoseReadingEntity",
            "MealEntity",
            "MealFoodItemEntity",
            "MacronutrientEntity",
            "ExerciseSessionEntity",
            "GmiEstimateEntity",
            "UserDemographicsEntity",
            "HealthConditionEntity"
        ]

        var totalDeleted = 0

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeCount

            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            let count = result?.result as? Int ?? 0
            totalDeleted += count
        }

        // Reset the context so in-memory objects reflect the deletions.
        context.reset()

        isDemoDataLoaded = false
        return totalDeleted
    }

    // MARK: - Check If Data Exists

    /// Returns true if there is any glucose, meal, or exercise data
    /// in Core Data (demo or real).
    static func hasAnyData(in context: NSManagedObjectContext) -> Bool {
        let checkEntities = [
            "GlucoseReadingEntity",
            "MealEntity",
            "ExerciseSessionEntity"
        ]

        for entityName in checkEntities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.fetchLimit = 1
            if let count = try? context.count(for: request), count > 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Errors

    enum DemoDataError: LocalizedError {
        case bundleFileNotFound

        var errorDescription: String? {
            switch self {
            case .bundleFileNotFound:
                return "Demo data file (DemoData.json) not found in app bundle."
            }
        }
    }
}
