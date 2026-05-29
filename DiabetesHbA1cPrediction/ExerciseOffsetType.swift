//  ExerciseOffsetType.swift  –  DiabetesHbA1cPrediction
//
//  Defines the user's preferred exercise type for the post-meal glucose
//  offset recommendation shown in Plan Feast Treat.
//
//  MET (Metabolic Equivalent of Task) values are clinical averages for
//  moderate-intensity exercise:
//    Walk  ≈ 3.5 METs  (brisk walking ~5 km/h)
//    Run   ≈ 9.0 METs  (jogging ~8 km/h)
//    Cycle ≈ 7.0 METs  (moderate effort ~18 km/h)
//    Swim  ≈ 6.0 METs  (moderate freestyle)
//
//  Calorie burn per minute ≈ MET × bodyWeightKg × 0.0175

import Foundation

enum ExerciseOffsetType: String, CaseIterable, Identifiable {
    case walk   = "walk"
    case run    = "run"
    case cycle  = "cycle"
    case swim   = "swim"
    case garden = "garden"

    var id: String { rawValue }

    /// Human-readable label for the picker
    var label: String {
        switch self {
        case .walk:   return "Walk"
        case .run:    return "Run"
        case .cycle:  return "Cycle"
        case .swim:   return "Swim"
        case .garden: return "Garden"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .walk:   return "figure.walk.circle.fill"
        case .run:    return "figure.run.circle.fill"
        case .cycle:  return "figure.outdoor.cycle"
        case .swim:   return "figure.pool.swim"
        case .garden: return "leaf.fill"
        }
    }

    /// Clinical average MET value for moderate intensity
    var metValue: Double {
        switch self {
        case .walk:   return 3.5
        case .run:    return 9.0
        case .cycle:  return 7.0
        case .swim:   return 6.0
        case .garden: return 3.5  // general gardening ≈ 3.0–4.0 METs; use walk equivalent
        }
    }

    /// Default pace when no personal history is available.
    /// Walk/Run/Cycle: km per minute.  Swim: metres per minute.
    /// Garden: 0 — gardening has no meaningful pace/distance.
    var defaultPace: Double {
        switch self {
        case .walk:   return 5.0 / 60.0    // 5 km/h
        case .run:    return 8.0 / 60.0    // 8 km/h
        case .cycle:  return 18.0 / 60.0   // 18 km/h
        case .swim:   return 30.0 / 60.0   // 30 m/min (≈ 1.8 km/h)
        case .garden: return 0.0           // not distance-based
        }
    }

    /// Whether pace-based distance should be shown in recommendations.
    /// False for activities where distance is not a meaningful output metric.
    var showsDistance: Bool {
        switch self {
        case .walk, .run, .cycle, .swim: return true
        case .garden:                    return false
        }
    }

    /// Distance unit label for display
    var distanceUnit: String {
        switch self {
        case .swim:  return "m"
        default:     return "km"
        }
    }

    /// The verb for the recommendation text
    var actionVerb: String {
        switch self {
        case .walk:   return "walk"
        case .run:    return "run"
        case .cycle:  return "cycle"
        case .swim:   return "swim"
        case .garden: return "gardening session"
        }
    }

    /// Core Data exercise type string used for pace lookup
    var coreDataType: String {
        switch self {
        case .walk:   return "Walking"
        case .run:    return "Running"
        case .cycle:  return "Cycling"
        case .swim:   return "Swimming"
        case .garden: return "Gardening"
        }
    }

    /// Reads the user's saved preference from UserDefaults, defaults to .walk
    static var current: ExerciseOffsetType {
        if let saved = UserDefaults.standard.string(forKey: "preferredExerciseType"),
           let type = ExerciseOffsetType(rawValue: saved) {
            return type
        }
        return .walk
    }
}
