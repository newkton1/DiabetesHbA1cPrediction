import Foundation

// MARK: - Country to HbA1c Unit Mapping

/// Maps ISO 3166-1 alpha-2 country codes to their primary HbA1c reporting unit
struct CountryHbA1cMapping {
    
    /// Countries that primarily use NGSP (%) for HbA1c reporting
    /// Includes: United States, Japan, and several Asian/Middle Eastern countries
    private static let ngspCountries: Set<String> = [
        // North America
        "US", // United States
        "CA", // Canada (uses both, but NGSP more common clinically)
        
        // Asia - NGSP dominant
        "JP", // Japan
        "KR", // South Korea
        "TW", // Taiwan
        "CN", // China
        "HK", // Hong Kong
        "SG", // Singapore
        "MY", // Malaysia
        "TH", // Thailand
        "PH", // Philippines
        "ID", // Indonesia
        "VN", // Vietnam
        "IN", // India
        "PK", // Pakistan
        "BD", // Bangladesh
        "LK", // Sri Lanka
        "NP", // Nepal
        
        // Middle East - mixed but NGSP common
        "SA", // Saudi Arabia
        "AE", // United Arab Emirates
        "KW", // Kuwait
        "QA", // Qatar
        "BH", // Bahrain
        "OM", // Oman
        "JO", // Jordan
        "LB", // Lebanon
        "IL", // Israel
        "TR", // Turkey
        "EG", // Egypt
        
        // Latin America - NGSP dominant
        "MX", // Mexico
        "BR", // Brazil
        "AR", // Argentina
        "CL", // Chile
        "CO", // Colombia
        "PE", // Peru
        "VE", // Venezuela
        "EC", // Ecuador
        "BO", // Bolivia
        "PY", // Paraguay
        "UY", // Uruguay
        "CR", // Costa Rica
        "PA", // Panama
        "GT", // Guatemala
        "HN", // Honduras
        "SV", // El Salvador
        "NI", // Nicaragua
        "DO", // Dominican Republic
        "PR", // Puerto Rico
        "CU", // Cuba
        
        // Africa - NGSP common
        "ZA", // South Africa
        "NG", // Nigeria
        "KE", // Kenya
        "GH", // Ghana
        "TZ", // Tanzania
        "UG", // Uganda
        "ET", // Ethiopia
        "MA", // Morocco
        "DZ", // Algeria
        "TN", // Tunisia
    ]
    
    /// Countries that primarily use IFCC (mmol/mol) for HbA1c reporting
    /// Includes: European Union, UK, Australia, New Zealand
    private static let ifccCountries: Set<String> = [
        // European Union & EEA
        "AT", // Austria
        "BE", // Belgium
        "BG", // Bulgaria
        "HR", // Croatia
        "CY", // Cyprus
        "CZ", // Czech Republic
        "DK", // Denmark
        "EE", // Estonia
        "FI", // Finland
        "FR", // France
        "DE", // Germany
        "GR", // Greece
        "HU", // Hungary
        "IE", // Ireland
        "IT", // Italy
        "LV", // Latvia
        "LT", // Lithuania
        "LU", // Luxembourg
        "MT", // Malta
        "NL", // Netherlands
        "PL", // Poland
        "PT", // Portugal
        "RO", // Romania
        "SK", // Slovakia
        "SI", // Slovenia
        "ES", // Spain
        "SE", // Sweden
        
        // UK & Commonwealth (IFCC)
        "GB", // United Kingdom
        "AU", // Australia
        "NZ", // New Zealand
        
        // Other European
        "NO", // Norway
        "CH", // Switzerland
        "IS", // Iceland
        "LI", // Liechtenstein
        
        // Scandinavian
        "FO", // Faroe Islands
        "GL", // Greenland
    ]
    
    /// Returns the default HbA1c unit for a given country code
    /// - Parameter countryCode: ISO 3166-1 alpha-2 country code
    /// - Returns: The primary HbA1c unit used in that country
    static func defaultUnit(forCountryCode countryCode: String) -> HbA1cUnit {
        let code = countryCode.uppercased()
        
        if ifccCountries.contains(code) {
            return .ifcc
        } else if ngspCountries.contains(code) {
            return .ngsp
        } else {
            // Default to NGSP for unmapped countries (more globally prevalent)
            return .ngsp
        }
    }
    
    /// Returns the default HbA1c unit based on the device's current locale
    /// - Returns: The HbA1c unit for the user's region
    static func defaultUnitFromLocale() -> HbA1cUnit {
        if let regionCode = Locale.current.region?.identifier {
            return defaultUnit(forCountryCode: regionCode)
        }
        // Fallback to NGSP if region cannot be determined
        return .ngsp
    }
    
    /// Returns the country name for a given country code
    /// - Parameter countryCode: ISO 3166-1 alpha-2 country code
    /// - Returns: Localized country name, or the code if not found
    static func countryName(forCode countryCode: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }
    
    /// Returns a list of all supported countries with their default units
    /// - Returns: Array of tuples containing (countryCode, countryName, defaultUnit)
    static func allSupportedCountries() -> [(code: String, name: String, unit: HbA1cUnit)] {
        let allCodes = ngspCountries.union(ifccCountries)
        return allCodes
            .map { code in
                (code: code, name: countryName(forCode: code), unit: defaultUnit(forCountryCode: code))
            }
            .sorted { $0.name < $1.name }
    }
}
