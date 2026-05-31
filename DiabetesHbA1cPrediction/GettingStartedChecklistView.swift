//
//  GettingStartedChecklistView.swift
//  DiabetesHbA1cPrediction
//
//  A dismissable checklist card shown on the Dashboard during the first
//  two weeks of use. Tracks 7 milestones from first actions through
//  data thresholds, with a progress bar and optional video link.
//

import SwiftUI

/// Getting-started checklist card displayed on the Dashboard.
/// Auto-hides when all milestones are complete or when manually dismissed.
struct GettingStartedChecklistView: View {

    @ObservedObject var coldStart: ColdStartManager
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text("Getting started")
                        .font(.headline)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coldStart.checklistDismissed = true
                    }
                } label: {
                    Text("Dismiss")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            // Milestone items
            VStack(spacing: 0) {
                checklistItem(
                    title: "Log your first glucose reading",
                    subtitle: "CGM or finger-stick — either works",
                    isComplete: coldStart.hasLoggedFirstGlucose
                )

                checklistItem(
                    title: "Log your first meal",
                    subtitle: "Search or build a meal from foods you ate",
                    isComplete: coldStart.hasLoggedFirstMeal
                )

                checklistItem(
                    title: "Log post-meal glucose",
                    subtitle: "Check between 90 and 120 minutes after eating to capture the meal effect",
                    isComplete: coldStart.hasLoggedPostMealGlucose
                )

                checklistItem(
                    title: "Log an exercise session",
                    subtitle: "Even a short walk — see how activity changes your response",
                    isComplete: coldStart.hasLoggedExercise
                )

                checklistItem(
                    title: "Reach 3 days of data",
                    subtitle: "Unlocks glucose trend charts",
                    isComplete: coldStart.reached3Days
                )

                checklistItem(
                    title: "Reach 7 days of data",
                    subtitle: "Unlocks similar-meal history",
                    isComplete: coldStart.reached7Days
                )

                checklistItem(
                    title: "Reach 14 days of data",
                    subtitle: "Unlocks your first GMI estimate",
                    isComplete: coldStart.reached14Days
                )
            }

            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 4)

            // Progress bar
            VStack(spacing: 6) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(coldStart.completedCount) of \(ColdStartManager.totalMilestones)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray4))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(
                                width: geo.size.width * Double(coldStart.completedCount) / Double(ColdStartManager.totalMilestones),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Video link
            Button {
                // Placeholder — link to video when available
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                        .font(.caption)
                    Text("Watch: Getting the best from Diabetes Feast")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Checklist Item Row

    private func checklistItem(title: String, subtitle: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Check circle
            ZStack {
                Circle()
                    .strokeBorder(isComplete ? Color.green : Color(.systemGray3), lineWidth: 1.5)
                    .frame(width: 22, height: 22)

                if isComplete {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 22, height: 22)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 2)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isComplete ? .regular : .medium)
                    .foregroundColor(isComplete ? .secondary : .primary)
                    .strikethrough(isComplete, color: .secondary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
