import SwiftUI
import Charts
import CoreData

/// Returns a display-friendly source name, shortening long labels for the UI
/// while keeping the stored Core Data value unchanged.
/// Uses String(localized:) rather than a bare literal so the result is
/// looked up in the String Catalog for the active language.
private func sourceDisplayName(_ source: String) -> String {
    switch source {
    case "Manual Finger Stick":
        return String(localized: "Finger\nStick")
    case "Continuous Glucose Monitor":
        return String(localized: "CGM")
    default:
        return source
    }
}

/// Returns a display-friendly, localized trend name for the raw trend value
/// stored in Core Data (e.g. "rising rapidly" -> "Rising Rapidly" / 「急上昇」).
private func trendDisplayName(_ trend: String) -> String {
    switch trend {
    case "stable":
        return String(localized: "Stable")
    case "rising":
        return String(localized: "Rising")
    case "falling":
        return String(localized: "Falling")
    case "rising rapidly":
        return String(localized: "Rising Rapidly")
    case "falling rapidly":
        return String(localized: "Falling Rapidly")
    default:
        return trend.capitalized
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

    // Note: fetchBatchSize doesn't limit *which* readings are available —
    // full history is still reachable (the chevron navigation depends on
    // that) — it just tells Core Data to page results into memory in
    // chunks instead of materialising every historical object at once,
    // which was a major contributor to the long-session memory growth.
    @FetchRequest(fetchRequest: {
        let request = GlucoseReadingEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GlucoseReadingEntity.timestamp, ascending: false)]
        request.fetchBatchSize = 50
        return request
    }())
    var glucoseReadings: FetchedResults<GlucoseReadingEntity>

    @FetchRequest(fetchRequest: {
        let request = MealEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)]
        request.fetchBatchSize = 50
        return request
    }())
    var meals: FetchedResults<MealEntity>

    @FetchRequest(fetchRequest: {
        let request = ExerciseSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: false)]
        request.fetchBatchSize = 50
        return request
    }())
    var exerciseSessions: FetchedResults<ExerciseSessionEntity>

    // Interactive chart state
    @State private var chartDaySetting: Int = 3  // 1, 3, or 7
    @State private var selectedHotspot: CurveHotspot? = nil
    @State private var popoverAnchorRight = false  // true → align popover to trailing edge
    @State private var weightSamples: [WeightSampleRecord] = []
    @State private var selectedWeightTrend: WeightTrendPoint? = nil
    /// Anchor date for the chart window's right edge. nil = "now" (default).
    /// Set by tapping a reading in the list to scroll the chart to that date.
    @State private var chartAnchorDate: Date? = nil
    /// Timestamp of a reading tapped in the list — triggers hotspot selection
    /// after the chart window has moved.
    @State private var pendingSelectionDate: Date? = nil
    // Reserved for future list-scroll-to-center if a lightweight approach is found
    // @State private var pendingListScrollID: NSManagedObjectID? = nil
    /// Timestamp of the reading selected in the list — shown as a vertical
    /// indicator line on the chart even when there is no matching hotspot.
    @State private var selectedReadingDate: Date? = nil

    @State private var showAddSheet = false
    @State private var showCGMSetup = false
    @State private var showDemoAlert = false
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
        Group {
            if isPortrait {
                NavigationStack {
                    portraitBody
                }
            } else {
                landscapeBody
            }
        }
        .demoRedirect(isPresented: $showDemoAlert)
    }

    // MARK: - Spike ↔ Meal Correlations

    /// Lookup of glucose reading → high-GI meal that preceded a spike, scoped
    /// to the readings actually visible in the current chart window (plus a
    /// margin on meals so the 90–120 min lookback still finds matches near
    /// the window edge).
    ///
    /// Previously this was a computed property re-run over the *entire*
    /// unbounded `glucoseReadings`/`meals` history, and — worse — it was
    /// read as `spikeCorrelations[reading.objectID]` from inside the
    /// `ForEach` row closure in `readingsList`, meaning that full O(n×m)
    /// scan reran from scratch for every single row. Found via Instruments:
    /// deleting a meal invalidates the `meals` fetch, re-rendering this
    /// list, which redid the full scan dozens of times over — the same
    /// "expensive live computation inside body" pattern already fixed in
    /// ColdStartManager and DashboardView. Now computed once per render,
    /// scoped to the visible window, and passed in as a plain dictionary.
    private func spikeCorrelations(forVisibleReadings windowReadings: [GlucoseReadingEntity]) -> [NSManagedObjectID: SpikeCorrelation] {
        guard !windowReadings.isEmpty else { return [:] }
        let mealWindowStart = chartWindowStart.addingTimeInterval(-3 * 3600)
        let mealWindowEnd = chartWindowEnd
        let nearbyMeals = meals.filter { meal in
            guard let ts = meal.timestamp else { return false }
            return ts >= mealWindowStart && ts <= mealWindowEnd
        }
        return SpikeCorrelator.correlate(
            readings: windowReadings,
            meals: nearbyMeals,
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
        .navigationTitle("Glucose")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Sync button — moved here from chart header to free space on SE
                    Button(action: syncFromHealth) {
                        HStack(spacing: 4) {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8, anchor: .center)
                            } else {
                                Image(systemName: syncSuccess ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                            }
                            Text("Sync")
                                .font(.caption2)
                        }
                        .foregroundColor(syncSuccess ? .green : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((syncSuccess ? Color.green : Color.blue).opacity(0.1))
                        .cornerRadius(6.6)
                        .animation(.easeInOut(duration: 0.3), value: syncSuccess)
                    }
                    .disabled(isSyncing)
                    .accessibilityLabel(isSyncing ? "Syncing with Apple Health" : syncSuccess ? "Health data synced successfully" : "Sync from Apple Health")

                    Button(action: { showCGMSetup = true }) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .accessibilityLabel("CGM setup")
                    }

                    Button(action: {
                        if DemoDataManager.isDemoDataLoaded {
                            showDemoAlert = true
                        } else {
                            showAddSheet = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .accessibilityLabel("Add glucose reading")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGlucoseReadingSheet(isPresented: $showAddSheet, moc: moc)
        }
        .sheet(isPresented: $showCGMSetup) {
            CGMSetupView()
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
            // Side-by-side: chart on left, readings list on right
            HStack(alignment: .top, spacing: 0) {
                chartSection
                    .frame(maxWidth: .infinity)

                // Right side: compact header + readings list
                VStack(alignment: .leading, spacing: 0) {
                    // Header row: Glucose title + Sync button + Add button
                    // fixedSize keeps this pinned — the List below scrolls independently
                    HStack {
                        Text("Glucose")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Spacer()
                        Button(action: syncFromHealth) {
                            HStack(spacing: 4) {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8, anchor: .center)
                                } else {
                                    Image(systemName: syncSuccess ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                }
                                Text("Sync")
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

                        Button(action: {
                            if DemoDataManager.isDemoDataLoaded {
                                showDemoAlert = true
                            } else {
                                showAddSheet = true
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .accessibilityLabel("Add glucose reading")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    readingsList
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    }

    // MARK: - Chart Section (3-day default, scrollable to 30 days)

    /// Number of days visible in the chart window
    private var chartWindowDays: Int { chartDaySetting }

    /// Right edge of the chart window — either "now" or a date set by tapping
    /// a reading in the list.
    /// For 1-day view, snaps to end-of-day (23:59:59) so the chart shows a full
    /// calendar day with evenly spaced 6-hour grid lines.
    private var chartWindowEnd: Date {
        let raw = chartAnchorDate ?? Date()
        if chartDaySetting <= 1 {
            // Snap to end of the calendar day containing `raw`
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: raw)
            return cal.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? raw
        }
        return raw
    }

    /// Left edge of the chart window
    /// For 1-day view, starts at midnight so x-axis labels (00, 06, 12, 18) align cleanly.
    private var chartWindowStart: Date {
        if chartDaySetting <= 1 {
            let cal = Calendar.current
            return cal.startOfDay(for: chartAnchorDate ?? Date())
        }
        return Calendar.current.date(byAdding: .day, value: -chartWindowDays, to: chartWindowEnd) ?? chartWindowEnd
    }

    /// Calendar component for x-axis stride (weeks for >14 days, hours for 1-day, days otherwise)
    private var xAxisStrideComponent: Calendar.Component {
        if chartWindowDays > 14 { return .weekOfYear }
        if chartWindowDays <= 1 { return .hour }
        return .day
    }

    /// Number of units per x-axis label
    private var xAxisStrideCount: Int {
        if chartWindowDays > 14 { return 1 }
        if chartWindowDays > 5 { return 2 }   // 7-day view: label every 2 days
        if chartWindowDays <= 1 { return 6 }   // 1-day view: label every 6 hours
        return 1                                // 3-day view: label every day
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
            localeIsMgDl: isMgdlRegion,
            windowDays: chartWindowDays
        )
    }

    @ViewBuilder
    private var chartSection: some View {
        if !glucoseReadings.isEmpty {
            let result = processedCurve
            let curvePoints = result.curve
            let hotspots = result.hotspots

            VStack(alignment: .leading, spacing: 8) {
                // Header: date navigation row (Sync moved to nav bar toolbar)
                HStack(spacing: 6) {
                    // Back arrow — scroll chart earlier (up to 30 days)
                    Button(action: { shiftChart(byDays: -chartWindowDays) }) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .accessibilityLabel("Scroll chart earlier")
                    }
                    .disabled(chartWindowStart <= (glucoseReadings.last?.timestamp ?? Date()))

                    Text(chartWindowLabel)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    // Forward arrow — scroll chart later (up to "now")
                    Button(action: { shiftChart(byDays: chartWindowDays) }) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .accessibilityLabel("Scroll chart later")
                    }
                    .disabled(chartAnchorDate == nil)

                    // Reset to "now" — hidden in landscape to save space
                    if chartAnchorDate != nil && isPortrait {
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

                    Picker("Window", selection: $chartDaySetting) {
                        Text("1d").tag(1)
                        Text("3d").tag(3)
                        Text("7d").tag(7)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                    .onChange(of: chartDaySetting) {
                        selectedHotspot = nil
                    }

                }
                .padding(.horizontal)

                if !curvePoints.isEmpty {
                    let chartUnitLabel = localeGlucoseUnit
                    let yRange = yAxisRange(for: chartUnitLabel)
                    // Widen stride if range expands beyond default to avoid label crowding
                    let yStride: Double = chartUnitLabel == "mmol/L"
                        ? ((yRange.max - yRange.min) > 8 ? 2 : 1)
                        : ((yRange.max - yRange.min) > 160 ? 40 : 20)
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
                                chartXLabelsInsidePlot(yRange: yRange)
                            }
                            .chartYScale(domain: yRange.min...yRange.max)
                            .chartYAxis(.hidden)
                            .chartXScale(domain: chartWindowStart...(chartDaySetting <= 1 ? chartWindowStart.addingTimeInterval(86400) : chartWindowEnd))
                            .chartXAxis {
                                // Grid lines only — labels are rendered inside the plot via annotations
                                if chartWindowDays <= 1 {
                                    AxisMarks(position: .bottom, values: .stride(by: .hour, count: 6)) { _ in
                                        AxisGridLine()
                                    }
                                } else {
                                    AxisMarks(position: .bottom, values: .stride(by: xAxisStrideComponent, count: xAxisStrideCount)) { _ in
                                        AxisGridLine()
                                    }
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
                                                          let tapGlucose: Double = proxy.value(atY: tapY) else { return }

                                                    // Find nearest hotspot using 2D distance (time + glucose)
                                                    // Normalise both axes to the plot frame so they contribute equally
                                                    let windowSeconds = Double(chartWindowDays) * 86400
                                                    let glucoseRange = 200.0  // typical chart range in mg/dL
                                                    let tapTolerance: Double = 0.06  // ~6% of plot frame in normalised coords

                                                    let nearest = hotspots
                                                        .map { hotspot -> (CurveHotspot, Double) in
                                                            let dtNorm = hotspot.point.timestamp.timeIntervalSince(tapDate) / windowSeconds
                                                            let dgNorm = (hotspot.point.valueMgDl - tapGlucose) / glucoseRange
                                                            let dist = sqrt(dtNorm * dtNorm + dgNorm * dgNorm)
                                                            return (hotspot, dist)
                                                        }
                                                        .filter { $0.1 < tapTolerance }
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

                                                                // Future: scroll the list to the matching reading
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
                            hotspotPopover(for: sel, allHotspots: hotspots)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)       // reduced from 16 — tighten space above red 180 line
                    .padding(.bottom, isPortrait ? 6 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.trailing)
                    .padding(.leading, 30) // room for rotated y-axis label
                    .overlay(alignment: .leading) {
                        Text(String(format: NSLocalizedString("Glucose Level %@", comment: ""), chartUnitLabel))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                            .frame(width: 14) // collapsed width so it sits in the leading margin
                    }

                    // "Date" or "Time" legend centred below the chart
                    Text(chartDaySetting <= 1 ? "Time" : "Date")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 70) // offset to align with plot area centre
                        .padding(.top, 2)
                    .accessibilityLabel("Glucose chart showing last \(chartWindowDays) days with \(hotspots.count) highlighted points. Use Next Hotspot and Previous Hotspot actions to navigate.")
                    .accessibilityAction(named: "Next hotspot") {
                        navigateHotspot(forward: true, in: hotspots)
                    }
                    .accessibilityAction(named: "Previous hotspot") {
                        navigateHotspot(forward: false, in: hotspots)
                    }
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

                    // Weight trend arrows beneath the chart (portrait only — saves vertical space in landscape)
                    if isPortrait {
                        weightTrendStrip()
                    }

                    // Tap hint — shown when there are hotspots but user hasn't tapped one yet
                    if selectedHotspot == nil && !hotspots.isEmpty && isPortrait {
                        Text("Tap a highlighted point to see meal and exercise details")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                } else {
                    // No glucose data in window (only HbA1c lab results or outside window)
                    VStack(spacing: 8) {
                        Text(String(format: NSLocalizedString("No glucose readings in the last %lld days", comment: ""), Int64(chartWindowDays)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if chartDaySetting < 7 {
                            Button("Try last 7 days") {
                                withAnimation { chartDaySetting = 7 }
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
        case .high:     return .orange
        case .veryHigh: return .red
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

    /// Renders date/time labels inside the plot area, positioned just below the
    /// green dashed baseline so they sit within the grey chart background.
    @ChartContentBuilder
    private func chartXLabelsInsidePlot(yRange: (min: Double, max: Double)) -> some ChartContent {
        let labelY = yRange.min  // position at the very bottom of the plot
        if chartDaySetting <= 1 {
            // 1-day: 06 · 12 · 18
            ForEach([6, 12, 18], id: \.self) { hour in
                let date = chartWindowStart.addingTimeInterval(Double(hour) * 3600)
                PointMark(x: .value("T", date), y: .value("L", labelY))
                    .opacity(0)
                    .annotation(position: .bottom, spacing: 2) {
                        Text(String(format: "%02d", hour))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
            }
        } else {
            // 3d/7d: day numbers at stride intervals
            let stride = xAxisStrideCount
            let cal = Calendar.current
            // Generate date marks at each stride day from the start of the window
            ForEach(labelDates(from: chartWindowStart, to: chartWindowEnd, strideComponent: xAxisStrideComponent, strideCount: stride), id: \.self) { date in
                PointMark(x: .value("T", date), y: .value("L", labelY))
                    .opacity(0)
                    .annotation(position: .bottom, spacing: 2) {
                        Text("\(cal.component(.day, from: date))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
            }
        }
    }

    /// Helper: generates an array of dates at the given stride within the window.
    private func labelDates(from start: Date, to end: Date, strideComponent: Calendar.Component, strideCount: Int) -> [Date] {
        let cal = Calendar.current
        var dates: [Date] = []
        // Start from the first stride-aligned date at or after `start`
        var current = cal.dateInterval(of: strideComponent, for: start)?.start ?? start
        if current < start {
            current = cal.date(byAdding: strideComponent, value: strideCount, to: current) ?? current
        }
        while current <= end {
            dates.append(current)
            guard let next = cal.date(byAdding: strideComponent, value: strideCount, to: current) else { break }
            current = next
        }
        return dates
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
    private func hotspotPopover(for hotspot: CurveHotspot, allHotspots: [CurveHotspot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Glucose value + close
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

            // Meal context — line 1: icon + meal name + time ago; line 2: carbs + GL
            if hotspot.nearbyMeals.isEmpty {
                Label("No meal logged", systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(hotspot.nearbyMeals) { meal in
                    VStack(alignment: .leading, spacing: 4) {
                        // Line 1: icon + meal name + time, all on one line
                        Label {
                            Text("\(meal.name) \(meal.minutesBeforeReading) min ago")
                        } icon: {
                            Image(systemName: "fork.knife")
                        }
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        // Line 2: carbs + GL, left-aligned under the icon
                        HStack(spacing: 8) {
                            Text("Carbs \(Int(meal.totalCarbs)) g")
                            if meal.totalGL > 0 {
                                Text("GL \(Int(meal.totalGL))")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
            }

            // Exercise context — line 1: icon + type + duration; line 2: calories
            if hotspot.nearbyExercise.isEmpty {
                Label("No exercise logged", systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(hotspot.nearbyExercise) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        // Line 1: icon + type + duration + timing
                        Label {
                            let timing = exercise.minutesBeforeReading >= 0
                                ? "\(exercise.minutesBeforeReading) min before"
                                : "\(abs(exercise.minutesBeforeReading)) min after"
                            Text("\(exercise.type) \(exercise.durationMinutes) min · \(timing)")
                        } icon: {
                            Image(systemName: "figure.walk")
                        }
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        // Line 2: calories underneath
                        if exercise.caloriesBurned > 0 {
                            Text("\(Int(exercise.caloriesBurned)) kcal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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
        .frame(maxWidth: isPortrait ? 280 : 240)
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            withAnimation { selectedHotspot = nil }
        }
        .accessibilityAction(named: "Next hotspot") {
            navigateHotspot(forward: true, in: allHotspots)
        }
        .accessibilityAction(named: "Previous hotspot") {
            navigateHotspot(forward: false, in: allHotspots)
        }
    }

    // MARK: - Hotspot VoiceOver Navigation

    /// Navigate to the next or previous hotspot in the current chart window.
    /// Called by accessibility actions and by the prev/next buttons in the popover.
    private func navigateHotspot(forward: Bool, in hotspots: [CurveHotspot]) {
        guard !hotspots.isEmpty else { return }

        let sorted = hotspots.sorted { $0.point.timestamp < $1.point.timestamp }

        if let current = selectedHotspot,
           let currentIndex = sorted.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = forward ? currentIndex + 1 : currentIndex - 1
            guard sorted.indices.contains(nextIndex) else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHotspot = sorted[nextIndex]
            }
        } else {
            // No hotspot selected — select the first or last
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHotspot = forward ? sorted.first : sorted.last
            }
        }
    }

    /// Index of the currently selected hotspot in the sorted array (1-based for display)
    private func hotspotPosition(in hotspots: [CurveHotspot]) -> (current: Int, total: Int)? {
        guard let current = selectedHotspot else { return nil }
        let sorted = hotspots.sorted { $0.point.timestamp < $1.point.timestamp }
        guard let idx = sorted.firstIndex(where: { $0.id == current.id }) else { return nil }
        return (idx + 1, sorted.count)
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

    // MARK: - Weight Trend Arrows

    /// Direction of weight change between consecutive readings.
    private enum WeightDirection {
        case up, down, stable
    }

    /// A single weight trend data point positioned at the date of the reading.
    private struct WeightTrendPoint: Identifiable {
        let id = UUID()
        let date: Date             // date of this weight reading
        let direction: WeightDirection
        let weightKg: Double       // current weight in kg
        let deltaKg: Double        // change from previous reading in kg
    }

    /// Computes weight trend arrows for the visible chart window.
    /// Compares each weight sample to its predecessor chronologically.
    /// A delta within ±1 kg is displayed as stable (no-change icon).
    private func weightTrends() -> [WeightTrendPoint] {
        guard weightSamples.count >= 2 else { return [] }

        // weightSamples are already sorted oldest → newest from HealthKitManager
        var trends: [WeightTrendPoint] = []

        for i in 1..<weightSamples.count {
            let current = weightSamples[i]

            // Only show arrows within the visible chart window
            guard current.date >= chartWindowStart && current.date <= chartWindowEnd else { continue }

            let previous = weightSamples[i - 1]
            let delta = current.kilograms - previous.kilograms

            let direction: WeightDirection
            if abs(delta) < 1.0 {
                direction = .stable
            } else if delta > 0 {
                direction = .up
            } else {
                direction = .down
            }

            trends.append(WeightTrendPoint(
                date: current.date,
                direction: direction,
                weightKg: current.kilograms,
                deltaKg: delta
            ))
        }

        return trends
    }

    /// Formats a weight trend point for the popover display.
    /// e.g. "84.3 kg (+1.2 kg)" or "186.0 lbs (no change)"
    private func weightTrendLabel(_ trend: WeightTrendPoint) -> String {
        let profile = HeightWeightUnitProfile.shared
        let useKg = profile.weightUnit == .kg
        let unit = useKg ? "kg" : "lbs"
        let displayWeight = useKg ? trend.weightKg : trend.weightKg * 2.20462
        let displayDelta = useKg ? trend.deltaKg : trend.deltaKg * 2.20462

        let weightStr = String(format: "%.1f %@", displayWeight, unit)
        let deltaStr: String
        switch trend.direction {
        case .up:
            deltaStr = String(format: "(+%.1f %@)", abs(displayDelta), unit)
        case .down:
            deltaStr = String(format: "(\u{2013}%.1f %@)", abs(displayDelta), unit)
        case .stable:
            deltaStr = "(no change)"
        }
        return "\(weightStr)  \(deltaStr)"
    }

    /// View showing weight trend arrows beneath the glucose chart x-axis.
    @ViewBuilder
    private func weightTrendStrip() -> some View {
        let trends = weightTrends()
        if !trends.isEmpty {
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    // Text label
                    Text("Weight\ntrend")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .frame(width: 38)
                        .accessibilityHidden(true)

                    // Use a Chart to align arrows with the glucose chart's x-axis
                    Chart {
                        ForEach(trends) { trend in
                            PointMark(
                                x: .value("Date", trend.date),
                                y: .value("Trend", 0)
                            )
                            .symbol {
                                switch trend.direction {
                                case .up:
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                case .down:
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                case .stable:
                                    Image(systemName: "equal")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartXScale(domain: chartWindowStart...chartWindowEnd)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: -1...1)
                    .frame(height: 22)
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
                                            guard let tapDate: Date = proxy.value(atX: tapX) else { return }

                                            // Find nearest trend point
                                            let nearest = trends
                                                .map { ($0, abs($0.date.timeIntervalSince(tapDate))) }
                                                .min(by: { $0.1 < $1.1 })

                                            if let match = nearest, match.1 < Double(chartWindowDays) * 86400 / 10 {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if selectedWeightTrend?.id == match.0.id {
                                                        selectedWeightTrend = nil  // toggle off
                                                    } else {
                                                        selectedWeightTrend = match.0
                                                    }
                                                }
                                            } else {
                                                withAnimation { selectedWeightTrend = nil }
                                            }
                                        }
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .accessibilityLabel("Weight trend: \(trends.map { switch $0.direction { case .up: return "up"; case .down: return "down"; case .stable: return "no change" } }.joined(separator: ", "))")

                // Weight popover
                if let sel = selectedWeightTrend {
                    Text(weightTrendLabel(sel))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .onTapGesture {
                            withAnimation { selectedWeightTrend = nil }
                        }
                        .padding(.top, 24)
                }
            }
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
            ColdStartEmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                heading: "Your trend history will appear here",
                bodyText: "Log blood glucose readings over a few days — by CGM or finger-stick — and you'll start to see patterns in how your levels respond to meals and activity.",
                progress: ColdStartEmptyStateView.Progress(
                    current: ColdStartManager.shared.glucoseDaysLogged,
                    total: ColdStartManager.trendDaysRequired,
                    label: "days logged"
                ),
                actionTitle: "Log glucose reading",
                actionIcon: "plus"
            )
            .padding(.vertical, 20)
        } else {
            let windowReadings = chartWindowReadings
            // Computed once here, not per-row — see spikeCorrelations(forVisibleReadings:) doc comment.
            let correlations = spikeCorrelations(forVisibleReadings: windowReadings)
            List {
                // Reading count header
                HStack {
                    Text(String(format: NSLocalizedString("%lld readings", comment: ""), Int64(windowReadings.count)))
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
                        if let correlation = correlations[reading.objectID] {
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
    /// English — same month: "13–16 Apr"   cross-month: "29 Apr – 1 May"
    /// Japanese — same month: "4月13–16日"   cross-month: "4月29日 – 5月1日"
    private var chartWindowLabel: String {
        let cal = Calendar.current
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        let df = DateFormatter()
        df.dateFormat = isJapanese ? "M月d日" : "d MMM"

        // 1-day view: show single date (e.g. "30 Apr" / "4月30日")
        if chartDaySetting <= 1 {
            return df.string(from: chartWindowStart)
        }

        let sameMonth = cal.component(.month, from: chartWindowStart) == cal.component(.month, from: chartWindowEnd)
        if sameMonth {
            let dayOnly = DateFormatter()
            dayOnly.dateFormat = "d"
            if isJapanese {
                let month = cal.component(.month, from: chartWindowStart)
                return "\(month)月\(dayOnly.string(from: chartWindowStart))–\(dayOnly.string(from: chartWindowEnd))日"
            } else {
                return "\(dayOnly.string(from: chartWindowStart))–\(df.string(from: chartWindowEnd))"
            }
        } else {
            return "\(df.string(from: chartWindowStart)) – \(df.string(from: chartWindowEnd))"
        }
    }

    /// Shift the chart window by a number of days (negative = earlier, positive = later).
    /// Clamps to the earliest glucose reading and resets to "now" if moving past today.
    private func shiftChart(byDays days: Int) {
        let calendar = Calendar.current
        let now = Date()
        let earliestAllowed = glucoseReadings.last?.timestamp ?? now
        let currentEnd = chartWindowEnd

        guard let newEnd = calendar.date(byAdding: .day, value: days, to: currentEnd) else { return }

        if newEnd >= now {
            // Moving forward past "now" → reset to live
            withAnimation { chartAnchorDate = nil }
        } else if newEnd.addingTimeInterval(TimeInterval(-chartWindowDays * 86400)) < earliestAllowed {
            // Would go past earliest glucose reading — clamp
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
    /// Dynamic y-axis range that expands if readings exceed the default range.
    /// Defaults: NGSP % 4–10 portrait / 4–13 landscape; mmol/mol 20–120 / 20–200;
    /// mmol/L 4–10; mg/dL 80–180. All expand dynamically when data exceeds defaults.
    /// Rounds to the next clean stride boundary so the scale stays tidy.
    /// Contracts back to the default when high/low readings scroll out of the window.
    func yAxisRange(for unitType: String) -> (min: Double, max: Double) {
        // Find the min and max reading values in the current chart window
        let glucoseValues = chartWindowReadings
            .filter { r in
                let unit = r.unit ?? ""
                return unit != "NGSP %" && unit != "mmol/mol"
            }
            .map { $0.value }
        let windowMax = glucoseValues.max() ?? 0
        let windowMin = glucoseValues.min() ?? 999

        // Find HbA1c/GMI values in the current chart window for dynamic scaling
        let ngspValues = chartWindowReadings
            .filter { ($0.unit ?? "") == "NGSP %" }
            .map { $0.value }
        let ifccValues = chartWindowReadings
            .filter { ($0.unit ?? "") == "mmol/mol" }
            .map { $0.value }

        switch unitType {
        case "NGSP %":
            let defaultMin: Double = 4
            let defaultMax: Double = isPortrait ? 10 : 13
            let dataMax = ngspValues.max() ?? 0
            let dataMin = ngspValues.min() ?? 999
            let effectiveMax = dataMax > defaultMax
                ? ceil(dataMax + 0.5)                // pad 0.5% above highest point
                : defaultMax
            let effectiveMin = dataMin < defaultMin
                ? floor(dataMin - 0.5)               // pad 0.5% below lowest point
                : defaultMin
            return (min: effectiveMin, max: effectiveMax)
        case "mmol/mol":
            let defaultMin: Double = 20
            let defaultMax: Double = isPortrait ? 120 : 200
            let dataMax = ifccValues.max() ?? 0
            let dataMin = ifccValues.min() ?? 999
            let effectiveMax = dataMax > defaultMax
                ? ceil(dataMax / 10.0) * 10.0        // round up to next 10 mmol/mol
                : defaultMax
            let effectiveMin = dataMin < defaultMin
                ? floor(dataMin / 10.0) * 10.0       // round down to next 10 mmol/mol
                : defaultMin
            return (min: effectiveMin, max: effectiveMax)
        case "mmol/L":
            let defaultMin: Double = 4
            let defaultMax: Double = 10
            let maxMmol = windowMax / 18.0182
            let minMmol = windowMin / 18.0182
            let effectiveMax = maxMmol > defaultMax
                ? ceil(maxMmol / 1.0) * 1.0
                : defaultMax
            let effectiveMin = minMmol < defaultMin
                ? floor(minMmol / 1.0) * 1.0    // round down to next 1 mmol/L
                : defaultMin
            return (min: effectiveMin, max: effectiveMax)
        default: // mg/dL
            let defaultMin: Double = 80
            let defaultMax: Double = 180
            let effectiveMax = windowMax > defaultMax
                ? ceil(windowMax / 20.0) * 20.0  // round up to next 20 mg/dL
                : defaultMax
            let effectiveMin = windowMin < defaultMin
                ? floor(windowMin / 20.0) * 20.0 // round down to next 20 mg/dL
                : defaultMin
            return (min: effectiveMin, max: effectiveMax)
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
        case "freestyle libre 2",   // legacy stored data — sensor discontinued Sept 2025
             "continuous glucose monitor",
             "cgm":
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

    // Cached rather than allocated per call — this is invoked once per row
    // in the readings list, and `DateFormatter()` init is expensive enough
    // that doing it per-row measurably showed up in Instruments once other
    // bigger costs in this view were fixed (see GMICardView.shortDate for
    // the same fix applied earlier).
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm MM/dd"
        return f
    }()

    /// Formats a Date to "HH:mm MM/dd" format
    func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    /// Syncs glucose data from HealthKit (CGM and manual entries)
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

            // Sync glucose readings from HealthKit to CoreData (CGM and manual entries)
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
                                    // type.rawValue is a runtime String, so it must be wrapped in
                                    // LocalizedStringKey explicitly to pick up the String Catalog
                                    // translation — Text(String) alone renders verbatim, un-localized.
                                    Text(LocalizedStringKey(type.rawValue))
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
                        Text(trendDisplayName(trend)).tag(trend)
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
                                        .accessibilityLabel("Confirm lab result entry")
                                        .accessibilityAddTraits(.isButton)
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
