import SwiftUI
import CoreData

/// User Profile view for collecting and managing user demographics and health conditions.
///
/// This view provides a comprehensive form for users to input personal information,
/// health conditions, and other relevant data. It validates input data and persists
/// changes to Core Data using the UserDemographicsEntity and HealthConditionEntity.
///
/// Height and weight units are locale-aware: US defaults to lbs/ft-in, elsewhere to kg/cm.
/// Core Data always stores metric (kg, cm). Conversion happens at the UI layer.
struct UserProfileView: View {
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    // MARK: - Fetch Requests
    @FetchRequest(
        entity: UserDemographicsEntity.entity(),
        sortDescriptors: []
    ) private var userDemographics: FetchedResults<UserDemographicsEntity>

    @FetchRequest(
        entity: HealthConditionEntity.entity(),
        sortDescriptors: []
    ) private var healthConditions: FetchedResults<HealthConditionEntity>

    // MARK: - Unit Profile
    @ObservedObject private var hwProfile = HeightWeightUnitProfile.shared

    // MARK: - State Variables
    // Personal Information
    @State private var age: String = ""
    @State private var sex: String = "Male"
    @State private var dateOfBirth: Date = Date()
    @State private var weight: String = ""      // displayed in user's preferred unit
    @State private var heightCm: String = ""    // used when unit is cm
    @State private var heightFt: String = ""    // used when unit is ft-in
    @State private var heightIn: String = ""    // used when unit is ft-in

    // Health Conditions
    @State private var hasDiabetes: Bool = false
    @State private var diabetesType: String = "Type 1"
    @State private var hasDawnEffect: Bool = false
    @State private var hasCOPD: Bool = false
    @State private var hasHeartDisease: Bool = false
    @State private var tobaccoUse: String = "Never"
    @State private var alcoholUnitsPerWeek: Int = 0

    // Exercise offset preference
    @State private var preferredExerciseType: ExerciseOffsetType = .walk

    // UI State
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Landscape: custom header with title on left, Save button on right
            if !isPortrait {
                HStack {
                    Text("User")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !isFormValid())
                }
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            Form {
            // MARK: - Section 1: Personal Information
            Section(header: Text("Personal Information")) {
                HStack {
                    Label("Age", systemImage: "calendar.circle.fill")
                    Spacer()
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .focused($isTextFieldFocused)
                }

                Picker(selection: $sex, label: Label("Sex", systemImage: "person.fill")) {
                    Text("Male").tag("Male")
                    Text("Female").tag("Female")
                    Text("Other").tag("Other")
                }

                // Height field — adapts to user's unit preference
                if hwProfile.heightUnit == .cm {
                    HStack {
                        Label("Height (cm)", systemImage: "figure.wave")
                        Spacer()
                        TextField("cm", text: $heightCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($isTextFieldFocused)
                    }
                } else {
                    HStack {
                        Label("Height (ft-in)", systemImage: "figure.wave")
                        Spacer()
                        TextField("ft", text: $heightFt)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 40)
                            .focused($isTextFieldFocused)
                        Text("'")
                            .foregroundColor(.secondary)
                        TextField("in", text: $heightIn)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 40)
                            .focused($isTextFieldFocused)
                        Text("\"")
                            .foregroundColor(.secondary)
                    }
                }

                // Weight field — adapts to user's unit preference
                HStack {
                    Label(hwProfile.weightUnit == .kg ? "Weight (kg)" : "Weight (lbs)",
                          systemImage: "scale.3d")
                    Spacer()
                    TextField(hwProfile.weightUnit == .kg ? "kg" : "lbs", text: $weight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .focused($isTextFieldFocused)
                }
            }

            // MARK: - Section 2: Health Conditions
            Section(header: Text("Health Conditions")) {
                Toggle(isOn: $hasDiabetes) {
                    Label("Diabetes", systemImage: "drop.circle.fill")
                }

                if hasDiabetes {
                    Picker(selection: $diabetesType, label: Label("Diabetes Type", systemImage: "pills.fill")) {
                        Text("Type 1").tag("Type 1")
                        Text("Type 2").tag("Type 2")
                        Text("Gestational").tag("Gestational")
                        Text("Other").tag("Other")
                    }

                    if diabetesType == "Type 1" {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("This app is NOT for Type 1 diabetics or anyone using insulin bolus therapy. It does not calculate insulin dosage and must not be used for that purpose.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }

                    if diabetesType == "Type 2" {
                        Toggle(isOn: $hasDawnEffect) {
                            Label("Dawn Effect", systemImage: "sunrise.fill")
                        }

                        if hasDawnEffect {
                            Text("HbA1c estimate will be adjusted to reduce the impact of elevated early morning glucose (4–8am) caused by the dawn effect.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle(isOn: $hasCOPD) {
                    Label("COPD", systemImage: "lungs.fill")
                }

                Toggle(isOn: $hasHeartDisease) {
                    Label("Heart Disease", systemImage: "heart.circle.fill")
                }

                Picker(selection: $tobaccoUse, label: Label("Tobacco Use", systemImage: "smoke.fill")) {
                    Text("Never").tag("Never")
                    Text("Former").tag("Former")
                    Text("Current").tag("Current")
                }

                HStack {
                    Label("Alcohol Units/Week", systemImage: "wineglass.fill")
                    Spacer()
                    Stepper(value: $alcoholUnitsPerWeek, in: 0...30, step: 1) {
                        Text("\(alcoholUnitsPerWeek)")
                            .frame(width: 40)
                    }
                }
            }

            // MARK: - Section 3: About
            Section(header: Text("About")) {
                HStack {
                    Label("BMI", systemImage: "figure.stand")
                    Spacer()
                    let bmiResult = calculateBMI()
                    Text(bmiResult.text)
                        .foregroundColor(bmiResult.color)
                }
            }

            // MARK: - Section 4: Settings
            Section(header: Text("Settings")) {
                // Preferred exercise type for post-meal offset recommendation
                Picker(selection: $preferredExerciseType,
                       label: Label("Offset Exercise", systemImage: "figure.run.circle.fill")) {
                    ForEach(ExerciseOffsetType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }

                NavigationLink(destination: HbA1cSettingsView(profile: HbA1cUserProfile.shared)) {
                    HStack {
                        Label("HbA1c Units", systemImage: "globe")
                        Spacer()
                        Text(HbA1cUserProfile.shared.effectiveUnit.shortUnit)
                            .foregroundColor(.secondary)
                    }
                }

                // Weight unit picker — shows abbreviation in row, full name in menu
                HStack {
                    Label("Weight Units", systemImage: "scale.3d")
                    Spacer()
                    Menu {
                        ForEach(HeightWeightUnitProfile.WeightUnit.allCases) { unit in
                            Button(action: {
                                let old = hwProfile.weightUnit
                                hwProfile.weightUnit = unit
                                convertWeightDisplay(from: old, to: unit)
                            }) {
                                HStack {
                                    Text(unit.label)
                                    if unit == hwProfile.weightUnit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(hwProfile.weightUnit.shortLabel)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Height unit picker — shows abbreviation in row, full name in menu
                HStack {
                    Label("Height Units", systemImage: "figure.wave")
                    Spacer()
                    Menu {
                        ForEach(HeightWeightUnitProfile.HeightUnit.allCases) { unit in
                            Button(action: {
                                let old = hwProfile.heightUnit
                                hwProfile.heightUnit = unit
                                convertHeightDisplay(from: old, to: unit)
                            }) {
                                HStack {
                                    Text(unit.label)
                                    if unit == hwProfile.heightUnit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(hwProfile.heightUnit.shortLabel)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // MARK: - DEBUG: Data Export (excluded from release builds)
            #if DEBUG
            Section(header: Text("Developer Tools")) {
                NavigationLink(destination: DataExportView()) {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                        .foregroundColor(.orange)
                }
            }
            #endif

            // MARK: - Section 5: About
            Section(header: Text("About")) {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }

                HStack {
                    Text("Version")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("1.0.0 (Beta)")
                        .foregroundColor(.secondary)
                }
            }
        }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Portrait: title on left, Save button on right
            if isPortrait {
                ToolbarItem(placement: .topBarLeading) {
                    Text("User")
                        .font(.system(size: 22, weight: .bold))
                        .fixedSize(horizontal: true, vertical: false)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !isFormValid())
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
            }
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK") { }
        } message: {
            Text(validationErrorMessage)
        }
        .alert("Profile Saved", isPresented: $showSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your profile has been saved successfully.")
        }
        .onAppear {
            loadExistingProfile()
        }
    }

    // MARK: - Unit Conversion on Toggle

    /// When user switches weight unit, convert the displayed value
    private func convertWeightDisplay(from oldUnit: HeightWeightUnitProfile.WeightUnit,
                                       to newUnit: HeightWeightUnitProfile.WeightUnit) {
        guard let value = Double(weight), value > 0 else { return }
        if oldUnit == .kg && newUnit == .lbs {
            weight = String(format: "%.0f", hwProfile.kgToLbs(value))
        } else if oldUnit == .lbs && newUnit == .kg {
            weight = String(format: "%.1f", hwProfile.lbsToKg(value))
        }
    }

    /// When user switches height unit, convert the displayed value
    private func convertHeightDisplay(from oldUnit: HeightWeightUnitProfile.HeightUnit,
                                       to newUnit: HeightWeightUnitProfile.HeightUnit) {
        if oldUnit == .cm && newUnit == .ftIn {
            if let cm = Double(heightCm), cm > 0 {
                let (feet, inches) = hwProfile.cmToFtIn(cm)
                heightFt = String(feet)
                heightIn = String(inches)
            }
        } else if oldUnit == .ftIn && newUnit == .cm {
            if let ft = Int(heightFt), let inches = Int(heightIn) {
                let cm = hwProfile.ftInToCm(feet: ft, inches: inches)
                heightCm = String(format: "%.0f", cm)
            }
        }
    }

    // MARK: - Helper Methods

    /// Load existing user profile data from Core Data, converting to user's preferred units.
    private func loadExistingProfile() {
        if let userDemographic = userDemographics.first {
            age = String(userDemographic.age)
            sex = userDemographic.sex ?? "Male"

            // Load weight (stored as kg) and convert to user's unit
            let storedWeightKg = userDemographic.weight
            if storedWeightKg > 0 {
                if hwProfile.weightUnit == .lbs {
                    weight = String(format: "%.0f", hwProfile.kgToLbs(storedWeightKg))
                } else {
                    weight = String(format: "%.1f", storedWeightKg)
                }
            }

            // Load height (stored as cm) and convert to user's unit
            let storedHeightCm = userDemographic.height
            if storedHeightCm > 0 {
                if hwProfile.heightUnit == .ftIn {
                    let (feet, inches) = hwProfile.cmToFtIn(storedHeightCm)
                    heightFt = String(feet)
                    heightIn = String(inches)
                } else {
                    heightCm = String(format: "%.0f", storedHeightCm)
                }
            }

            if let dob = userDemographic.dateOfBirth {
                dateOfBirth = dob
            }

            if let diabetesTypeValue = userDemographic.diabetesType {
                diabetesType = diabetesTypeValue
            }
        }

        if let healthCondition = healthConditions.first {
            hasDiabetes = healthCondition.hasDiabetes
            hasDawnEffect = healthCondition.hasDawnEffect
            hasCOPD = healthCondition.hasCOPD
            hasHeartDisease = healthCondition.hasHeartDisease
            tobaccoUse = healthCondition.tobaccoUse ?? "Never"
            alcoholUnitsPerWeek = Int(healthCondition.alcoholUnitsPerWeek)

            if let diabetesTypeValue = healthCondition.diabetesType {
                diabetesType = diabetesTypeValue
            }
        }

        // Load exercise offset preference
        if let saved = UserDefaults.standard.string(forKey: "preferredExerciseType"),
           let type = ExerciseOffsetType(rawValue: saved) {
            preferredExerciseType = type
        }
    }

    // MARK: - Metric Conversion Helpers

    /// Convert the displayed weight to kilograms for storage
    private func weightInKg() -> Double? {
        guard let value = Double(weight) else { return nil }
        return hwProfile.weightUnit == .lbs ? hwProfile.lbsToKg(value) : value
    }

    /// Convert the displayed height to centimetres for storage
    private func heightInCm() -> Double? {
        if hwProfile.heightUnit == .ftIn {
            guard let ft = Int(heightFt), let inches = Int(heightIn) else { return nil }
            return hwProfile.ftInToCm(feet: ft, inches: inches)
        } else {
            return Double(heightCm)
        }
    }

    // MARK: - Validation

    /// Validate the form input with unit-aware ranges.
    private func isFormValid() -> Bool {
        // Block save for Type 1 diabetics — app is not designed for insulin bolus therapy
        if hasDiabetes && diabetesType == "Type 1" {
            return false
        }

        // Check age
        if let ageInt = Int(age), ageInt < 1 || ageInt > 120 {
            return false
        }

        // Check weight in user's unit
        if let w = Double(weight) {
            if hwProfile.weightUnit == .kg {
                if w < 20 || w > 300 { return false }
            } else {
                if w < 44 || w > 660 { return false }
            }
        }

        // Check height in user's unit
        if hwProfile.heightUnit == .cm {
            if let h = Double(heightCm), (h < 50 || h > 250) { return false }
        } else {
            if let ft = Int(heightFt), let inches = Int(heightIn) {
                let totalInches = ft * 12 + inches
                if totalInches < 20 || totalInches > 98 { return false }
                if inches < 0 || inches > 11 { return false }
            }
        }

        // Ensure required fields are filled
        let heightFilled = hwProfile.heightUnit == .cm ? !heightCm.isEmpty : (!heightFt.isEmpty && !heightIn.isEmpty)
        return !age.isEmpty && !weight.isEmpty && heightFilled
    }

    // MARK: - BMI Calculation

    /// Calculate BMI from the displayed values, converting to metric first.
    private func calculateBMI() -> (text: String, color: Color) {
        guard let heightCmVal = heightInCm(),
              let weightKgVal = weightInKg(),
              heightCmVal > 0 else {
            return ("N/A", .secondary)
        }

        let heightM = heightCmVal / 100.0
        let bmi = weightKgVal / (heightM * heightM)

        let category: String
        let color: Color
        if bmi < 18.5 {
            category = "Underweight"
            color = .orange
        } else if bmi < 25.0 {
            category = "Normal"
            color = .green
        } else if bmi < 30.0 {
            category = "Overweight"
            color = .orange
        } else {
            category = "Obese"
            color = .orange
        }

        return (String(format: "%.1f - %@", bmi, category), color)
    }

    /// Calculate the current age based on the selected date of birth.
    private func calculateCurrentAge() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: now)
        return ageComponents.year ?? 0
    }

    // MARK: - Save

    /// Save the user profile to Core Data. Converts to metric before storing.
    private func saveProfile() {
        guard isFormValid() else {
            showValidationError = true
            if let ageInt = Int(age), ageInt < 1 || ageInt > 120 {
                validationErrorMessage = "Age must be between 1 and 120 years."
            } else if heightInCm() == nil || (heightInCm()! < 50 || heightInCm()! > 250) {
                if hwProfile.heightUnit == .cm {
                    validationErrorMessage = "Height must be between 50 and 250 cm."
                } else {
                    validationErrorMessage = "Height must be between 1'8\" and 8'2\"."
                }
            } else if weightInKg() == nil || (weightInKg()! < 20 || weightInKg()! > 300) {
                if hwProfile.weightUnit == .kg {
                    validationErrorMessage = "Weight must be between 20 and 300 kg."
                } else {
                    validationErrorMessage = "Weight must be between 44 and 660 lbs."
                }
            } else {
                validationErrorMessage = "Please fill in all required fields."
            }
            return
        }

        isSaving = true

        let userDemographic: UserDemographicsEntity
        if let existing = userDemographics.first {
            userDemographic = existing
        } else {
            userDemographic = UserDemographicsEntity(context: viewContext)
        }

        userDemographic.age = Int16(age) ?? 0
        userDemographic.sex = sex
        userDemographic.dateOfBirth = dateOfBirth
        userDemographic.height = heightInCm() ?? 0.0    // always stored as cm
        userDemographic.weight = weightInKg() ?? 0.0     // always stored as kg
        userDemographic.diabetesType = hasDiabetes ? diabetesType : nil
        userDemographic.menopausalStatus = sex == "Female" ? "Not specified" : nil

        let healthCondition: HealthConditionEntity
        if let existing = healthConditions.first {
            healthCondition = existing
        } else {
            healthCondition = HealthConditionEntity(context: viewContext)
        }

        healthCondition.hasDiabetes = hasDiabetes
        healthCondition.diabetesType = hasDiabetes ? diabetesType : nil
        healthCondition.hasDawnEffect = hasDiabetes && diabetesType == "Type 2" ? hasDawnEffect : false
        healthCondition.hasCOPD = hasCOPD
        healthCondition.hasHeartDisease = hasHeartDisease
        healthCondition.tobaccoUse = tobaccoUse
        healthCondition.alcoholUnitsPerWeek = Double(alcoholUnitsPerWeek)

        // Save exercise offset preference
        UserDefaults.standard.set(preferredExerciseType.rawValue, forKey: "preferredExerciseType")

        do {
            try viewContext.save()
            isSaving = false
            isTextFieldFocused = false
            showSaveSuccess = true
        } catch {
            isSaving = false
            showValidationError = true
            validationErrorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview
#Preview {
    UserProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
