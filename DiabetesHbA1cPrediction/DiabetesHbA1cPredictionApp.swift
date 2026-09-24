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
import UserNotifications
import BackgroundTasks

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

    // MARK: - ERM Bootstrap

    /// Touch the ERM singleton here — before any scene code runs — so its
    /// NotificationCenter observers are registered before the first
    /// feastMealSaved / cancelIfExercised notification can fire.
    /// ERMLoader.m (+load) does the same job at binary-load time; this call
    /// is a belt-and-suspenders fallback in case NSClassFromString returns nil
    /// on a specific device/OS combination.
    init() {
        ExerciseReminderManager.bootstrap()
        // Register the BGAppRefreshTask handler that ERM uses to check for
        // in-progress exercise around T+80, before the T+90 nudge fires.
        // Must be registered here — before the first scene is created.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: ExerciseReminderManager.nudgeCheckTaskID,
            using: nil
        ) { task in
            // Hop to MainActor before calling ERM — its properties are main-actor-isolated.
            Task { @MainActor in
                ExerciseReminderManager.shared.handleNudgeCheckBackground(
                    task: task as! BGAppRefreshTask)
            }
        }
    }

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
                // Posted via NotificationCenter — ERM.swift is in a separate Swift
                // compilation batch (Xcode 26) and cannot be referenced by name here.
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        NotificationCenter.default.post(
                            name: Notification.Name("com.diabetesfeast.cancelIfExercised"),
                            object: nil)
                    }
                }
                // Request HealthKit permissions on first appearance,
                // then start the glucose observer for live sync.
                // Skip during UI test screenshot runs (avoids the auth dialog).
                .onAppear {
                    // Request notification permission early so the app appears
                    // in Settings → Notifications from the very first launch.
                    // Called directly on UNUserNotificationCenter rather than via
                    // ExerciseReminderManager, which lives in a separate Swift
                    // compilation batch (Xcode 26) and cannot be referenced here.
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound])
                    }

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
                                // Start observing HealthKit for new workouts so
                                // the app is woken in the background when the user
                                // completes a walk/run and can cancel the T+150
                                // "Have you exercised?" nudge before it fires.
                                healthKitManager.startExerciseObserver()
                                // Also observe step count changes so nudges can be
                                // cancelled while a walk is still in progress —
                                // before the workout is saved and the workout observer fires.
                                healthKitManager.startStepObserver()
                            }
                        }
                    }
                }
        }
    }
}
