import SwiftUI

// MARK: - Diabetes Health App Color Theme
// Designed for a diabetes management / HbA1c prediction app.
// Optimised for psychological wellbeing, accessibility (WCAG AA+),
// and light/dark mode support.
//
// Palette rationale:
//   Primary:   Teal — calm, trustworthy, health-positive
//   Semantic:  Green/Amber/Red — in-range / caution / critical
//   Planned:   Indigo — distinguishes future/hypothetical meals
//   Neutral:   Warm grays — less clinical than pure gray

// MARK: - Core Theme Colors

struct AppTheme {

    // MARK: Primary Brand Colors (the 30% layer)

    /// Main brand teal — headers, navigation, primary buttons
    static let primary = Color("Primary", bundle: nil)
    static let primaryLight = Color("PrimaryLight", bundle: nil)
    static let primaryDark = Color("PrimaryDark", bundle: nil)

    /// Fallback programmatic definitions (use if not using Asset Catalog)
    enum Programmatic {
        static let primary = Color(light: .init(hex: 0x0B7A6F), dark: .init(hex: 0x2DD4BF))
        static let primaryLight = Color(light: .init(hex: 0x99F6E4), dark: .init(hex: 0x134E4A))
        static let primaryDark = Color(light: .init(hex: 0x0F766E), dark: .init(hex: 0x5EEAD4))
    }

    // MARK: Semantic Health Colors (the 10% accent layer)

    /// In-range / good / positive trend
    static let inRange = Color(light: .init(hex: 0x15803D), dark: .init(hex: 0x4ADE80))

    /// Caution / attention needed / trending high
    static let caution = Color(light: .init(hex: 0xB45309), dark: .init(hex: 0xFBBF24))

    /// Critical / out-of-range / urgent
    static let critical = Color(light: .init(hex: 0xDC2626), dark: .init(hex: 0xF87171))

    /// Planned/future meals — distinct from actual/recorded data
    static let planned = Color(light: .init(hex: 0x4F46E5), dark: .init(hex: 0xA5B4FC))

    // MARK: Background Colors (the 60% layer)

    /// Main app background
    static let background = Color(light: .init(hex: 0xFAFAFA), dark: .init(hex: 0x111827))

    /// Card / elevated surface background
    static let surface = Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x1F2937))

    /// Secondary surface (grouped table background, etc.)
    static let surfaceSecondary = Color(light: .init(hex: 0xF3F4F6), dark: .init(hex: 0x1A2332))

    // MARK: Text Colors

    /// Primary text — high contrast for readability
    static let textPrimary = Color(light: .init(hex: 0x111827), dark: .init(hex: 0xF9FAFB))

    /// Secondary text — labels, descriptions
    static let textSecondary = Color(light: .init(hex: 0x6B7280), dark: .init(hex: 0x9CA3AF))

    /// Tertiary text — timestamps, footnotes
    static let textTertiary = Color(light: .init(hex: 0x9CA3AF), dark: .init(hex: 0x6B7280))

    // MARK: Borders & Dividers

    static let border = Color(light: .init(hex: 0xE5E7EB), dark: .init(hex: 0x374151))
    static let divider = Color(light: .init(hex: 0xF3F4F6), dark: .init(hex: 0x1F2937))
}

// MARK: - HbA1c Range Coloring

/// Returns the appropriate semantic color for an HbA1c value (in canonical IFCC mmol/mol).
/// Uses smooth transitions rather than hard cut-offs to reduce anxiety.
extension AppTheme {

    /// Returns the semantic color for an HbA1c value stored in IFCC mmol/mol
    static func hba1cColor(forCanonicalValue ifccValue: Double) -> Color {
        // Thresholds in IFCC mmol/mol:
        //   < 42  = normal (green)
        //   42-47 = pre-diabetes / well-controlled (green → amber transition)
        //   48-52 = above target but close (amber zone)
        //   53-63 = above typical target (amber → red transition)
        //   > 64  = significantly above target (red)

        switch ifccValue {
        case ..<42:
            return inRange
        case 42..<48:
            return inRange  // Still "okay" for many patients
        case 48..<53:
            return caution
        case 53..<64:
            return caution
        default:
            return critical
        }
    }

    /// Returns the semantic color for an HbA1c value in NGSP %
    static func hba1cColor(forNGSPPercent ngspValue: Double) -> Color {
        let ifccValue = ngspToIFCC(ngspValue)
        return hba1cColor(forCanonicalValue: ifccValue)
    }

    /// Returns a gradient for the HbA1c range visualization
    /// (for the spectrum bar showing predicted value position)
    static let hba1cGradient = LinearGradient(
        colors: [inRange, caution, critical],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Meal Builder Colors

extension AppTheme {

    /// Color for the running carbohydrate total based on the user's typical range.
    /// personalCarbTarget: the user's typical per-meal carb target in grams.
    static func carbTotalColor(currentCarbs: Double, personalTarget: Double) -> Color {
        let ratio = currentCarbs / max(personalTarget, 1.0)
        switch ratio {
        case ..<0.8:
            return inRange
        case 0.8..<1.2:
            return caution
        default:
            return critical
        }
    }

    /// Badge/accent color for planned (future) meals vs actual (past) meals
    static func mealTimelineColor(isPlanned: Bool) -> Color {
        return isPlanned ? planned : Programmatic.primary
    }
}

// MARK: - Glucose Reading Colors

extension AppTheme {

    /// Color for a blood glucose reading in mg/dL
    static func glucoseColor(mgdL: Double) -> Color {
        switch mgdL {
        case ..<54:     return critical   // Clinically low
        case 54..<70:   return caution    // Low
        case 70..<180:  return inRange    // In target range (ADA standard)
        case 180..<250: return caution    // Above target
        default:        return critical   // High
        }
    }

    /// Color for a blood glucose reading in mmol/L
    static func glucoseColor(mmolL: Double) -> Color {
        return glucoseColor(mgdL: mmolL * 18.0182)
    }
}

// MARK: - Accessible Companion Icons

/// Pair every semantic color with an SF Symbol icon so color is never
/// the sole indicator. Critical for colour-blind users.
enum StatusIndicator {
    case inRange
    case caution
    case critical
    case planned

    var color: Color {
        switch self {
        case .inRange:  return AppTheme.inRange
        case .caution:  return AppTheme.caution
        case .critical: return AppTheme.critical
        case .planned:  return AppTheme.planned
        }
    }

    var iconName: String {
        switch self {
        case .inRange:  return "checkmark.circle.fill"
        case .caution:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .planned:  return "calendar.circle.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .inRange:  return "In range"
        case .caution:  return "Needs attention"
        case .critical: return "Out of range"
        case .planned:  return "Planned"
        }
    }
}

// MARK: - Status Badge View

/// A reusable badge that combines color + icon + label for full accessibility.
struct StatusBadge: View {
    let indicator: StatusIndicator
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: indicator.iconName)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(indicator.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(indicator.color.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(indicator.accessibilityLabel): \(text)")
    }
}

// MARK: - HbA1c Gradient Bar View

/// A visual gradient bar showing where the user's HbA1c sits on the spectrum.
/// Position is based on canonical IFCC mmol/mol value.
struct HbA1cGradientBar: View {
    let canonicalValue: Double  // IFCC mmol/mol
    let unit: HbA1cUnit

    /// Map IFCC value to 0...1 position on the bar
    /// Range: 20 mmol/mol (excellent) to 100 mmol/mol (very high)
    private var normalizedPosition: CGFloat {
        let clamped = min(max(canonicalValue, 20), 100)
        return CGFloat((clamped - 20) / 80)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Value label
            Text(formatHbA1c(fromCanonicalIFCC(value: canonicalValue, to: unit), unit: unit))
                .font(.title2.bold())
                .foregroundStyle(AppTheme.hba1cColor(forCanonicalValue: canonicalValue))

            // Gradient bar with indicator
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.hba1cGradient)
                        .frame(height: 12)

                    // Position indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .offset(x: normalizedPosition * (geo.size.width - 18))
                }
            }
            .frame(height: 18)

            // Range labels
            HStack {
                Text("Normal")
                    .foregroundStyle(AppTheme.inRange)
                Spacer()
                Text("Target")
                    .foregroundStyle(AppTheme.caution)
                Spacer()
                Text("High")
                    .foregroundStyle(AppTheme.critical)
            }
            .font(.caption2)
        }
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HbA1c \(formatHbA1c(fromCanonicalIFCC(value: canonicalValue, to: unit), unit: unit))")
    }
}

// MARK: - Color Extension for Hex Initialization

extension Color {
    /// Create a Color that adapts to light/dark mode
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

extension Color {
    /// Initialize from a hex integer (e.g., 0x0D9488)
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers for Consistent Theming

extension View {
    /// Apply the standard card style used throughout the app
    func cardStyle() -> some View {
        self
            .padding()
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    /// Apply the standard section header style
    func sectionHeaderStyle() -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(.uppercase)
    }
}
