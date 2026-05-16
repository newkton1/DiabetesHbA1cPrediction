import SwiftUI
import CoreData

/// View for exporting all Core Data as JSON.
/// Useful for backup, device migration, and validation testing.
struct DataExportView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: true)]
    ) private var glucoseReadings: FetchedResults<GlucoseReadingEntity>

    @FetchRequest(
        entity: MealEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: true)]
    ) private var meals: FetchedResults<MealEntity>

    @FetchRequest(
        entity: ExerciseSessionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: true)]
    ) private var exercises: FetchedResults<ExerciseSessionEntity>

    @FetchRequest(
        entity: GmiEstimateEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GmiEstimateEntity.predictionDate, ascending: true)]
    ) private var predictions: FetchedResults<GmiEstimateEntity>

    @FetchRequest(
        entity: UserDemographicsEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \UserDemographicsEntity.lastUpdated, ascending: false)]
    ) private var userProfiles: FetchedResults<UserDemographicsEntity>

    @FetchRequest(
        entity: HealthConditionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \HealthConditionEntity.lastUpdated, ascending: false)]
    ) private var healthConditions: FetchedResults<HealthConditionEntity>

    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var exportSummary = ""
    #if DEBUG
    @State private var seedSummary = ""
    @State private var showSeedConfirm = false
    #endif

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var body: some View {
        List {
            Section(header: Text("Data Summary")) {
                SummaryRow(label: "Glucose Readings", count: glucoseReadings.count)
                SummaryRow(label: "Meals", count: meals.count)
                SummaryRow(label: "Exercise Sessions", count: exercises.count)
                SummaryRow(label: "GMI Estimates", count: predictions.count)
                SummaryRow(label: "User Profiles", count: userProfiles.count)
                SummaryRow(label: "Health Conditions", count: healthConditions.count)
            }

            Section(header: Text("Export")) {
                Button(action: exportAllData) {
                    Label("Export All Data as JSON", systemImage: "square.and.arrow.up")
                }

                if !exportSummary.isEmpty {
                    Text(exportSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            #if DEBUG
            Section(header: Text("Seed Demo Data")) {
                Button(action: { showSeedConfirm = true }) {
                    Label("Seed 12 Weeks of Demo Data", systemImage: "wand.and.stars")
                }

                if !seedSummary.isEmpty {
                    Text(seedSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Adds 10 lab HbA1c results, ~110 CGM/meter readings, 30 meals, and 20 exercise sessions spanning the last 12 weeks. Safe on top of existing data but will add duplicates if tapped twice.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .alert("Seed demo data?", isPresented: $showSeedConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Seed") { seedDemoData() }
            } message: {
                Text("This adds 12 weeks of sample data for simulator testing. It does not delete anything, but repeated taps will create duplicates.")
            }
            #endif

            Section(header: Text("Info")) {
                Text("Exports all app data as a single JSON file suitable for validation evidence or Apple Review submission. No data leaves the device until you choose where to share it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            // Present the share sheet from outside the List to avoid
            // SwiftUI presentation conflicts with List/NavigationLink.
            EmptyView()
                .sheet(isPresented: $showShareSheet) {
                    if let url = exportURL {
                        ShareSheet(activityItems: [url])
                    }
                }
        )
    }

    // MARK: - Export Logic

    private func exportAllData() {
        let export: [String: Any] = [
            "exportDate": iso8601.string(from: Date()),
            "appVersion": "1.0",
            "userProfile": exportUserProfiles(),
            "healthConditions": exportHealthConditions(),
            "glucoseReadings": exportGlucoseReadings(),
            "meals": exportMeals(),
            "exerciseSessions": exportExercises(),
            "hba1cPredictions": exportPredictions()
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
            let filename = "DiabetesFeast_Export_\(dateFormatter.string(from: Date())).json"

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try jsonData.write(to: fileURL)

            let sizeKB = Double(jsonData.count) / 1024.0
            exportSummary = String(format: "Ready: %@ (%.1f KB)", filename, sizeKB)
            exportURL = fileURL
            showShareSheet = true
        } catch {
            exportSummary = "Export failed: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    // MARK: - Seed Demo Data

    private func seedDemoData() {
        PreviewData.populate(context: viewContext)
        let df = DateFormatter()
        df.timeStyle = .medium
        seedSummary = "Seeded at \(df.string(from: Date())). Pull to refresh dashboard."
    }
    #endif

    // MARK: - Entity Serialization

    private func exportUserProfiles() -> [[String: Any]] {
        userProfiles.map { user in
            var dict: [String: Any] = [:]
            if let id = user.id { dict["id"] = id.uuidString }
            dict["age"] = user.age
            if let sex = user.sex { dict["sex"] = sex }
            if let dob = user.dateOfBirth { dict["dateOfBirth"] = iso8601.string(from: dob) }
            dict["height"] = user.height
            dict["weight"] = user.weight
            if let dtype = user.diabetesType { dict["diabetesType"] = dtype }
            if let meno = user.menopausalStatus { dict["menopausalStatus"] = meno }
            if let updated = user.lastUpdated { dict["lastUpdated"] = iso8601.string(from: updated) }
            return dict
        }
    }

    private func exportHealthConditions() -> [[String: Any]] {
        healthConditions.map { hc in
            var dict: [String: Any] = [:]
            if let id = hc.id { dict["id"] = id.uuidString }
            dict["hasDiabetes"] = hc.hasDiabetes
            if let dtype = hc.diabetesType { dict["diabetesType"] = dtype }
            dict["hasDawnEffect"] = hc.hasDawnEffect
            dict["hasCOPD"] = hc.hasCOPD
            dict["hasHeartDisease"] = hc.hasHeartDisease
            if let tobacco = hc.tobaccoUse { dict["tobaccoUse"] = tobacco }
            dict["alcoholUnitsPerWeek"] = hc.alcoholUnitsPerWeek
            if let other = hc.otherConditions { dict["otherConditions"] = other }
            if let updated = hc.lastUpdated { dict["lastUpdated"] = iso8601.string(from: updated) }
            return dict
        }
    }

    private func exportGlucoseReadings() -> [[String: Any]] {
        glucoseReadings.map { reading in
            var dict: [String: Any] = [:]
            if let id = reading.id { dict["id"] = id.uuidString }
            if let ts = reading.timestamp { dict["timestamp"] = iso8601.string(from: ts) }
            dict["value"] = reading.value
            if let unit = reading.unit { dict["unit"] = unit }
            if let trend = reading.trend { dict["trend"] = trend }
            if let source = reading.source { dict["source"] = source }
            return dict
        }
    }

    private func exportMeals() -> [[String: Any]] {
        meals.map { meal in
            var dict: [String: Any] = [:]
            if let id = meal.id { dict["id"] = id.uuidString }
            if let name = meal.name { dict["name"] = name }
            dict["calories"] = meal.calories
            if let ts = meal.timestamp { dict["timestamp"] = iso8601.string(from: ts) }
            if let mtype = meal.mealType { dict["mealType"] = mtype }
            dict["timeSinceLastMeal"] = meal.timeSinceLastMeal
            if let planned = meal.plannedDateTime { dict["plannedDateTime"] = iso8601.string(from: planned) }

            // Food items
            if let foodItems = meal.foodItems as? Set<MealFoodItemEntity> {
                dict["foodItems"] = foodItems.map { item in
                    var fDict: [String: Any] = [:]
                    if let name = item.foodName { fDict["foodName"] = name }
                    if let cat = item.foodCategory { fDict["foodCategory"] = cat }
                    fDict["quantity"] = item.quantity
                    fDict["servingSize"] = item.servingSize
                    if let unit = item.servingUnit { fDict["servingUnit"] = unit }
                    fDict["caloriesPerServing"] = item.caloriesPerServing
                    fDict["carbsPerServing"] = item.carbsPerServing
                    fDict["proteinPerServing"] = item.proteinPerServing
                    fDict["fatPerServing"] = item.fatPerServing
                    fDict["fiberPerServing"] = item.fiberPerServing
                    fDict["glycemicIndex"] = item.glycemicIndex
                    return fDict
                }
            }

            // Macronutrients
            if let macros = meal.macronutrients as? Set<MacronutrientEntity> {
                dict["macronutrients"] = macros.map { macro in
                    var mDict: [String: Any] = [:]
                    if let type = macro.type { mDict["type"] = type }
                    mDict["amount"] = macro.amount
                    if let unit = macro.unit { mDict["unit"] = unit }
                    return mDict
                }
            }

            return dict
        }
    }

    private func exportExercises() -> [[String: Any]] {
        exercises.map { ex in
            var dict: [String: Any] = [:]
            if let id = ex.id { dict["id"] = id.uuidString }
            if let type = ex.type { dict["type"] = type }
            if let start = ex.startDate { dict["startDate"] = iso8601.string(from: start) }
            if let end = ex.endDate { dict["endDate"] = iso8601.string(from: end) }
            dict["duration"] = ex.duration
            dict["distance"] = ex.distance
            dict["intensity"] = ex.intensity
            dict["caloriesBurned"] = ex.caloriesBurned
            if let notes = ex.notes { dict["notes"] = notes }
            return dict
        }
    }

    private func exportPredictions() -> [[String: Any]] {
        predictions.map { pred in
            var dict: [String: Any] = [:]
            if let id = pred.id { dict["id"] = id.uuidString }
            dict["predictedValue"] = pred.predictedValue
            dict["confidenceLevel"] = pred.confidenceLevel
            if let date = pred.predictionDate { dict["predictionDate"] = iso8601.string(from: date) }
            if let version = pred.modelVersion { dict["modelVersion"] = version }
            // Include contributing factors if available
            if let factorsData = pred.contributingFactorsJSON,
               let factors = try? JSONSerialization.jsonObject(with: factorsData) {
                dict["contributingFactors"] = factors
            }
            return dict
        }
    }
}

// MARK: - Helper Views

private struct SummaryRow: View {
    let label: String
    let count: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)")
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Share Sheet (UIKit wrapper)

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
