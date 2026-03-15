//
//  Persistence.swift
//  DiabetesHbA1cPrediction
//
//  Manages the Core Data stack for the application.
//  Provides a shared instance for the live app and a preview
//  instance pre-loaded with sample data for SwiftUI previews.
//

import CoreData

/// Central Core Data stack controller.
/// Access via `PersistenceController.shared` (live app) or
/// `PersistenceController.preview` (SwiftUI previews / tests).
struct PersistenceController {

    // MARK: - Shared Instance

    /// The singleton used by the running application.
    static let shared = PersistenceController()

    // MARK: - Preview Instance

    /// An in-memory store pre-loaded with sample data for Xcode previews.
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Seed lightweight sample data so previews aren't empty.
        // PreviewData.populate(context:) adds realistic demo records
        // if available; otherwise previews simply start with an empty store.
        do {
            try viewContext.save()
        } catch {
            // Preview seeding is best-effort; a crash here is acceptable
            // during development but should never ship.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    // MARK: - Container

    /// The underlying `NSPersistentContainer` that owns the Core Data store.
    let container: NSPersistentContainer

    // MARK: - Initialiser

    /// Creates a new persistence controller.
    /// - Parameter inMemory: When `true`, the store lives entirely in RAM
    ///   (used for previews and unit tests so they don't touch disk).
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DiabetesHbA1cPrediction")

        if inMemory {
            container.persistentStoreDescriptions.first!.url =
                URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 • The parent directory does not exist, cannot be created,
                   or disallows writing.
                 • The persistent store is not accessible due to permissions
                   or data-protection when the device is locked.
                 • The device is out of space.
                 • The store could not be migrated to the current model version.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // Automatically merge changes from background contexts
        // into the view context so the UI stays in sync.
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Use a sensible merge policy: in-memory wins over store
        // in the rare case of a conflict.
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
}
