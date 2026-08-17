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
    @Environment(\.openURL) private var openURL
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

    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: false)]
    ) private var glucoseReadings: FetchedResults<GlucoseReadingEntity>

    @FetchRequest(
        entity: GmiEstimateEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GmiEstimateEntity.predictionDate, ascending: false)]
    ) private var gmiEstimates: FetchedResults<GmiEstimateEntity>

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

    // Share state
    @State private var showShareWarning = false
    @State private var showShareSheet = false
    @State private var shareSummaryText = ""
    @State private var showExportJSONWarning = false
    @State private var showExportExcelWarning = false
    @State private var navigateToExport = false

    // Demo data states
    @State private var isLoadingDemoData = false
    @State private var showDemoLoadResult = false
    @State private var demoLoadMessage = ""
    @State private var showWipeConfirmation = false
    @State private var isWipingData = false
    @State private var showWipeResult = false
    @State private var wipeResultMessage = ""

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Landscape: custom header with title on left, Save button on right
            if !isPortrait {
                HStack {
                    Text("User")
                        .font(.title3.bold())
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

                    // Dawn effect is now detected automatically from glucose patterns
                    // and displayed as an informational notice on the Dashboard.
                }

                Toggle(isOn: $hasCOPD) {
                    Label("COPD", systemImage: "lungs.fill")
                }

                Toggle(isOn: $hasHeartDisease) {
                    Label("Heart Disease", systemImage: "heart.circle.fill")
                }

                Picker(selection: $tobaccoUse, label: Label("Tobacco Use", systemImage: "smoke.fill")) {
                    Text("Never").tag("Never")
                    Text("Quit more than 1 year").tag("Former")
                    Text("Smoking more than 1 year").tag("Current")
                }

                HStack {
                    Label("Alcohol Units/Week", systemImage: "wineglass.fill")
                    Spacer()
                    Stepper(value: $alcoholUnitsPerWeek, in: 0...30, step: 1) {
                        Text("\(alcoholUnitsPerWeek)")
                            .frame(width: 40)
                    }
                    .accessibilityValue(Text("\(alcoholUnitsPerWeek) units per week"))
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
                        Text(LocalizedStringKey(type.label)).tag(type)
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
                                .accessibilityHidden(true)
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
                                .accessibilityHidden(true)
                        }
                    }
                }
            }

            // MARK: - Share Summary
            Section(header: Text("Share")) {
                Button(action: { showShareWarning = true }) {
                    Label("Quick GMI Text Summary", systemImage: "square.and.arrow.up")
                }
            }

            // MARK: - Data Management
            Section(header: Text("Data Management")) {
                Button(action: { showExportJSONWarning = true }) {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
                .navigationDestination(isPresented: $navigateToExport) {
                    DataExportView()
                }
                NavigationLink(destination: DataImportView()) {
                    Label("Import Data from JSON", systemImage: "square.and.arrow.down")
                }
            }

            // MARK: - Demo Data
            Section(header: Text("Demo Data")) {
                Button(action: loadDemoData) {
                    Label("Load Demo Data", systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(isLoadingDemoData)

                if isLoadingDemoData {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading demo data\u{2026}")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Button(role: .destructive, action: { showWipeConfirmation = true }) {
                    Label("Wipe All Data", systemImage: "trash")
                }
                .disabled(isWipingData)

                if isWipingData {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Wiping data\u{2026}")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Text("Load sample data to explore the app, or wipe all data to start fresh.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .alert("Demo Data Loaded", isPresented: $showDemoLoadResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(demoLoadMessage)
            }
            .alert("Wipe All Data?", isPresented: $showWipeConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Wipe", role: .destructive) { wipeDemoData() }
            } message: {
                Text("This will permanently delete all data including glucose readings, meals, exercise sessions, and GMI estimates. This cannot be undone.")
            }
            .alert("Data Wiped", isPresented: $showWipeResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(wipeResultMessage)
            }

            // MARK: - Section 5: About
            Section(header: Text("About")) {
                Button {
                    if let url = URL(string: "https://www.youtube.com/watch?v=T3dPPyUxcxg&list=PLEMcKQpcQpgup74VYGWHEFwembOmnPt_U") {
                        openURL(url)
                    }
                } label: {
                    Label("Watch Onboarding Guide", systemImage: "play.circle")
                }

                Button {
                    if let url = URL(string: "https://discord.gg/DWtt7vPQkb") {
                        openURL(url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Join the Discord Community", systemImage: "bubble.left.and.bubble.right.fill")
                        Text("Requires free Discord app for iPhone. Community can also be accessed on desktop from a browser.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    if let url = URL(string: "https://chat.whatsapp.com/JicFbQNtyYaFILacW1MAxu") {
                        openURL(url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Join the WhatsApp Community", systemImage: "message.fill")
                        Text("Requires free WhatsApp app for iPhone.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: PrivacyPolicyView()) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }

                NavigationLink(destination: ReferencesView()) {
                    Label("References & Citations", systemImage: "book.closed")
                }

                HStack {
                    Text("Version")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("1.0")
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
                        .font(.title3.bold())
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
        .alert("Share Health Data?", isPresented: $showShareWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Share") {
                shareSummaryText = buildGmiSummary()
                showShareSheet = true
            }
        } message: {
            Text("This will share your glucose and GMI data with a third party of your choosing (e.g. email, messaging app). This export contains sensitive personal health information. Are you sure you want to continue?")
        }
        .alert("Export Health Data?", isPresented: $showExportJSONWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                navigateToExport = true
            }
        } message: {
            Text("The export screen contains all your health data including glucose readings, meals, exercise sessions, and your personal profile. This data is sensitive — only share it with people you trust.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(activityItems: [shareSummaryText])
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

        return (String(format: "%.1f - %@", bmi, NSLocalizedString(category, comment: "")), color)
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
        // Dawn effect is now detected automatically — no longer user-toggled
        healthCondition.hasDawnEffect = false
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

    // MARK: - GMI Summary Builder

    /// Builds a plain-text summary of the user's glucose and GMI data
    /// suitable for sharing via the iOS share sheet.
    private func buildGmiSummary() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        var lines: [String] = []
        lines.append("Diabetes Feast — GMI Summary")
        lines.append("Generated: \(df.string(from: Date()))")
        lines.append("")

        // Recent glucose readings (last 14 days)
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recentReadings = glucoseReadings.filter { reading in
            guard let ts = reading.timestamp else { return false }
            let unit = reading.unit ?? ""
            // Exclude HbA1c lab results
            return ts >= fourteenDaysAgo && unit != "NGSP %" && unit != "mmol/mol"
        }

        if !recentReadings.isEmpty {
            let values = recentReadings.map { $0.value }
            let avg = values.reduce(0, +) / Double(values.count)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            let unit = recentReadings.first?.unit ?? "mg/dL"

            lines.append("Glucose (last 14 days)")
            lines.append("  Readings: \(recentReadings.count)")
            lines.append("  Average: \(String(format: "%.0f", avg)) \(unit)")
            lines.append("  Range: \(String(format: "%.0f", minVal)) – \(String(format: "%.0f", maxVal)) \(unit)")
            lines.append("")
        } else {
            lines.append("Glucose: No readings in the last 14 days")
            lines.append("")
        }

        // Most recent GMI estimate
        if let latest = gmiEstimates.first,
           let date = latest.predictionDate {
            lines.append("Most Recent GMI Estimate")
            lines.append("  Value: \(String(format: "%.1f", latest.predictedValue))%")
            lines.append("  Date: \(df.string(from: date))")
            lines.append("")
        }

        // HbA1c lab results
        let labResults = glucoseReadings.filter { ($0.unit == "NGSP %" || $0.unit == "mmol/mol") }
        if !labResults.isEmpty {
            lines.append("HbA1c Lab Results")
            for lab in labResults.prefix(5) {
                let dateStr = lab.timestamp.map { df.string(from: $0) } ?? "Unknown date"
                lines.append("  \(String(format: "%.1f", lab.value)) \(lab.unit ?? "%") — \(dateStr)")
            }
            lines.append("")
        }

        lines.append("—")
        lines.append("This summary is for personal tracking only and does not constitute medical advice.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Demo Data Actions

    private func loadDemoData() {
        isLoadingDemoData = true
        Task { @MainActor in
            defer { isLoadingDemoData = false }
            do {
                let result = try DemoDataManager.loadDemoData(into: viewContext)
                demoLoadMessage = String(format: NSLocalizedString("Loaded %lld records: %lld glucose readings, %lld meals, %lld exercise sessions.", comment: ""), Int64(result.totalImported), Int64(result.glucoseReadings.imported), Int64(result.meals.imported), Int64(result.exerciseSessions.imported))
                if result.totalSkipped > 0 {
                    demoLoadMessage += String(format: NSLocalizedString(" (%lld duplicates skipped.)", comment: ""), Int64(result.totalSkipped))
                }
            } catch {
                demoLoadMessage = "Failed to load demo data: \(error.localizedDescription)"
            }
            showDemoLoadResult = true
        }
    }

    private func wipeDemoData() {
        isWipingData = true
        Task { @MainActor in
            defer { isWipingData = false }
            do {
                let count = try DemoDataManager.wipeAllData(from: viewContext)
                ColdStartManager.shared.resetOnboarding()
                ColdStartManager.shared.refresh(context: viewContext)
                wipeResultMessage = "Deleted \(count) records. The app is ready for your own data."
            } catch {
                wipeResultMessage = "Failed to wipe data: \(error.localizedDescription)"
            }
            showWipeResult = true
        }
    }
}

// MARK: - Share Sheet (UIKit wrapper)

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    UserProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
