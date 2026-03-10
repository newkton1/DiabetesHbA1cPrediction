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
                // Request HealthKit permissions on first appearance,
                // then start the glucose observer for live sync.
                .onAppear {
                    if HealthKitManager.isHealthKitAvailable() {
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
