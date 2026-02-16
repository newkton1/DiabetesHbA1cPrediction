import SwiftUI
import CoreData

/// User Profile view for collecting and managing user demographics and health conditions.
///
/// This view provides a comprehensive form for users to input personal information,
/// health conditions, and other relevant data. It validates input data and persists
/// changes to Core Data using the UserDemographicsEntity and HealthConditionEntity.
///
/// The form is organized into three main sections:
/// 1. Personal Information (age, sex, date of birth, height, weight)
/// 2. Health Conditions (diabetes, COPD, heart disease, tobacco use, alcohol consumption)
/// 3. About (calculated BMI and current age)
struct UserProfileView: View {
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Fetch Requests
    /// Fetch the single UserDemographicsEntity (or create one if none exists).
    /// Assuming there's only one user profile per app instance.
    @FetchRequest(
        entity: UserDemographicsEntity.entity(),
        sortDescriptors: []
    ) private var userDemographics: FetchedResults<UserDemographicsEntity>

    /// Fetch the associated HealthConditionEntity.
    @FetchRequest(
        entity: HealthConditionEntity.entity(),
        sortDescriptors: []
    ) private var healthConditions: FetchedResults<HealthConditionEntity>

    // MARK: - State Variables
    // Personal Information
    @State private var age: String = ""
    @State private var sex: String = "Male"
    @State private var dateOfBirth: Date = Date()
    @State private var height: String = "" // in centimeters
    @State private var weight: String = "" // in kilograms

    // Health Conditions
    @State private var hasDiabetes: Bool = false
    @State private var diabetesType: String = "Type 1"
    @State private var hasCOPD: Bool = false
    @State private var hasHeartDisease: Bool = false
    @State private var tobaccoUse: String = "Never"
    @State private var alcoholUnitsPerWeek: Int = 0

    // UI State
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isSaving = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
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
                    }

                    Picker(selection: $sex, label: Label("Sex", systemImage: "person.fill")) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }

                    HStack {
                        Label("Height (cm)", systemImage: "figure.wave")
                        Spacer()
                        TextField("Height", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Label("Weight (kg)", systemImage: "scale.3d")
                        Spacer()
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                // MARK: - Section 2: Health Conditions
                Section(header: Text("Health Conditions")) {
                    Toggle(isOn: $hasDiabetes) {
                        Label("Diabetes", systemImage: "drop.circle.fill")
                    }

                    // Only show diabetes type picker if diabetes toggle is on
                    if hasDiabetes {
                        Picker(selection: $diabetesType, label: Label("Diabetes Type", systemImage: "pills.fill")) {
                            Text("Type 1").tag("Type 1")
                            Text("Type 2").tag("Type 2")
                            Text("Gestational").tag("Gestational")
                            Text("Other").tag("Other")
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
                    // Display calculated BMI
                    HStack {
                        Label("BMI", systemImage: "figure.stand")
                        Spacer()
                        Text(calculateBMI())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Save Button
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

                ToolbarItem(placement: .navigationBarLeading) {
                    // Close/Dismiss Button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK") { }
            } message: {
                Text(validationErrorMessage)
            }
            .onAppear {
                loadExistingProfile()
            }
        }
    }

    // MARK: - Helper Methods

    /// Load existing user profile data from Core Data into the state variables.
    /// If no profile exists, the form starts with default values.
    private func loadExistingProfile() {
        // Load UserDemographicsEntity data
        if let userDemographic = userDemographics.first {
            age = String(userDemographic.age)
            sex = userDemographic.sex ?? "Male"
            height = String(userDemographic.height)
            weight = String(userDemographic.weight)

            if let dob = userDemographic.dateOfBirth {
                dateOfBirth = dob
            }

            if let diabetesTypeValue = userDemographic.diabetesType {
                diabetesType = diabetesTypeValue
            }

            if let menopausalStatus = userDemographic.menopausalStatus {
                // You can use this for further logic if needed
                _ = menopausalStatus
            }
        }

        // Load HealthConditionEntity data
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
    }

    /// Validate the form input according to specified constraints.
    /// - Age: 1-120 years
    /// - Weight: 20-300 kg
    /// - Height: 50-250 cm
    /// - Returns: True if all fields are valid, false otherwise.
    private func isFormValid() -> Bool {
        // Check age
        if let ageInt = Int(age), ageInt < 1 || ageInt > 120 {
            return false
        }

        // Check weight
        if let weightDouble = Double(weight), weightDouble < 20 || weightDouble > 300 {
            return false
        }

        // Check height
        if let heightDouble = Double(height), heightDouble < 50 || heightDouble > 250 {
            return false
        }

        // At least one of age, weight, height should be filled
        return !age.isEmpty && !height.isEmpty && !weight.isEmpty
    }

    /// Calculate Body Mass Index (BMI) based on current height and weight.
    /// BMI = weight (kg) / (height (m))^2
    /// - Returns: Formatted BMI string with interpretation, or "N/A" if data is incomplete.
    private func calculateBMI() -> String {
        guard let heightCm = Double(height),
              let weightKg = Double(weight),
              heightCm > 0 else {
            return "N/A"
        }

        let heightM = heightCm / 100.0
        let bmi = weightKg / (heightM * heightM)

        let category: String
        if bmi < 18.5 {
            category = "Underweight"
        } else if bmi < 25.0 {
            category = "Normal"
        } else if bmi < 30.0 {
            category = "Overweight"
        } else {
            category = "Obese"
        }

        return String(format: "%.1f - %@", bmi, category)
    }

    /// Calculate the current age based on the selected date of birth.
    /// - Returns: Integer age in years.
    private func calculateCurrentAge() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: now)
        return ageComponents.year ?? 0
    }

    /// Save the user profile to Core Data.
    /// Creates new entities if they don't exist, or updates existing ones.
    /// Validates all fields before saving.
    private func saveProfile() {
        // Validate form
        guard isFormValid() else {
            showValidationError = true
            if let ageInt = Int(age), ageInt < 1 || ageInt > 120 {
                validationErrorMessage = "Age must be between 1 and 120 years."
            } else if let heightDouble = Double(height), heightDouble < 50 || heightDouble > 250 {
                validationErrorMessage = "Height must be between 50 and 250 cm."
            } else if let weightDouble = Double(weight), weightDouble < 20 || weightDouble > 300 {
                validationErrorMessage = "Weight must be between 20 and 300 kg."
            } else {
                validationErrorMessage = "Please fill in all required fields."
            }
            return
        }

        isSaving = true

        // Create or update UserDemographicsEntity
        let userDemographic: UserDemographicsEntity
        if let existing = userDemographics.first {
            userDemographic = existing
        } else {
            userDemographic = UserDemographicsEntity(context: viewContext)
        }

        userDemographic.age = Int16(age) ?? 0
        userDemographic.sex = sex
        userDemographic.dateOfBirth = dateOfBirth
        userDemographic.height = Double(height) ?? 0.0
        userDemographic.weight = Double(weight) ?? 0.0
        userDemographic.diabetesType = hasDiabetes ? diabetesType : nil
        userDemographic.menopausalStatus = sex == "Female" ? "Not specified" : nil

        // Create or update HealthConditionEntity
        let healthCondition: HealthConditionEntity
        if let existing = healthConditions.first {
            healthCondition = existing
        } else {
            healthCondition = HealthConditionEntity(context: viewContext)
        }

        healthCondition.hasDiabetes = hasDiabetes
        healthCondition.diabetesType = hasDiabetes ? diabetesType : nil
        healthCondition.hasCOPD = hasCOPD
        healthCondition.hasHeartDisease = hasHeartDisease
        healthCondition.tobaccoUse = tobaccoUse
        healthCondition.alcoholUnitsPerWeek = Double(alcoholUnitsPerWeek)

        // Save to Core Data
        do {
            try viewContext.save()
            isSaving = false
            dismiss()
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
