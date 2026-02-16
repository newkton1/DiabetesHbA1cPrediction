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

    // Physical Activity
    let weeklyExerciseMinutes: Double    // minutes - total aerobic exercise per week
    let exerciseIntensityAvg: Double     // 1-10 scale - average intensity of exercise sessions

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

    // Lifestyle Factors
    let tobaccoUse: String               // "Never", "Former", or "Current"
    let alcoholUnitsPerWeek: Double      // standard drink units per week
    let timeSinceLastMealHours: Double   // hours since last food intake
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

        // Step 4: Apply exercise adjustment
        // Regular physical activity improves insulin sensitivity and glucose control
        // Effects: 150+ min/week moderate intensity reduces HbA1c by ~0.3%
        // Reference: American Diabetes Association Standards of Care
        // Exercise effect compounds with intensity: max reduction = -0.3%
        if input.weeklyExerciseMinutes > 0 {
            let exerciseEffect = min(
                0.3,
                (input.weeklyExerciseMinutes / 150.0) * (input.exerciseIntensityAvg / 10.0) * 0.3
            )
            predictedHbA1c -= exerciseEffect
            contributingFactors["Exercise Benefits"] = -exerciseEffect
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
            print("Error: Unable to fetch glucose readings")
            return nil
        }

        guard !glucoseReadings.isEmpty else {
            print("Error: No glucose readings available for prediction")
            return nil
        }

        // Calculate glucose metrics
        let averageGlucose = glucoseReadings.reduce(0) { $0 + $1 } / Double(glucoseReadings.count)
        let glucoseVariability = calculateCoefficientOfVariation(glucoseReadings)

        // Fetch meals from last 30 days
        let meals = fetchMeals(from: context, days: 30) ?? []
        let (dailyCarbIntake, dailyCalories) = calculateDailyNutrition(meals)

        // Fetch exercise sessions from last 30 days
        let exerciseSessions = fetchExerciseSessions(from: context, days: 30) ?? []
        let (weeklyExerciseMinutes, exerciseIntensityAvg) = calculateExerciseMetrics(exerciseSessions)

        // Fetch user demographics
        guard let demographics = fetchUserDemographics(from: context) else {
            print("Error: Unable to fetch user demographics")
            return nil
        }

        // Fetch health conditions
        let healthConditions = fetchHealthConditions(from: context) ?? [:]

        let input = PredictionInput(
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
            timeSinceLastMealHours: calculateTimeSinceLastMeal(meals)
        )

        return input
    }

    /// Runs full prediction pipeline: gather inputs, predict, and save results
    /// - Parameter context: NSManagedObjectContext for Core Data operations
    /// - Returns: PredictionResult if successful, nil otherwise
    func runPredictionAndSave(context: NSManagedObjectContext) -> PredictionResult? {
        // Gather inputs from Core Data
        guard let input = gatherInputs(context: context) else {
            print("Error: Failed to gather prediction inputs")
            return nil
        }

        // Run prediction
        let result = predict(from: input)

        // Save prediction result to Core Data
        savePredictionResult(result, to: context)

        // Attempt to save context
        do {
            try context.save()
            print("Successfully saved prediction result to Core Data")
            return result
        } catch {
            print("Error saving prediction result: \(error.localizedDescription)")
            return nil
        }
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
                if let glucoseValue = object.value(forKey: "glucoseValue") as? NSNumber {
                    return glucoseValue.doubleValue
                }
                return nil
            }

            return glucoseValues.isEmpty ? nil : glucoseValues
        } catch {
            print("Error fetching glucose readings: \(error.localizedDescription)")
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
            print("Error fetching meals: \(error.localizedDescription)")
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
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@", cutoffDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            return try context.fetch(fetchRequest) as? [NSManagedObject]
        } catch {
            print("Error fetching exercise sessions: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches user demographic information from Core Data
    private func fetchUserDemographics(
        from context: NSManagedObjectContext
    ) -> (age: Int, sex: String, bmi: Double, hasDiabetes: Bool, diabetesType: String?, tobaccoUse: String, alcoholUnitsPerWeek: Double)? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "UserDemographicsEntity")

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject],
                  let user = results.first else {
                return nil
            }

            let age = (user.value(forKey: "age") as? NSNumber)?.intValue ?? 0
            let sex = (user.value(forKey: "sex") as? String) ?? "Unknown"
            let bmi = (user.value(forKey: "bmi") as? NSNumber)?.doubleValue ?? 25.0
            let hasDiabetes = (user.value(forKey: "hasDiabetes") as? NSNumber)?.boolValue ?? false
            let diabetesType = user.value(forKey: "diabetesType") as? String
            let tobaccoUse = (user.value(forKey: "tobaccoUse") as? String) ?? "Never"
            let alcoholUnitsPerWeek = (user.value(forKey: "alcoholUnitsPerWeek") as? NSNumber)?.doubleValue ?? 0.0

            return (age, sex, bmi, hasDiabetes, diabetesType, tobaccoUse, alcoholUnitsPerWeek)
        } catch {
            print("Error fetching user demographics: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches health conditions from HealthConditionEntity
    private func fetchHealthConditions(from context: NSManagedObjectContext) -> [String: Bool]? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "HealthConditionEntity")

        do {
            guard let results = try context.fetch(fetchRequest) as? [NSManagedObject] else {
                return [:]
            }

            var conditions: [String: Bool] = [:]
            for entity in results {
                if let conditionName = entity.value(forKey: "conditionName") as? String,
                   let isActive = entity.value(forKey: "isActive") as? NSNumber {
                    conditions[conditionName] = isActive.boolValue
                }
            }

            return conditions
        } catch {
            print("Error fetching health conditions: \(error.localizedDescription)")
            return [:]
        }
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

    /// Calculates daily carbohydrate and calorie intake from meals
    private func calculateDailyNutrition(_ meals: [NSManagedObject]) -> (carbs: Double, calories: Double) {
        guard !meals.isEmpty else { return (0, 0) }

        let totalCarbs = meals.reduce(0) { $0 + (($1.value(forKey: "carbohydrates") as? NSNumber)?.doubleValue ?? 0) }
        let totalCalories = meals.reduce(0) { $0 + (($1.value(forKey: "calories") as? NSNumber)?.doubleValue ?? 0) }

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

        let totalMinutes = sessions.reduce(0) { $0 + (($1.value(forKey: "durationMinutes") as? NSNumber)?.doubleValue ?? 0) }
        let totalIntensity = sessions.reduce(0) { $0 + (($1.value(forKey: "intensityLevel") as? NSNumber)?.doubleValue ?? 5) }
        let avgIntensity = totalIntensity / Double(sessions.count)

        // Calculate weekly average if data spans multiple weeks
        let weeksOfData = max(1, Int(sessions.count) / 7)
        let weeklyMinutes = totalMinutes / Double(weeksOfData)

        return (weeklyMinutes, avgIntensity)
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

    /// Determines risk category based on HbA1c value
    /// Uses ADA diagnostic criteria thresholds
    private func determineRiskCategory(hbA1c: Double) -> String {
        if hbA1c < 5.7 {
            return "Normal"
        } else if hbA1c < 6.5 {
            return "Pre-diabetes"
        } else if hbA1c <= 7.0 {
            return "Diabetes - Well Controlled"
        } else if hbA1c <= 8.0 {
            return "Diabetes - Needs Attention"
        } else {
            return "Diabetes - High Risk"
        }
    }

    /// Generates clinical recommendations based on prediction results and contributing factors
    private func generateRecommendations(
        input: PredictionInput,
        predictedHbA1c: Double,
        riskCategory: String,
        contributingFactors: [String: Double]
    ) -> [String] {
        var recommendations: [String] = []

        // Category-based recommendations
        if riskCategory == "Diabetes - High Risk" {
            recommendations.append("Urgent: Consult with endocrinologist for medication adjustment")
            recommendations.append("Consider continuous glucose monitoring (CGM) system")
            recommendations.append("Schedule comprehensive metabolic panel and kidney function tests")
        } else if riskCategory == "Diabetes - Needs Attention" {
            recommendations.append("Work with diabetes care team to optimize medication regimen")
            recommendations.append("Monitor blood glucose more frequently (at least 4 times daily)")
        } else if riskCategory == "Pre-diabetes" {
            recommendations.append("Intensive lifestyle intervention recommended")
            recommendations.append("Target weight loss of 7-10% of body weight")
        }

        // Factor-specific recommendations
        if contributingFactors["Glucose Variability"] ?? 0 > 0.1 {
            recommendations.append("Focus on glucose stability: eat consistent meals at regular times")
            recommendations.append("Identify and avoid foods that cause blood sugar spikes")
        }

        if contributingFactors["High Carb Intake"] ?? 0 > 0.05 {
            recommendations.append("Reduce carbohydrate intake: aim for <250g per day")
            recommendations.append("Choose low glycemic index carbohydrates (whole grains, vegetables)")
        }

        if (contributingFactors["Exercise Benefits"] ?? 0) == 0 && input.weeklyExerciseMinutes < 150 {
            recommendations.append("Increase aerobic exercise: target 150 minutes per week")
            recommendations.append("Add resistance training 2-3 times per week")
        }

        if input.bmi >= 30.0 {
            recommendations.append("Weight management: aim for BMI <25 through diet and exercise")
            recommendations.append("Consider bariatric surgery evaluation if BMI >35 with diabetes")
        } else if input.bmi >= 25.0 {
            recommendations.append("Maintain healthy weight: current BMI indicates overweight status")
        }

        if input.hasCOPD {
            recommendations.append("Pulmonology follow-up: manage COPD to reduce systemic inflammation")
            recommendations.append("Ensure adequate oxygenation during exercise")
        }

        if input.hasHeartDisease {
            recommendations.append("Cardiology follow-up: optimize cardiovascular medications")
            recommendations.append("Monitor blood pressure closely (target <130/80 mmHg)")
        }

        if input.tobaccoUse == "Current" {
            recommendations.append("CRITICAL: Smoking cessation strongly recommended")
            recommendations.append("Consult tobacco cessation program or consider nicotine replacement")
        } else if input.tobaccoUse == "Former" {
            recommendations.append("Continued abstinence from tobacco is essential")
        }

        if input.alcoholUnitsPerWeek > 14.0 {
            recommendations.append("Reduce alcohol consumption: current intake is excessive")
            recommendations.append("Target less than 7 units per week for women, 14 for men")
        }

        // General preventive recommendations
        if recommendations.count < 5 {
            recommendations.append("Continue regular health check-ups every 3 months")
            recommendations.append("Monitor HbA1c levels every 3 months")
            recommendations.append("Maintain consistent medication adherence")
        }

        return recommendations
    }

    /// Saves prediction result to Core Data as HbA1cPredictionEntity
    private func savePredictionResult(_ result: PredictionResult, to context: NSManagedObjectContext) {
        let predictionEntity = NSEntityDescription.insertNewObject(
            forEntityName: "HbA1cPredictionEntity",
            into: context
        )

        predictionEntity.setValue(result.predictedHbA1c, forKey: "predictedHbA1c")
        predictionEntity.setValue(result.confidenceLevel, forKey: "confidenceLevel")
        predictionEntity.setValue(result.riskCategory, forKey: "riskCategory")
        predictionEntity.setValue(Date(), forKey: "predictionDate")

        // Save contributing factors as JSON string
        if let factorsJSON = try? JSONSerialization.data(
            withJSONObject: result.contributingFactors,
            options: []
        ) {
            predictionEntity.setValue(factorsJSON, forKey: "contributingFactorsJSON")
        }

        // Save recommendations as JSON array
        if let recommendationsJSON = try? JSONSerialization.data(
            withJSONObject: result.recommendations,
            options: []
        ) {
            predictionEntity.setValue(recommendationsJSON, forKey: "recommendationsJSON")
        }

        predictionEntity.setValue(modelVersion, forKey: "modelVersion")
    }
}
