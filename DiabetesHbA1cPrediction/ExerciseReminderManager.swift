//  ExerciseReminderManager.swift  –  DiabetesHbA1cPrediction
//
//  Schedules two gentle local notifications after the user saves a What If?
//  feast plan, motivating them to do the offset exercise before blood glucose peaks.
//
//  Nudge 1 (T+90 min)  — offset window is opening; invites action.
//  Nudge 2 (T+95 min)  — glucose may be peaking; softer urgency.
//  Monitoring stops at T+180 min; both notifications are cancelled automatically
//  if HealthKit shows sufficient activity since the feast start, OR if the user
//  taps "Done — I exercised" directly on the notification banner.
//
//  Philosophy: motivate, never scold.

import Foundation
import UserNotifications
import HealthKit
import BackgroundTasks

// Convenience alias so log calls are short.
private func elog(_ msg: String, function: String = #function) {
    ERMLogger.shared.log(msg, function: function)
}

@MainActor
final class ExerciseReminderManager: NSObject {

    static let shared = ExerciseReminderManager()

    // MARK: - Constants

    /// BGTaskScheduler identifier — must match Info.plist BGTaskSchedulerPermittedIdentifiers.
    static let nudgeCheckTaskID = "com.diabetesfeast.healthkit.refresh"

    private let center           = UNUserNotificationCenter.current()
    private let healthStore      = HKHealthStore()
    private let nudge1ID         = "feastExerciseNudge1"
    private let nudge2ID         = "feastExerciseNudge2"
    private let feastTimeKey     = "exerciseReminderFeastStartTime"
    private let categoryID       = "feastExerciseNudgeCategory"
    private let actionID         = "FEAST_EXERCISE_DONE"
    private let rewardPendingKey = "offsetExerciseRewardPending"

    /// Minimum step count since feast start to consider the user active.
    /// ~1,200 steps ≈ 10 min of purposeful walking at average adult stride (75 cm),
    /// the minimum duration shown in clinical studies to produce meaningful postprandial glucose benefit.
    private let minSteps: Double = 1200

    private override init() {
        super.init()
        elog("ERM singleton initialised")
        // Must set delegate before any notification response can be delivered.
        center.delegate = self
        registerCategory()
        // All callers below post notifications instead of referencing ERM types
        // directly, because ERM.swift is compiled in a separate parallel Swift batch
        // (Xcode 26 batch mode) and its type is not visible to those files at build time.
        // Closures hop to @MainActor explicitly so Swift 6 actor-isolation is satisfied.
        NotificationCenter.default.addObserver(
            forName: Notification.Name("com.diabetesfeast.feastMealSaved"),
            object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.scheduleReminders()
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name("com.diabetesfeast.workoutDetected"),
            object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            elog("NC workoutDetected received — isMonitoring=\(self.isMonitoring)")
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring else {
                    elog("workoutDetected: not monitoring, skipping check")
                    return
                }
                await self.performBackgroundExerciseCheck()
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name("com.diabetesfeast.cancelIfExercised"),
            object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            elog("NC cancelIfExercised received — isMonitoring=\(self.isMonitoring)")
            Task { @MainActor [weak self] in
                self?.cancelIfExercised()
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name("com.diabetesfeast.cancelFeastReminders"),
            object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            elog("NC cancelFeastReminders received")
            Task { @MainActor [weak self] in
                self?.cancelAll()
            }
        }
    }

    // MARK: - Setup

    /// Called from DiabetesHbA1cPredictionApp.init() via ObjC runtime (NSClassFromString +
    /// perform) so the singleton initialises before any SwiftUI scene code runs.
    /// Using a named method avoids the Swift 6 prohibition on defining +load.
    /// No compile-time reference to this type is needed from external files.
    @objc static func bootstrap() {
        _ = shared
    }

    /// Kept for source compatibility. The bootstrap() call above makes this a no-op.
    func setup() { }

    // MARK: - Schedule

    /// Call immediately after a feast plan is saved.
    /// `feastTime` defaults to `Date()` (the moment of saving).
    func scheduleReminders(feastTime: Date = Date()) {
        elog("scheduleReminders called — feastTime=\(feastTime)")
        cancelPendingOnly()
        UserDefaults.standard.set(feastTime, forKey: feastTimeKey)

        // Schedule a BGAppRefreshTask for T+80 so iOS wakes the app and can
        // cancel the T+90 nudge if the user is already mid-walk at that point.
        // HKObserverQuery alone is unreliable here because Apple Watch step data
        // doesn't sync to iPhone HealthKit in real-time during a walk.
        let bgTaskTime = feastTime.addingTimeInterval(80 * 60)
        submitNudgeCheckTask(earliestStart: bgTaskTime)
        elog("BGTask scheduled for T+80 = \(bgTaskTime)")

        // Nudge1 (T+90) is NOT pre-scheduled here.
        // The BGTask fires at T+80, checks for activity, and conditionally fires
        // nudge1 immediately if the user is NOT exercising. This prevents the nudge
        // from firing during a mid-walk via the OS-level UNCalendarNotificationTrigger,
        // which cannot be cancelled if the app is killed while the user walks.
        let nudge2Time = feastTime.addingTimeInterval(95 * 60)
        elog("Nudge1 (T+90): will be fired conditionally by BGTask at T+80")
        elog("Nudge2 (T+95) scheduled for \(nudge2Time)")

        requestPermissionIfNeeded { [weak self] granted in
            guard granted, let self else {
                elog("scheduleReminders: notification permission NOT granted")
                return
            }

            // Only nudge2 is pre-scheduled. Nudge1 is handled by the BGTask.
            self.scheduleNudge(
                identifier: self.nudge2ID,
                fireDate:   nudge2Time,
                title: NSLocalizedString(
                    "Blood Glucose May Be Peaking",
                    comment: "Exercise nudge 2 title — shown 95 min after feast start"),
                body: NSLocalizedString(
                    "Your blood glucose may be peaking right now. A short walk would really help — any movement counts.",
                    comment: "Exercise nudge 2 body — gentle urgency")
            )
        }
    }

    // MARK: - Cancel if exercised (foreground check)

    /// Call when app enters foreground. Checks HealthKit for activity since
    /// feast time; cancels remaining nudges and fires the reward notification
    /// if sufficient activity is found.
    func cancelIfExercised() {
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else {
            elog("cancelIfExercised: no feastTimeKey — not monitoring, returning")
            return
        }

        let elapsed = Date().timeIntervalSince(feastTime)
        elog("cancelIfExercised: elapsed=\(Int(elapsed/60))min since feast")
        guard elapsed > 0 else { return }

        if elapsed >= 180 * 60 {
            elog("cancelIfExercised: T+180 elapsed — calling cancelAll()")
            cancelAll()
            return
        }

        Task {
            elog("cancelIfExercised: querying hasActivitySince \(feastTime)…")
            let active = await hasActivitySince(feastTime)
            elog("cancelIfExercised: hasActivitySince returned active=\(active)")
            if active {
                await MainActor.run {
                    // Double-fire guard: another path (BGTask/observer) may have already
                    // sent the reward while we were awaiting the HealthKit query.
                    // cancelAll() clears feastTimeKey, so its absence means we lost the race.
                    guard UserDefaults.standard.object(forKey: self.feastTimeKey) != nil else {
                        elog("cancelIfExercised: feastTimeKey gone — reward already sent by another path, skipping")
                        return
                    }
                    elog("cancelIfExercised: SENDING REWARD — cancelling nudges")
                    // Set reward flag BEFORE cancelAll() clears the feast key.
                    UserDefaults.standard.set(true, forKey: self.rewardPendingKey)
                    self.cancelAll()
                    self.scheduleRewardNotification()
                    // Notify ExerciseLogView in case it is already on screen
                    // (onAppear won't re-fire for a view that's already visible).
                    NotificationCenter.default.post(
                        name: Notification.Name("com.diabetesfeast.offsetRewardEarned"), object: nil)
                }
            }
        }
    }

    // MARK: - Public cancel

    /// Cancels all pending nudges, removes any already-delivered nudge banners
    /// from Notification Centre, and clears the stored feast time.
    func cancelAll() {
        elog("cancelAll() called — removing nudge1+nudge2, clearing feastTimeKey")
        center.removePendingNotificationRequests(withIdentifiers: [nudge1ID, nudge2ID])
        center.removeDeliveredNotifications(withIdentifiers: [nudge1ID, nudge2ID])
        UserDefaults.standard.removeObject(forKey: feastTimeKey)
    }

    // MARK: - BGTask (scheduled nudge-check at T+80)

    /// Submits a BGAppRefreshTask that fires at or after `earliestStart`, giving
    /// iOS a dedicated background-wake opportunity to cancel the T+90 nudge if
    /// the user is already exercising.  Safe to call multiple times — any
    /// existing pending BGAppRefreshTask with the same identifier is replaced.
    private func submitNudgeCheckTask(earliestStart: Date) {
        let request = BGAppRefreshTaskRequest(identifier: Self.nudgeCheckTaskID)
        request.earliestBeginDate = earliestStart
        do {
            try BGTaskScheduler.shared.submit(request)
            elog("BGAppRefreshTask submitted for \(earliestStart)")
        } catch {
            elog("BGAppRefreshTask submit FAILED: \(error)")
        }
    }

    /// Called by the BGTaskScheduler handler registered in DiabetesHbA1cPredictionApp.init().
    /// Checks for activity since feast time; if found, cancels remaining nudges and
    /// posts the reward notification — exactly like performBackgroundExerciseCheck(),
    /// but driven by BGTaskScheduler rather than HealthKit observer.
    func handleNudgeCheckBackground(task: BGAppRefreshTask) {
        elog("handleNudgeCheckBackground: BGTask FIRED by iOS")
        task.expirationHandler = {
            elog("handleNudgeCheckBackground: BGTask EXPIRED by iOS")
            task.setTaskCompleted(success: false)
        }
        Task { @MainActor [weak self] in
            guard let self else {
                elog("handleNudgeCheckBackground: self is nil — completing failed")
                task.setTaskCompleted(success: false)
                return
            }
            defer { task.setTaskCompleted(success: true) }
            guard self.isMonitoring,
                  let feastTime = UserDefaults.standard.object(forKey: self.feastTimeKey) as? Date
            else {
                elog("handleNudgeCheckBackground: not monitoring or no feastTime — exiting early")
                return
            }

            let elapsed = Date().timeIntervalSince(feastTime)
            elog("handleNudgeCheckBackground: T+\(Int(elapsed/60))min since feast (\(feastTime))")

            elog("handleNudgeCheckBackground: querying hasActivitySince…")
            let active = await self.hasActivitySince(feastTime)
            elog("handleNudgeCheckBackground: hasActivitySince returned active=\(active)")

            if !active {
                // User is NOT exercising — fire nudge1 NOW (immediate delivery).
                // Because nudge1 is no longer pre-scheduled via UNCalendarNotificationTrigger,
                // this is the only place it can fire, so it can never appear mid-walk.
                elog("handleNudgeCheckBackground: no activity — firing nudge1 NOW")
                self.scheduleNudge(
                    identifier: self.nudge1ID,
                    fireDate:   Date(),   // immediate (scheduleNudge uses nil trigger for past dates)
                    title: NSLocalizedString(
                        "Feast Offset Window Opening",
                        comment: "Exercise nudge 1 title"),
                    body: NSLocalizedString(
                        "Your feast offset window is opening — ready for that exercise? Even a short one helps.",
                        comment: "Exercise nudge 1 body")
                )
                return
            }

            // Double-fire guard: another path may have already sent the reward
            // while we were awaiting the HealthKit query. cancelAll() clears
            // feastTimeKey, so its absence means we lost the race — bail out.
            guard UserDefaults.standard.object(forKey: self.feastTimeKey) != nil else {
                elog("handleNudgeCheckBackground: feastTimeKey gone — reward already sent by another path, skipping")
                return
            }
            elog("handleNudgeCheckBackground: ACTIVITY DETECTED — sending reward, cancelling nudges")
            UserDefaults.standard.set(true, forKey: self.rewardPendingKey)
            self.cancelAll()
            self.scheduleRewardNotification()
            NotificationCenter.default.post(
                name: Notification.Name("com.diabetesfeast.offsetRewardEarned"), object: nil)
        }
    }

    // MARK: - HealthKit activity check

    private func hasActivitySince(_ startDate: Date) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            elog("hasActivitySince: HealthKit not available")
            return false
        }
        let workout = await hasWorkoutSince(startDate)
        elog("hasActivitySince: hasWorkoutSince=\(workout)")
        if workout { return true }
        let steps = await stepCountSince(startDate)
        elog("hasActivitySince: stepCount=\(Int(steps)) (min=\(Int(minSteps)))")
        return steps >= minSteps
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
            ) { _, samples, error in
                let found = !(samples ?? []).isEmpty
                if let error { elog("hasWorkoutSince HK error: \(error)") }
                elog("hasWorkoutSince: found=\(found) (samples=\(samples?.count ?? 0))")
                continuation.resume(returning: found)
            }
            self.healthStore.execute(query)
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
            ) { _, stats, error in
                let count = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                if let error { elog("stepCountSince HK error: \(error)") }
                elog("stepCountSince: steps=\(Int(count)) since \(startDate)")
                continuation.resume(returning: count)
            }
            self.healthStore.execute(query)
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
        let content                  = UNMutableNotificationContent()
        content.title                = title
        content.body                 = body
        content.sound                = .default
        content.categoryIdentifier   = categoryID
        content.userInfo             = ["type": "feastExerciseNudge"]

        // If the fire date is in the future, use a calendar trigger (exact delivery).
        // If it's now or in the past, use nil trigger (immediate delivery) — this is
        // used by the BGTask path which fires nudge1 on-demand rather than pre-scheduling it.
        let trigger: UNNotificationTrigger?
        if fireDate > Date().addingTimeInterval(5) {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            elog("scheduleNudge: scheduling \(identifier) for \(fireDate) via calendar trigger")
        } else {
            trigger = nil
            elog("scheduleNudge: scheduling \(identifier) for immediate delivery (nil trigger)")
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                elog("scheduleNudge: FAILED to schedule \(identifier): \(error)")
            } else {
                elog("scheduleNudge: SUCCESS — \(identifier) delivered/scheduled")
            }
        }
    }

    /// Cancels pending notifications without touching the stored feast time
    /// (used when rescheduling for a new feast).
    private func cancelPendingOnly() {
        elog("cancelPendingOnly: removing pending nudge1+nudge2")
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

    // MARK: - Background exercise check (called from HealthKitManager observer)

    /// Async version of the offset-exercise check designed for background wakes.
    /// Unlike `cancelIfExercised()` (which spawns its own inner Task), this method
    /// is fully awaitable so the HealthKit observer can call `finish()` only after
    /// the HealthKit query and notification work are truly complete.
    ///
    /// If activity is detected:
    ///   1. Cancels remaining nudge notifications.
    ///   2. Posts an immediate reward notification visible on the lock screen.
    func performBackgroundExerciseCheck() async {
        elog("performBackgroundExerciseCheck: entered")
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else {
            elog("performBackgroundExerciseCheck: no feastTimeKey — returning")
            return
        }
        let elapsed = Date().timeIntervalSince(feastTime)
        elog("performBackgroundExerciseCheck: T+\(Int(elapsed/60))min since feast")
        guard elapsed > 0 else { return }
        if elapsed >= 180 * 60 {
            elog("performBackgroundExerciseCheck: T+180 elapsed — calling cancelAll()")
            cancelAll()
            return
        }
        elog("performBackgroundExerciseCheck: querying hasActivitySince…")
        let active = await hasActivitySince(feastTime)
        elog("performBackgroundExerciseCheck: hasActivitySince returned active=\(active)")
        guard active else {
            elog("performBackgroundExerciseCheck: no activity — returning without cancelling")
            return
        }
        // Double-fire guard: another path (BGTask) may have already sent the reward
        // while we were awaiting the HealthKit query. cancelAll() clears feastTimeKey,
        // so its absence means we lost the race — bail out.
        guard UserDefaults.standard.object(forKey: feastTimeKey) != nil else {
            elog("performBackgroundExerciseCheck: feastTimeKey gone — reward already sent by another path, skipping")
            return
        }
        elog("performBackgroundExerciseCheck: ACTIVITY DETECTED — sending reward, cancelling nudges")
        // Set the reward flag BEFORE cancelAll() clears the feast key,
        // so the in-app alert can still fire if the notification was missed.
        UserDefaults.standard.set(true, forKey: rewardPendingKey)
        cancelAll()
        scheduleRewardNotification()
        // Notify ExerciseLogView in case it is already on screen.
        NotificationCenter.default.post(
            name: Notification.Name("com.diabetesfeast.offsetRewardEarned"), object: nil)
    }

    /// Posts an immediate local notification congratulating the user on completing
    /// their offset exercise.
    private func scheduleRewardNotification() {
        elog("scheduleRewardNotification: posting reward notification NOW")
        let content      = UNMutableNotificationContent()
        content.title    = NSLocalizedString("Offset Exercise Complete!", comment: "")
        content.body     = NSLocalizedString(
            "Great work! Your offset exercise helps manage your glucose response.", comment: "")
        content.sound    = .default
        content.userInfo = ["type": "feastOffsetReward"]

        let request = UNNotificationRequest(
            identifier: "feastOffsetReward_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil   // nil trigger = deliver immediately
        )
        center.add(request) { error in
            if let error {
                elog("scheduleRewardNotification: ERROR \(error)")
            } else {
                elog("scheduleRewardNotification: reward notification delivered successfully")
            }
        }
    }

    // MARK: - Reward flag (survives background→foreground transition)

    /// Returns true if a background exercise check set the reward pending flag,
    /// and clears the flag so the alert only shows once.
    func consumePendingReward() -> Bool {
        let pending = UserDefaults.standard.bool(forKey: rewardPendingKey)
        elog("consumePendingReward: pending=\(pending)")
        if pending { UserDefaults.standard.removeObject(forKey: rewardPendingKey) }
        return pending
    }

    // MARK: - Offset-exercise helpers

    /// True while a feast plan is active and the monitoring window (< 180 min) hasn't expired.
    var isMonitoring: Bool {
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else { return false }
        let elapsed = Date().timeIntervalSince(feastTime)
        return elapsed >= 0 && elapsed < 180 * 60
    }

    /// Returns `true` if `date` falls within the offset exercise window [feastTime+60min, feastTime+180min].
    func isOffsetExercise(at date: Date) -> Bool {
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else { return false }
        let lower = feastTime.addingTimeInterval(60 * 60)
        let upper = feastTime.addingTimeInterval(180 * 60)
        return date >= lower && date <= upper
    }

    /// Checks HealthKit for activity since feast start. Cancels pending nudges if activity is
    /// found and returns `true` so the caller can show a reward message.
    func cancelIfExercisedReturning() async -> Bool {
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else { return false }
        let elapsed = Date().timeIntervalSince(feastTime)
        guard elapsed > 0 && elapsed < 180 * 60 else {
            if elapsed >= 180 * 60 { cancelAll() }
            return false
        }
        let active = await hasActivitySince(feastTime)
        if active {
            UserDefaults.standard.set(true, forKey: rewardPendingKey)
            cancelAll()
        }
        return active
    }

    /// Returns true if `mealTimestamp` matches the currently monitored feast start
    /// time (within a 60-second tolerance).
    func isActiveFeast(mealTimestamp: Date) -> Bool {
        guard let feastTime = UserDefaults.standard.object(forKey: feastTimeKey) as? Date else { return false }
        return abs(feastTime.timeIntervalSince(mealTimestamp)) < 60
    }

    // MARK: - Permission (async, for app launch)

    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
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
        let type = response.notification.request.content.userInfo["type"] as? String ?? "unknown"
        elog("didReceive notification response: identifier=\(response.notification.request.identifier) type=\(type) action=\(response.actionIdentifier)")
        if response.actionIdentifier == actionID {
            elog("'Done — I exercised' tapped — calling cancelAll()")
            cancelAll()
        }
        completionHandler()
    }

    /// Show nudge and reward banners even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let type = notification.request.content.userInfo["type"] as? String ?? "unknown"
        let id   = notification.request.identifier
        elog("willPresent notification: id=\(id) type=\(type)")
        let isFeastNotification = type == "feastExerciseNudge" || type == "feastOffsetReward"
        completionHandler(isFeastNotification ? [.banner, .sound] : [])
    }
}
