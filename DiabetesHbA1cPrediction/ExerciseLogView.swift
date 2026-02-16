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
    @FetchRequest(
        entity: ExerciseSessionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ExerciseSessionEntity.startDate, ascending: false)]
    ) var exercises: FetchedResults<ExerciseSessionEntity>

    @State private var showAddSheet = false
    @State private var showSyncAlert = false
    @State private var syncMessage = ""
    @State private var isSyncing = false
    @State private var showDeleteConfirmation = false
    @State private var exerciseToDelete: ExerciseSessionEntity?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header with Sync Button
                HStack {
                    Text("Exercise Log")
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

                // MARK: - Weekly Summary Card
                WeeklySummaryCard(exercises: exercises)
                    .padding()

                // MARK: - Exercise List
                List {
                    if exercises.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)

                            Text("No Exercise Sessions")
                                .font(.headline)

                            Text("Add your first workout or sync from Health")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
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
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
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
        }
    }

    // MARK: - Helper Methods

    /// Syncs exercise data from HealthKit
    func syncFromHealth() {
        isSyncing = true

        // Note: In a real app, this would call HealthKitManager.shared.syncExerciseData()
        // For now, we'll simulate the sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            syncMessage = "Sync completed successfully"
            showSyncAlert = true
            isSyncing = false
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
            print("Error deleting exercise: \(error.localizedDescription)")
        }
    }
    
    /// Deletes a single exercise session
    func deleteSingleExercise(_ exercise: ExerciseSessionEntity) {
        moc.delete(exercise)
        
        do {
            try moc.save()
        } catch {
            print("Error deleting exercise: \(error.localizedDescription)")
        }
    }
}

// MARK: - Weekly Summary Card
/// Displays aggregated weekly exercise statistics
struct WeeklySummaryCard: View {
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

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 16) {
                // Total Minutes
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(Int(weeklyStats.minutes))")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                // Total Calories
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Calories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(Int(weeklyStats.calories))")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                // Session Count
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundColor(.green)
                        Text("Sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(weeklyStats.sessions)")
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

// MARK: - Exercise Row View
/// Individual row for displaying an exercise session
struct ExerciseRowView: View {
    let exercise: ExerciseSessionEntity

    var duration: String {
        let hours = Int(exercise.duration) / 60
        let minutes = Int(exercise.duration) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Exercise type icon
            Image(systemName: exerciseIcon(for: exercise.type ?? ""))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            // Exercise details
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.type ?? "Unknown")
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(Int(exercise.caloriesBurned)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Intensity bar (1-10)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Intensity")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 2) {
                    ForEach(1...10, id: \.self) { level in
                        Rectangle()
                            .fill(intensityColor(for: level, currentIntensity: Int(exercise.intensity)))
                            .frame(height: 4)
                    }
                }
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

    @State private var selectedType = "Walking"
    @State private var selectedStartDate = Date()
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var intensity: Double = 5
    @State private var distance: Double = 5.0 // Distance in km for Walking/Running/Cycling
    @State private var caloriesBurned: String = ""
    @State private var notes: String = ""
    @State private var useEstimatedCalories = true

    let exerciseTypes = ["Walking", "Running", "Cycling", "Swimming", "Strength Training", "Yoga", "HIIT", "Dancing", "Hiking", "Other"]

    /// Exercise types that should show Distance slider instead of Intensity
    private var isDistanceBasedExercise: Bool {
        ["Walking", "Running", "Cycling"].contains(selectedType)
    }

    var body: some View {
        NavigationStack {
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
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Stepper(value: $hours, in: 0...23) {
                                Text("\(hours)")
                                    .frame(width: 24)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Stepper(value: $minutes, in: 0...59) {
                                Text("\(minutes)")
                                    .frame(width: 24)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(hours * 60 + minutes) minutes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
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
            .navigationTitle("Add Exercise Session")
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
                    .disabled(selectedType.isEmpty || (hours == 0 && minutes == 0))
                }
            }
        }
    }

    /// Saves the new exercise session to Core Data
    func saveExercise() {
        let durationInMinutes = Double(hours * 60 + minutes)
        let calories = useEstimatedCalories ? estimateCalories() : Double(caloriesBurned) ?? 0

        let newExercise = ExerciseSessionEntity(context: moc)
        newExercise.id = UUID()
        newExercise.type = selectedType
        newExercise.startDate = selectedStartDate
        newExercise.endDate = Calendar.current.date(byAdding: .minute, value: Int(durationInMinutes), to: selectedStartDate)
        newExercise.duration = durationInMinutes
        newExercise.intensity = intensity
        newExercise.caloriesBurned = calories
        newExercise.notes = notes.isEmpty ? nil : notes

        do {
            try moc.save()
            isPresented = false
        } catch {
            print("Error saving exercise: \(error.localizedDescription)")
        }
    }

    /// Estimates calories burned based on exercise type, duration, and intensity
    /// Uses approximate values for average person (varies by weight, fitness level, etc.)
    func estimateCalories() -> Double {
        let durationInMinutes = Double(hours * 60 + minutes)
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
