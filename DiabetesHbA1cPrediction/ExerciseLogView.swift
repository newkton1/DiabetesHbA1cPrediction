import SwiftUI
import CoreData

/// ExerciseLogView displays exercise sessions with weekly summary and management capabilities
/// Features include:
/// - Weekly summary card showing total minutes, calories, and session count
/// - List of exercise sessions with type, duration, calories, and intensity
/// - Manual entry sheet with comprehensive exercise details
/// - HealthKit synchronization
/// - Swipe to delete functionality
/// - Estimated calorie calculation based on exercise type and duration
struct ExerciseLogView: View {
    @Environment(\.managedObjectContext) var moc
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FetchRequest(
        entity: ExerciseSessionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: false)]
    ) var exercises: FetchedResults<ExerciseSessionEntity>

    @State private var showAddSheet = false
    @State private var showDemoAlert = false
    @State private var showSyncAlert = false
    @State private var syncMessage = ""
    @State private var isSyncing = false
    @State private var syncSuccess = false
    @State private var showDeleteConfirmation = false
    @State private var exerciseToDelete: ExerciseSessionEntity?
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showHealthKitError = false

    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            Group {
                if isPortrait {
                    portraitContent
                } else {
                    landscapeContent
                }
            }
            .id(isPortrait) // Force full view rebuild on orientation change
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Portrait only: title on left, + button on right
                if isPortrait {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Exercise Log")
                            .font(.title3.bold())
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
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
                        }
                        .accessibilityLabel("Add exercise session")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseSessionSheet(isPresented: $showAddSheet, moc: moc)
            }
            .alert("Sync Status", isPresented: $showSyncAlert) {
                Button("OK") { }
            } message: {
                Text(syncMessage)
            }
            .alert("Delete Exercise", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    exerciseToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let exercise = exerciseToDelete {
                        deleteSingleExercise(exercise)
                    }
                    exerciseToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this exercise session?")
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
            }
        }
        .demoRedirect(isPresented: $showDemoAlert)
    }

    // MARK: - Portrait Content
    private var portraitContent: some View {
        VStack(spacing: 0) {
            // MARK: - Last 7 Days Summary header with Sync Button
            HStack {
                Text("Last 7 Days Summary")
                    .font(.headline)

                Spacer()

                syncHealthButton
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // MARK: - Weekly Summary Card (without its own title)
            WeeklySummaryCardNoTitle(exercises: exercises)
                .padding(.horizontal)
                .padding(.bottom)

            // MARK: - Full Exercise Log header
            Text("Full Exercise Log")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 4)

            // MARK: - Exercise List
            List {
                if exercises.isEmpty {
                    emptyStateView
                } else {
                    ForEach(exercises, id: \.id) { exercise in
                        ExerciseRowView(exercise: exercise)
                            .contextMenu {
                                Button(role: .destructive) {
                                    exerciseToDelete = exercise
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSingleExercise(exercise)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Landscape Content
    private var landscapeContent: some View {
        VStack(spacing: 0) {
            // Fixed header: title on left, + button on right
            HStack {
                Text("Exercise Log")
                    .font(.title3.bold())
                Spacer()
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
                        .accessibilityLabel("Add exercise session")
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Scrollable content
            ScrollView {
                VStack(spacing: 4) {
                    // "Last 7 Days Summary" header with Sync Health button on right
                    HStack {
                        Text("Last 7 Days Summary")
                            .font(.headline)
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
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    // Weekly summary card (without "Last 7 Days" header - using NoTitle version)
                    WeeklySummaryCardNoTitle(exercises: exercises)
                        .padding(.horizontal)

                    // Full Exercise Log header
                    Text("Full Exercise Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Exercise items
                    if exercises.isEmpty {
                        emptyStateView
                            .padding(.vertical, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(exercises, id: \.id) { exercise in
                                ExerciseRowView(exercise: exercise)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            exerciseToDelete = exercise
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)

                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Shared Components

    private var syncHealthButton: some View {
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
        .accessibilityLabel(isSyncing ? "Syncing with Apple Health" : syncSuccess ? "Health data synced" : "Sync from Apple Health")
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .accessibilityHidden(true)

            Text("No Exercise Sessions")
                .font(.headline)

            Text("Add your first workout or sync from Health")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }
    // MARK: - Helper Methods

    /// Syncs exercise data from HealthKit to CoreData
    func syncFromHealth() {
        isSyncing = true

        Task {
            let healthKitManager = HealthKitManager.shared

            // Ensure we have HealthKit authorization first
            let authorized = await healthKitManager.requestAuthorization()
            guard authorized else {
                syncMessage = "HealthKit authorization denied. Please enable access in Settings > Health > Data Access & Devices."
                showSyncAlert = true
                isSyncing = false
                return
            }

            // Sync formal workout records from HealthKit to CoreData
            let exerciseCount = await healthKitManager.syncExerciseToCorData(context: moc, days: 30)

            // Sync daily walking/step activity (ambient data from casual walking)
            let activityResult = await healthKitManager.syncDailyActivityToCorData(context: moc, days: 30)

            // Also sync glucose data while we're at it
            let glucoseResult = await healthKitManager.syncGlucoseToCorData(context: moc, days: 30)

            // Build a descriptive sync message
            var messageParts: [String] = []
            if exerciseCount > 0 {
                messageParts.append("\(exerciseCount) new workout\(exerciseCount == 1 ? "" : "s")")
            }
            if activityResult.new > 0 {
                messageParts.append("\(activityResult.new) day\(activityResult.new == 1 ? "" : "s") of walking activity")
            }
            if activityResult.updated > 0 {
                messageParts.append("\(activityResult.updated) day\(activityResult.updated == 1 ? "" : "s") of walking updated")
            }
            if glucoseResult.newImported > 0 {
                messageParts.append("\(glucoseResult.newImported) new glucose reading\(glucoseResult.newImported == 1 ? "" : "s")")
            }

            // Check for sync save errors
            if let syncError = healthKitManager.lastSyncError {
                syncMessage = "Sync encountered an error: \(syncError)"
                healthKitManager.lastSyncError = nil
            } else if messageParts.isEmpty {
                syncMessage = "Sync completed. No new data found in HealthKit for the last 30 days."
            } else {
                syncMessage = "Sync completed successfully! \(messageParts.joined(separator: ", "))."
            }

            showSyncAlert = true
            isSyncing = false
            syncSuccess = healthKitManager.lastSyncError == nil

            // Reset sync success indicator after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                syncSuccess = false
            }
        }
    }

    /// Deletes exercise sessions at the specified offsets
    func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            let exercise = exercises[index]
            moc.delete(exercise)
        }

        do {
            try moc.save()
        } catch {
            saveErrorMessage = "Could not delete exercise. Please try again."
            showSaveError = true
        }
    }

    /// Deletes a single exercise session
    func deleteSingleExercise(_ exercise: ExerciseSessionEntity) {
        moc.delete(exercise)

        do {
            try moc.save()
        } catch {
            saveErrorMessage = "Could not delete exercise. Please try again."
            showSaveError = true
        }
    }
}

// MARK: - Weekly Summary Card
/// Displays aggregated weekly exercise statistics
struct WeeklySummaryCard: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let exercises: FetchedResults<ExerciseSessionEntity>

    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    var weeklyStats: (minutes: Double, calories: Double, sessions: Int) {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let thisWeekExercises = exercises.filter { exercise in
            guard let startDate = exercise.startDate else { return false }
            return startDate >= weekAgo
        }

        let totalMinutes = thisWeekExercises.reduce(0) { $0 + $1.duration }
        let totalCalories = thisWeekExercises.reduce(0) { $0 + $1.caloriesBurned }
        let sessionCount = thisWeekExercises.count

        return (totalMinutes, totalCalories, sessionCount)
    }

    /// Formats an integer without thousands separators
    private func formatNoComma(_ value: Int) -> String {
        return "\(value)"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Last 7 Days Summary")
                    .font(.headline)
                Spacer()
            }

            if isPortrait {
                // Portrait: text titles with unit labels, no icons
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("Time")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Minutes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatNoComma(Int(weeklyStats.minutes)))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("Energy")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Calories")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatNoComma(Int(weeklyStats.calories)))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("Sessions")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Count")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(weeklyStats.sessions)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // Landscape: original icon-based layout
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("Minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatNoComma(Int(weeklyStats.minutes)))
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("Calories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatNoComma(Int(weeklyStats.calories)))
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(.green)
                            Text("Sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatNoComma(weeklyStats.sessions))
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Weekly Summary Card (No Title) - for Portrait mode
/// Displays aggregated weekly exercise statistics without the "Last 7 Days" header
struct WeeklySummaryCardNoTitle: View {
    let exercises: FetchedResults<ExerciseSessionEntity>

    var weeklyStats: (minutes: Double, calories: Double, sessions: Int) {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let thisWeekExercises = exercises.filter { exercise in
            guard let startDate = exercise.startDate else { return false }
            return startDate >= weekAgo
        }

        let totalMinutes = thisWeekExercises.reduce(0) { $0 + $1.duration }
        let totalCalories = thisWeekExercises.reduce(0) { $0 + $1.caloriesBurned }
        let sessionCount = thisWeekExercises.count

        return (totalMinutes, totalCalories, sessionCount)
    }

    /// Formats an integer without thousands separators
    private func formatNoComma(_ value: Int) -> String {
        return "\(value)"
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Time")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("Minutes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatNoComma(Int(weeklyStats.minutes)))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("Energy")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("Calories")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatNoComma(Int(weeklyStats.calories)))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("Sessions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("Count")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(weeklyStats.sessions)")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Row View
/// Individual row for displaying an exercise session
struct ExerciseRowView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let exercise: ExerciseSessionEntity

    /// True when the device is in portrait orientation
    private var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }

    /// Formats an integer without thousands separators
    private func formatNoComma(_ value: Int) -> String {
        return "\(value)"
    }

    /// Color for the flame icon — red when intensity bar is red (7+), otherwise secondary
    private var flameColor: Color {
        Int(exercise.intensity) > 6 ? .red : .secondary
    }

    /// Duration displayed in minutes only for both portrait and landscape
    var durationText: String {
        let totalMinutes = Int(exercise.duration)
        return "\(totalMinutes) min"
    }

    /// Format the exercise date as MM/dd
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: exercise.startDate ?? Date())
    }

    var body: some View {
        if isPortrait {
            portraitLayout
        } else {
            landscapeLayout
        }
    }

    // MARK: - Portrait Layout
    /// Icon next to title, duration & calories horizontal, vertical intensity bar on far right
    private var portraitLayout: some View {
        HStack(spacing: 10) {
            // Exercise details with icon inline with title
            VStack(alignment: .leading, spacing: 6) {
                // Icon + Title + Date on same line
                HStack(spacing: 6) {
                    Image(systemName: exerciseIcon(for: exercise.type ?? ""))
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("\(exercise.type ?? "Unknown") \(dateText)")
                        .font(.headline)
                }

                // Duration and calories on same horizontal line
                HStack(spacing: 12) {
                    Label(durationText, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(Int(exercise.caloriesBurned)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(flameColor)
                }
            }

            Spacer()

            // Vertical intensity bar on far right with rotated label
            HStack(alignment: .center, spacing: 3) {
                // Bar with fixed segment heights
                VStack(spacing: 0.5) {
                    ForEach((1...10).reversed(), id: \.self) { level in
                        Rectangle()
                            .fill(intensityColor(for: level, currentIntensity: Int(exercise.intensity)))
                            .frame(width: 6, height: 5.5)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityValue("Intensity: \(Int(exercise.intensity)) out of 10")

                // Rotated label
                Text("Intensity")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Landscape Layout
    /// Original horizontal layout for landscape mode
    private var landscapeLayout: some View {
        HStack(spacing: 12) {
            // Exercise type icon
            Image(systemName: exerciseIcon(for: exercise.type ?? ""))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            // Exercise details
            VStack(alignment: .leading, spacing: 6) {
                Text("\(exercise.type ?? "Unknown") \(dateText)")
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(durationText, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(formatNoComma(Int(exercise.caloriesBurned))) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(flameColor)
                }
            }

            Spacer()

            // Horizontal intensity bar (1-10)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Intensity")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                HStack(spacing: 2) {
                    ForEach(1...10, id: \.self) { level in
                        Rectangle()
                            .fill(intensityColor(for: level, currentIntensity: Int(exercise.intensity)))
                            .frame(height: 4)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityValue("Intensity: \(Int(exercise.intensity)) out of 10")
            }
            .frame(width: 70)
        }
        .padding(.vertical, 8)
    }

    /// Returns the appropriate SF Symbol for an exercise type
    func exerciseIcon(for type: String) -> String {
        switch type.lowercased() {
        case "walking":
            return "figure.walk"
        case "running":
            return "figure.run"
        case "cycling":
            return "figure.outdoor.cycle"
        case "swimming":
            return "figure.pool.swim"
        case "strength training":
            return "dumbbell.fill"
        case "yoga":
            return "figure.mind.and.body"
        case "hiit":
            return "bolt.fill"
        case "dancing":
            return "music.note"
        case "hiking":
            return "figure.hiking"
        case "gardening":
            return "leaf.fill"
        default:
            return "figure.walk"
        }
    }

    /// Returns the color for an intensity level
    func intensityColor(for level: Int, currentIntensity: Int) -> Color {
        if level <= currentIntensity {
            if currentIntensity <= 3 {
                return .green
            } else if currentIntensity <= 6 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - Add Exercise Session Sheet
/// Sheet for manually adding a new exercise session
struct AddExerciseSessionSheet: View {
    @Binding var isPresented: Bool
    var moc: NSManagedObjectContext
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var selectedType = "Walking"
    @State private var selectedStartDate = Date()
    @State private var durationMinutes: Int = 30
    @State private var intensity: Double = 5
    @State private var distance: Double = 5.0 // Distance in km for Walking/Running/Cycling
    @State private var caloriesBurned: String = ""
    @State private var notes: String = ""
    @State private var useEstimatedCalories = true

    let exerciseTypes = ["Walking", "Running", "Cycling", "Swimming", "Strength Training", "Yoga", "HIIT", "Dancing", "Hiking", "Gardening", "Other"]

    /// Exercise types that should show Distance slider instead of Intensity
    private var isDistanceBasedExercise: Bool {
        ["Walking", "Running", "Cycling"].contains(selectedType)
    }

    private var isPortrait: Bool {
        verticalSizeClass != .compact
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPortrait {
                    Text("Add Exercise Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }
                Form {
                Section("Exercise Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(exerciseTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                Section("Start Time") {
                    DatePicker("Date & Time", selection: $selectedStartDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }

                Section("Duration") {
                    Stepper(value: $durationMinutes, in: 5...300, step: 5) {
                        if durationMinutes >= 60 {
                            let hrs = durationMinutes / 60
                            let mins = durationMinutes % 60
                            if mins == 0 {
                                Text("\(hrs) hr")
                                    .font(.body)
                                    .fontWeight(.semibold)
                            } else {
                                Text("\(hrs) hr \(mins) min")
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                        } else {
                            Text("\(durationMinutes) min")
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Show Distance slider for Walking/Running/Cycling, Intensity for others
                if isDistanceBasedExercise {
                    Section("Distance") {
                        HStack {
                            Slider(value: $distance, in: 0.5...20, step: 0.5)
                            Text(String(format: "%.1f km", distance))
                                .frame(width: 60)
                                .font(.headline)
                        }
                    }
                } else {
                    Section("Intensity (1-10)") {
                        HStack {
                            Slider(value: $intensity, in: 1...10, step: 1)
                            Text("\(Int(intensity))")
                                .frame(width: 30)
                                .font(.headline)
                        }
                    }
                }

                Section("Calories Burned") {
                    Toggle("Use Estimated Value", isOn: $useEstimatedCalories)

                    if useEstimatedCalories {
                        Text("\(Int(estimateCalories())) cal")
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            TextField("Enter value", text: $caloriesBurned)
                                .keyboardType(.numberPad)
                            Text("cal")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            }
            .navigationTitle(isPortrait ? "" : "Add Exercise Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(selectedType.isEmpty || durationMinutes == 0)
                }
            }
            .alert("Save Error", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    /// Saves the new exercise session to Core Data
    func saveExercise() {
        let durationInMinutes = Double(durationMinutes)
        let calories = useEstimatedCalories ? estimateCalories() : Double(caloriesBurned) ?? 0

        let newExercise = ExerciseSessionEntity(context: moc)
        newExercise.id = UUID()
        newExercise.type = selectedType
        newExercise.startDate = selectedStartDate
        newExercise.endDate = Calendar.current.date(byAdding: .minute, value: Int(durationInMinutes), to: selectedStartDate)
        newExercise.duration = durationInMinutes
        newExercise.intensity = intensity
        newExercise.caloriesBurned = calories
        newExercise.distance = isDistanceBasedExercise ? distance : 0.0
        newExercise.notes = notes.isEmpty ? nil : notes

        do {
            try moc.save()
            isPresented = false
        } catch {
            saveErrorMessage = "Could not save exercise session. Please try again."
            showSaveError = true
        }
    }

    /// Estimates calories burned based on exercise type, duration, and intensity
    /// Uses approximate values for average person (varies by weight, fitness level, etc.)
    func estimateCalories() -> Double {
        let durationInMinutes = Double(durationMinutes)
        let intensity = self.intensity

        // Base calories per minute for each exercise type
        let baseCaloriesPerMinute: Double = {
            switch selectedType.lowercased() {
            case "walking":
                return 3.5 // ~210 cal/hour at moderate pace
            case "running":
                return 10.0 // ~600 cal/hour at moderate pace
            case "cycling":
                return 8.0 // ~480 cal/hour at moderate pace
            case "swimming":
                return 9.0 // ~540 cal/hour
            case "strength training":
                return 6.0 // ~360 cal/hour
            case "yoga":
                return 3.0 // ~180 cal/hour
            case "hiit":
                return 12.0 // ~720 cal/hour
            case "dancing":
                return 7.0 // ~420 cal/hour
            case "hiking":
                return 7.5 // ~450 cal/hour
            case "gardening":
                return 3.5 // ~210 cal/hour (comparable to moderate walking)
            default:
                return 5.0 // ~300 cal/hour
            }
        }()

        // Adjust by intensity (1-10 scale)
        let intensityMultiplier = intensity / 5.0 // 5 is baseline

        return baseCaloriesPerMinute * durationInMinutes * intensityMultiplier
    }
}

#Preview {
    ExerciseLogView()
        .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
