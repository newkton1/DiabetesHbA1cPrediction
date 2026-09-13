//  ExerciseReminderManager.swift  –  DiabetesHbA1cPrediction
//
//  Schedules two gentle local notifications after the user saves a What If?
//  feast plan, motivating them to do the offset exercise before blood glucose peaks.
//
//  Nudge 1 (T+90 min)  — offset window is opening; invites action.
//  Nudge 2 (T+150 min) — glucose may be peaking; softer urgency.
//  Monitoring stops at T+180 min; both notifications are cancelled automatically
//  if HealthKit shows sufficient activity since the feast start, OR if the user
//  taps "Done — I exercised" directly on the notification banner.
//
//  Philosophy: motivate, never scold.

import Foundation
import UserNotifications
import HealthKit

final class ExerciseReminderManager: NSObject {

    static let shared = ExerciseReminderManager()

    // MARK: - Constants

    private let center       = UNUserNotificationCenter.current()
    private let healthStore  = HKHealthStore()
    private let nudge1ID     = "feastExerciseNudge1"
    private let nudge2ID     = "feastExerciseNudge2"
    private let feastTimeKey = "exerciseReminderFeastStartTime"
    private let categoryID   = "feastExerciseNudgeCategory"
    private let actionID     = "FEAST_EXERCISE_DONE"

    /// Minimum step count since feast start to consider the user active.
    private let minSteps: Double = 500

    private override init() {
        super.init()
        // Must set delegate before any notification response can be delivered.
        center.delegate = self
        registerCategory()
    }

    // MARK: - Setup

    /// Call at app launch to ensure the singleton (and its delegate) is live
    /// before iOS delivers any pending notification response.
    func setup() { /* forces init */ }

    // MARK: - Schedule

    /// Call immediately after a feast plan is saved.
    /// `feastTime` defaults to `Date()` (the moment of saving).
    func scheduleReminders(feastTime: Date = Date()) {
        cancelPendingOnly()
        UserDefaults.standard.set(feastTime, forKey: feastTimeKey)

        requestPermissionIfNeeded { [weak self] granted in
            guard granted, let self else { return }

            self.scheduleNudge(
                identifier: self.nudge1ID,
                fireDate:   feastTime.addingTimeInterval(90 * 60),
                title: NSLocalizedString(
                    "Feast Offset Window Opening",
                    comment: "Exercise nudge 1 title — shown 90 min after feast start"),
                body: NSLocalizedString(
                    "Your feast offset window is opening — ready for that exercise? Even a short one helps.",
                    comment: "Exercise nudge 1 body — motivating, not scolding")
            )

            self.scheduleNudge(
                identifier: self.nudge2ID,
                fireDate:   feastTime.addingTimeInterval(150 * 60),
                title: NSLocalizedString(
                    "Blood Glucose May Be Peaking",
                    comment: "Exercise nudge 2 title — shown 150 min after feast start"),
                body: NSLocalizedString(
                    "Your blood glucose may be peaking right now. A short walk would really help — any movement counts.",
                    comment: "Exercise nudge 2 body — gentle urgency")
            )
        }
    }

    // MARK: - Cancel if exercised (foreground check)

    /// Call when app enters foreground. Checks HealthKit for activity since
    /// feast time; cancels remaining nudges silently if sufficient activity found.
    func cancelIfExercised() {
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else { return }

        let elapsed = Date().timeIntervalSince(feastTime)
        guard elapsed > 0 else { return }

        if elapsed >= 180 * 60 {
            cancelAll()
            return
        }

        Task {
            let active = await hasActivitySince(feastTime)
            if active {
                await MainActor.run { self.cancelAll() }
                #if DEBUG
                print("ExerciseReminderManager: activity detected — nudges cancelled.")
                #endif
            }
        }
    }

    // MARK: - Public cancel

    /// Cancels all pending nudges and clears the stored feast time.
    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [nudge1ID, nudge2ID])
        UserDefaults.standard.removeObject(forKey: feastTimeKey)
    }

    // MARK: - HealthKit activity check

    private func hasActivitySince(_ startDate: Date) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        if await hasWorkoutSince(startDate)            { return true }
        if await stepCountSince(startDate) >= minSteps { return true }
        return false
    }

    private func hasWorkoutSince(_ startDate: Date) async -> Bool {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate:  predicate,
                limit:      1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: !(samples ?? []).isEmpty)
            }
            healthStore.execute(query)
        }
    }

    private func stepCountSince(_ startDate: Date) async -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType:            stepType,
                quantitySamplePredicate: predicate,
                options:                 .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Private helpers

    private func registerCategory() {
        let doneAction = UNNotificationAction(
            identifier: actionID,
            title: NSLocalizedString(
                "Done — I exercised",
                comment: "Notification action button — user confirms they have exercised"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier:         categoryID,
            actions:            [doneAction],
            intentIdentifiers:  [],
            options:            []
        )
        center.setNotificationCategories([category])
    }

    private func scheduleNudge(identifier: String, fireDate: Date, title: String, body: String) {
        guard fireDate > Date() else {
            #if DEBUG
            print("ExerciseReminderManager: skipping \(identifier) — fire date is in the past.")
            #endif
            return
        }

        let content                  = UNMutableNotificationContent()
        content.title                = title
        content.body                 = body
        content.sound                = .default
        content.categoryIdentifier   = categoryID
        content.userInfo             = ["type": "feastExerciseNudge"]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            #if DEBUG
            if let error {
                print("ExerciseReminderManager: failed to schedule \(identifier): \(error)")
            } else {
                print("ExerciseReminderManager: scheduled \(identifier) for \(fireDate)")
            }
            #endif
        }
    }

    /// Cancels pending notifications without touching the stored feast time
    /// (used when rescheduling for a new feast).
    private func cancelPendingOnly() {
        center.removePendingNotificationRequests(withIdentifiers: [nudge1ID, nudge2ID])
    }

    private func requestPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            default:
                completion(false)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension ExerciseReminderManager: UNUserNotificationCenterDelegate {

    /// Handles the "Done — I exercised" action button tap (works even when app
    /// is backgrounded — iOS wakes the app to deliver the response).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == actionID {
            cancelAll()
            #if DEBUG
            print("ExerciseReminderManager: 'Done — I exercised' tapped — all nudges cancelled.")
            #endif
        }
        completionHandler()
    }

    /// Show nudge banners even when the app is in the foreground (e.g. during testing).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.content.userInfo["type"] as? String == "feastExerciseNudge" else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound])
    }
}
