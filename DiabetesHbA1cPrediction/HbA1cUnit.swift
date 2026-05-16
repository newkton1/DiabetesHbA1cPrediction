import Foundation

// MARK: - HbA1c Unit System

/// Represents the two international HbA1c measurement standards
enum HbA1cUnit: String, Codable, CaseIterable {
    /// NGSP standard used in US, Japan, etc. - expressed as percentage (e.g., 7.0%)
    case ngsp = "NGSP"
    /// IFCC standard used in EU, Australia, etc. - expressed as mmol/mol (e.g., 53 mmol/mol)
    case ifcc = "IFCC"
    
    var displayName: String {
        switch self {
        case .ngsp: return "% (NGSP)"
        case .ifcc: return "mmol/mol (IFCC)"
        }
    }
    
    var shortUnit: String {
        switch self {
        case .ngsp: return "%"
        case .ifcc: return "mmol/mol"
        }
    }
    
    var description: String {
        switch self {
        case .ngsp: return "Percentage (US, Japan)"
        case .ifcc: return "mmol/mol (EU, Australia)"
        }
    }
}

// MARK: - Conversion Functions

/// Converts NGSP percentage to IFCC mmol/mol
/// Formula: IFCC = (NGSP - 2.15) × 10.929
/// Reference: IFCC standardization equation
func ngspToIFCC(_ ngsp: Double) -> Double {
    return (ngsp - 2.15) * 10.929
}

/// Converts IFCC mmol/mol to NGSP percentage
/// Formula: NGSP = (IFCC / 10.929) + 2.15
/// Reference: IFCC standardization equation
func ifccToNGSP(_ ifcc: Double) -> Double {
    return (ifcc / 10.929) + 2.15
}

/// Converts GMI (NGSP %) to estimated mean glucose in mg/dL
/// Inverse of: GMI (%) = 3.31 + 0.02392 × mean_mg/dL
/// Therefore: mean_mg/dL = (GMI - 3.31) / 0.02392
/// Reference: Bergenstal et al. Diabetes Care 2018;41(11):2275-2280
func gmiToMeanGlucose(gmiPercent: Double) -> Double {
    return (gmiPercent - 3.31) / 0.02392
}

/// Converts GMI (NGSP %) to estimated mean glucose in mmol/L
func gmiToMeanGlucoseMmol(gmiPercent: Double) -> Double {
    return gmiToMeanGlucose(gmiPercent: gmiPercent) / 18.0182
}

// MARK: - Canonical Storage Helpers

/// Converts user input to canonical IFCC storage format
/// - Parameters:
///   - value: The HbA1c value entered by user
///   - unit: The unit the value is expressed in
/// - Returns: Value in IFCC mmol/mol for internal storage
func toCanonicalIFCC(value: Double, from unit: HbA1cUnit) -> Double {
    switch unit {
    case .ngsp:
        return ngspToIFCC(value)
    case .ifcc:
        return value
    }
}

/// Converts canonical IFCC storage format to display unit
/// - Parameters:
///   - ifccValue: The HbA1c value in IFCC mmol/mol
///   - unit: The target display unit
/// - Returns: Value in the requested unit
func fromCanonicalIFCC(value ifccValue: Double, to unit: HbA1cUnit) -> Double {
    switch unit {
    case .ngsp:
        return ifccToNGSP(ifccValue)
    case .ifcc:
        return ifccValue
    }
}

// MARK: - Range Thresholds

/// HbA1c range thresholds (stored in IFCC mmol/mol)
/// Based on commonly referenced clinical thresholds for informational purposes
struct HbA1cThresholds {
    /// Normal range: < 39 mmol/mol (< 5.7%)
    static let normalUpperBound: Double = 39.0

    /// Above typical range: 39-47 mmol/mol (5.7-6.4%)
    static let prediabetesLowerBound: Double = 39.0
    static let prediabetesUpperBound: Double = 47.0

    /// Elevated range: ≥ 48 mmol/mol (≥ 6.5%)
    static let diabetesLowerBound: Double = 48.0

    /// Moderately elevated target: < 53 mmol/mol (< 7.0%)
    static let goodControlTarget: Double = 53.0
    
    /// Returns the range category for a given IFCC value
    /// NOTE: Labels are deliberately non-diagnostic to comply with Apple Guideline 5.1.1(ix)
    static func riskCategory(forIFCC value: Double) -> String {
        if value < normalUpperBound {
            return "Normal Range"
        } else if value < diabetesLowerBound {
            return "Above Typical Range"
        } else if value < goodControlTarget {
            return "Moderately Elevated"
        } else {
            return "Elevated"
        }
    }
    
    /// Returns threshold values in the specified unit
    static func thresholds(in unit: HbA1cUnit) -> (normal: Double, prediabetes: Double, diabetes: Double, goodControl: Double) {
        switch unit {
        case .ifcc:
            return (normalUpperBound, prediabetesUpperBound, diabetesLowerBound, goodControlTarget)
        case .ngsp:
            return (
                ifccToNGSP(normalUpperBound),
                ifccToNGSP(prediabetesUpperBound),
                ifccToNGSP(diabetesLowerBound),
                ifccToNGSP(goodControlTarget)
            )
        }
    }
}

// MARK: - Formatting Helpers

/// Formats an HbA1c value for display
/// - Parameters:
///   - value: The value to format
///   - unit: The unit for display
///   - includeUnit: Whether to append the unit string
/// - Returns: Formatted string
func formatHbA1c(_ value: Double, unit: HbA1cUnit, includeUnit: Bool = true) -> String {
    let decimalPlaces = unit == .ngsp ? 1 : 0
    let formatted = String(format: "%.\(decimalPlaces)f", value)
    let separator = unit == .ngsp ? "" : " "
    return includeUnit ? "\(formatted)\(separator)\(unit.shortUnit)" : formatted
}
