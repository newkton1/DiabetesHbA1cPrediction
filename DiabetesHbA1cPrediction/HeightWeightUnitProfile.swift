import Foundation
import Combine

/// Manages user preferences for height and weight measurement units.
/// Auto-detects locale (US → imperial, elsewhere → metric) with manual override.
/// Follows the same singleton pattern as HbA1cUserProfile.
///
/// Core Data always stores metric (kg, cm). Conversion happens at the UI layer.
final class HeightWeightUnitProfile: ObservableObject {

    // MARK: - Singleton
    static let shared = HeightWeightUnitProfile()

    // MARK: - Unit Enums

    enum WeightUnit: String, CaseIterable, Identifiable {
        case kg = "kg"
        case lbs = "lbs"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .kg: return "Kilograms (kg)"
            case .lbs: return "Pounds (lbs)"
            }
        }

        var shortLabel: String { rawValue }
    }

    enum HeightUnit: String, CaseIterable, Identifiable {
        case cm = "cm"
        case ftIn = "ftIn"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .cm: return "Centimetres (cm)"
            case .ftIn: return "Feet & Inches (ft-in)"
            }
        }

        var shortLabel: String {
            switch self {
            case .cm: return "cm"
            case .ftIn: return "ft-in"
            }
        }
    }

    // MARK: - UserDefaults Keys
    private let weightUnitKey = "hw_weight_unit"
    private let heightUnitKey = "hw_height_unit"

    // MARK: - Published Properties

    @Published var weightUnit: WeightUnit {
        didSet { UserDefaults.standard.set(weightUnit.rawValue, forKey: weightUnitKey) }
    }

    @Published var heightUnit: HeightUnit {
        didSet { UserDefaults.standard.set(heightUnit.rawValue, forKey: heightUnitKey) }
    }

    // MARK: - Initialization

    private init() {
        // Determine locale-based defaults
        let regionCode = Locale.current.region?.identifier ?? "US"
        let isUS = (regionCode == "US")

        // Load saved preferences or use locale defaults
        if let savedWeight = UserDefaults.standard.string(forKey: weightUnitKey),
           let unit = WeightUnit(rawValue: savedWeight) {
            self.weightUnit = unit
        } else {
            self.weightUnit = isUS ? .lbs : .kg
        }

        if let savedHeight = UserDefaults.standard.string(forKey: heightUnitKey),
           let unit = HeightUnit(rawValue: savedHeight) {
            self.heightUnit = unit
        } else {
            self.heightUnit = isUS ? .ftIn : .cm
        }
    }

    // MARK: - Conversion Helpers

    /// Convert kilograms to pounds
    func kgToLbs(_ kg: Double) -> Double {
        kg * 2.20462
    }

    /// Convert pounds to kilograms
    func lbsToKg(_ lbs: Double) -> Double {
        lbs / 2.20462
    }

    /// Convert centimetres to total inches
    func cmToInches(_ cm: Double) -> Double {
        cm / 2.54
    }

    /// Convert total inches to centimetres
    func inchesToCm(_ inches: Double) -> Double {
        inches * 2.54
    }

    /// Convert centimetres to feet and inches tuple
    func cmToFtIn(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = cmToInches(cm)
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches.rounded()) % 12
        return (feet, inches)
    }

    /// Convert feet and inches to centimetres
    func ftInToCm(feet: Int, inches: Int) -> Double {
        let totalInches = Double(feet * 12 + inches)
        return inchesToCm(totalInches)
    }

    // MARK: - Display Formatting

    /// Format a weight value (stored in kg) for display in user's preferred unit
    func formatWeight(_ kg: Double) -> String {
        if weightUnit == .lbs {
            return String(format: "%.0f lbs", kgToLbs(kg))
        } else {
            return String(format: "%.1f kg", kg)
        }
    }

    /// Format a height value (stored in cm) for display in user's preferred unit
    func formatHeight(_ cm: Double) -> String {
        if heightUnit == .ftIn {
            let (feet, inches) = cmToFtIn(cm)
            return "\(feet)'\(inches)\""
        } else {
            return String(format: "%.0f cm", cm)
        }
    }

    /// Reset to locale-detected defaults
    func resetToDefaults() {
        let regionCode = Locale.current.region?.identifier ?? "US"
        let isUS = (regionCode == "US")
        weightUnit = isUS ? .lbs : .kg
        heightUnit = isUS ? .ftIn : .cm
    }

    /// The detected region name for display
    var detectedRegion: String {
        let regionCode = Locale.current.region?.identifier ?? "US"
        return Locale.current.localizedString(forRegionCode: regionCode) ?? regionCode
    }
}
