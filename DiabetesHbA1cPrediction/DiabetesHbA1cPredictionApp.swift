//
//  DiabetesHbA1cPredictionApp.swift
//  DiabetesHbA1cPrediction
//
//  The main entry point for the iOS application.
//  Configures the Core Data stack via PersistenceController and injects
//  the managed object context into the SwiftUI environment so every
//  child view can read/write data without manual plumbing.
//
//  Also sets up HealthKit authorisation on first launch so the app can
//  begin syncing exercise and glucose data from Apple Health immediately.
//

import SwiftUI
import CoreData

/// The @main attribute marks this struct as the application entry point.
@main
struct DiabetesHbA1cPredictionApp: App {

    // MARK: - Core Data Stack

    /// The persistence controller that owns the NSPersistentContainer.
    /// Using `shared` for the live app; tests/previews use `.preview`.
    let persistenceController = PersistenceController.shared

    // MARK: - HealthKit Manager

    /// Observable HealthKit manager — shared instance so authorisation
    /// state is visible across the app.
    @StateObject private var healthKitManager = HealthKitManager.shared

    // MARK: - Scene phase (for exercise reminder checks)

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Welcome Sheet

    /// Controls whether the first-launch welcome sheet is visible.
    /// Initialised from UserDefaults so it only shows once.
    @State private var showWelcomeSheet = WelcomeSheetView.shouldPresent

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the Core Data managed object context into the
                // environment so any @FetchRequest or
                // @Environment(\.managedObjectContext) in child views
                // automatically receives the correct context.
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
                // Make the HealthKit manager available as an environment object
                // so views can observe authorisation state and trigger syncs.
                .environmentObject(healthKitManager)
                // Show the one-time welcome sheet on first launch.
                .sheet(isPresented: $showWelcomeSheet) {
                    WelcomeSheetView()
                }
                // Cancel pending exercise nudges if the user has been active
                // since their feast start time.
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        ExerciseReminderManager.shared.cancelIfExercised()
                    }
                }
                // Request HealthKit permissions on first appearance,
                // then start the glucose observer for live sync.
                // Skip during UI test screenshot runs (avoids the auth dialog).
                .onAppear {
                    // Ensure the exercise reminder delegate is live before
                    // any notification response is delivered at cold launch.
                    ExerciseReminderManager.shared.setup()

                    let isUITestRun = ProcessInfo.processInfo.environment["IS_UI_SCREENSHOT_TEST"] == "1"
                        || ProcessInfo.processInfo.arguments.contains("-SkipHealthKitAuth")
                    if HealthKitManager.isHealthKitAvailable() && !isUITestRun {
                        healthKitManager.requestAuthorization { success in
                            if success {
                                #if DEBUG
                                print("[HealthKit] Authorisation granted.")
                                #endif
                                // Start observing HealthKit for new glucose data
                                // so readings auto-sync into Core Data and the
                                // stale-data banner clears without manual sync.
                                healthKitManager.startGlucoseObserver(
                                    context: persistenceController.container.viewContext
                                )
                            }
                        }
                    }
                }
        }
    }
}
