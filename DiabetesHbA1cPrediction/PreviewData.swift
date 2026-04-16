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
        user.age = 45
        user.sex = "Male"
        user.dateOfBirth = dateFrom(year: 2000, month: 1, day: 1)
        user.height = 170.0     // cm
        user.weight = 80.0      // kg
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
        hc.tobaccoUse = "Never"
        hc.alcoholUnitsPerWeek = 0.0
        hc.otherConditions = "None"
        hc.lastUpdated = Date()
        hc.user = user

        // ── 3. Lab HbA1c Results (10 results over 12 weeks) ──────
        // Stored as GlucoseReadingEntity with source "Hospital Lab Test",
        // alternating between NGSP % (US/JP) and IFCC mmol/mol (EU) units
        // so the dashboard chart can be visually verified in both modes.
        let labResults: [(daysAgo: Int, ngspPercent: Double, ifccMmol: Double, useIfcc: Bool)] = [
            (83, 7.4, 57, false),
            (74, 7.3, 56, true),
            (65, 7.2, 55, false),
            (56, 7.1, 54, true),
            (47, 7.0, 53, false),
            (38, 6.9, 52, true),
            (29, 6.9, 52, false),
            (20, 6.8, 51, true),
            (11, 6.7, 50, false),
            ( 2, 6.6, 49, true),
        ]
        for lab in labResults {
            let reading = GlucoseReadingEntity(context: context)
            reading.id = UUID()
            reading.timestamp = Calendar.current.date(byAdding: .day, value: -lab.daysAgo,
                to: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!)
            reading.value = lab.useIfcc ? lab.ifccMmol : lab.ngspPercent
            reading.unit = lab.useIfcc ? "mmol/mol" : "NGSP %"
            reading.trend = "stable"
            reading.source = "Hospital Lab Test"
        }

        // ── 4. CGM / Finger-Stick Readings (12 weeks) ────────────
        // Sparse coverage (1/day) for prior 70 days, dense (3/day) for
        // last 14 days. Values are deterministic (based on index) so
        // screenshots stay reproducible across runs.
        //
        // Sparse: days 14..83 → ~70 readings
        var cgmIndex = 0
        for d in 14...83 {
            let hour = [7, 12, 18][d % 3]
            // 110–170 mg/dL oscillation around a gently-declining mean
            let trendBase = 150.0 - Double(83 - d) * 0.3
            let value = trendBase + sin(Double(d) * 0.7) * 20
            let source = (d % 4 == 0) ? "TestMeter" : "TestCGM"
            let reading = GlucoseReadingEntity(context: context)
            reading.id = UUID()
            reading.timestamp = Calendar.current.date(byAdding: .day, value: -d,
                to: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!)
            reading.value = value.rounded()
            reading.unit = "mg/dL"
            reading.trend = value > 150 ? "rising" : (value < 100 ? "falling" : "stable")
            reading.source = source
            cgmIndex += 1
        }

        // Dense: last 14 days at 07:00, 12:00, 18:00 → 42 readings
        let denseHours = [7, 12, 18]
        for d in 0...13 {
            for (hi, hour) in denseHours.enumerated() {
                // Morning lower, post-meal peaks higher
                let hourAdj: Double = (hi == 0) ? -15 : (hi == 1) ? 25 : 5
                let value = 125.0 + hourAdj + sin(Double(d * 3 + hi) * 0.5) * 18
                let source = (d + hi) % 5 == 0 ? "TestMeter" : "TestCGM"
                let reading = GlucoseReadingEntity(context: context)
                reading.id = UUID()
                reading.timestamp = Calendar.current.date(byAdding: .day, value: -d,
                    to: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!)
                reading.value = value.rounded()
                reading.unit = "mg/dL"
                reading.trend = value > 150 ? "rising" : (value < 100 ? "falling" : "stable")
                reading.source = source
                cgmIndex += 1
            }
        }

        // ── 5. Meals (30 meals across 12 weeks) ──────────────────
        let mealTemplates: [(name: String, cals: Double, carbs: Double, protein: Double, fat: Double, fiber: Double)] = [
            ("Rice bowl with salmon",       520, 68, 28, 14,  4),
            ("Miso soup and grilled fish",  380, 18, 32, 18,  3),
            ("Soba noodles with tempura",   610, 82, 18, 20,  5),
            ("Chicken salad",               420, 22, 38, 22,  6),
            ("Oatmeal with berries",        310, 54, 10,  6,  8),
            ("Mixed vegetable curry",       560, 64, 14, 22,  9),
            ("Omelette and toast",          450, 32, 24, 24,  3),
            ("Udon with egg",               510, 76, 20, 12,  4),
            ("Grilled pork and rice",       680, 72, 34, 24,  5),
            ("Tofu and vegetables",         380, 28, 26, 18,  7),
        ]
        // Spread 30 meals evenly across 84 days (roughly every 2.8 days)
        for i in 0..<30 {
            let daysAgo = Int(Double(i) * (83.0 / 29.0))
            let template = mealTemplates[i % mealTemplates.count]
            let hour = [7, 12, 18][i % 3]
            let meal = MealEntity(context: context)
            meal.id = UUID()
            meal.name = template.name
            meal.calories = template.cals
            meal.timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo,
                to: Calendar.current.date(bySettingHour: hour, minute: 30, second: 0, of: Date())!)
            meal.unitString = "kcal"

            for (type, amount) in [("carbohydrates", template.carbs), ("protein", template.protein),
                                   ("fat", template.fat), ("fiber", template.fiber)] {
                let macro = MacronutrientEntity(context: context)
                macro.type = type
                macro.amount = amount
                macro.unit = "g"
                macro.meal = meal
            }
        }

        // ── 6. Exercise Sessions (20 sessions across 12 weeks) ───
        let exerciseTemplates: [(type: String, durationMin: Double, intensity: Double, calories: Double)] = [
            ("Walking",           35, 4.0, 180),
            ("Cycling",           45, 6.5, 320),
            ("Strength Training", 40, 7.0, 250),
            ("Swimming",          30, 6.0, 280),
            ("Running",           25, 8.0, 310),
            ("Yoga",              50, 3.0, 140),
            ("Hiking",            60, 5.0, 360),
        ]
        // Spread 20 sessions evenly across 84 days (roughly every 4.2 days)
        for i in 0..<20 {
            let daysAgo = Int(Double(i) * (83.0 / 19.0))
            let template = exerciseTemplates[i % exerciseTemplates.count]
            let session = ExerciseSessionEntity(context: context)
            session.id = UUID()
            session.type = template.type
            session.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo,
                to: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)
            session.duration = template.durationMin * 60  // stored in seconds
            session.endDate = session.startDate?.addingTimeInterval(session.duration)
            session.intensity = template.intensity
            session.caloriesBurned = template.calories
            session.notes = "Preview sample data – not real"
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
            #if DEBUG
            print("[PreviewData] Successfully seeded \(labResults.count) lab HbA1c results, "
                + "\(cgmIndex) CGM/meter readings, 30 meals, 20 exercises, \(predictions.count) predictions.")
            #endif
        } catch {
            #if DEBUG
            print("[PreviewData] Save failed: \(error)")
            #endif
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
