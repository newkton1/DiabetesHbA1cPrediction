//
//  PersistenceController.swift
//  DiabetesHbA1cPrediction
//
//  Manages the Core Data stack for the entire application.
//  Provides a shared singleton plus an in-memory preview instance
//  used for SwiftUI previews and simulator testing with dummy data.
//

import CoreData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DiabetesHbA1cPrediction", category: "CoreData")

struct PersistenceController {

    /// Indicates whether the Core Data store failed to load.
    /// When true, the app should present a fallback UI rather than crashing.
    @MainActor static var storeLoadError: NSError?

    // MARK: - Singleton

    /// Shared instance used throughout the live application.
    static let shared = PersistenceController()

    // MARK: - Preview Instance (populated with dummy data for simulator testing)

    /// In-memory store pre-loaded with sample data for Xcode previews and simulator validation.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext

        // --- Dummy User Demographics ---
        let user = UserDemographicsEntity(context: ctx)
        user.id = UUID()
        user.age = 52
        user.sex = "Male"
        user.dateOfBirth = Calendar.current.date(from: DateComponents(year: 1974, month: 3, day: 15))
        user.height = 175.0   // cm
        user.weight = 82.0    // kg
        user.diabetesType = "Type 2"
        user.menopausalStatus = "N/A"
        user.lastUpdated = Date()

        // --- Dummy Health Conditions ---
        let conditions = HealthConditionEntity(context: ctx)
        conditions.id = UUID()
        conditions.hasDiabetes = true
        conditions.diabetesType = "Type 2"
        conditions.hasCOPD = false
        conditions.hasHeartDisease = true
        conditions.tobaccoUse = "Former"       // Never / Former / Current
        conditions.alcoholUnitsPerWeek = 6.0
        conditions.otherConditions = "Mild hypertension"
        conditions.lastUpdated = Date()
        conditions.user = user

        // --- Dummy Glucose Readings (last 7 days) ---
        for dayOffset in 0..<7 {
            for hour in [7, 12, 18] {           // morning, noon, evening
                let reading = GlucoseReadingEntity(context: ctx)
                reading.id = UUID()
                reading.timestamp = Calendar.current.date(byAdding: .day, value: -dayOffset,
                    to: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!)
                // Simulate realistic glucose range 90-180 mg/dL
                reading.value = Double.random(in: 90...180)
                reading.unit = "mg/dL"
                reading.trend = ["stable", "rising", "falling"].randomElement() ?? "stable"
                reading.source = dayOffset % 2 == 0 ? "FreeStyleLibre2" : "ManualFingerStick"
            }
        }

        // --- Dummy Meals ---
        let mealNames = [
            ("Grilled chicken salad", 420.0),
            ("Oatmeal with berries", 310.0),
            ("Spaghetti Bolognese", 680.0),
            ("Vegetable stir-fry with rice", 520.0),
            ("Greek yogurt with honey", 210.0)
        ]
        for (i, (name, cals)) in mealNames.enumerated() {
            let meal = MealEntity(context: ctx)
            meal.id = UUID()
            meal.name = name
            meal.calories = cals
            meal.timestamp = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            meal.unitString = "kcal"

            // Macronutrients for each meal
            let carbs = MacronutrientEntity(context: ctx)
            carbs.type = "carbohydrates"
            carbs.amount = Double.random(in: 30...80)
            carbs.unit = "g"
            carbs.meal = meal

            let protein = MacronutrientEntity(context: ctx)
            protein.type = "protein"
            protein.amount = Double.random(in: 15...45)
            protein.unit = "g"
            protein.meal = meal

            let fat = MacronutrientEntity(context: ctx)
            fat.type = "fat"
            fat.amount = Double.random(in: 10...30)
            fat.unit = "g"
            fat.meal = meal

            let fiber = MacronutrientEntity(context: ctx)
            fiber.type = "fiber"
            fiber.amount = Double.random(in: 2...12)
            fiber.unit = "g"
            fiber.meal = meal
        }

        // --- Dummy Exercise Sessions ---
        let exerciseTypes = ["Walking", "Running", "Cycling", "Swimming", "Strength Training"]
        for i in 0..<5 {
            let session = ExerciseSessionEntity(context: ctx)
            session.id = UUID()
            session.type = exerciseTypes[i]
            session.startDate = Calendar.current.date(byAdding: .day, value: -i,
                to: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)
            session.duration = Double.random(in: 20...60) * 60  // seconds
            session.endDate = session.startDate?.addingTimeInterval(session.duration)
            session.intensity = Double.random(in: 3...8) // 1-10 scale
            session.caloriesBurned = Double.random(in: 150...500)
            session.notes = "Auto-synced from Health"
        }

        // --- Dummy HbA1c Predictions ---
        for weekOffset in 0..<4 {
            let prediction = HbA1cPredictionEntity(context: ctx)
            prediction.id = UUID()
            prediction.predictedValue = Double.random(in: 5.8...7.5)
            prediction.confidenceLevel = Double.random(in: 0.70...0.92)
            prediction.predictionDate = Calendar.current.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())
            prediction.modelVersion = "1.0.0"
            // Store contributing factors as JSON
            let factors: [String: Double] = [
                "avgGlucose": Double.random(in: 110...160),
                "carbIntake": Double.random(in: 180...300),
                "exerciseMinutes": Double.random(in: 100...300),
                "weight": 82.0
            ]
            prediction.contributingFactorsJSON = try? JSONSerialization.data(withJSONObject: factors)
        }

        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("Preview data save error: \(error)")
            #endif
        }
        return controller
    }()

    // MARK: - Core Data Container

    /// The NSPersistentContainer that manages the Core Data stack.
    let container: NSPersistentContainer

    /// Initialises the Core Data stack.
    /// - Parameter inMemory: When `true`, uses an in-memory store (for previews/tests).
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DiabetesHbA1cPrediction")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable lightweight migration to handle model changes automatically
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        // Encrypt the Core Data store at rest using file protection.
        // completeUntilFirstUserAuthentication keeps data encrypted until the user
        // unlocks the device for the first time after boot, then remains accessible
        // in the background — a good balance for health data apps.
        if !inMemory {
            description?.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                logger.error("Core Data store failed to load: \(error.localizedDescription, privacy: .public)")
                // Store the error so the app can present a user-facing alert
                // instead of crashing.
                Task { @MainActor in
                    PersistenceController.storeLoadError = error
                }
            }
        }
        // Automatically merge changes from background contexts into the view context.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // MARK: - Convenience Save

    /// Saves the view context if there are uncommitted changes.
    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("Core Data save error: \(error)")
            #endif
        }
    }
}
