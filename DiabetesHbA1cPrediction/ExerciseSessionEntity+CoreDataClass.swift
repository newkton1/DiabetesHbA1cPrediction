//
//  ExerciseSessionEntity+CoreDataClass.swift
//  DiabetesHbA1Cprediction
//
//  Created by test2 on 2025/08/28.
//
//

import Foundation
import CoreData

@objc(ExerciseSessionEntity)
public class ExerciseSessionEntity: NSManagedObject {

}

// MARK: - Shared intensity score (manual entries and Apple Health use the same rule)

extension ExerciseSessionEntity {

    /// 1–10 intensity on a MET-like scale, so the bar colours match standard bands:
    /// 1–3 light (green), 4–6 moderate (yellow), 7–10 vigorous (red).
    ///
    /// - Walking / hiking / running / cycling with a distance: from pace (km/h).
    /// - Everything else: calories per minute relative to that activity's typical rate.
    static func estimatedIntensity(type: String, minutes: Double, distanceKm: Double, calories: Double) -> Double {
        let t = type.lowercased()
        if minutes > 0, distanceKm > 0 {
            let kmh = distanceKm / (minutes / 60.0)
            if let met = paceMET(type: t, kmh: kmh) { return clampScore(met) }
        }
        let base = baseline(for: t)
        if minutes > 0, calories > 0 {
            return clampScore(base.met * (calories / minutes) / base.caloriesPerMinute)
        }
        return clampScore(base.met)
    }

    /// Intensity to show and export: pace-based when a distance exists (so old and new,
    /// manual and Health entries agree), otherwise the stored value (e.g. the manual slider).
    var effectiveIntensity: Double {
        if distance > 0, duration > 0, Self.paceMET(type: (type ?? "").lowercased(), kmh: distance / (duration / 60.0)) != nil {
            return Self.estimatedIntensity(type: type ?? "", minutes: duration, distanceKm: distance, calories: caloriesBurned)
        }
        return intensity
    }

    /// Typical calories/min (same table as the manual calorie estimate) and typical MET.
    static func baseline(for type: String) -> (caloriesPerMinute: Double, met: Double) {
        switch type.lowercased() {
        case "walking":            return (3.5, 3.5)
        case "running":            return (10.0, 9.8)
        case "cycling":            return (8.0, 7.5)
        case "swimming":           return (9.0, 7.0)
        case "strength training":  return (6.0, 5.0)
        case "yoga":               return (3.0, 2.5)
        case "hiit":               return (12.0, 8.0)
        case "dancing":            return (7.0, 5.0)
        case "hiking":             return (7.5, 6.0)
        case "gardening":          return (3.5, 3.5)
        default:                   return (5.0, 4.0)
        }
    }

    /// MET from pace (Compendium of Physical Activities, approximate). nil = pace not meaningful.
    static func paceMET(type: String, kmh: Double) -> Double? {
        guard kmh.isFinite, kmh > 0 else { return nil }
        switch type {
        case "walking", "hiking":
            let table: [(Double, Double)] = [(2.0, 2.0), (3.2, 2.8), (4.0, 3.0), (4.8, 3.5),
                                             (5.6, 4.3), (6.4, 5.0), (7.2, 7.0), (8.0, 8.3)]
            let walk = interpolate(table, kmh)
            return type == "hiking" ? walk + 2.0 : walk
        case "running":
            return max(6.0, kmh * 1.02)
        case "cycling":
            switch kmh {
            case ..<16: return 4.0
            case ..<19: return 6.8
            case ..<22: return 8.0
            case ..<25: return 10.0
            default:    return 12.0
            }
        default:
            return nil
        }
    }

    private static func interpolate(_ table: [(Double, Double)], _ x: Double) -> Double {
        guard let first = table.first, let last = table.last else { return 0 }
        if x <= first.0 { return first.1 }
        if x >= last.0 { return last.1 }
        for i in 1..<table.count where x <= table[i].0 {
            let (x0, y0) = table[i - 1], (x1, y1) = table[i]
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        }
        return last.1
    }

    private static func clampScore(_ v: Double) -> Double {
        min(10, max(1, v.rounded()))
    }
}
