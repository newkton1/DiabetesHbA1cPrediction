//
//  TrialManager.swift
//  DiabetesHbA1cPrediction
//
//  Tracks the user's free trial period.
//  The trial begins on first app launch and lasts 30 days.
//  After 30 days, the user must subscribe to continue.
//
//  Note: This is a client-side trial tracker that works alongside
//  the StoreKit free trial. The StoreKit trial handles billing;
//  this class handles the in-app access gate.
//

import Foundation
import Combine

final class TrialManager: ObservableObject {

    static let shared = TrialManager()

    // MARK: - Constants

    private let trialDurationDays = 30
    private let firstLaunchKey    = "trialFirstLaunchDate"

    // MARK: - Published State

    /// True when the user is within the 30-day trial window.
    @Published var isInTrial: Bool = false

    /// Days remaining in the trial (0 if expired or subscribed).
    @Published var daysRemaining: Int = 0

    // MARK: - Init

    private init() {
        recordFirstLaunchIfNeeded()
        refresh()
    }

    // MARK: - Public

    /// Call on every app launch to refresh trial state.
    func refresh() {
        guard let startDate = firstLaunchDate else {
            isInTrial     = false
            daysRemaining = 0
            return
        }

        let elapsed = Calendar.current.dateComponents(
            [.day],
            from: startDate,
            to: Date()
        ).day ?? 0

        let remaining = max(0, trialDurationDays - elapsed)
        daysRemaining = remaining
        isInTrial     = remaining > 0
    }

    /// The date of first app launch (nil if not yet recorded).
    var firstLaunchDate: Date? {
        UserDefaults.standard.object(forKey: firstLaunchKey) as? Date
    }

    // MARK: - Private

    /// Records the first launch date once, permanently.
    private func recordFirstLaunchIfNeeded() {
        guard UserDefaults.standard.object(forKey: firstLaunchKey) == nil else { return }
        UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
    }
}
