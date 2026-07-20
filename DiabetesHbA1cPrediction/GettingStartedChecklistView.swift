//
//  GettingStartedChecklistView.swift
//  DiabetesHbA1cPrediction
//
//  Progressive 4-step onboarding card shown on the Dashboard.
//  Guides users through: Glucose → Meals → Post-meal glucose → Exercise
//  Each step has a 3-segment progress bar. After all steps, day-count
//  milestones (3, 7, 14) are shown. Tap navigates to the relevant tab.
//
//  IMPORTANT: All copy avoids predictive/diagnostic language for
//  Apple App Store compliance. Uses past tense, emphasizes historical data.
//

import SwiftUI

/// Progressive getting-started card displayed on the Dashboard.
/// Shows one active step at a time with a 3-segment progress bar,
/// plus step dots for context. Auto-hides when dismissed or when
/// demo data is loaded.
struct GettingStartedChecklistView: View {

    @ObservedObject var coldStart: ColdStartManager
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Step Metadata

    private struct StepInfo {
        let icon: String
        let title: String
        let subtitle: String
        let healthKitNote: String?
        let tab: ContentView.Tab
    }

    private let steps: [OnboardingStep: StepInfo] = [
        .glucose: StepInfo(
            icon: "drop.fill",
            title: "Log glucose readings",
            subtitle: "When no CGM readings, add your first 3 finger-stick readings",
            healthKitNote: "Connected to Apple Health — glucose syncs automatically",
            tab: .glucose
        ),
        .meals: StepInfo(
            icon: "fork.knife",
            title: "Log your meals",
            subtitle: "Search or build meals from the foods you ate",
            healthKitNote: nil,
            tab: .meals
        ),
        .postMealGlucose: StepInfo(
            icon: "clock.arrow.circlepath",
            title: "Capture post-meal glucose",
            subtitle: "Log a reading 1–3 hours after eating to see how meals affected your levels",
            healthKitNote: "With CGM and meals logged, post-meal readings are captured automatically",
            tab: .glucose
        ),
        .exercise: StepInfo(
            icon: "figure.run",
            title: "Log exercise sessions",
            subtitle: "Record walks, runs, or workouts to see how activity affected your glucose",
            healthKitNote: "Connected to Apple Health — workouts sync automatically",
            tab: .exercise
        ),
    ]

    // MARK: - Day Milestone Metadata

    private struct DayMilestone {
        let days: Int
        let title: String
        let subtitle: String
        let icon: String
    }

    private let dayMilestones: [DayMilestone] = [
        DayMilestone(days: 3, title: "3 days of data",
                     subtitle: "Glucose trend charts are now available",
                     icon: "chart.xyaxis.line"),
        DayMilestone(days: 7, title: "7 days of data",
                     subtitle: "Similar-meal history is now available",
                     icon: "arrow.triangle.branch"),
        DayMilestone(days: 14, title: "14 days of data",
                     subtitle: "Your first GMI estimate is now available",
                     icon: "trophy.fill"),
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().padding(.horizontal, 16)

            if coldStart.allStepsComplete {
                dayMilestonesSection
            } else {
                activeStepSection
            }

            Divider().padding(.horizontal, 16).padding(.top, 6)
            footerRow
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
                Text("Getting Started")
                    .font(.headline)
            }

            Spacer()

            // Step dots (shows progress through 4 steps)
            if !coldStart.allStepsComplete {
                stepDots
            }

            Spacer().frame(width: 12)

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
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(dotColor(for: step))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func dotColor(for step: OnboardingStep) -> Color {
        if coldStart.isStepComplete(step) {
            return .green
        } else if coldStart.currentStep == step {
            return .blue
        } else {
            return Color(.systemGray4)
        }
    }

    // MARK: - Active Step Section

    private var activeStepSection: some View {
        Group {
            if let current = coldStart.currentStep,
               let info = steps[current] {
                Button {
                    withAnimation {
                        selectedTab = info.tab
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        // Step label
                        Text("Step \(current.rawValue + 1) of 4")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.top, 12)

                        // Icon + title row
                        HStack(spacing: 10) {
                            Image(systemName: info.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)

                            Text(LocalizedStringKey(info.title))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }

                        // HealthKit auto-detect note or subtitle
                        if let hkNote = info.healthKitNote, isHealthKitActive(for: current) {
                            Label {
                                Text(hkNote)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text(LocalizedStringKey(info.subtitle))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 3-segment progress bar
                        segmentBar(for: current)
                            .padding(.bottom, 2)

                        // Tap hint
                        HStack {
                            Spacer()
                            Text("Tap to go to \(NSLocalizedString(info.tab.rawValue, comment: "Tab name"))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 3-Segment Progress Bar

    private func segmentBar(for step: OnboardingStep) -> some View {
        let filled = coldStart.segmentsFilled(for: step)
        let total = ColdStartManager.stepsPerMilestone

        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < filled ? Color.green : Color(.systemGray4))
                        .frame(height: 6)
                }
            }

            // Segment labels
            HStack {
                ForEach(0..<total, id: \.self) { i in
                    if i > 0 { Spacer() }
                    Text(LocalizedStringKey(segmentLabel(index: i)))
                        .font(.system(size: 9))
                        .foregroundColor(i < filled ? .green : .secondary)
                    if i < total - 1 { Spacer() }
                }
            }
        }
    }

    private func segmentLabel(index: Int) -> String {
        switch index {
        case 0: return "First"
        case 1: return "Second"
        case 2: return "Third"
        default: return ""
        }
    }

    // MARK: - Day Milestones Section (post-steps)

    private var dayMilestonesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("All steps complete — keep going!")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(dayMilestones, id: \.days) { milestone in
                let reached = coldStart.glucoseDaysLogged >= milestone.days
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(reached ? Color.green : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        Image(systemName: milestone.icon)
                            .font(.system(size: 12))
                            .foregroundColor(reached ? .white : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(milestone.title))
                            .font(.subheadline)
                            .fontWeight(reached ? .regular : .medium)
                            .foregroundColor(reached ? .secondary : .primary)
                            .strikethrough(reached, color: .secondary)
                        if reached {
                            Text(LocalizedStringKey(milestone.subtitle))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(milestone.days - coldStart.glucoseDaysLogged) more day\(milestone.days - coldStart.glucoseDaysLogged == 1 ? "" : "s") to unlock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if reached {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            // Progress summary
            if coldStart.allStepsComplete {
                Text("\(coldStart.glucoseDaysLogged) day\(coldStart.glucoseDaysLogged == 1 ? "" : "s") of data logged")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(coldStart.completedStepCount) of 4 steps complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func isHealthKitActive(for step: OnboardingStep) -> Bool {
        switch step {
        case .glucose, .postMealGlucose:
            return coldStart.glucoseFromHealthKit
        case .exercise:
            return coldStart.exerciseFromHealthKit
        case .meals:
            return false
        }
    }
}
