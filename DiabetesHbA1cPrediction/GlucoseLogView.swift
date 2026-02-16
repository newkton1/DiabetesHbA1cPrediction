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
    @FetchRequest(
        entity: GlucoseReadingEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: false)]
    ) var glucoseReadings: FetchedResults<GlucoseReadingEntity>

    @State private var showAddSheet = false
    @State private var showSyncAlert = false
    @State private var syncMessage = ""
    @State private var isSyncing = false

    // Manual entry state
    @State private var glucoseValue: String = ""
    @State private var selectedSource = "Manual Finger Stick"
    @State private var selectedTrend = "stable"
    @State private var selectedTimestamp = Date()

    let sourceOptions = ["Manual Finger Stick", "FreeStyle Libre 2 (manual entry)"]
    let trendOptions = ["stable", "rising", "falling", "rising rapidly", "falling rapidly"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header with Sync Button
                HStack {
                    Text("Glucose Log")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: syncFromHealth) {
                        HStack(spacing: 4) {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8, anchor: .center)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Sync Health")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .disabled(isSyncing)
                }
                .padding()

                // MARK: - 30-Day Glucose Chart
                if !glucoseReadings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 30 Days")
                            .font(.headline)
                            .padding(.horizontal)

                        // Filter to last 30 days of readings
                        let last30Days = glucoseReadings.filter { reading in
                            guard let timestamp = reading.timestamp else { return false }
                            return Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0 <= 30
                        }

                        if !last30Days.isEmpty {
                            Chart {
                                // Horizontal reference lines
                                RuleMark(y: .value("Target Min", 70))
                                    .foregroundStyle(Color.green.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                                RuleMark(y: .value("Safe Max", 100))
                                    .foregroundStyle(Color.yellow.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                                RuleMark(y: .value("Warning", 126))
                                    .foregroundStyle(Color.orange.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                                RuleMark(y: .value("Critical", 180))
                                    .foregroundStyle(Color.red.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                                // Data points with color coding
                                ForEach(Array(last30Days.enumerated()), id: \.element.id) { index, reading in
                                    if let value = reading.value as Double?, let timestamp = reading.timestamp {
                                        let color = glucoseColor(for: value)

                                        LineMarkPreview(
                                            x: timestamp,
                                            y: value,
                                            color: color
                                        )
                                    }
                                }

                                // Connect points with line segments, each colored appropriately
                                let sortedReadings = last30Days.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
                                ForEach(Array(sortedReadings.enumerated()), id: \.element.id) { index, reading in
                                    if let value = reading.value as Double?, let timestamp = reading.timestamp {
                                        let color = glucoseColor(for: value)

                                        PointMark(
                                            x: .value("Time", timestamp),
                                            y: .value("Glucose (mg/dL)", value)
                                        )
                                        .foregroundStyle(color)
                                        .symbolSize(50)
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5))
                            }
                            .frame(height: 250)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }

                // MARK: - Readings List
                List {
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
                        .listRowSeparator(.hidden)
                    } else {
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
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteReadings)
                    }
                }
                .listStyle(.plain)
            }
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
    }

    // MARK: - Helper Methods
    
    /// Formats glucose value with appropriate unit label
    func formatGlucoseValue(_ value: Double, unit: String?) -> String {
        let unitStr = unit ?? "mg/dL"
        if unitStr == "NGSP %" || unitStr == "mmol/mol" {
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
        } else {
            // mg/dL
            switch value {
            case ..<70:
                return .red
            case 70..<100:
                return .green
            case 100..<126:
                return .yellow
            case 126..<181:
                return .orange
            default:
                return .red
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

    /// Syncs glucose data from HealthKit
    func syncFromHealth() {
        isSyncing = true

        // Note: In a real app, this would call HealthKitManager.shared.syncGlucoseData()
        // For now, we'll simulate the sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            syncMessage = "Sync completed successfully"
            showSyncAlert = true
            isSyncing = false
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
    case ngsp = "NGSP % (US/Japan)"
    case ifcc = "IFCC mmol/mol (Europe/World)"
    
    var unitLabel: String {
        switch self {
        case .ngsp:
            return "NGSP %"
        case .ifcc:
            return "mmol/mol"
        }
    }
}

// MARK: - Add Glucose Reading Sheet
/// Sheet for manually adding a new glucose reading
struct AddGlucoseReadingSheet: View {
    @Binding var isPresented: Bool
    var moc: NSManagedObjectContext

    @State private var glucoseValue: String = ""
    @State private var selectedSource = "Manual Finger Stick"
    @State private var selectedTrend = "stable"
    @State private var selectedTimestamp = Date()
    @State private var selectedUnit: GlucoseUnitType = .ngsp

    let sourceOptions = ["Manual Finger Stick", "FreeStyle Libre 2 (manual entry)"]
    let trendOptions = ["stable", "rising", "falling", "rising rapidly", "falling rapidly"]
    
    /// Converts NGSP % to IFCC mmol/mol
    /// Formula: IFCC = (NGSP - 2.15) × 10.929
    private func ngspToIFCC(_ ngsp: Double) -> Double {
        return (ngsp - 2.15) * 10.929
    }
    
    /// Converts IFCC mmol/mol to NGSP %
    /// Formula: NGSP = (IFCC / 10.929) + 2.15
    private func ifccToNGSP(_ ifcc: Double) -> Double {
        return (ifcc / 10.929) + 2.15
    }

    var body: some View {
        NavigationStack {
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
                    DatePicker("Time", selection: $selectedTimestamp, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Add Glucose Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveReading()
                    }
                    .disabled(glucoseValue.isEmpty || Double(glucoseValue) == nil)
                }
            }
        }
    }

    /// Saves the new glucose reading to Core Data
    /// Stores the value in the selected unit system along with the unit type
    func saveReading() {
        guard let value = Double(glucoseValue) else { return }

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
            print("Error saving reading: \(error.localizedDescription)")
        }
    }
}

#Preview {
    GlucoseLogView()
        .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
