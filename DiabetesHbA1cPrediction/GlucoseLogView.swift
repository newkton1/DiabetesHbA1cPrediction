import SwiftUI
import Charts
import CoreData

/// Returns a display-friendly source name, shortening long labels for the UI
/// while keeping the stored Core Data value unchanged
private func sourceDisplayName(_ source: String) -> String {
    switch source {
    case "Manual Finger Stick":
        return "Finger\nStick"
    case "Continuous Glucose Monitor":
        return "CGM"
    default:
        return source
    }
}

/// GlucoseLogView displays glucose readings with an interactive chart and management capabilities
/// Features include:
/// - 7-day (expandable to 14-day) interactive chart with tap-to-reveal hotspot popovers
/// - Spike detection and meal/exercise correlation via GlucoseCurveProcessor
/// - CGM-density thinning for clean curves with full resolution around spikes
/// - Data gap detection (>2h gaps break the line)
/// - List of readings with sources and trends
/// - Manual entry sheet with glucose and HbA1c lab result tabs
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

    @FetchRequest(
        entity: MealEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]
    ) var meals: FetchedResults<MealEntity>

    @FetchRequest(
        entity: ExerciseSessionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: false)]
    ) var exerciseSessions: FetchedResults<ExerciseSessionEntity>

    // Interactive chart state
    @State private var showExtendedWindow = false
    @State private var selectedHotspot: CurveHotspot? = nil
    @State private var popoverAnchorRight = false  // true → align popover to trailing edge
    @State private var weightSamples: [WeightSampleRecord] = []
    /// Anchor date for the chart window's right edge. nil = "now" (default).
    /// Set by tapping a reading in the list to scroll the chart to that date.
    @State private var chartAnchorDate: Date? = nil
    /// Timestamp of a reading tapped in the list — triggers hotspot selection
    /// after the chart window has moved.
    @State private var pendingSelectionDate: Date? = nil
    /// Timestamp of the reading selected in the list — shown as a vertical
    /// indicator line on the chart even when there is no matching hotspot.
    @State private var selectedReadingDate: Date? = nil

    @State private var showAddSheet = false
    @State private var showSyncAlert = false
    @State private var syncMessage = ""
    @State private var isSyncing = false
    @State private var syncSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showHealthKitError = false

    // Manual entry state
    @State private var glucoseValue: String = ""
    @State private var selectedSource = "Manual Finger Stick"
    @State private var selectedTrend = "stable"
    @State private var selectedTimestamp = Date()

    let sourceOptions = ["Manual Finger Stick", "Continuous Glucose Monitor"]
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

    // MARK: - Spike ↔ Meal Correlations

    /// Lookup of glucose reading → high-GI meal that preceded a spike.
    /// Only populated for readings ≥170 mg/dL (or mmol/L equivalent) with
    /// a high-GI meal 90–120 minutes before.
    private var spikeCorrelations: [NSManagedObjectID: SpikeCorrelation] {
        SpikeCorrelator.correlate(
            readings: Array(glucoseReadings),
            meals: Array(meals),
            isMgDl: isMgdlRegion
        )
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
                        .accessibilityLabel("Add glucose reading")
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
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .alert("HealthKit Error", isPresented: $showHealthKitError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(HealthKitManager.shared.authorizationError ?? "HealthKit could not be authorized. Check Settings > Health > Data Access & Devices.")
        }
        .onAppear {
            if let error = HealthKitManager.shared.authorizationError, !error.isEmpty {
                showHealthKitError = true
            }
            // Fetch weekly weight samples for popover weight-delta display
            Task {
                weightSamples = await HealthKitManager.shared.fetchWeeklyWeights()
            }
        }
    }

    // MARK: - Landscape Body
    private var landscapeBody: some View {
        VStack(spacing: 0) {
            // Fixed header: title on left, + button on right
            HStack {
                Text("Glucose Readings")
                    .font(.title3.bold())

                Spacer()

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .accessibilityLabel("Add glucose reading")
                }
            }
            .padding(.horizontal)
            .padding(.top, 14)
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
                                    .font(.caption2)
                            }
                            .foregroundColor(syncSuccess ? .green : .blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background((syncSuccess ? Color.green : Color.blue).opacity(0.1))
                            .cornerRadius(6.6)
                            .animation(.easeInOut(duration: 0.3), value: syncSuccess)
                        }
                        .disabled(isSyncing)
                        .accessibilityLabel(isSyncing ? "Syncing with Apple Health" : syncSuccess ? "Health data synced successfully" : "Sync from Apple Health")
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
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    // MARK: - Chart Section (3-day default, scrollable to 30 days)

    /// Number of days visible in the chart window
    private var chartWindowDays: Int { showExtendedWindow ? 7 : 3 }

    /// Right edge of the chart window — either "now" or a date set by tapping
    /// a reading in the list.
    private var chartWindowEnd: Date {
        chartAnchorDate ?? Date()
    }

    /// Left edge of the chart window
    private var chartWindowStart: Date {
        Calendar.current.date(byAdding: .day, value: -chartWindowDays, to: chartWindowEnd) ?? chartWindowEnd
    }

    /// Processed curve and hotspots from GlucoseCurveProcessor
    private var processedCurve: (curve: [CurvePoint], hotspots: [CurveHotspot]) {
        return GlucoseCurveProcessor.process(
            readings: Array(glucoseReadings),
            meals: Array(meals),
            exerciseSessions: Array(exerciseSessions),
            weightSamples: weightSamples,
            windowStart: chartWindowStart,
            windowEnd: chartWindowEnd,
            localeIsMgDl: isMgdlRegion
        )
    }

    @ViewBuilder
    private var chartSection: some View {
        if !glucoseReadings.isEmpty {
            let result = processedCurve
            let curvePoints = result.curve
            let hotspots = result.hotspots

            VStack(alignment: .leading, spacing: 12) {
                // Header row: window label + navigation + Sync Health
                HStack(spacing: 8) {
                    // Back arrow — scroll chart earlier (up to 30 days)
                    Button(action: { shiftChart(byDays: -chartWindowDays) }) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                    }
                    .disabled(chartWindowStart <= Calendar.current.date(byAdding: .day, value: -30, to: Date())!)

                    Text(chartWindowLabel)
                        .font(.headline)

                    // Forward arrow — scroll chart later (up to "now")
                    Button(action: { shiftChart(byDays: chartWindowDays) }) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .disabled(chartAnchorDate == nil)

                    // Reset to "now"
                    if chartAnchorDate != nil {
                        Button(action: {
                            withAnimation { chartAnchorDate = nil }
                            selectedHotspot = nil
                            selectedReadingDate = nil
                        }) {
                            Text("Now")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Button(action: {
                        withAnimation { showExtendedWindow.toggle() }
                        selectedHotspot = nil
                    }) {
                        Text(showExtendedWindow ? "3 Days" : "7 Days")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    // Sync Health button (portrait only — landscape has its own)
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
                                    .font(.caption)
                            }
                            .foregroundColor(syncSuccess ? .green : .blue)
                            .padding(.horizontal, 13.2)
                            .padding(.vertical, 8.8)
                            .background((syncSuccess ? Color.green : Color.blue).opacity(0.1))
                            .cornerRadius(6.6)
                            .animation(.easeInOut(duration: 0.3), value: syncSuccess)
                        }
                        .disabled(isSyncing)
                        .accessibilityLabel(isSyncing ? "Syncing with Apple Health" : syncSuccess ? "Health data synced successfully" : "Sync from Apple Health")
                    }
                }
                .padding(.horizontal)

                if !curvePoints.isEmpty {
                    let chartUnitLabel = localeGlucoseUnit
                    let yRange = yAxisRange(for: chartUnitLabel)
                    let yStride: Double = chartUnitLabel == "mmol/L" ? 1 : 20
                    let chartHeight: CGFloat = isPortrait ? 200 : 170
                    let plotHeight: CGFloat = isPortrait ? 160 : 130

                    ZStack(alignment: popoverAnchorRight ? .topTrailing : .topLeading) {
                        HStack(spacing: 0) {
                            // Main chart area — no ScrollView needed for 7/14 days
                            Chart {
                                chartReferenceLines(unitLabel: chartUnitLabel)
                                chartCurveLine(points: curvePoints)
                                chartDataPoints(points: curvePoints)
                                chartHotspotRings(points: curvePoints)
                                chartSelectionIndicator()
                            }
                            .chartYScale(domain: yRange.min...yRange.max)
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(position: .bottom, values: .automatic(desiredCount: chartWindowDays)) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                                        .font(.caption2)
                                }
                            }
                            .chartPlotStyle { plotArea in
                                plotArea.frame(height: plotHeight)
                            }
                            .chartOverlay { proxy in
                                GeometryReader { geometry in
                                    let plotFrame = geometry[proxy.plotFrame!]
                                    Rectangle()
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onEnded { value in
                                                    let tapX = value.location.x - plotFrame.origin.x
                                                    let tapY = value.location.y - plotFrame.origin.y

                                                    // Map screen position to data coordinates
                                                    guard let tapDate: Date = proxy.value(atX: tapX),
                                                          let _: Double = proxy.value(atY: tapY) else { return }

                                                    // Find nearest hotspot within a tap tolerance
                                                    let tolerance: TimeInterval = Double(chartWindowDays) * 86400 / 30  // ~1/30th of visible window
                                                    let nearest = hotspots
                                                        .map { ($0, abs($0.point.timestamp.timeIntervalSince(tapDate))) }
                                                        .filter { $0.1 < tolerance }
                                                        .min(by: { $0.1 < $1.1 })

                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        selectedReadingDate = nil  // clear list-tap indicator
                                                        if let match = nearest {
                                                            if selectedHotspot?.id == match.0.id {
                                                                selectedHotspot = nil
                                                            } else {
                                                                selectedHotspot = match.0
                                                                // Position popover on the side with more room
                                                                popoverAnchorRight = tapX > plotFrame.width / 2
                                                            }
                                                        } else {
                                                            selectedHotspot = nil
                                                        }
                                                    }
                                                }
                                        )
                                }
                            }
                            .frame(height: chartHeight)

                            // Pinned Y-axis on the right
                            Chart {
                                RuleMark(y: .value("", yRange.min))
                                    .foregroundStyle(.clear)
                            }
                            .chartYScale(domain: yRange.min...yRange.max)
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .stride(by: yStride)) { _ in
                                    AxisValueLabel()
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartPlotStyle { plotArea in
                                plotArea.frame(width: 0, height: plotHeight)
                            }
                            .frame(width: 40, height: chartHeight)
                        }

                        // Hotspot popover overlay
                        if let sel = selectedHotspot {
                            hotspotPopover(for: sel)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, isPortrait ? 8 : 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(alignment: .leading) {
                        Text("Glucose Level \(chartUnitLabel)")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                            .offset(x: -46)
                    }
                    .padding(.horizontal)
                    .accessibilityLabel("Interactive glucose chart showing last \(chartWindowDays) days. Tap highlighted points to see meal and exercise details.")
                    .onChange(of: isPortrait) {
                        selectedHotspot = nil  // dismiss popover on rotation
                    }
                    .onChange(of: pendingSelectionDate) {
                        guard let targetDate = pendingSelectionDate else { return }
                        pendingSelectionDate = nil

                        // Find the nearest hotspot to the tapped reading
                        let tolerance: TimeInterval = 300  // 5 minutes
                        let nearest = hotspots
                            .map { ($0, abs($0.point.timestamp.timeIntervalSince(targetDate))) }
                            .filter { $0.1 < tolerance }
                            .min(by: { $0.1 < $1.1 })

                        if let match = nearest {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedHotspot = match.0
                                // Position popover on the left side (reading is centred)
                                popoverAnchorRight = false
                            }
                        }
                    }

                    // Tap hint — shown when there are hotspots but user hasn't tapped one yet
                    if selectedHotspot == nil && !hotspots.isEmpty {
                        Text("Tap a highlighted point to see meal and exercise details")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                } else {
                    // No glucose data in window (only HbA1c lab results or outside window)
                    VStack(spacing: 8) {
                        Text("No glucose readings in the last \(chartWindowDays) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !showExtendedWindow {
                            Button("Try last 7 days") {
                                withAnimation { showExtendedWindow = true }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Severity → Color mapping
    private func severityColor(_ severity: GlucoseSeverity) -> Color {
        switch severity {
        case .hypo:     return .red
        case .normal:   return .green
        case .elevated: return .yellow
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    // MARK: - Chart Content Builders (broken out to help Swift type-checker)

    @ChartContentBuilder
    private func chartReferenceLines(unitLabel: String) -> some ChartContent {
        if unitLabel == "mmol/L" {
            RuleMark(y: .value("Hypo", 3.9))
                .foregroundStyle(Color.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            RuleMark(y: .value("Normal", 5.6))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            RuleMark(y: .value("Warning", 7.8))
                .foregroundStyle(Color.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
        } else {
            RuleMark(y: .value("Target Min", 70))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            RuleMark(y: .value("Safe Max", 100))
                .foregroundStyle(Color.yellow.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            RuleMark(y: .value("Warning", 126))
                .foregroundStyle(Color.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            RuleMark(y: .value("Critical", 180))
                .foregroundStyle(Color.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
        }
    }

    @ChartContentBuilder
    private func chartCurveLine(points: [CurvePoint]) -> some ChartContent {
        ForEach(points) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.displayValue),
                series: .value("Segment", point.segmentID)
            )
            .foregroundStyle(Color.blue.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
    }

    @ChartContentBuilder
    private func chartDataPoints(points: [CurvePoint]) -> some ChartContent {
        ForEach(points) { point in
            PointMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.displayValue)
            )
            .foregroundStyle(severityColor(point.severity))
            .symbolSize(point.isHotspot ? 50 : 20)
        }
    }

    @ChartContentBuilder
    private func chartHotspotRings(points: [CurvePoint]) -> some ChartContent {
        ForEach(points.filter(\.isHotspot)) { point in
            PointMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.displayValue)
            )
            .foregroundStyle(severityColor(point.severity).opacity(0.3))
            .symbolSize(120)
            .symbol(.circle)
        }
    }

    @ChartContentBuilder
    private func chartSelectionIndicator() -> some ChartContent {
        if let sel = selectedHotspot {
            RuleMark(x: .value("Selected", sel.point.timestamp))
                .foregroundStyle(Color.primary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
        } else if let readingDate = selectedReadingDate {
            // Vertical indicator for a list-tapped reading that isn't a hotspot
            RuleMark(x: .value("Tapped", readingDate))
                .foregroundStyle(Color.blue.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
    }

    // MARK: - Accessibility Helpers

    /// Builds a VoiceOver label for a hotspot point on the chart
    private func hotspotAccessibilityLabel(for point: CurvePoint) -> Text {
        let valueText = formatGlucoseValue(point.displayValue, unit: localeGlucoseUnit)
        let timeText = formatPopoverTime(point.timestamp)
        let typeText: String
        switch point.hotspotType {
        case .spikePeak:     typeText = "Glucose spike"
        case .recoverySlope: typeText = "Recovery point"
        case .highReading:   typeText = "High glucose"
        case .none:          typeText = "Glucose reading"
        }
        return Text("\(typeText): \(valueText) at \(timeText)")
    }

    // MARK: - Hotspot Popover
    /// Anchored popover showing glucose context when a hotspot is tapped
    private func hotspotPopover(for hotspot: CurveHotspot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Glucose value + timestamp
            HStack {
                Text(formatGlucoseValue(hotspot.point.displayValue, unit: localeGlucoseUnit))
                    .font(.headline)
                    .foregroundColor(severityColor(hotspot.point.severity))

                Spacer()

                // Close button
                Button(action: { withAnimation { selectedHotspot = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .accessibilityLabel("Dismiss popover")
            }

            Text(formatPopoverTime(hotspot.point.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)

            // Spike delta / high reading label
            if hotspot.point.hotspotType == .spikePeak, let delta = hotspot.deltaFromBaseline {
                let displayDelta = isMgdlRegion ? delta : delta / 18.0182
                let formatted = isMgdlRegion
                    ? "+\(Int(displayDelta)) \(instantaneousGlucoseUnit)"
                    : String(format: "+%.1f %@", displayDelta, instantaneousGlucoseUnit)
                Label(formatted + " from baseline", systemImage: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            } else if hotspot.point.hotspotType == .highReading {
                Label("Above 170 mg/dL threshold", systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            } else if hotspot.point.hotspotType == .recoverySlope {
                Label("Returning to baseline", systemImage: "arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
            }

            Divider()

            // Meal context
            if hotspot.nearbyMeals.isEmpty {
                Label("No meal logged", systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(hotspot.nearbyMeals) { meal in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(meal.name, systemImage: "fork.knife")
                            .font(.caption.weight(.medium))
                        HStack(spacing: 8) {
                            Text("\(Int(meal.totalCarbs))g carbs")
                            if meal.totalGL > 0 {
                                Text("Carb impact: \(Int(meal.totalGL))")
                            }
                            Text("\(meal.minutesBeforeReading) min before")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption2)
                    }
                }
            }

            // Exercise context
            if hotspot.nearbyExercise.isEmpty {
                Label("No exercise logged", systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(hotspot.nearbyExercise) { exercise in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(exercise.type, systemImage: "figure.walk")
                            .font(.caption.weight(.medium))
                        HStack(spacing: 8) {
                            Text("\(exercise.durationMinutes) min")
                            Text("\(exercise.minutesAfterReading) min after reading")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption2)
                    }
                }
            }

            // Weight delta (3-month change)
            if let wd = hotspot.weightDelta {
                Divider()
                weightDeltaRow(wd)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: isPortrait ? 260 : 240)
        .padding(.top, 8)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            withAnimation { selectedHotspot = nil }
        }
    }

    /// Formats a date for the popover: "Wed 16 Apr, 14:32"
    private func formatPopoverTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: date)
    }

    /// Formats a weight delta row for the popover
    @ViewBuilder
    private func weightDeltaRow(_ wd: WeightDelta) -> some View {
        let profile = HeightWeightUnitProfile.shared
        let useKg = profile.weightUnit == .kg
        let delta = useKg ? wd.deltaKg : wd.deltaKg * 2.20462
        let unit = useKg ? "kg" : "lbs"
        let sign = delta >= 0 ? "+" : ""
        let formatted = String(format: "%@%.1f %@", sign, delta, unit)
        let color: Color = abs(delta) < (useKg ? 1.0 : 2.2) ? .secondary
            : delta > 0 ? .orange : .green
        let icon = delta >= 0 ? "arrow.up.right" : "arrow.down.right"
        let weeksSpan = Int(abs(wd.currentDate.timeIntervalSince(wd.referenceDate)) / (7 * 86400))

        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(formatted) over ~\(weeksSpan) weeks")
                    .font(.caption.weight(.medium))
                    .foregroundColor(color)
                let currentFormatted = String(format: "%.1f %@", useKg ? wd.currentWeight : wd.currentWeight * 2.20462, unit)
                Text("Current: \(currentFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundColor(color)
        }
    }

    // MARK: - Readings filtered to chart window

    /// Glucose readings whose timestamp falls within the current chart window.
    /// Sorted descending (newest first) to match the list's visual order.
    private var chartWindowReadings: [GlucoseReadingEntity] {
        glucoseReadings.filter { reading in
            guard let ts = reading.timestamp else { return false }
            return ts >= chartWindowStart && ts <= chartWindowEnd
        }
        // glucoseReadings is already sorted descending, so no re-sort needed
    }

    // MARK: - Readings List (top-level List — supports swipeActions)
    @ViewBuilder
    private var readingsList: some View {
        if glucoseReadings.isEmpty {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .accessibilityHidden(true)

                Text("No Glucose Readings")
                    .font(.headline)

                Text("Add your first reading or sync from Health")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
        } else {
            let windowReadings = chartWindowReadings
            List {
                // Reading count header
                HStack {
                    Text("\(windowReadings.count) readings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(chartWindowLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.clear)

                ForEach(windowReadings, id: \.id) { reading in
                    HStack(spacing: 12) {
                        // Glucose value with color coding (converted to locale unit)
                        // HbA1c readings (NGSP %, mmol/mol) keep their original unit
                        let isHbA1c = (reading.unit == "NGSP %" || reading.unit == "mmol/mol")
                        let displayVal = isHbA1c ? reading.value : convertToLocaleUnit(reading.value, from: reading.unit)
                        let displayUnit = isHbA1c ? (reading.unit ?? localeGlucoseUnit) : localeGlucoseUnit
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(formatGlucoseValue(displayVal, unit: displayUnit))
                                    .font(isPortrait ? .headline : .subheadline)
                                    .foregroundColor(glucoseColor(for: displayVal, unit: displayUnit))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                // Trend arrow
                                if let trend = reading.trend {
                                    Image(systemName: trendIcon(for: trend))
                                        .font(.caption2)
                                        .foregroundColor(glucoseColor(for: displayVal, unit: displayUnit))
                                        .accessibilityLabel("Glucose trend: \(trend)")
                                }
                            }

                            // Time
                            if let timestamp = reading.timestamp {
                                Text(formatTime(timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Centre: high-GI meal that likely caused this spike
                        if let correlation = spikeCorrelations[reading.objectID] {
                            VStack(alignment: .center, spacing: 2) {
                                Image(systemName: "fork.knife")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(correlation.topFoodName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                                Text("GI \(correlation.maxGI)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Likely spike cause: \(correlation.topFoodName), glycaemic index \(correlation.maxGI)")
                        } else {
                            Spacer()
                        }

                        // Source icon and label
                        HStack(spacing: 8) {
                            if isPortrait {
                                Image(systemName: sourceIcon(for: reading.source ?? ""))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                            }

                            Text(sourceDisplayName(reading.source ?? "Unknown"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        scrollChartTo(reading: reading)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            moc.delete(reading)
                            do {
                                try moc.save()
                            } catch {
                                saveErrorMessage = "Could not delete reading. Please try again."
                                showSaveError = true
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Chart Navigation Helpers

    /// Human-readable label for the chart window date range.
    private var chartWindowLabel: String {
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return "\(df.string(from: chartWindowStart)) – \(df.string(from: chartWindowEnd))"
    }

    /// Shift the chart window by a number of days (negative = earlier, positive = later).
    /// Clamps to the 30-day lookback limit and resets to "now" if moving past today.
    private func shiftChart(byDays days: Int) {
        let calendar = Calendar.current
        let now = Date()
        let earliestAllowed = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let currentEnd = chartWindowEnd

        guard let newEnd = calendar.date(byAdding: .day, value: days, to: currentEnd) else { return }

        if newEnd >= now {
            // Moving forward past "now" → reset to live
            withAnimation { chartAnchorDate = nil }
        } else if newEnd.addingTimeInterval(TimeInterval(-chartWindowDays * 86400)) < earliestAllowed {
            // Would go past 30-day limit — clamp
            return
        } else {
            withAnimation { chartAnchorDate = newEnd }
        }
        selectedHotspot = nil
        selectedReadingDate = nil
    }

    /// Scroll the chart so that the given reading is centred, and select the
    /// nearest hotspot so its popover appears automatically.  Also shows a
    /// vertical indicator line on the chart for the tapped reading.
    private func scrollChartTo(reading: GlucoseReadingEntity) {
        guard let ts = reading.timestamp else { return }
        let now = Date()

        // Always centre the chart on the tapped reading so the user can see
        // where it sits, even when it was already inside the visible window.
        let halfWindow = TimeInterval(chartWindowDays * 86400 / 2)
        var newEnd = ts.addingTimeInterval(halfWindow)
        if newEnd > now { newEnd = now }

        withAnimation {
            chartAnchorDate = (newEnd >= now ? nil : newEnd)
            selectedReadingDate = ts
        }

        // Clear current popover and queue the auto-select
        selectedHotspot = nil
        pendingSelectionDate = ts
    }

    // MARK: - Helper Methods

    /// Returns the locale-appropriate glucose display unit string
    /// Used to unify all readings into a single unit for chart and list display
    var localeGlucoseUnit: String {
        GlucoseUnitType.localeDefault.unitLabel
    }

    /// Converts a stored glucose value to the locale-appropriate display unit
    /// Handles cross-unit conversion between mg/dL and mmol/L on the fly
    /// HbA1c units (NGSP %, mmol/mol) are returned as-is since they have separate handling
    func convertToLocaleUnit(_ value: Double, from storedUnit: String?) -> Double {
        let stored = storedUnit ?? "mg/dL"
        let target = localeGlucoseUnit

        // Same unit — no conversion needed
        if stored == target { return value }

        // Cross-convert between mg/dL and mmol/L
        switch (stored, target) {
        case ("mmol/L", "mg/dL"):
            return value * 18.0182
        case ("mg/dL", "mmol/L"):
            return value / 18.0182
        default:
            // HbA1c units or unknown — return as-is
            return value
        }
    }

    /// Determines the predominant unit type from a collection of readings
    /// Now returns the locale-appropriate unit for glucose readings (mg/dL or mmol/L)
    /// so that mixed-unit data is always displayed on a unified scale
    func predominantUnitType(for readings: [GlucoseReadingEntity]) -> String {
        // Check if readings contain HbA1c data
        let hba1cUnits: Set<String> = ["NGSP %", "mmol/mol"]
        let hasOnlyHbA1c = readings.allSatisfy { hba1cUnits.contains($0.unit ?? "") }
        if hasOnlyHbA1c, let first = readings.first?.unit {
            return first
        }
        // For glucose readings, always use the locale unit so mixed data unifies
        return localeGlucoseUnit
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
        case "freestyle libre 2":
            return "waveform.circle.fill"
        case "manual finger stick":
            return "drop.fill"
        case "healthkit":
            return "cross.circle.fill"
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
            let syncResult = await healthKitManager.syncGlucoseToCorData(context: moc, days: 30)

            await MainActor.run {
                // Check for sync save errors
                if let syncError = healthKitManager.lastSyncError {
                    syncMessage = "Sync encountered an error: \(syncError)"
                    healthKitManager.lastSyncError = nil
                } else if syncResult.newImported > 0 {
                    syncMessage = "Sync completed successfully! Imported \(syncResult.newImported) new glucose reading\(syncResult.newImported == 1 ? "" : "s") from HealthKit."
                } else if syncResult.totalFound > 0 {
                    syncMessage = "Sync completed. Your glucose readings are already up to date (\(syncResult.totalFound) reading\(syncResult.totalFound == 1 ? "" : "s") in HealthKit, all previously synced)."
                } else {
                    syncMessage = "Sync completed. No glucose readings found in HealthKit for the last 30 days."
                }
                showSyncAlert = true
                isSyncing = false
                syncSuccess = healthKitManager.lastSyncError == nil

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
            saveErrorMessage = "Could not delete reading. Please try again."
            showSaveError = true
        }
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

    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

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
    @State private var showLabConfirmAlert = false
    @State private var hasConfirmedLabResult = false

    let sourceOptions = ["Manual Finger Stick", "Continuous Glucose Monitor"]
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
                // Segmented control (custom to support red "Lab" text)
                HStack(spacing: 0) {
                    ForEach(AddReadingEntryType.allCases, id: \.self) { type in
                        Button {
                            selectedEntryType = type
                        } label: {
                            Group {
                                if type == .hba1c {
                                    Text("HbA1c ") + Text("Lab").foregroundColor(.red) + Text(" Result")
                                } else {
                                    Text(type.rawValue)
                                }
                            }
                            .font(.footnote.weight(selectedEntryType == type ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedEntryType == type ? Color(.systemBackground) : Color.clear)
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color(.systemGray5))
                .cornerRadius(9)
                .padding(.horizontal)
                .padding(.top, isPortrait ? 10 : 6)
                .padding(.bottom, 4)
                .onChange(of: selectedEntryType) {
                    hasConfirmedLabResult = false
                }

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
                        Text(sourceDisplayName(source)).tag(source)
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

            Section {
                HStack {
                    TextField("Enter lab result", text: $hba1cValue)
                        .keyboardType(.decimalPad)
                        .disabled(!hasConfirmedLabResult)
                        .overlay(
                            Group {
                                if !hasConfirmedLabResult {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            showLabConfirmAlert = true
                                        }
                                }
                            }
                        )
                    Text(effectiveHbA1cUnit.shortUnit)
                        .foregroundColor(.secondary)
                }

                if parsedHbA1cValue != nil && !isHbA1cValueValid {
                    Text("Value out of clinical range")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                HStack(spacing: 4) {
                    Text("HbA1c")
                    Text("Lab")
                        .foregroundColor(.red)
                    Text("Result")
                }
            }

            Section {
                DatePicker("Lab Test Date", selection: $hba1cLabDate, in: ...Date(),
                           displayedComponents: [.date])
            } header: {
                Text("Lab Test Date")
            }
        }
        .alert("Confirm Lab Result", isPresented: $showLabConfirmAlert) {
            Button("Yes, it's a lab result") {
                hasConfirmedLabResult = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Is this HbA1c value from a lab blood test? Do NOT enter CGM estimate — this app's estimates require actual lab results.")
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
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
            saveErrorMessage = "Could not save glucose reading. Please try again."
            showSaveError = true
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
            saveErrorMessage = "Could not save HbA1c lab result. Please try again."
            showSaveError = true
        }
    }
}

#Preview {
    GlucoseLogView()
        .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
