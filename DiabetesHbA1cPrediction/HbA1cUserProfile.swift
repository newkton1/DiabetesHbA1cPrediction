import SwiftUI
import Combine

// MARK: - HbA1c User Profile Manager

/// Manages user's HbA1c unit preferences with persistence
class HbA1cUserProfile: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HbA1cUserProfile()
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let countryCode = "hba1c_country_code"
        static let unitOverride = "hba1c_unit_override"
        static let hasCompletedOnboarding = "hba1c_onboarding_completed"
    }
    
    // MARK: - Published Properties
    
    /// The user's selected country code
    @Published var countryCode: String {
        didSet {
            UserDefaults.standard.set(countryCode, forKey: Keys.countryCode)
            updateEffectiveUnit()
        }
    }
    
    /// Manual unit override (nil means use country default)
    @Published var unitOverride: HbA1cUnit? {
        didSet {
            if let unit = unitOverride {
                UserDefaults.standard.set(unit.rawValue, forKey: Keys.unitOverride)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.unitOverride)
            }
            updateEffectiveUnit()
        }
    }
    
    /// The effective unit to use (override or country default)
    @Published private(set) var effectiveUnit: HbA1cUnit
    
    /// Whether the user has completed HbA1c unit onboarding
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved country code or detect from locale
        let savedCountry = UserDefaults.standard.string(forKey: Keys.countryCode)
            ?? Locale.current.region?.identifier
            ?? "US"
        self.countryCode = savedCountry
        
        // Load unit override if set
        if let overrideRaw = UserDefaults.standard.string(forKey: Keys.unitOverride),
           let override = HbA1cUnit(rawValue: overrideRaw) {
            self.unitOverride = override
            self.effectiveUnit = override
        } else {
            self.unitOverride = nil
            self.effectiveUnit = CountryHbA1cMapping.defaultUnit(forCountryCode: savedCountry)
        }
        
        // Load onboarding status
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }
    
    // MARK: - Helper Methods
    
    private func updateEffectiveUnit() {
        if let override = unitOverride {
            effectiveUnit = override
        } else {
            effectiveUnit = CountryHbA1cMapping.defaultUnit(forCountryCode: countryCode)
        }
    }
    
    /// Converts a canonical IFCC value to the user's display unit
    func formatHbA1c(_ ifccValue: Double) -> String {
        let displayValue = fromCanonicalIFCC(value: ifccValue, to: effectiveUnit)
        // Qualify with module name to call the global function, not this instance method
        let decimalPlaces = effectiveUnit == .ngsp ? 1 : 0
        let formatted = String(format: "%.\(decimalPlaces)f", displayValue)
        // Chicago Manual of Style: symbolic representations (%) close up to
        // the number. SI convention: spelled-out unit abbreviations (mmol/mol)
        // take a separating space.
        let separator = effectiveUnit == .ngsp ? "" : " "
        return "\(formatted)\(separator)\(effectiveUnit.shortUnit)"
    }

    /// Converts a canonical IFCC value to the user's display unit (value only)
    func displayValue(_ ifccValue: Double) -> Double {
        return fromCanonicalIFCC(value: ifccValue, to: effectiveUnit)
    }
    
    /// Parses user input and converts to canonical IFCC
    func parseUserInput(_ value: Double) -> Double {
        return toCanonicalIFCC(value: value, from: effectiveUnit)
    }
    
    /// Returns the country name for the current country code
    var countryName: String {
        CountryHbA1cMapping.countryName(forCode: countryCode)
    }
    
    /// Resets to detected defaults
    func resetToDefaults() {
        countryCode = Locale.current.region?.identifier ?? "US"
        unitOverride = nil
    }
}

// MARK: - Country Picker View

struct CountryPickerView: View {
    @ObservedObject var profile: HbA1cUserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredCountries: [(code: String, name: String, unit: HbA1cUnit)] {
        let countries = CountryHbA1cMapping.allSupportedCountries()
        if searchText.isEmpty {
            return countries
        }
        return countries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries, id: \.code) { country in
                    Button {
                        profile.countryCode = country.code
                        dismiss()
                    } label: {
                        HStack {
                            Text(country.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(country.unit.shortUnit)
                                .foregroundStyle(.secondary)
                            if country.code == profile.countryCode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - HbA1c Settings View

struct HbA1cSettingsView: View {
    @ObservedObject var profile: HbA1cUserProfile
    @State private var showCountryPicker = false
    
    var body: some View {
        Form {
            Section {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(profile.countryName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(.primary)
                
                HStack {
                    Text("Default Unit")
                    Spacer()
                    Text(CountryHbA1cMapping.defaultUnit(forCountryCode: profile.countryCode).displayName)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Region")
            } footer: {
                Text("HbA1c units are automatically set based on your country's standard.")
            }
            
            Section {
                Toggle("Use Different Units", isOn: Binding(
                    get: { profile.unitOverride != nil },
                    set: { enabled in
                        if enabled {
                            // Set override to opposite of country default
                            let countryDefault = CountryHbA1cMapping.defaultUnit(forCountryCode: profile.countryCode)
                            profile.unitOverride = countryDefault == .ngsp ? .ifcc : .ngsp
                        } else {
                            profile.unitOverride = nil
                        }
                    }
                ))
                
                if profile.unitOverride != nil {
                    Picker("Display Unit", selection: Binding(
                        get: { profile.unitOverride ?? .ngsp },
                        set: { profile.unitOverride = $0 }
                    )) {
                        ForEach(HbA1cUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            } header: {
                Text("Manual Override")
            } footer: {
                Text("Override the default if your healthcare provider uses a different unit system.")
            }
            
            Section {
                HStack {
                    Text("Current Setting")
                    Spacer()
                    Text(profile.effectiveUnit.displayName)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }
                
                // Show example conversion
                let exampleIFCC: Double = 53.0
                HStack {
                    Text("Example (7.0% / 53 mmol/mol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(profile.formatHbA1c(exampleIFCC))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Preview")
            }
        }
        .navigationTitle("HbA1c Units")
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(profile: profile)
        }
    }
}

// MARK: - Onboarding View

struct HbA1cOnboardingView: View {
    @ObservedObject var profile: HbA1cUserProfile
    @State private var showCountryPicker = false
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "globe")
                .font(.largeTitle)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            
            Text("HbA1c Units")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Different countries use different units to measure HbA1c. We'll automatically use the right format based on your location.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text("Your Country")
                        Spacer()
                        Text(profile.countryName)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .foregroundStyle(.primary)
                
                HStack {
                    Text("HbA1c will be shown as")
                    Spacer()
                    Text(profile.effectiveUnit.displayName)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                profile.hasCompletedOnboarding = true
                onComplete()
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(profile: profile)
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    NavigationStack {
        HbA1cSettingsView(profile: HbA1cUserProfile.shared)
    }
}

#Preview("Onboarding") {
    HbA1cOnboardingView(profile: HbA1cUserProfile.shared) {
        #if DEBUG
        print("Onboarding complete")
        #endif
    }
}
