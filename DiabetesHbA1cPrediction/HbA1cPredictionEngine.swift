import Foundation
import CoreData
import Combine

/// Struct representing all inputs required for HbA1c prediction
/// Contains glucose metrics, dietary information, physical activity, demographics, and health conditions
struct PredictionInput {
    // Glucose Metrics
    let averageGlucose: Double           // mg/dL - average blood glucose over measurement period
    let glucoseVariability: Double       // coefficient of variation (%) - measure of glucose stability

    // Dietary Intake
    let dailyCarbIntake: Double          // grams - carbohydrate consumption
    let dailyCalories: Double            // kilocalories - total energy intake

    // Physical Activity (7-day window)
    let weeklyExerciseMinutes: Double    // minutes - total aerobic exercise per week
    let exerciseIntensityAvg: Double     // 1-10 scale - average intensity of exercise sessions

    // Cardio-specific metrics (Walking/Running/Cycling - last 7 days)
    var cardioDistanceKm: Double = 0     // km - total distance from cardio exercises
    var cardioCaloriesBurned: Double = 0 // calories - total from cardio exercises

    // Non-cardio metrics (all other exercise types - last 7 days)
    var nonCardioMinutes: Double = 0     // minutes - total duration of non-cardio exercises
    var nonCardioIntensityAvg: Double = 0 // 1-10 scale - average intensity of non-cardio

    // Demographics
    let age: Int                         // years
    let sex: String                      // "Male" or "Female"
    let bmi: Double                      // body mass index (kg/m²)

    // Diabetes Status
    let hasDiabetes: Bool                // current diabetes diagnosis
    let diabetesType: String?            // "Type 1" or "Type 2" (nil if no diabetes)

    // Comorbidities
    let hasCOPD: Bool                    // Chronic Obstructive Pulmonary Disease
    let hasHeartDisease: Bool            // history of heart disease or current condition

    // Dawn Effect
    var hasDawnEffect: Bool = false      // user-confirmed dawn effect
    var dawnEffectDetected: Bool = false  // algorithmically detected dawn pattern

    // Lifestyle Factors
    let tobaccoUse: String               // "Never", "Former", or "Current"
    let alcoholUnitsPerWeek: Double      // standard drink units per week
    let timeSinceLastMealHours: Double   // hours since last food intake
    
    // Last Meal Data (for immediate glucose impact)
    var lastMealCarbs: Double = 0        // grams - carbohydrates from last meal
    var lastMealGlycemicLoad: Double = 0 // glycemic load of last meal
    
    // Planned Meal Data (for future impact projection)
    var plannedMealCarbs: Double? = nil   // grams - planned meal carbohydrates
    var plannedMealGlycemicLoad: Double? = nil  // planned meal glycemic load
    var hoursUntilPlannedMeal: Double? = nil    // hours until planned meal
}

/// Struct representing the HbA1c prediction result with clinical interpretation
struct PredictionResult {
    let predictedHbA1c: Double           // percentage (e.g., 6.5 represents 6.5%)
    let confidenceLevel: Double          // 0.0 to 1.0 - statistical confidence in prediction
    let riskCategory: String             // clinical risk classification
    let contributingFactors: [String: Double]  // factor name -> contribution to HbA1c (%)
    let recommendations: [String]        // actionable clinical recommendations
}

/// Core HbA1c prediction engine using medical formulas and adjustment factors
/// Based on the Nathan et al. formula relating average glucose to HbA1c
/// Reference: Nathan et al. Diabetes Care 2008;31:1473-1478
class HbA1cPredictionEngine: ObservableObject {
    let modelVersion = "1.0.0"

    /// Set after each prediction run — true if dawn effect pattern was detected algorithmically
    @Published var lastRunDetectedDawnEffect: Bool = UserDefaults.standard.bool(forKey: "lastRunDetectedDawnEffect")
    /// Set after each prediction run — true if dawn compensation was applied (user-enabled or detected)
    @Published var lastRunAppliedDawnCompensation: Bool = UserDefaults.standard.bool(forKey: "lastRunAppliedDawnCompensation")

    // MARK: - Public Methods

    /// Predicts HbA1c from comprehensive health and lifestyle inputs
    /// - Parameter input: PredictionInput struct containing all required data
    /// - Returns: PredictionResult with predicted HbA1c, confidence, risk category, and recommendations
    func predict(from input: PredictionInput) -> PredictionResult {
        var contributingFactors: [String: Double] = [:]

        // Step 1: Calculate base HbA1c using Nathan et al. formula
        // This formula is derived from prospective data in 507 individuals with diabetes
        // and correlates glucose monitoring data with HbA1c values
        // Formula: HbA1c (%) = (averageGlucose + 46.7) / 28.7
        let baseHbA1c = (input.averageGlucose + 46.7) / 28.7
        var predictedHbA1c = baseHbA1c

        // Note dawn effect compensation in contributing factors
        // (The actual compensation is applied during glucose averaging, not here)
        if input.hasDawnEffect || input.dawnEffectDetected {
            contributingFactors["Dawn Effect Adjustment"] = 0.0  // informational — applied at averaging stage
        }

        // Step 2: Apply glucose variability adjustment
        // High glucose variability (CV > 36%) indicates unstable glucose control
        // and is associated with worse glycemic outcomes independent of average glucose
        // Reference: Brownlee & Hirsch. Glycemic Variability in Diabetes Complications (2006)
        // Greater variability = more oxidative stress = higher HbA1c trajectory
        if input.glucoseVariability > 36.0 {
            let variabilityAdjustment = min(0.3, (input.glucoseVariability - 36.0) / 36.0 * 0.3)
            predictedHbA1c += variabilityAdjustment
            contributingFactors["Glucose Variability"] = variabilityAdjustment
        }

        // Step 3: Apply dietary adjustment - carbohydrate intake
        // High carbohydrate intake (>300g/day) is associated with higher postprandial glucose
        // and can lead to HbA1c elevation of 0.1-0.2%
        // Reference: Academy of Nutrition and Dietetics Standard of Care
        if input.dailyCarbIntake > 300.0 {
            let carbAdjustment = 0.1 + min(0.1, (input.dailyCarbIntake - 300.0) / 100.0 * 0.1)
            predictedHbA1c += carbAdjustment
            contributingFactors["High Carb Intake"] = carbAdjustment
        }

        // Step 4: Apply exercise adjustment (dual-pathway, 7-day history)
        // Cardio (Walking/Running/Cycling): uses distance + calories burned
        // Non-cardio (all others): uses duration + intensity
        // Reference: American Diabetes Association Standards of Care
        var totalExerciseEffect = 0.0

        // Cardio pathway: distance + calories
        if input.cardioDistanceKm > 0 || input.cardioCaloriesBurned > 0 {
            let distanceEffect = input.cardioDistanceKm * 0.02  // ~0.3% reduction per 15 km/week
            let calorieEffect = (input.cardioCaloriesBurned / 500.0) * 0.15  // ~0.15% per 500 cal
            let cardioEffect = min(0.4, distanceEffect + calorieEffect)
            totalExerciseEffect += cardioEffect
            contributingFactors["Cardio Exercise"] = -cardioEffect
        }

        // Non-cardio pathway: duration + intensity
        if input.nonCardioMinutes > 0 {
            let nonCardioEffect = min(
                0.3,
                (input.nonCardioMinutes / 150.0) * (input.nonCardioIntensityAvg / 10.0) * 0.3
            )
            totalExerciseEffect += nonCardioEffect
            contributingFactors["Other Exercise"] = -nonCardioEffect
        }

        // Cap total exercise benefit at 0.6% HbA1c reduction
        totalExerciseEffect = min(0.6, totalExerciseEffect)
        if totalExerciseEffect > 0 {
            predictedHbA1c -= totalExerciseEffect
            contributingFactors["Exercise Benefits"] = -totalExerciseEffect
        }

        // Step 5: Apply age adjustment
        // HbA1c targets are often age-adjusted; older adults (>60) have slightly higher
        // baseline HbA1c values due to physiological changes in glucose metabolism
        // Reference: Endocrine Society Guidelines for Older Adults
        if input.age > 60 {
            let ageAdjustment = 0.1
            predictedHbA1c += ageAdjustment
            contributingFactors["Age Factor"] = ageAdjustment
        }

        // Step 6: Apply BMI adjustment
        // Obesity is strongly associated with insulin resistance and hyperglycemia
        // Overweight (BMI 25-29.9): +0.1%, Obese (BMI ≥30): +0.2%
        // Reference: Diabetes UK Obesity Management Guidelines
        if input.bmi >= 30.0 {
            let bmiAdjustment = 0.2
            predictedHbA1c += bmiAdjustment
            contributingFactors["Obesity"] = bmiAdjustment
        } else if input.bmi >= 25.0 {
            let bmiAdjustment = 0.1
            predictedHbA1c += bmiAdjustment
            contributingFactors["Overweight"] = bmiAdjustment
        }

        // Step 7: Apply COPD adjustment
        // COPD is associated with systemic inflammation (elevated CRP, TNF-alpha)
        // This chronic inflammatory state impairs glucose metabolism and insulin action
        // Reference: NEJM 2007; COPD patients have 2-3x higher diabetes risk
        // Adjustment: +0.1% HbA1c
        if input.hasCOPD {
            let copdAdjustment = 0.1
            predictedHbA1c += copdAdjustment
            contributingFactors["COPD Inflammation"] = copdAdjustment
        }

        // Step 8: Apply heart disease adjustment
        // Cardiovascular disease is both a consequence and contributor to hyperglycemia
        // Heart disease patients often have insulin resistance and autonomic dysfunction
        // Reference: Heart disease increases cardiovascular risk in hyperglycemia
        // Adjustment: +0.1% HbA1c
        if input.hasHeartDisease {
            let heartAdjustment = 0.1
            predictedHbA1c += heartAdjustment
            contributingFactors["Heart Disease"] = heartAdjustment
        }

        // Step 9: Apply tobacco use adjustment
        // Smoking impairs insulin secretion, increases insulin resistance, and causes
        // oxidative stress that damages beta cells
        // Current smoking: +0.15% HbA1c (active metabolic effects)
        // Former smoking: +0.05% HbA1c (residual insulin resistance)
        // Reference: American Heart Association, Diabetes Care 2009
        let tobaccoAdjustment: Double
        switch input.tobaccoUse {
        case "Current":
            tobaccoAdjustment = 0.15
        case "Former":
            tobaccoAdjustment = 0.05
        default: // "Never"
            tobaccoAdjustment = 0.0
        }

        if tobaccoAdjustment > 0 {
            predictedHbA1c += tobaccoAdjustment
            contributingFactors["Tobacco Use"] = tobaccoAdjustment
        }

        // Step 10: Apply alcohol consumption adjustment
        // Alcohol has complex effects on glucose metabolism:
        // - Moderate consumption (7-14 units/week) may provide slight cardioprotective benefit
        //   and modest reduction in HbA1c (-0.05%)
        // - Heavy consumption (>14 units/week) impairs liver function and glucose homeostasis,
        //   increases HbA1c (+0.1%)
        // Reference: Journal of Studies on Alcohol and Drugs, Diabetes Care
        let alcoholAdjustment: Double
        if input.alcoholUnitsPerWeek > 14.0 {
            alcoholAdjustment = 0.1  // Heavy consumption
        } else if input.alcoholUnitsPerWeek >= 7.0 {
            alcoholAdjustment = -0.05  // Moderate consumption
        } else {
            alcoholAdjustment = 0.0
        }

        if alcoholAdjustment != 0 {
            predictedHbA1c += alcoholAdjustment
            contributingFactors["Alcohol Consumption"] = alcoholAdjustment
        }
        
        // Step 11: Apply recent meal impact adjustment
        // Recent high glycemic load meals have a transient effect on blood glucose
        // that can affect HbA1c trajectory if patterns persist
        if input.lastMealGlycemicLoad > 0 && input.timeSinceLastMealHours < 6 {
            // Recent meal impact decreases with time
            let timeFactor = max(0, 1.0 - input.timeSinceLastMealHours / 6.0)
            
            if input.lastMealGlycemicLoad > 25 {
                // High glycemic load meal (>25)
                let mealImpact = min(0.1, (input.lastMealGlycemicLoad - 25) / 50.0 * 0.1) * timeFactor
                predictedHbA1c += mealImpact
                contributingFactors["Recent High GL Meal"] = mealImpact
            }
        }
        
        // High carb recent meals add additional impact
        if input.lastMealCarbs > 80 && input.timeSinceLastMealHours < 4 {
            let carbImpact = min(0.05, (input.lastMealCarbs - 80) / 100.0 * 0.05)
            predictedHbA1c += carbImpact
            contributingFactors["Recent High Carb Meal"] = carbImpact
        }

        // Ensure predicted HbA1c stays within physiological bounds
        predictedHbA1c = max(4.0, min(14.0, predictedHbA1c))

        // Step 11: Calculate confidence level
        // Confidence is based on data availability and glucose stability
        // More stable glucose readings (lower CV) and consistent data improve confidence
        let confidenceLevel = calculateConfidence(
            glucoseVariability: input.glucoseVariability
        )

        // Step 12: Determine risk category based on HbA1c thresholds
        // ADA Diagnostic Criteria and Clinical Guidelines
        let riskCategory = determineRiskCategory(hbA1c: predictedHbA1c)

        // Step 13: Generate clinical recommendations based on modifiable factors
        let recommendations = generateRecommendations(
            input: input,
            predictedHbA1c: predictedHbA1c,
            riskCategory: riskCategory,
            contributingFactors: contributingFactors
        )

        return PredictionResult(
            predictedHbA1c: round(predictedHbA1c * 10.0) / 10.0,  // Round to 1 decimal
            confidenceLevel: confidenceLevel,
            riskCategory: riskCategory,
            contributingFactors: contributingFactors,
            recommendations: recommendations
        )
    }

    /// Gathers prediction inputs from Core Data entities
    /// - Parameter context: NSManagedObjectContext for Core Data access
    /// - Returns: PredictionInput if sufficient data is available, nil otherwise
    func gatherInputs(context: NSManagedObjectContext) -> PredictionInput? {
        // Fetch glucose readings from last 90 days
        guard let glucoseReadings = fetchGlucoseReadings(
            from: context,
            days: 90
        ) else {
            #if DEBUG
            print("Error: Unable to fetch glucose readings")
            #endif
            return nil
        }

        guard !glucoseReadings.isEmpty else {
            #if DEBUG
            print("Error: No glucose readings available for prediction")
            #endif
            return nil
        }

        // Calculate glucose metrics
        let glucoseVariability = calculateCoefficientOfVariation(glucoseReadings)

        // Fetch meals from last 30 days
        let meals = fetchMeals(from: context, days: 30) ?? []

        // Fetch health conditions early — needed for dawn effect check
        let healthConditions = fetchHealthConditions(from: context) ?? [:]
        let userHasDawnEffect = healthConditions["DawnEffect"] ?? false

        // Calculate average glucose — use dawn-adjusted average if dawn effect is active
        let averageGlucose: Double
        let dawnEffectDetected: Bool

        if let timestampedReadings = fetchGlucoseReadingsWithTimestamps(from: context, days: 90),
           !timestampedReadings.isEmpty {
            // Run dawn detection algorithm regardless of user setting
            dawnEffectDetected = detectDawnEffect(readings: timestampedReadings, meals: meals)

            // Apply dawn compensation if user has enabled it OR if detected
            if userHasDawnEffect || dawnEffectDetected {
                averageGlucose = calculateDawnAdjustedAverage(timestampedReadings)
            } else {
                averageGlucose = glucoseReadings.reduce(0, +) / Double(glucoseReadings.count)
            }
        } else {
            averageGlucose = glucoseReadings.reduce(0, +) / Double(glucoseReadings.count)
            dawnEffectDetected = false
        }
        let (dailyCarbIntake, dailyCalories) = calculateDailyNutrition(meals)

        // Fetch exercise sessions from last 7 days
        let exerciseSessions = fetchExerciseSessions(from: context, days: 7) ?? []
        let (weeklyExerciseMinutes, exerciseIntensityAvg) = calculateExerciseMetrics(exerciseSessions)
        let exerciseSplit = calculateExerciseSplit(exerciseSessions)

        // Fetch user demographics
        guard let demographics = fetchUserDemographics(from: context) else {
            #if DEBUG
            print("Error: Unable to fetch user demographics")
            #endif
            return nil
        }

        // Health conditions already fetched above for dawn effect check

        // Fetch last meal data for meal-aware prediction
        let lastMealData = fetchLastMeal(from: context)
        
        // Fetch next planned meal
        let plannedMeals = fetchPlannedMeals(from: context)
        let nextPlannedMeal = plannedMeals.first
        
        var input = PredictionInput(
            averageGlucose: averageGlucose,
            glucoseVariability: glucoseVariability,
            dailyCarbIntake: dailyCarbIntake,
            dailyCalories: dailyCalories,
            weeklyExerciseMinutes: weeklyExerciseMinutes,
            exerciseIntensityAvg: exerciseIntensityAvg,
            age: demographics.age,
            sex: demographics.sex,
            bmi: demographics.bmi,
            hasDiabetes: demographics.hasDiabetes,
            diabetesType: demographics.diabetesType,
            hasCOPD: healthConditions["COPD"] ?? false,
            hasHeartDisease: healthConditions["HeartDisease"] ?? false,
            tobaccoUse: demographics.tobaccoUse,
            alcoholUnitsPerWeek: demographics.alcoholUnitsPerWeek,
            timeSinceLastMealHours: lastMealData?.hoursSince ?? calculateTimeSinceLastMeal(meals)
        )
        
        // Add cardio/non-cardio exercise split
        input.cardioDistanceKm = exerciseSplit.cardioDistanceKm
        input.cardioCaloriesBurned = exerciseSplit.cardioCalories
        input.nonCardioMinutes = exerciseSplit.nonCardioMinutes
        input.nonCardioIntensityAvg = exerciseSplit.nonCardioIntensityAvg

        // Add dawn effect flags
        input.hasDawnEffect = userHasDawnEffect
        input.dawnEffectDetected = dawnEffectDetected

        // Add last meal data
        if let lastMeal = lastMealData {
            input.lastMealCarbs = lastMeal.carbs
            input.lastMealGlycemicLoad = lastMeal.glycemicLoad
        }
        
        // Add planned meal data
        if let planned = nextPlannedMeal {
            input.plannedMealCarbs = planned.carbs
            input.plannedMealGlycemicLoad = planned.glycemicLoad
            input.hoursUntilPlannedMeal = planned.hoursUntil
        }

        return input
    }

    /// Runs full prediction pipeline: gather inputs, predict, and save results
    /// - Parameter context: NSManagedObjectContext for Core Data operations
    /// - Returns: PredictionResult if successful, nil otherwise
    func runPredictionAndSave(context: NSManagedObjectContext) -> PredictionResult? {
        // Gather inputs from Core Data
        guard let input = gatherInputs(context: context) else {
            #if DEBUG
            print("Error: Failed to gather prediction inputs")
            #endif
            return nil
        }

        // Update dawn effect state for UI notifications and persist for next launch
        lastRunDetectedDawnEffect = input.dawnEffectDetected
        lastRunAppliedDawnCompensation = input.hasDawnEffect || input.dawnEffectDetected
        UserDefaults.standard.set(lastRunDetectedDawnEffect, forKey: "lastRunDetectedDawnEffect")
        UserDefaults.standard.set(lastRunAppliedDawnCompensation, forKey: "lastRunAppliedDawnCompensation")

        // Run prediction (includes dual-pathway exercise calculation)
        let result = predict(from: input)
        var finalHbA1c = result.predictedHbA1c
        var finalConfidence = result.confidenceLevel
        var updatedFactors = result.contributingFactors

        // Blend with prior HbA1c measurements if available (time-decay weighted)
        // Now supports single readings (at 50/50 blend) and 2+ readings (at 30/70 blend)
        if let priorReadings = fetchPriorHbA1cReadings(from: context), !priorReadings.isEmpty {
            finalHbA1c = blendWithPriorHbA1c(
                formulaPrediction: finalHbA1c,
                priorReadings: priorReadings
            )
            finalHbA1c = max(4.0, min(14.0, finalHbA1c))
            let confidenceBoost = priorReadings.count >= 2 ? 0.15 : 0.08
            finalConfidence = min(1.0, finalConfidence + confidenceBoost)
            updatedFactors["Prior HbA1c Blending"] = 0.0  // marker indicating blending was applied
        }

        let finalResult = PredictionResult(
            predictedHbA1c: round(finalHbA1c * 10.0) / 10.0,
            confidenceLevel: finalConfidence,
            riskCategory: determineRiskCategory(hbA1c: finalHbA1c),
            contributingFactors: updatedFactors,
            recommendations: result.recommendations
        )

        // Save prediction result to Core Data
        savePredictionResult(finalResult, to: context)

        // Attempt to save context
        do {
            try context.save()
            #if DEBUG
            print("Successfully saved prediction result to Core Data")
            #endif
            return finalResult
        } catch {
            #if DEBUG
            print("Error saving prediction result: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Meal-Aware Prediction Methods
    
    /// Fetches the most recent logged meal (not planned) with calculated totals
    /// - Parameter context: NSManagedObjectContext for Core Data access
    /// - Returns: Tuple containing carbs, glycemic load, and hours since meal; nil if no meal found
    func fetchLastMeal(from context: NSManagedObjectContext) -> (carbs: Double, glycemicLoad: Double, hoursSince: Double)? {
        let fetchRequest: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "mealType != %@ OR mealType == nil", "plannedMeal")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            guard let meal = try context.fetch(fetchRequest).first,
                  let timestamp = meal.timestamp else {
                return nil
            }
            
            // Calculate totals from food items or macronutrients
            var totalCarbs: Double = 0
            var totalGlycemicLoad: Double = 0
            
            // Try to get from food items first (new system)
            if let foodItems = meal.foodItems as? Set<MealFoodItemEntity>, !foodItems.isEmpty {
                for item in foodItems {
                    let carbsForItem = item.carbsPerServing * item.quantity
                    let fiberForItem = item.fiberPerServing * item.quantity
                    let netCarbs = max(0, carbsForItem - fiberForItem)
                    totalCarbs += carbsForItem
                    totalGlycemicLoad += (Double(item.glycemicIndex) * netCarbs) / 100.0
                }
            } else if let macros = meal.macronutrients as? Set<MacronutrientEntity> {
                // Fall back to macronutrients (legacy system)
                totalCarbs = macros.filter { $0.type == "carbohydrates" || $0.type == "carbs" }
                    .reduce(0) { $0 + $1.amount }
                // Estimate glycemic load with average GI of 55
                totalGlycemicLoad = (55 * totalCarbs) / 100.0
            }
            
            // Use meal's timeSinceLastMeal if available, otherwise calculate from timestamp
            let hoursSince: Double
            if meal.timeSinceLastMeal > 0 {
                // Add time elapsed since the meal was logged
                let loggedHoursAgo = Date().timeIntervalSince(timestamp) / 3600.0
                hoursSince = meal.timeSinceLastMeal + loggedHoursAgo
            } else {
                hoursSince = Date().timeIntervalSince(timestamp) / 3600.0
            }
            
            return (carbs: totalCarbs, glycemicLoad: totalGlycemicLoad, hoursSince: hoursSince)
        } catch {
            #if DEBUG
            print("Error fetching last meal: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// Fetches upcoming planned meals
    /// - Parameter context: NSManagedObjectContext for Core Data access
    /// - Returns: Array of tuples containing carbs, glycemic load, and hours until meal
    func fetchPlannedMeals(from context: NSManagedObjectContext) -> [(carbs: Double, glycemicLoad: Double, hoursUntil: Double)] {
        let fetchRequest: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "mealType == %@ AND plannedDateTime > %@", "plannedMeal", Date() as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntity.plannedDateTime, ascending: true)]
        
        do {
            let meals = try context.fetch(fetchRequest)
            
            return meals.compactMap { meal -> (carbs: Double, glycemicLoad: Double, hoursUntil: Double)? in
                guard let plannedDate = meal.plannedDateTime else { return nil }
                
                var totalCarbs: Double = 0
                var totalGlycemicLoad: Double = 0
                
                // Try to get from food items first (new system)
                if let foodItems = meal.foodItems as? Set<MealFoodItemEntity>, !foodItems.isEmpty {
                    for item in foodItems {
                        let carbsForItem = item.carbsPerServing * item.quantity
                        let fiberForItem = item.fiberPerServing * item.quantity
                        let netCarbs = max(0, carbsForItem - fiberForItem)
                        totalCarbs += carbsForItem
                        totalGlycemicLoad += (Double(item.glycemicIndex) * netCarbs) / 100.0
                    }
                } else if let macros = meal.macronutrients as? Set<MacronutrientEntity> {
                    // Fall back to macronutrients (legacy system)
                    totalCarbs = macros.filter { $0.type == "carbohydrates" || $0.type == "carbs" }
                        .reduce(0) { $0 + $1.amount }
                    // Estimate glycemic load with average GI of 55
                    totalGlycemicLoad = (55 * totalCarbs) / 100.0
                }
                
                let hoursUntil = plannedDate.timeIntervalSince(Date()) / 3600.0
                
                return (carbs: totalCarbs, glycemicLoad: totalGlycemicLoad, hoursUntil: hoursUntil)
            }
        } catch {
            #if DEBUG
            print("Error fetching planned meals: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    /// Predicts future HbA1c impact based on a planned meal
    /// - Parameters:
    ///   - currentPrediction: The current HbA1c prediction result
    ///   - plannedMealCarbs: Carbohydrates in the planned meal (grams)
    ///   - plannedMealGI: Average glycemic index of the planned meal
    ///   - hoursUntilMeal: Hours until the meal will be consumed
    /// - Returns: Adjusted prediction result incorporating the planned meal impact
    func predictWithPlannedMeal(
        currentPrediction: PredictionResult,
        plannedMealCarbs: Double,
        plannedMealGI: Double,
        hoursUntilMeal: Double
    ) -> PredictionResult {
        var adjustedHbA1c = currentPrediction.predictedHbA1c
        var updatedFactors = currentPrediction.contributingFactors
        
        // Calculate glycemic load of planned meal
        let glycemicLoad = (plannedMealGI * plannedMealCarbs) / 100.0
        
        // Impact factor based on meal size and GI
        // High GL meals (>20) have more significant impact
        // The impact is reduced for meals further in the future (less immediate effect)
        let timeFactor = max(0.5, 1.0 - (hoursUntilMeal / 24.0) * 0.3)  // Reduces impact for meals >8h away
        
        if glycemicLoad > 20 {
            // High glycemic load meal
            let glImpact = min(0.15, (glycemicLoad - 20) / 100.0 * 0.15) * timeFactor
            adjustedHbA1c += glImpact
            updatedFactors["Planned High GL Meal"] = glImpact
        } else if glycemicLoad > 10 {
            // Moderate glycemic load meal
            let glImpact = min(0.05, (glycemicLoad - 10) / 50.0 * 0.05) * timeFactor
            adjustedHbA1c += glImpact
            updatedFactors["Planned Moderate GL Meal"] = glImpact
        }
        // Low GL meals (<10) have minimal impact
        
        // High carb meals (>60g) add additional adjustment
        if plannedMealCarbs > 60 {
            let carbImpact = min(0.1, (plannedMealCarbs - 60) / 100.0 * 0.1) * timeFactor
            adjustedHbA1c += carbImpact
            updatedFactors["Planned High Carb Meal"] = carbImpact
        }
        
        // Ensure bounds
        adjustedHbA1c = max(4.0, min(14.0, adjustedHbA1c))
        
        // Update recommendations based on planned meal
        var updatedRecommendations = currentPrediction.recommendations
        
        if glycemicLoad > 20 {
            updatedRecommendations.insert("This planned meal has a high carb impact. Lower-GI alternatives tend to produce a smaller glucose response.", at: 0)
        }
        
        if plannedMealCarbs > 80 {
            updatedRecommendations.insert("This planned meal is high in carbohydrates. Protein or fiber is sometimes associated with a slower glucose response.", at: 0)
        }
        
        // Determine updated risk category
        let updatedRiskCategory = determineRiskCategory(hbA1c: adjustedHbA1c)
        
        return PredictionResult(
            predictedHbA1c: round(adjustedHbA1c * 10.0) / 10.0,
            confidenceLevel: currentPrediction.confidenceLevel * 0.9,  // Slightly lower confidence for projected values
            riskCategory: updatedRiskCategory,
            contributingFactors: updatedFactors,
            recommendations: updatedRecommendations
        )
    }

    // MARK: - Private Helper Methods

    /// Fetches glucose readings from Core Data for specified number of days
    private func fetchGlucoseReadings(
        from context: NSManagedObjectContext,
        days: Int
    ) -> [Double]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlucoseReadingEntity")

        // Set predicate to fetch readings from last N days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@", cutoffDate as NSDate)

        // Sort by timestamp descending
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject] else {
                return nil
            }

            let glucoseValues = results.compactMap { object -> Double? in
                guard let glucoseValue = object.value(forKey: "value") as? NSNumber else { return nil }
                let unit = object.value(forKey: "unit") as? String ?? "mg/dL"
                // Nathan formula requires mg/dL — convert mmol/L readings before use
                if unit == "mmol/L" {
                    return glucoseValue.doubleValue * 18.0182
                }
                return glucoseValue.doubleValue
            }

            return glucoseValues.isEmpty ? nil : glucoseValues
        } catch {
            #if DEBUG
            print("Error fetching glucose readings: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetches meal entities from Core Data
    private func fetchMeals(
        from context: NSManagedObjectContext,
        days: Int
    ) -> [NSManagedObject]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MealEntity")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@", cutoffDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            return try context.fetch(fetchRequest) as? [NSManagedObject]
        } catch {
            #if DEBUG
            print("Error fetching meals: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetches exercise session entities from Core Data
    private func fetchExerciseSessions(
        from context: NSManagedObjectContext,
        days: Int
    ) -> [NSManagedObject]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ExerciseSessionEntity")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(format: "startDate >= %@", cutoffDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        do {
            return try context.fetch(fetchRequest) as? [NSManagedObject]
        } catch {
            #if DEBUG
            print("Error fetching exercise sessions: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetches user demographic information from Core Data
    /// Combines data from UserDemographicsEntity and HealthConditionEntity
    private func fetchUserDemographics(
        from context: NSManagedObjectContext
    ) -> (age: Int, sex: String, bmi: Double, hasDiabetes: Bool, diabetesType: String?, tobaccoUse: String, alcoholUnitsPerWeek: Double)? {
        let userFetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "UserDemographicsEntity")
        let healthFetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "HealthConditionEntity")

        do {
            // Fetch user demographics
            guard let userResults = try context.fetch(userFetchRequest) as? [NSManagedObject],
                  let user = userResults.first else {
                // Return default values if no user profile exists
                return (age: 40, sex: "Unknown", bmi: 25.0, hasDiabetes: false, diabetesType: nil, tobaccoUse: "Never", alcoholUnitsPerWeek: 0.0)
            }

            let age = (user.value(forKey: "age") as? NSNumber)?.intValue ?? 40
            let sex = (user.value(forKey: "sex") as? String) ?? "Unknown"
            
            // Calculate BMI from height and weight
            let height = (user.value(forKey: "height") as? NSNumber)?.doubleValue ?? 170.0 // cm
            let weight = (user.value(forKey: "weight") as? NSNumber)?.doubleValue ?? 70.0 // kg
            let heightInMeters = height / 100.0
            let bmi = heightInMeters > 0 ? weight / (heightInMeters * heightInMeters) : 25.0
            
            // Get diabetes type from user demographics (if exists there)
            var diabetesType = user.value(forKey: "diabetesType") as? String
            
            // Fetch health conditions for additional data
            var hasDiabetes = false
            var tobaccoUse = "Never"
            var alcoholUnitsPerWeek = 0.0
            
            if let healthResults = try context.fetch(healthFetchRequest) as? [NSManagedObject],
               let health = healthResults.first {
                hasDiabetes = (health.value(forKey: "hasDiabetes") as? NSNumber)?.boolValue ?? false
                if diabetesType == nil {
                    diabetesType = health.value(forKey: "diabetesType") as? String
                }
                tobaccoUse = (health.value(forKey: "tobaccoUse") as? String) ?? "Never"
                alcoholUnitsPerWeek = (health.value(forKey: "alcoholUnitsPerWeek") as? NSNumber)?.doubleValue ?? 0.0
            }

            return (age, sex, bmi, hasDiabetes, diabetesType, tobaccoUse, alcoholUnitsPerWeek)
        } catch {
            #if DEBUG
            print("Error fetching user demographics: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetches health conditions from HealthConditionEntity
    private func fetchHealthConditions(from context: NSManagedObjectContext) -> [String: Bool]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "HealthConditionEntity")

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject],
                  let health = results.first else {
                return [:]
            }

            var conditions: [String: Bool] = [:]

            // Get conditions from the HealthConditionEntity attributes
            if let hasCOPD = (health.value(forKey: "hasCOPD") as? NSNumber)?.boolValue {
                conditions["COPD"] = hasCOPD
            }
            if let hasHeartDisease = (health.value(forKey: "hasHeartDisease") as? NSNumber)?.boolValue {
                conditions["HeartDisease"] = hasHeartDisease
            }
            if let hasDawnEffect = (health.value(forKey: "hasDawnEffect") as? NSNumber)?.boolValue {
                conditions["DawnEffect"] = hasDawnEffect
            }

            return conditions
        } catch {
            #if DEBUG
            print("Error fetching health conditions: \(error.localizedDescription)")
            #endif
            return [:]
        }
    }

    /// Represents a prior HbA1c measurement with its timestamp for time-decay weighting
    struct TimestampedHbA1c {
        let value: Double    // NGSP percentage
        let date: Date
    }

    /// Fetches prior HbA1c measurements from GlucoseReadingEntity
    /// Includes Hospital Lab Test entries alongside Manual Finger Stick and FreeStyle Libre
    /// Only returns readings within the last 12 weeks (older readings are excluded)
    /// Returns up to 10 most recent readings converted to NGSP percentage with timestamps
    private func fetchPriorHbA1cReadings(
        from context: NSManagedObjectContext,
        maxReadings: Int = 10
    ) -> [TimestampedHbA1c]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlucoseReadingEntity")

        // Filter for HbA1c measurements (unit is NGSP % or mmol/mol)
        // and valid sources (Manual Finger Stick, CGM, or Hospital Lab Test)
        let unitPredicate = NSPredicate(format: "unit IN %@", ["NGSP %", "mmol/mol"])
        let sourcePredicate = NSPredicate(format: "source IN %@",
            ["Manual Finger Stick", "Continuous Glucose Monitor", "FreeStyle Libre 2", "Hospital Lab Test"])

        // Only include readings from the last 12 weeks
        let twelveWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? Date()
        let datePredicate = NSPredicate(format: "timestamp >= %@", twelveWeeksAgo as NSDate)

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            unitPredicate, sourcePredicate, datePredicate
        ])

        // Sort by timestamp descending to get most recent first
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = maxReadings

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject] else {
                return nil
            }

            let hba1cReadings = results.compactMap { object -> TimestampedHbA1c? in
                guard let value = object.value(forKey: "value") as? NSNumber,
                      let unit = object.value(forKey: "unit") as? String,
                      let timestamp = object.value(forKey: "timestamp") as? Date else {
                    return nil
                }
                // Convert to NGSP percentage if stored as IFCC mmol/mol
                let ngspValue: Double
                if unit == "mmol/mol" {
                    ngspValue = ifccToNGSP(value.doubleValue)
                } else if unit == "NGSP %" {
                    ngspValue = value.doubleValue
                } else {
                    return nil
                }
                return TimestampedHbA1c(value: ngspValue, date: timestamp)
            }

            return hba1cReadings.isEmpty ? nil : hba1cReadings
        } catch {
            #if DEBUG
            print("Error fetching prior HbA1c readings: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Blends formula-based prediction with prior HbA1c measurements using time-decay weighting
    ///
    /// Time-decay schedule:
    ///   - 0–4 weeks old:  weight = 1.0 (full impact)
    ///   - 4–12 weeks old: weight decays linearly from 1.0 → 0.2
    ///   - > 12 weeks old: excluded (not fetched)
    ///
    /// Minimum 1 reading required for blending (was 2 with old index-based approach).
    /// Returns blended HbA1c in NGSP %
    private func blendWithPriorHbA1c(
        formulaPrediction: Double,
        priorReadings: [TimestampedHbA1c]
    ) -> Double {
        guard !priorReadings.isEmpty else {
            return formulaPrediction
        }

        let now = Date()

        // Calculate time-decayed weighted average
        var weightedSum = 0.0
        var totalWeight = 0.0

        for reading in priorReadings {
            let ageInWeeks = now.timeIntervalSince(reading.date) / (7.0 * 24.0 * 3600.0)

            let weight: Double
            if ageInWeeks <= 4.0 {
                // Full weight for readings within 4 weeks
                weight = 1.0
            } else if ageInWeeks <= 12.0 {
                // Linear decay from 1.0 at 4 weeks to 0.2 at 12 weeks
                weight = 1.0 - (ageInWeeks - 4.0) * (0.8 / 8.0)
            } else {
                // Should not reach here (filtered out by fetch), but safety net
                weight = 0.0
            }

            if weight > 0 {
                weightedSum += reading.value * weight
                totalWeight += weight
            }
        }

        guard totalWeight > 0 else {
            return formulaPrediction
        }

        let priorAverage = weightedSum / totalWeight

        // Blend ratio depends on how many valid readings we have
        // 1 reading:  50% formula + 50% prior (less confidence in single measurement)
        // 2+ readings: 30% formula + 70% prior (strong confidence in repeated measurements)
        let priorWeight = priorReadings.count >= 2 ? 0.7 : 0.5
        let formulaWeight = 1.0 - priorWeight

        let blendedValue = (formulaPrediction * formulaWeight) + (priorAverage * priorWeight)
        return blendedValue
    }

    /// Calculates coefficient of variation from glucose readings
    /// CV = (standard deviation / mean) * 100
    private func calculateCoefficientOfVariation(_ readings: [Double]) -> Double {
        guard readings.count > 1 else { return 0 }

        let mean = readings.reduce(0, +) / Double(readings.count)
        let variance = readings.reduce(0) { $0 + pow($1 - mean, 2) } / Double(readings.count)
        let standardDeviation = sqrt(variance)

        let cv = (standardDeviation / mean) * 100
        return cv
    }

    // MARK: - Dawn Effect Support

    /// Represents a glucose reading with its timestamp for time-of-day analysis
    struct TimestampedGlucoseReading {
        let value: Double    // mg/dL
        let timestamp: Date
    }

    /// Fetches glucose readings with timestamps from Core Data for dawn effect analysis
    private func fetchGlucoseReadingsWithTimestamps(
        from context: NSManagedObjectContext,
        days: Int
    ) -> [TimestampedGlucoseReading]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlucoseReadingEntity")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND (unit == %@ OR unit == %@)", cutoffDate as NSDate, "mg/dL", "mmol/L")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject] else {
                return nil
            }

            let readings = results.compactMap { object -> TimestampedGlucoseReading? in
                guard let glucoseValue = object.value(forKey: "value") as? NSNumber,
                      let timestamp = object.value(forKey: "timestamp") as? Date else { return nil }
                let unit = object.value(forKey: "unit") as? String ?? "mg/dL"
                // Exclude HbA1c lab test entries — only glucose readings
                let source = object.value(forKey: "source") as? String ?? ""
                if source == "Hospital Lab Test" { return nil }

                let mgdlValue: Double
                if unit == "mmol/L" {
                    mgdlValue = glucoseValue.doubleValue * 18.0182
                } else {
                    mgdlValue = glucoseValue.doubleValue
                }
                return TimestampedGlucoseReading(value: mgdlValue, timestamp: timestamp)
            }

            return readings.isEmpty ? nil : readings
        } catch {
            #if DEBUG
            print("Error fetching timestamped glucose readings: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Calculates time-weighted average glucose with dawn effect compensation.
    /// Divides the day into 5 windows and down-weights the dawn window (04:00–08:00)
    /// to reduce the impact of liver-driven morning glucose spikes.
    ///
    /// Time windows:
    ///   - Dawn:      04:00–08:00  (weight: 0.6 when dawn effect active)
    ///   - Morning:   08:00–12:00  (weight: 1.0)
    ///   - Afternoon:  12:00–18:00 (weight: 1.0)
    ///   - Evening:   18:00–22:00  (weight: 1.0)
    ///   - Night:     22:00–04:00  (weight: 1.0)
    ///
    /// The 0.6 dawn weight is a calibration starting point. It reduces the dawn spike's
    /// contribution by ~40%, reflecting that transient liver-driven glucose elevation
    /// contributes less to actual glycation than sustained post-meal elevations.
    private static let dawnWeightFactor: Double = 0.6

    func calculateDawnAdjustedAverage(_ readings: [TimestampedGlucoseReading]) -> Double {
        guard !readings.isEmpty else { return 0 }

        let calendar = Calendar.current

        // Group readings into time windows by hour
        var dawnReadings: [Double] = []      // 04:00–08:00
        var morningReadings: [Double] = []   // 08:00–12:00
        var afternoonReadings: [Double] = [] // 12:00–18:00
        var eveningReadings: [Double] = []   // 18:00–22:00
        var nightReadings: [Double] = []     // 22:00–04:00

        for reading in readings {
            let hour = calendar.component(.hour, from: reading.timestamp)
            switch hour {
            case 4..<8:
                dawnReadings.append(reading.value)
            case 8..<12:
                morningReadings.append(reading.value)
            case 12..<18:
                afternoonReadings.append(reading.value)
            case 18..<22:
                eveningReadings.append(reading.value)
            default: // 22-23 and 0-3
                nightReadings.append(reading.value)
            }
        }

        // Calculate average for each window that has data
        var weightedSum = 0.0
        var totalWeight = 0.0

        let windows: [(readings: [Double], weight: Double)] = [
            (dawnReadings, Self.dawnWeightFactor),
            (morningReadings, 1.0),
            (afternoonReadings, 1.0),
            (eveningReadings, 1.0),
            (nightReadings, 1.0)
        ]

        for window in windows {
            if !window.readings.isEmpty {
                let windowAvg = window.readings.reduce(0, +) / Double(window.readings.count)
                weightedSum += windowAvg * window.weight
                totalWeight += window.weight
            }
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    /// Detects dawn effect pattern from glucose readings and meal data.
    ///
    /// For CGM-like data (many readings): looks for 5+ days out of last 14 where
    /// morning peak (04:00–08:00) exceeds night baseline (00:00–03:00) by 30+ mg/dL
    /// with no meal logged in the preceding 4 hours.
    ///
    /// For finger stick data (fewer readings): looks for 3+ fasting morning readings
    /// above 130 mg/dL in the last 30 days with no meal for 10+ hours prior.
    ///
    /// Returns true if dawn effect pattern is detected.
    func detectDawnEffect(
        readings: [TimestampedGlucoseReading],
        meals: [NSManagedObject]
    ) -> Bool {
        let calendar = Calendar.current

        // Determine if this looks like CGM data (many readings per day) or finger stick
        let last14Days = readings.filter {
            guard let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) else { return false }
            return $0.timestamp >= cutoff
        }

        let uniqueDays = Set(last14Days.map { calendar.startOfDay(for: $0.timestamp) })
        let readingsPerDay = uniqueDays.count > 0 ? Double(last14Days.count) / Double(uniqueDays.count) : 0

        if readingsPerDay >= 10 {
            // CGM-like detection: many readings per day
            return detectDawnEffectCGM(readings: last14Days, meals: meals, calendar: calendar)
        } else {
            // Finger stick detection: fewer readings
            let last30Days = readings.filter {
                guard let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) else { return false }
                return $0.timestamp >= cutoff
            }
            return detectDawnEffectFingerStick(readings: last30Days, meals: meals, calendar: calendar)
        }
    }

    /// CGM detection: looks for rising glucose pattern 04:00–08:00 vs 00:00–03:00 baseline
    private func detectDawnEffectCGM(
        readings: [TimestampedGlucoseReading],
        meals: [NSManagedObject],
        calendar: Calendar
    ) -> Bool {
        // Group readings by day
        var dayGroups: [Date: [TimestampedGlucoseReading]] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.timestamp)
            dayGroups[day, default: []].append(reading)
        }

        var dawnDayCount = 0

        for (day, dayReadings) in dayGroups {
            // Night baseline: 00:00–03:00
            let nightBaseline = dayReadings
                .filter { calendar.component(.hour, from: $0.timestamp) < 4 }
                .map { $0.value }

            // Morning peak: 04:00–08:00
            let morningReadings = dayReadings
                .filter {
                    let hour = calendar.component(.hour, from: $0.timestamp)
                    return hour >= 4 && hour < 8
                }
                .map { $0.value }

            guard !nightBaseline.isEmpty, !morningReadings.isEmpty else { continue }

            let nightAvg = nightBaseline.reduce(0, +) / Double(nightBaseline.count)
            let morningPeak = morningReadings.max() ?? 0

            // Check no meal logged between 00:00–08:00 for this day
            let dayStart = day
            let morningEnd = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day

            let hasMealBefore = meals.contains { meal in
                guard let mealTime = meal.value(forKey: "timestamp") as? Date else { return false }
                return mealTime >= dayStart && mealTime < morningEnd
            }

            if morningPeak - nightAvg > 30 && !hasMealBefore {
                dawnDayCount += 1
            }
        }

        // Dawn effect detected if pattern appears 5+ days out of last 14
        return dawnDayCount >= 5
    }

    /// Finger stick detection: looks for high fasting morning readings
    private func detectDawnEffectFingerStick(
        readings: [TimestampedGlucoseReading],
        meals: [NSManagedObject],
        calendar: Calendar
    ) -> Bool {
        var suspectDawnCount = 0

        // Filter to morning readings before 9am
        let morningReadings = readings.filter {
            calendar.component(.hour, from: $0.timestamp) < 9
        }

        for reading in morningReadings {
            guard reading.value > 130 else { continue }

            // Find most recent meal before this reading
            let lastMealBefore = meals
                .compactMap { meal -> Date? in
                    guard let mealTime = meal.value(forKey: "timestamp") as? Date,
                          mealTime < reading.timestamp else { return nil }
                    return mealTime
                }
                .max()

            let hoursSinceMeal: Double
            if let lastMeal = lastMealBefore {
                hoursSinceMeal = reading.timestamp.timeIntervalSince(lastMeal) / 3600.0
            } else {
                hoursSinceMeal = 24 // No meal found — assume long fast
            }

            if hoursSinceMeal > 10 {
                suspectDawnCount += 1
            }
        }

        // Dawn effect suspected if 3+ qualifying readings in last 30 days
        return suspectDawnCount >= 3
    }

    /// Calculates daily carbohydrate and calorie intake from meals
    private func calculateDailyNutrition(_ meals: [NSManagedObject]) -> (carbs: Double, calories: Double) {
        guard !meals.isEmpty else { return (0, 0) }

        var totalCarbs: Double = 0
        var totalCalories: Double = 0
        
        for meal in meals {
            // Get calories directly from meal
            if let calories = (meal.value(forKey: "calories") as? NSNumber)?.doubleValue {
                totalCalories += calories
            }
            
            // Get carbs from macronutrients relationship
            if let macronutrients = meal.value(forKey: "macronutrients") as? Set<NSManagedObject> {
                for macro in macronutrients {
                    let macroType = macro.value(forKey: "type") as? String ?? ""
                    if macroType == "carbohydrates" || macroType == "carbs" {
                        if let amount = (macro.value(forKey: "amount") as? NSNumber)?.doubleValue {
                            totalCarbs += amount
                        }
                    }
                }
            }
        }

        // Calculate daily average if we have multiple days of data
        let daysOfData = Set(meals.compactMap { meal -> String? in
            guard let timestamp = meal.value(forKey: "timestamp") as? Date else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: timestamp)
        }).count

        let dailyCarbsAverage = daysOfData > 0 ? totalCarbs / Double(daysOfData) : totalCarbs
        let dailyCaloriesAverage = daysOfData > 0 ? totalCalories / Double(daysOfData) : totalCalories

        return (dailyCarbsAverage, dailyCaloriesAverage)
    }

    /// Calculates weekly exercise minutes and average intensity
    private func calculateExerciseMetrics(_ sessions: [NSManagedObject]) -> (weeklyMinutes: Double, avgIntensity: Double) {
        guard !sessions.isEmpty else { return (0, 0) }

        let totalMinutes = sessions.reduce(0) { $0 + (($1.value(forKey: "duration") as? NSNumber)?.doubleValue ?? 0) }
        let totalIntensity = sessions.reduce(0) { $0 + (($1.value(forKey: "intensity") as? NSNumber)?.doubleValue ?? 5) }
        let avgIntensity = totalIntensity / Double(sessions.count)

        // Calculate weekly average if data spans multiple weeks
        let weeksOfData = max(1, Int(sessions.count) / 7)
        let weeklyMinutes = totalMinutes / Double(weeksOfData)

        return (weeklyMinutes, avgIntensity)
    }

    /// Calculates cardio vs non-cardio exercise split from 7-day session data
    /// Cardio (Walking/Running/Cycling): returns distance + calories
    /// Non-cardio (all others): returns duration + average intensity
    private func calculateExerciseSplit(_ sessions: [NSManagedObject]) -> (cardioDistanceKm: Double, cardioCalories: Double, nonCardioMinutes: Double, nonCardioIntensityAvg: Double) {
        guard !sessions.isEmpty else { return (0, 0, 0, 0) }

        let cardioTypes: Set<String> = ["Walking", "Running", "Cycling"]
        var cardioDistance = 0.0
        var cardioCalories = 0.0
        var nonCardioMinutes = 0.0
        var nonCardioIntensitySum = 0.0
        var nonCardioCount = 0

        for session in sessions {
            let type = (session.value(forKey: "type") as? String) ?? ""
            if cardioTypes.contains(type) {
                cardioDistance += (session.value(forKey: "distance") as? NSNumber)?.doubleValue ?? 0
                cardioCalories += (session.value(forKey: "caloriesBurned") as? NSNumber)?.doubleValue ?? 0
            } else {
                nonCardioMinutes += (session.value(forKey: "duration") as? NSNumber)?.doubleValue ?? 0
                nonCardioIntensitySum += (session.value(forKey: "intensity") as? NSNumber)?.doubleValue ?? 5
                nonCardioCount += 1
            }
        }

        let nonCardioIntensityAvg = nonCardioCount > 0 ? nonCardioIntensitySum / Double(nonCardioCount) : 0
        return (cardioDistance, cardioCalories, nonCardioMinutes, nonCardioIntensityAvg)
    }

    /// Calculates time since last meal in hours
    private func calculateTimeSinceLastMeal(_ meals: [NSManagedObject]) -> Double {
        guard let lastMeal = meals.first,
              let timestamp = lastMeal.value(forKey: "timestamp") as? Date else {
            return 12.0  // Default to 12 hours if no meals found
        }

        let hoursSinceLastMeal = Date().timeIntervalSince(timestamp) / 3600.0
        return hoursSinceLastMeal
    }

    /// Calculates confidence level based on data characteristics
    /// Higher confidence with stable glucose readings and more data points
    private func calculateConfidence(glucoseVariability: Double) -> Double {
        // Base confidence starts at 0.6
        var confidence = 0.6

        // Stable glucose increases confidence (lower CV is better)
        if glucoseVariability < 20.0 {
            confidence += 0.3  // Very stable
        } else if glucoseVariability < 36.0 {
            confidence += 0.2  // Moderately stable
        } else if glucoseVariability < 50.0 {
            confidence += 0.1  // Some variability
        }

        // Cap confidence at 1.0
        return min(1.0, confidence)
    }

    /// Determines range category based on HbA1c value
    /// Uses ADA-referenced thresholds for informational classification
    /// NOTE: Labels are deliberately non-diagnostic to comply with Apple Guideline 5.1.1(ix)
    private func determineRiskCategory(hbA1c: Double) -> String {
        if hbA1c < 5.7 {
            return "Normal Range"
        } else if hbA1c < 6.5 {
            return "Above Typical Range"
        } else if hbA1c <= 7.0 {
            return "Moderately Elevated"
        } else if hbA1c <= 8.0 {
            return "Elevated"
        } else {
            return "Significantly Elevated"
        }
    }

    /// Generates wellness observations based on estimate results and contributing factors
    private func generateRecommendations(
        input: PredictionInput,
        predictedHbA1c: Double,
        riskCategory: String,
        contributingFactors: [String: Double]
    ) -> [String] {
        var recommendations: [String] = []

        // Category-based wellness observations
        // NOTE: All observations use educational, non-directive language. This is a
        // wellness app — not a diagnostic tool (Apple Guideline 5.1.1(ix)).
        if riskCategory == "Significantly Elevated" {
            recommendations.append("This wellness estimate is in a higher range. You may find it interesting to share these trends with your healthcare provider.")
            recommendations.append("Continuous glucose monitoring (CGM) is one way some people observe patterns at this level.")
            recommendations.append("People in this range often have regular lab work, including metabolic panels and kidney function tests.")
        } else if riskCategory == "Elevated" {
            recommendations.append("This wellness estimate is above typical levels. Sharing these trends with your healthcare provider may be interesting.")
            recommendations.append("More frequent blood glucose checks can help reveal patterns and trends.")
        } else if riskCategory == "Above Typical Range" {
            recommendations.append("Research suggests lifestyle factors can be associated with changes in this range.")
            recommendations.append("Studies show that modest weight changes may be associated with different glucose levels.")
        }

        // Factor-specific recommendations
        if contributingFactors["Glucose Variability"] ?? 0 > 0.1 {
            recommendations.append("Glucose variability is a factor here. Some people observe more stable levels with consistent meal timing.")
            recommendations.append("Tracking which foods are associated with glucose changes can provide useful insights.")
        }

        if contributingFactors["High Carb Intake"] ?? 0 > 0.05 {
            recommendations.append("Current carbohydrate intake appears high. Research associates lower daily carbohydrate intake with different glucose patterns.")
            recommendations.append("Low glycemic index foods (whole grains, vegetables) tend to be associated with smaller glucose responses.")
        }

        if (contributingFactors["Exercise Benefits"] ?? 0) == 0 && input.weeklyExerciseMinutes < 150 {
            recommendations.append("The ADA notes that 150 minutes of aerobic exercise per week is associated with better glucose levels in research studies.")
            recommendations.append("Research also associates resistance training 2\u{2013}3 times per week with improved metabolic markers.")
        }

        if input.bmi >= 30.0 {
            recommendations.append("BMI is in a range that research associates with higher glucose levels. Your healthcare provider can offer personalised context.")
        } else if input.bmi >= 25.0 {
            recommendations.append("BMI is slightly above the typical range. Research associates weight with metabolic health markers.")
        }

        if input.hasCOPD {
            recommendations.append("COPD is associated with systemic inflammation, which research links to glucose levels.")
        }

        if input.hasHeartDisease {
            recommendations.append("Research shows heart disease and glucose levels are closely linked.")
        }

        if input.tobaccoUse == "Current" {
            recommendations.append("Research shows a strong link between smoking and glucose metabolism.")
        } else if input.tobaccoUse == "Former" {
            recommendations.append("Continued tobacco abstinence supports better long-term metabolic health.")
        }

        if input.alcoholUnitsPerWeek > 14.0 {
            recommendations.append("Current alcohol intake is above levels that research typically associates with stable glucose patterns.")
        }

        // General informational guidance
        if recommendations.count < 5 {
            recommendations.append("Regular health check-ups (typically every 3 months) help track trends over time.")
            recommendations.append("Periodic HbA1c monitoring can provide a useful longer-term picture of glucose levels.")
            recommendations.append("Research associates consistent routines around diet and exercise with more stable glucose patterns.")
        }

        return recommendations
    }

    /// Saves prediction result to Core Data as HbA1cPredictionEntity
    /// Values are stored in IFCC (mmol/mol) format for international standardization
    private func savePredictionResult(_ result: PredictionResult, to context: NSManagedObjectContext) {
        let predictionEntity = NSEntityDescription.insertNewObject(
            forEntityName: "HbA1cPredictionEntity",
            into: context
        )

        // Convert NGSP (%) to IFCC (mmol/mol) for canonical storage
        let ifccValue = ngspToIFCC(result.predictedHbA1c)
        
        predictionEntity.setValue(UUID(), forKey: "id")
        predictionEntity.setValue(ifccValue, forKey: "predictedValue")
        predictionEntity.setValue(result.confidenceLevel, forKey: "confidenceLevel")
        predictionEntity.setValue(Date(), forKey: "predictionDate")
        predictionEntity.setValue(modelVersion, forKey: "modelVersion")

        // Save contributing factors as JSON data
        if let factorsJSON = try? JSONSerialization.data(
            withJSONObject: result.contributingFactors,
            options: []
        ) {
            predictionEntity.setValue(factorsJSON, forKey: "contributingFactorsJSON")
        }
    }
}
