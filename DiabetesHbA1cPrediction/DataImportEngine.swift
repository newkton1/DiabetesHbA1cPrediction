//
//  DataImportEngine.swift
//  DiabetesHbA1cPrediction
//
//  Imports a JSON file (produced by DataExportView) into Core Data.
//  Handles all 6 entity types, skips duplicates by UUID, and reports
//  per-entity counts so the UI can show a summary.
//
//  Phase J.1 of the data-import feature.
//

import Foundation
import CoreData

// MARK: - Import Result

/// Summary returned after an import completes.
struct DataImportResult {
    var glucoseReadings: ImportCount = .zero
    var meals: ImportCount = .zero
    var exerciseSessions: ImportCount = .zero
    var hba1cPredictions: ImportCount = .zero
    var userProfiles: ImportCount = .zero
    var healthConditions: ImportCount = .zero
    var warnings: [String] = []

    struct ImportCount: Equatable {
        var found: Int = 0
        var imported: Int = 0
        var skipped: Int = 0   // duplicate UUID

        static let zero = ImportCount()
    }

    /// Total records successfully imported across all entity types.
    var totalImported: Int {
        glucoseReadings.imported + meals.imported +
        exerciseSessions.imported + hba1cPredictions.imported +
        userProfiles.imported + healthConditions.imported
    }

    /// Total records skipped (already present) across all entity types.
    var totalSkipped: Int {
        glucoseReadings.skipped + meals.skipped +
        exerciseSessions.skipped + hba1cPredictions.skipped +
        userProfiles.skipped + healthConditions.skipped
    }
}

// MARK: - Import Engine

/// Stateless engine that parses an exported JSON file and writes its
/// contents into the given Core Data context.
///
/// Usage:
/// ```
/// let result = try DataImportEngine.importJSON(from: url, into: context)
/// ```
enum DataImportEngine {

    // MARK: - Public Entry Point

    /// Parse the JSON file at `url` and import every record into `context`.
    /// The context is saved once at the end if any records were imported.
    ///
    /// - Throws: If the file cannot be read or the top-level JSON is invalid.
    /// - Returns: A summary of what was imported / skipped.
    static func importJSON(
        from url: URL,
        into context: NSManagedObjectContext
    ) throws -> DataImportResult {
        // 1. Read & parse top-level JSON.
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat("Top-level JSON is not a dictionary.")
        }

        var result = DataImportResult()

        // 2. Import each entity type. Order matters slightly because
        //    UserDemographics ↔ HealthCondition have a 1:1 relationship,
        //    but since the export doesn't nest them, we import independently
        //    and skip relationship wiring (it's profile-level data that the
        //    user will re-enter or that already exists).

        if let profiles = root["userProfile"] as? [[String: Any]] {
            result.userProfiles = importUserProfiles(profiles, into: context)
        }

        if let conditions = root["healthConditions"] as? [[String: Any]] {
            result.healthConditions = importHealthConditions(conditions, into: context)
        }

        if let readings = root["glucoseReadings"] as? [[String: Any]] {
            result.glucoseReadings = importGlucoseReadings(readings, into: context)
        }

        if let mealArray = root["meals"] as? [[String: Any]] {
            result.meals = importMeals(mealArray, into: context)
        }

        if let exercises = root["exerciseSessions"] as? [[String: Any]] {
            result.exerciseSessions = importExercises(exercises, into: context)
        }

        if let predictions = root["hba1cPredictions"] as? [[String: Any]] {
            result.hba1cPredictions = importPredictions(predictions, into: context)
        }

        // 3. Save if anything was imported.
        if result.totalImported > 0 {
            try context.save()
        }

        return result
    }

    // MARK: - Error Type

    enum ImportError: LocalizedError {
        case invalidFormat(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat(let msg): return "Import error: \(msg)"
            }
        }
    }

    // MARK: - Date Parsing

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Fallback formatter without fractional seconds (for hand-edited files).
    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }
        return iso8601.date(from: str) ?? iso8601NoFrac.date(from: str)
    }

    // MARK: - Duplicate Check

    /// Returns true if an entity with the given UUID already exists.
    private static func exists(
        entity: String,
        uuid: UUID,
        in context: NSManagedObjectContext
    ) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return (try? context.count(for: request)) ?? 0 > 0
    }

    // MARK: - User Profiles

    private static func importUserProfiles(
        _ items: [[String: Any]],
        into context: NSManagedObjectContext
    ) -> DataImportResult.ImportCount {
        var count = DataImportResult.ImportCount(found: items.count)

        for dict in items {
            let uuid: UUID
            if let idStr = dict["id"] as? String, let parsed = UUID(uuidString: idStr) {
                uuid = parsed
            } else {
                uuid = UUID()
            }

            if exists(entity: "UserDemographicsEntity", uuid: uuid, in: context) {
                count.skipped += 1
                continue
            }

            let entity = UserDemographicsEntity(context: context)
            entity.id = uuid
            entity.age = Int16(dict["age"] as? Int ?? 0)
            entity.sex = dict["sex"] as? String
            entity.dateOfBirth = parseDate(dict["dateOfBirth"])
            entity.height = dict["height"] as? Double ?? 0
            entity.weight = dict["weight"] as? Double ?? 0
            entity.diabetesType = dict["diabetesType"] as? String
            entity.menopausalStatus = dict["menopausalStatus"] as? String
            entity.lastUpdated = parseDate(dict["lastUpdated"]) ?? Date()

            count.imported += 1
        }

        return count
    }

    // MARK: - Health Conditions

    private static func importHealthConditions(
        _ items: [[String: Any]],
        into context: NSManagedObjectContext
    ) -> DataImportResult.ImportCount {
        var count = DataImportResult.ImportCount(found: items.count)

        for dict in items {
            let uuid: UUID
            if let idStr = dict["id"] as? String, let parsed = UUID(uuidString: idStr) {
                uuid = parsed
            } else {
                uuid = UUID()
            }

            if exists(entity: "HealthConditionEntity", uuid: uuid, in: context) {
                count.skipped += 1
                continue
            }

            let entity = HealthConditionEntity(context: context)
            entity.id = uuid
            entity.hasDiabetes = dict["hasDiabetes"] as? Bool ?? false
            entity.diabetesType = dict["diabetesType"] as? String
            entity.hasDawnEffect = dict["hasDawnEffect"] as? Bool ?? false
            entity.hasCOPD = dict["hasCOPD"] as? Bool ?? false
            entity.hasHeartDisease = dict["hasHeartDisease"] as? Bool ?? false
            entity.tobaccoUse = dict["tobaccoUse"] as? String
            entity.alcoholUnitsPerWeek = dict["alcoholUnitsPerWeek"] as? Double ?? 0
            entity.otherConditions = dict["otherConditions"] as? String
            entity.lastUpdated = parseDate(dict["lastUpdated"]) ?? Date()

            count.imported += 1
        }

        return count
    }

    // MARK: - Glucose Readings

    private static func importGlucoseReadings(
        _ items: [[String: Any]],
        into context: NSManagedObjectContext
    ) -> DataImportResult.ImportCount {
        var count = DataImportResult.ImportCount(found: items.count)

        for dict in items {
            let uuid: UUID
            if let idStr = dict["id"] as? String, let parsed = UUID(uuidString: idStr) {
                uuid = parsed
            } else {
                uuid = UUID()
            }

            if exists(entity: "GlucoseReadingEntity", uuid: uuid, in: context) {
                count.skipped += 1
                continue
            }

            let entity = GlucoseReadingEntity(context: context)
            entity.id = uuid
            entity.timestamp = parseDate(dict["timestamp"])
            entity.value = dict["value"] as? Double ?? 0
            entity.unit = dict["unit"] as? String
            entity.trend = dict["trend"] as? String
            entity.source = dict["source"] as? String

            count.imported += 1
        }

        return count
    }

    // MARK: - Meals (with nested food items + macronutrients)

    private static func importMeals(
        _ items: [[String: Any]],
        into context: NSManagedObjectContext
    ) -> DataImportResult.ImportCount {
        var count = DataImportResult.ImportCount(found: items.count)

        for dict in items {
            let uuid: UUID
            if let idStr = dict["id"] as? String, let parsed = UUID(uuidString: idStr) {
                uuid = parsed
            } else {
                uuid = UUID()
            }

            if exists(entity: "MealEntity", uuid: uuid, in: context) {
                count.skipped += 1
                continue
            }

            let meal = MealEntity(context: context)
            meal.id = uuid
            meal.name = dict["name"] as? String
            meal.calories = dict["calories"] as? Double ?? 0
            meal.timestamp = parseDate(dict["timestamp"])
            meal.mealType = dict["mealType"] as? String
            meal.timeSinceLastMeal = dict["timeSinceLastMeal"] as? Double ?? 0
            meal.plannedDateTime = parseDate(dict["plannedDateTime"])
            meal.unitString = dict["unitString"] as? String

            // Nested food items
            if let foodItems = dict["foodItems"] as? [[String: Any]] {
                for fDict in foodItems {
                    let item = MealFoodItemEntity(context: context)
                    item.id = UUID() // food items don't have stable IDs in export
                    item.foodName = fDict["foodName"] as? String
                    item.foodCategory = fDict["foodCategory"] as? String
                    item.quantity = fDict["quantity"] as? Double ?? 1
                    item.servingSize = fDict["servingSize"] as? Double ?? 0
                    item.servingUnit = fDict["servingUnit"] as? String
                    item.caloriesPerServing = fDict["caloriesPerServing"] as? Double ?? 0
                    item.carbsPerServing = fDict["carbsPerServing"] as? Double ?? 0
                    item.proteinPerServing = fDict["proteinPerServing"] as? Double ?? 0
                    item.fatPerServing = fDict["fatPerServing"] as? Double ?? 0
                    item.fiberPerServing = fDict["fiberPerServing"] as? Double ?? 0
                    item.glycemicIndex = Int16(fDict["glycemicIndex"] as? Int ?? 0)
                    item.meal = meal
                }
            }

            // Nested macronutrients
            if let macros = dict["macronutrients"] as? [[String: Any]] {
                for mDict in macros {
                    let macro = MacronutrientEntity(context: context)
                    macro.type = mDict["type"] as? String
                    macro.amount = mDict["amount"] as? Double ?? 0
                    macro.unit = mDict["unit"] as? String ?? "g"
                    macro.meal = meal
                }
            }

            count.imported += 1
        }

        return count
    }

    // MARK: - Exercise Sessions

    private static func importExercises(
        _ items: [[String: Any]],
        into context: NSManagedObjectContext
    ) -> DataImportResult.ImportCount {
        var count = DataImportResult.ImportCount(found: items.count)

        for dict in items {
            let uuid: UUID
            if let idStr = dict["id"] as? String, let parsed = UUID(uuidString: idStr) {
                uuid = parsed
            } else {
                uuid = UUID()
            }

            if exists(entity: "ExerciseSessionEntity", uuid: uuid, in: context) {
                count.skipped += 1
                continue
            }

            let entity = ExerciseSessionEntity(context: context)
            entity.id = uuid
            entity.type = dict["type"] as? String
            entity.startDate = parseDate(dict["startDate"])
            entity.endDate = parseDate(dict["endDate"])
            entity.duration = dict["duration"] as? Double ?? 0
            entity.distance = dict["distance"] as? Double ?? 0
            entity.intensity = dict["intensity"] as? Double ?? 0
            entity.caloriesBurned = dict["caloriesBurned"] as? Double ?? 0
            entity.notes = dict["notes"] as? String

            count.imported += 1
        }

        return count
    }

    // MARK: - GMI Estimates (HbA1c Predictions)

    private static func importPredictions(
        _ items: [[String: Any]],
        into context: NSManagedObjectContext
    ) -> DataImportResult.ImportCount {
        var count = DataImportResult.ImportCount(found: items.count)

        for dict in items {
            let uuid: UUID
            if let idStr = dict["id"] as? String, let parsed = UUID(uuidString: idStr) {
                uuid = parsed
            } else {
                uuid = UUID()
            }

            if exists(entity: "HbA1cPredictionEntity", uuid: uuid, in: context) {
                count.skipped += 1
                continue
            }

            let entity = HbA1cPredictionEntity(context: context)
            entity.id = uuid
            entity.predictedValue = dict["predictedValue"] as? Double ?? 0
            entity.confidenceLevel = dict["confidenceLevel"] as? Double ?? 0
            entity.predictionDate = parseDate(dict["predictionDate"])
            entity.modelVersion = dict["modelVersion"] as? String

            // Restore contributing factors as binary JSON
            if let factors = dict["contributingFactors"] {
                entity.contributingFactorsJSON = try? JSONSerialization.data(
                    withJSONObject: factors
                )
            }

            count.imported += 1
        }

        return count
    }
}
