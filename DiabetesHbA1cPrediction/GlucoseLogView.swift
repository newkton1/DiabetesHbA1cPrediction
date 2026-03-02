import SwiftUI
import Charts
import CoreData

/// GlucoseLogView displays glucose readings with a 30-day chart and management capabilities
/// Features include:
/// - Line chart with color-coded segments based on glucose values
/// - List of readings with sources and trends
/// - Manual entry sheet
/// - HealthKit synchronization
/// - Swipe to delete functionality
struct GlucoseLogView: View {
    @Environment(\.managedObjectContext) var moc
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: false)]
    ) var glucoseReadings: FetchedResults<GlucoseReadingEntity>

    @State private var showAddSheet = false
    @State private var showSyncAlert = false
    @State private var syncMessage = ""
    @State private var isSyncing = false
    @State private var syncSuccess = false

    // Manual entry state
    @State private var glucoseValue: String = ""
    @State private var selectedSource = "Manual Finger Stick"
    @State private var selectedTrend = "stable"
    @State private var selectedTimestamp = Date()

    let sourceOptions = ["Manual Finger Stick", "FreeStyle Libre 2 (manual entry)"]
    let trendOptions = ["stable", "rising", "falling", "rising rapidly", "falling rapidly"]

    var body: some View {
        NavigationStack {
            if isPortrait {
                portraitBody
            } else {
                landscapeBody
            }
        }
    }

    // MARK: - Locale helpers

    /// True when device region is USA or Japan — use mg/dL for instantaneous glucose
    private var isMgdlRegion: Bool {
        let region = Locale.current.region?.identifier ?? ""
        return region == "US" || region == "JP"
    }

    /// Unit string for instantaneous glucose based on locale
    private var instantaneousGlucoseUnit: String {
        isMgdlRegion ? "mg/dL" : "mmol/L"
    }

    // MARK: - Portrait Body
    private var portraitBody: some View {
        VStack(spacing: 0) {
            chartSection
                .fixedSize(horizontal: false, vertical: true)

            readingsList
        }
        .navigationTitle("Glucose Readings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGlucoseReadingSheet(isPresented: $showAddSheet, moc: moc)
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK") { }
        } message: {
            Text(syncMessage)
        }
    }

    // MARK: - Landscape Body
    private var landscapeBody: some View {
        VStack(spacing: 0) {
            // Fixed header: title on left, + button on right
            HStack {
                Text("Instant Blood Glucose")
                    .font(.system(size: 22, weight: .bold))

                Spacer()
                
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Side-by-side: chart on left, readings list on right
            HStack(alignment: .top, spacing: 0) {
                chartSection
                    .frame(maxWidth: .infinity)

                // Right side: Sync Health button header + readings list
                VStack(alignment: .leading, spacing: 0) {
                    // Sync Health button aligned with "Last 30 Days" header on left
                    HStack {
                        Spacer()
                        Button(action: syncFromHealth) {
                            HStack(spacing: 4) {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8, anchor: .center)
                                } else {
                                    Image(systemName: syncSuccess ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                }
                                Text("Sync Health")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(syncSuccess ? .green : .blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background((syncSuccess ? Color.green : Color.blue).opacity(0.1))
                            .cornerRadius(6.6)
                            .animation(.easeInOut(duration: 0.3), value: syncSuccess)
                        }
                        .disabled(isSyncing)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    readingsList
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddSheet) {
            AddGlucoseReadingSheet(isPresented: $showAddSheet, moc: moc)
        }
        .alert("Sync Status", isPresented: $showSyncAlert) {
            Button("OK") { }
        } message: {
            Text(syncMessage)
        }
    }

    // MARK: - Chart Section (fixed height, no ScrollView)
    @ViewBuilder
    private var chartSection: some View {
        if !glucoseReadings.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Last 30 Days")
                        .font(.headline)

                    Spacer()

                    // Show Sync Health button here only in portrait mode
                    if isPortrait {
                        Button(action: syncFromHealth) {
                            HStack(spacing: 4) {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.88, anchor: .center)
                                } else {
                                    Image(systemName: syncSuccess ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                }
                                Text("Sync Health")
                                    .font(.system(size: 13.2))
                            }
                            .foregroundColor(syncSuccess ? .green : .blue)
                            .padding(.horizontal, 13.2)
                            .padding(.vertical, 8.8)
                            .background((syncSuccess ? Color.green : Color.blue).opacity(0.1))
                            .cornerRadius(6.6)
                            .animation(.easeInOut(duration: 0.3), value: syncSuccess)
                        }
                        .disabled(isSyncing)
                    }
                }
                .padding(.horizontal)

                // Filter to last 30 days of glucose readings (exclude HbA1c lab results)
                let hba1cUnits: Set<String> = ["NGSP %", "mmol/mol"]
                let last30Days = glucoseReadings.filter { reading in
                    guard let timestamp = reading.timestamp else { return false }
                    let isHbA1c = hba1cUnits.contains(reading.unit ?? "")
                    let withinWindow = Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0 <= 30
                    return !isHbA1c && withinWindow
                }

                if !last30Days.isEmpty {
                    // Determine the predominant unit type for scale
                    let chartUnitType = predominantUnitType(for: Array(last30Days))
                    let yAxisRange = yAxisRange(for: chartUnitType)

                    Chart {
                        // Horizontal reference lines based on unit type
                        if chartUnitType == "NGSP %" {
                            RuleMark(y: .value("Target", 6.5))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Warning", 7.0))
                                .foregroundStyle(Color.red.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        } else if chartUnitType == "mmol/mol" {
                            RuleMark(y: .value("Target", 47))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Warning", 53))
                                .foregroundStyle(Color.red.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        } else if chartUnitType == "mmol/L" {
                            // mmol/L reference lines
                            RuleMark(y: .value("Hypo", 3.9))
                                .foregroundStyle(Color.red.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Normal", 5.6))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Warning", 7.8))
                                .foregroundStyle(Color.orange.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        } else {
                            // mg/dL reference lines
                            RuleMark(y: .value("Target Min", 70))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Safe Max", 100))
                                .foregroundStyle(Color.yellow.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Warning", 126))
                                .foregroundStyle(Color.orange.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                            RuleMark(y: .value("Critical", 180))
                                .foregroundStyle(Color.red.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        }

                        // Connecting line — single series so SwiftUI Charts joins all points
                        let sortedLine = last30Days.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
                        ForEach(Array(sortedLine.enumerated()), id: \.element.id) { _, reading in
                            if let value = reading.value as Double?, let timestamp = reading.timestamp {
                                LineMark(
                                    x: .value("Time", timestamp),
                                    y: .value("Glucose", value)
                                )
                                .foregroundStyle(Color.blue.opacity(0.45))
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                            }
                        }

                        // Colour-coded data points on top of the line
                        ForEach(Array(sortedLine.enumerated()), id: \.element.id) { _, reading in
                            if let value = reading.value as Double?, let timestamp = reading.timestamp {
                                let color = glucoseColor(for: value, unit: reading.unit)
                                PointMark(
                                    x: .value("Time", timestamp),
                                    y: .value("Glucose", value)
                                )
                                .foregroundStyle(color)
                                .symbolSize(50)
                            }
                        }
                    }
                    .chartYScale(domain: yAxisRange.min...yAxisRange.max)
                    .chartYAxis {
                        let stride: Double = {
                            if chartUnitType == "NGSP %" { return 1 }
                            if chartUnitType == "mmol/mol" { return 20 }
                            if chartUnitType == "mmol/L" { return 1 }
                            return 20  // mg/dL
                        }()
                        AxisMarks(position: .leading, values: .stride(by: stride)) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic(desiredCount: isPortrait ? 4 : 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                                .font(.system(size: isPortrait ? 10 : 9))
                        }
                    }
                    .chartPlotStyle { plotArea in
                        plotArea
                            .frame(height: isPortrait ? 140 : 120)
                    }
                    .frame(height: isPortrait ? 180 : 160)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, isPortrait ? 8 : 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(alignment: .leading) {
                        // Vertical y-axis label — shown in both portrait and landscape
                        let yLabel = "Glucose Level \(chartUnitType)"
                        VStack(spacing: 0) {
                            ForEach(Array(yLabel.enumerated()), id: \.offset) { _, char in
                                Text(String(char))
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .offset(x: -2)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Readings List (top-level List — supports swipeActions)
    @ViewBuilder
    private var readingsList: some View {
        if glucoseReadings.isEmpty {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("No Glucose Readings")
                    .font(.headline)

                Text("Add your first reading or sync from Health")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
        } else {
            List {
                ForEach(glucoseReadings, id: \.id) { reading in
                    HStack(spacing: 12) {
                        // Glucose value with color coding
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(formatGlucoseValue(reading.value, unit: reading.unit))
                                    .font(.headline)
                                    .foregroundColor(glucoseColor(for: reading.value, unit: reading.unit))

                                // Trend arrow
                                if let trend = reading.trend {
                                    Image(systemName: trendIcon(for: trend))
                                        .font(.caption2)
                                        .foregroundColor(glucoseColor(for: reading.value, unit: reading.unit))
                                }
                            }

                            // Time
                            if let timestamp = reading.timestamp {
                                Text(formatTime(timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Source icon
                        HStack(spacing: 8) {
                            Image(systemName: sourceIcon(for: reading.source ?? ""))
                                .font(.headline)
                                .foregroundColor(.blue)

                            Text(reading.source ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            moc.delete(reading)
                            try? moc.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Helper Methods

    /// Determines the predominant unit type from a collection of readings
    /// Used to set appropriate chart scale
    func predominantUnitType(for readings: [GlucoseReadingEntity]) -> String {
        var unitCounts: [String: Int] = [:]
        for reading in readings {
            let unit = reading.unit ?? "mg/dL"
            unitCounts[unit, default: 0] += 1
        }
        return unitCounts.max(by: { $0.value < $1.value })?.key ?? "mg/dL"
    }
    
    /// Returns the appropriate Y-axis range based on unit type and locale
    /// - NGSP %: 4 to 10 (portrait) or 4 to 13 (landscape)
    /// - IFCC mmol/mol: 20 to 120 (portrait) or 20 to 200 (landscape)
    /// - mg/dL (US/JP): 60 to 180
    /// - mmol/L (other regions): 3 to 10
    func yAxisRange(for unitType: String) -> (min: Double, max: Double) {
        switch unitType {
        case "NGSP %":
            return isPortrait ? (min: 4, max: 10) : (min: 4, max: 13)
        case "mmol/mol":
            return isPortrait ? (min: 20, max: 120) : (min: 20, max: 200)
        case "mmol/L":
            return (min: 3, max: 10)
        default: // mg/dL
            return (min: 60, max: 180)
        }
    }
    
    /// Formats glucose value with appropriate unit label
    func formatGlucoseValue(_ value: Double, unit: String?) -> String {
        let unitStr = unit ?? "mg/dL"
        if unitStr == "NGSP %" || unitStr == "mmol/mol" || unitStr == "mmol/L" {
            return String(format: "%.1f %@", value, unitStr)
        } else {
            return "\(Int(value)) \(unitStr)"
        }
    }

    /// Returns the appropriate color for a glucose value based on unit type
    /// For mg/dL:
    /// - Green: 70-99 (target range)
    /// - Yellow: 100-125 (slightly elevated)
    /// - Orange: 126-180 (elevated)
    /// - Red: >180 or <70 (critical)
    /// For NGSP %:
    /// - Green: ≤6.5%
    /// - Red: >6.5%
    /// For IFCC mmol/mol:
    /// - Green: ≤47 mmol/mol
    /// - Red: >47 mmol/mol
    func glucoseColor(for value: Double, unit: String? = nil) -> Color {
        let unitStr = unit ?? "mg/dL"

        if unitStr == "NGSP %" {
            return value <= 6.5 ? .green : .red
        } else if unitStr == "mmol/mol" {
            return value <= 47 ? .green : .red
        } else if unitStr == "mmol/L" {
            switch value {
            case ..<3.9:        return .red     // hypoglycemia
            case 3.9..<5.6:     return .green   // normal
            case 5.6..<7.0:     return .yellow  // slightly elevated
            case 7.0..<10.0:    return .orange  // elevated
            default:            return .red     // very high
            }
        } else {
            // mg/dL
            switch value {
            case ..<70:         return .red
            case 70..<100:      return .green
            case 100..<126:     return .yellow
            case 126..<181:     return .orange
            default:            return .red
            }
        }
    }

    /// Returns the appropriate SF Symbol for a trend value
    func trendIcon(for trend: String) -> String {
        switch trend.lowercased() {
        case "rising rapidly":
            return "arrow.up.up"
        case "rising":
            return "arrow.up"
        case "stable":
            return "minus"
        case "falling":
            return "arrow.down"
        case "falling rapidly":
            return "arrow.down.down"
        default:
            return "minus"
        }
    }

    /// Returns the appropriate SF Symbol for a source value
    func sourceIcon(for source: String) -> String {
        switch source.lowercased() {
        case "freestyle libre 2 (manual entry)":
            return "waveform.circle.fill"
        case "manual finger stick":
            return "drop.fill"
        case "healthkit":
            return "heart.fill"
        case "hospital lab test":
            return "cross.case.fill"
        default:
            return "questionmark.circle"
        }
    }

    /// Formats a Date to "HH:mm MM/dd" format
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm MM/dd"
        return formatter.string(from: date)
    }

    /// Syncs glucose data from HealthKit (FreeStyle Libre 2 / manual entries)
    func syncFromHealth() {
        isSyncing = true

        Task {
            let healthKitManager = HealthKitManager.shared

            // Ensure we have HealthKit authorization first
            let authorized = await healthKitManager.requestAuthorization()
            guard authorized else {
                await MainActor.run {
                    syncMessage = "HealthKit authorization denied. Please enable access in Settings > Health > Data Access & Devices."
                    showSyncAlert = true
                    isSyncing = false
                }
                return
            }

            // Sync glucose readings from HealthKit to CoreData (includes FreeStyle Libre 2 data)
            let glucoseCount = await healthKitManager.syncGlucoseToCorData(context: moc, days: 30)

            await MainActor.run {
                if glucoseCount > 0 {
                    syncMessage = "Sync completed successfully! Imported \(glucoseCount) new glucose reading\(glucoseCount == 1 ? "" : "s") from HealthKit."
                } else {
                    syncMessage = "Sync completed. No new glucose readings found in HealthKit for the last 30 days."
                }
                showSyncAlert = true
                isSyncing = false
                syncSuccess = true

                // Reset success indicator after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    syncSuccess = false
                }
            }
        }
    }

    /// Deletes glucose readings at the specified offsets
    func deleteReadings(at offsets: IndexSet) {
        for index in offsets {
            let reading = glucoseReadings[index]
            moc.delete(reading)
        }

        do {
            try moc.save()
        } catch {
            print("Error deleting reading: \(error.localizedDescription)")
        }
    }
}

// MARK: - LineMarkPreview Helper
/// Helper struct to create line segments with color coding
struct LineMarkPreview: ChartContent {
    let x: Date
    let y: Double
    let color: Color

    var body: some ChartContent {
        PointMark(x: .value("Time", x), y: .value("Glucose", y))
            .foregroundStyle(color)
    }
}

// MARK: - Glucose Unit Types
/// Enum representing different glucose measurement unit systems
enum GlucoseUnitType: String, CaseIterable {
    case mgdl = "mg/dL (US/Japan)"
    case mmoll = "mmol/L (Europe/World)"

    var unitLabel: String {
        switch self {
        case .mgdl:
            return "mg/dL"
        case .mmoll:
            return "mmol/L"
        }
    }

    /// Returns the locale-appropriate default unit
    static var localeDefault: GlucoseUnitType {
        let region = Locale.current.region?.identifier ?? ""
        return (region == "US" || region == "JP") ? .mgdl : .mmoll
    }
}

// MARK: - Add Reading Entry Type
/// Segmented control options for the Add Reading sheet
enum AddReadingEntryType: String, CaseIterable {
    case glucose = "Glucose Reading"
    case hba1c = "HbA1c Lab Result"
}

// MARK: - Add Glucose Reading Sheet
/// Sheet for manually adding a new glucose reading or HbA1c lab result
/// Uses a segmented control (Option B) to switch between the two entry forms
struct AddGlucoseReadingSheet: View {
    @Binding var isPresented: Bool
    var moc: NSManagedObjectContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ObservedObject private var hba1cProfile = HbA1cUserProfile.shared

    // MARK: - Segmented tab selection
    @State private var selectedEntryType: AddReadingEntryType = .glucose

    // MARK: - Glucose Reading State
    @State private var glucoseValue: String = ""
    @State private var selectedSource = "Manual Finger Stick"
    @State private var selectedTrend = "stable"
    @State private var selectedTimestamp = Date()
    @State private var selectedUnit: GlucoseUnitType = .localeDefault

    // MARK: - HbA1c Lab Result State
    @State private var hba1cValue: String = ""
    @State private var hba1cLabDate = Date()
    @State private var hba1cUnitOverride: HbA1cUnit? = nil

    let sourceOptions = ["Manual Finger Stick", "FreeStyle Libre 2 (manual entry)"]
    let trendOptions = ["stable", "rising", "falling", "rising rapidly", "falling rapidly"]

    /// Parses the typed glucose value using the device locale so both
    /// period (US/JP: "6.5") and comma (EU: "6,5") decimal separators work.
    private var parsedGlucoseValue: Double? {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: glucoseValue)?.doubleValue
    }

    /// Parses the typed HbA1c value using the device locale
    private var parsedHbA1cValue: Double? {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: hba1cValue)?.doubleValue
    }

    /// The effective HbA1c unit: local override on this sheet, or the profile default
    private var effectiveHbA1cUnit: HbA1cUnit {
        hba1cUnitOverride ?? hba1cProfile.effectiveUnit
    }

    /// Validates the HbA1c value falls within a clinically plausible range
    private var isHbA1cValueValid: Bool {
        guard let value = parsedHbA1cValue else { return false }
        switch effectiveHbA1cUnit {
        case .ngsp:
            return value >= 3.0 && value <= 20.0   // % range
        case .ifcc:
            return value >= 9.0 && value <= 195.0   // mmol/mol range
        }
    }

    /// How many weeks ago the selected lab date is (for the decay note)
    private var labDateWeeksAgo: Int {
        let days = Calendar.current.dateComponents([.day], from: hba1cLabDate, to: Date()).day ?? 0
        return max(0, days / 7)
    }

    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }

    /// Whether the Save button should be enabled
    private var isSaveDisabled: Bool {
        switch selectedEntryType {
        case .glucose:
            return glucoseValue.isEmpty || parsedGlucoseValue == nil
        case .hba1c:
            return hba1cValue.isEmpty || !isHbA1cValueValid
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Entry Type", selection: $selectedEntryType) {
                    ForEach(AddReadingEntryType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, isPortrait ? 10 : 6)
                .padding(.bottom, 4)

                // Show the appropriate form based on selected segment
                switch selectedEntryType {
                case .glucose:
                    glucoseForm
                case .hba1c:
                    hba1cForm
                }
            }
            .navigationTitle(isPortrait ? "" : "Add Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        switch selectedEntryType {
                        case .glucose:
                            saveGlucoseReading()
                        case .hba1c:
                            saveHbA1cLabResult()
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    // MARK: - Glucose Reading Form

    private var glucoseForm: some View {
        Form {
            Section("Glucose Value Units") {
                Picker("Unit System", selection: $selectedUnit) {
                    ForEach(GlucoseUnitType.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            }

            Section("Glucose Value") {
                HStack {
                    TextField("Enter value", text: $glucoseValue)
                        .keyboardType(.decimalPad)
                    Text(selectedUnit.unitLabel)
                        .foregroundColor(.secondary)
                }
            }

            Section("Source") {
                Picker("Source", selection: $selectedSource) {
                    ForEach(sourceOptions, id: \.self) { source in
                        Text(source).tag(source)
                    }
                }
            }

            Section("Trend") {
                Picker("Trend", selection: $selectedTrend) {
                    ForEach(trendOptions, id: \.self) { trend in
                        Text(trend.capitalized).tag(trend)
                    }
                }
            }

            Section("Timestamp") {
                DatePicker("Time", selection: $selectedTimestamp, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
            }
        }
    }

    // MARK: - HbA1c Lab Result Form

    private var hba1cForm: some View {
        Form {
            Section {
                HStack {
                    Text("Unit System")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(effectiveHbA1cUnit.displayName)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }

                Picker("Override Unit", selection: $hba1cUnitOverride) {
                    Text("Auto (\(hba1cProfile.effectiveUnit.shortUnit))").tag(nil as HbA1cUnit?)
                    ForEach(HbA1cUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit as HbA1cUnit?)
                    }
                }
            } header: {
                Text("HbA1c Units")
            } footer: {
                Text("Auto-detected from your region (\(hba1cProfile.countryName)). Override if your lab report uses a different standard.")
            }

            Section("HbA1c Value") {
                HStack {
                    TextField("Enter lab result", text: $hba1cValue)
                        .keyboardType(.decimalPad)
                    Text(effectiveHbA1cUnit.shortUnit)
                        .foregroundColor(.secondary)
                }

                if parsedHbA1cValue != nil && !isHbA1cValueValid {
                    Text("Value out of clinical range")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section {
                DatePicker("Lab Test Date", selection: $hba1cLabDate, in: ...Date(),
                           displayedComponents: [.date])
            } header: {
                Text("Lab Test Date")
            } footer: {
                Text(labDateWeightDescription)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Time-Weighted Impact", systemImage: "chart.line.downtrend.xyaxis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Lab results from the last 4 weeks have full impact on your estimated HbA1c. Impact decreases for results 1–3 months old, and results older than 3 months are excluded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// Describes the weight this lab result will receive based on its date
    private var labDateWeightDescription: String {
        let weeks = labDateWeeksAgo
        if weeks <= 4 {
            return "This result is within 4 weeks — it will have full weight in your HbA1c estimate."
        } else if weeks <= 8 {
            return "This result is \(weeks) weeks old — it will have moderate weight in your HbA1c estimate."
        } else if weeks <= 12 {
            return "This result is \(weeks) weeks old — it will have reduced weight in your HbA1c estimate."
        } else {
            return "This result is over 3 months old — it will not be included in your HbA1c estimate."
        }
    }

    // MARK: - Save Actions

    /// Saves a new glucose reading to Core Data
    func saveGlucoseReading() {
        guard let value = parsedGlucoseValue else { return }

        let newReading = GlucoseReadingEntity(context: moc)
        newReading.id = UUID()
        newReading.value = value
        newReading.timestamp = selectedTimestamp
        newReading.source = selectedSource
        newReading.trend = selectedTrend
        newReading.unit = selectedUnit.unitLabel

        do {
            try moc.save()
            isPresented = false
        } catch {
            print("Error saving glucose reading: \(error.localizedDescription)")
        }
    }

    /// Saves a manual HbA1c lab result to Core Data as a GlucoseReadingEntity
    /// Stores the value in the user's selected HbA1c unit with a special source marker
    func saveHbA1cLabResult() {
        guard let value = parsedHbA1cValue, isHbA1cValueValid else { return }

        let newReading = GlucoseReadingEntity(context: moc)
        newReading.id = UUID()
        newReading.value = value
        newReading.timestamp = hba1cLabDate
        newReading.source = "Hospital Lab Test"
        newReading.trend = nil

        // Store with the unit label that matches what fetchPriorHbA1cReadings expects
        switch effectiveHbA1cUnit {
        case .ngsp:
            newReading.unit = "NGSP %"
        case .ifcc:
            newReading.unit = "mmol/mol"
        }

        do {
            try moc.save()
            isPresented = false
        } catch {
            print("Error saving HbA1c lab result: \(error.localizedDescription)")
        }
    }
}

#Preview {
    GlucoseLogView()
        .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
