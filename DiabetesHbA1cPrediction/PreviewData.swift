//
//  PreviewData.swift
//  DiabetesHbA1cPrediction
//
//  Provides static dummy data for SwiftUI previews and for validating
//  the app in the Xcode iOS Simulator.
//
//  ┌──────────────────────────────────────────────────────────────────┐
//  │  HOW TO USE IN SIMULATOR                                        │
//  │                                                                  │
//  │  1. Launch the app in the simulator.                             │
//  │  2. The first time it runs, Core Data is empty.                 │
//  │  3. Navigate to the Profile tab and fill in dummy demographics: │
//  │       Age: 52, Sex: Male, Height: 175, Weight: 82               │
//  │       Diabetes: Type 2, Heart Disease: Yes                      │
//  │  4. Go to Meals tab → tap + → search "White Rice" → log it.    │
//  │  5. Go to Glucose tab → tap + → enter 145 mg/dL → save.        │
//  │  6. Go to Dashboard → tap "Run New Prediction".                 │
//  │                                                                  │
//  │  ALTERNATIVELY: Call PreviewData.populateIfEmpty(context:) in   │
//  │  the app delegate or onAppear to auto-seed data for testing.    │
//  └──────────────────────────────────────────────────────────────────┘
//

import Foundation
import CoreData

/// Utility struct that seeds a Core Data context with realistic test data.
/// Used both by SwiftUI previews (via PersistenceController.preview) and
/// optionally by the live app for first-run demo mode.
struct PreviewData {

    // MARK: - Auto-Populate

    /// Populates the given context with dummy data ONLY if no
    /// UserDemographicsEntity exists yet (i.e. first launch).
    /// Call this from the app's .onAppear or from a #Preview block.
    static func populateIfEmpty(context: NSManagedObjectContext) {
        let request = UserDemographicsEntity.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return } // Already has data
        populate(context: context)
    }

    // MARK: - Full Population

    /// Seeds the context with a complete set of test data covering
    /// all six entities. Saves automatically.
    static func populate(context: NSManagedObjectContext) {

        // ── 1. User Demographics ──────────────────────────────────
        let user = UserDemographicsEntity(context: context)
        user.id = UUID()
        user.age = 52
        user.sex = "Male"
        user.dateOfBirth = dateFrom(year: 1974, month: 3, day: 15)
        user.height = 175.0     // cm
        user.weight = 82.0      // kg
        user.diabetesType = "Type 2"
        user.menopausalStatus = "N/A"
        user.lastUpdated = Date()

        // ── 2. Health Conditions ──────────────────────────────────
        let hc = HealthConditionEntity(context: context)
        hc.id = UUID()
        hc.hasDiabetes = true
        hc.diabetesType = "Type 2"
        hc.hasCOPD = false
        hc.hasHeartDisease = true
        hc.tobaccoUse = "Former"
        hc.alcoholUnitsPerWeek = 6.0
        hc.otherConditions = "Mild hypertension"
        hc.lastUpdated = Date()
        hc.user = user

        // ── 3. Glucose Readings (21 readings over 7 days) ────────
        let glucoseValues: [(day: Int, hour: Int, value: Double, source: String)] = [
            (0, 7,  112, "FreeStyleLibre2"), (0, 12, 145, "FreeStyleLibre2"), (0, 18, 128, "FreeStyleLibre2"),
            (1, 7,  105, "ManualFingerStick"), (1, 12, 162, "FreeStyleLibre2"), (1, 18, 138, "FreeStyleLibre2"),
            (2, 7,  98,  "ManualFingerStick"), (2, 12, 155, "FreeStyleLibre2"), (2, 18, 119, "FreeStyleLibre2"),
            (3, 7,  118, "FreeStyleLibre2"), (3, 12, 172, "FreeStyleLibre2"), (3, 18, 141, "ManualFingerStick"),
            (4, 7,  95,  "ManualFingerStick"), (4, 12, 148, "FreeStyleLibre2"), (4, 18, 125, "FreeStyleLibre2"),
            (5, 7,  108, "FreeStyleLibre2"), (5, 12, 159, "FreeStyleLibre2"), (5, 18, 132, "FreeStyleLibre2"),
            (6, 7,  101, "ManualFingerStick"), (6, 12, 168, "FreeStyleLibre2"), (6, 18, 144, "FreeStyleLibre2"),
        ]
        for g in glucoseValues {
            let reading = GlucoseReadingEntity(context: context)
            reading.id = UUID()
            reading.timestamp = Calendar.current.date(byAdding: .day, value: -g.day,
                to: Calendar.current.date(bySettingHour: g.hour, minute: 0, second: 0, of: Date())!)
            reading.value = g.value
            reading.unit = "mg/dL"
            reading.trend = g.value > 150 ? "rising" : (g.value < 100 ? "falling" : "stable")
            reading.source = g.source
        }

        // ── 4. Meals (7 meals over the week) ─────────────────────
        let meals: [(name: String, cals: Double, carbs: Double, protein: Double, fat: Double, fiber: Double, daysAgo: Int)] = [
            ("Oatmeal with blueberries",        310, 54, 11, 6,  8,  0),
            ("Grilled chicken Caesar salad",     420, 18, 38, 22, 4,  0),
            ("Spaghetti Bolognese",              680, 78, 28, 24, 6,  1),
            ("Greek yogurt with honey & walnuts", 285, 32, 15, 12, 1,  1),
            ("Salmon with steamed vegetables",   480, 22, 42, 24, 5,  2),
            ("Turkey sandwich on whole wheat",   390, 42, 28, 12, 6,  3),
            ("Vegetable stir-fry with brown rice", 520, 68, 16, 18, 7, 4),
        ]
        for m in meals {
            let meal = MealEntity(context: context)
            meal.id = UUID()
            meal.name = m.name
            meal.calories = m.cals
            meal.timestamp = Calendar.current.date(byAdding: .day, value: -m.daysAgo, to: Date())
            meal.unitString = "kcal"

            for (type, amount) in [("carbohydrates", m.carbs), ("protein", m.protein), ("fat", m.fat), ("fiber", m.fiber)] {
                let macro = MacronutrientEntity(context: context)
                macro.type = type
                macro.amount = amount
                macro.unit = "g"
                macro.meal = meal
            }
        }

        // ── 5. Exercise Sessions ──────────────────────────────────
        let exercises: [(type: String, daysAgo: Int, durationMin: Double, intensity: Double, calories: Double)] = [
            ("Walking",           0, 35, 4.0, 180),
            ("Cycling",           1, 45, 6.5, 320),
            ("Strength Training", 2, 40, 7.0, 250),
            ("Swimming",          3, 30, 6.0, 280),
            ("Running",           5, 25, 8.0, 310),
        ]
        for e in exercises {
            let session = ExerciseSessionEntity(context: context)
            session.id = UUID()
            session.type = e.type
            session.startDate = Calendar.current.date(byAdding: .day, value: -e.daysAgo,
                to: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)
            session.duration = e.durationMin * 60  // stored in seconds
            session.endDate = session.startDate?.addingTimeInterval(session.duration)
            session.intensity = e.intensity
            session.caloriesBurned = e.calories
            session.notes = "Simulator test data"
        }

        // ── 6. HbA1c Predictions ─────────────────────────────────
        let predictions: [(weeksAgo: Int, hba1c: Double, confidence: Double)] = [
            (0, 6.8, 0.85),
            (1, 7.0, 0.82),
            (2, 7.1, 0.78),
            (3, 6.9, 0.80),
        ]
        for p in predictions {
            let pred = HbA1cPredictionEntity(context: context)
            pred.id = UUID()
            pred.predictedValue = p.hba1c
            pred.confidenceLevel = p.confidence
            pred.predictionDate = Calendar.current.date(byAdding: .weekOfYear, value: -p.weeksAgo, to: Date())
            pred.modelVersion = "1.0.0"
            let factors: [String: Double] = [
                "avgGlucose": 135.0 + Double(p.weeksAgo) * 3,
                "carbIntake": 240 + Double(p.weeksAgo) * 10,
                "exerciseMinutes": 175 - Double(p.weeksAgo) * 15,
                "bmi": 26.8,
                "glucoseVariability": 0.22 + Double(p.weeksAgo) * 0.02
            ]
            pred.contributingFactorsJSON = try? JSONSerialization.data(withJSONObject: factors)
        }

        // ── Save ──────────────────────────────────────────────────
        do {
            try context.save()
            print("[PreviewData] Successfully seeded \(glucoseValues.count) glucose readings, "
                + "\(meals.count) meals, \(exercises.count) exercises, \(predictions.count) predictions.")
        } catch {
            print("[PreviewData] Save failed: \(error)")
        }
    }

    // MARK: - Helpers

    private static func dateFrom(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}
