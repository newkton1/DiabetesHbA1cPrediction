//
//  DemoClearedTransitionView.swift
//  DiabetesHbA1cPrediction
//
//  Shown immediately after a user clears demo data.
//  Explains that the app's features unlock progressively
//  as they build their own data history, so the transition
//  from a fully-loaded demo to a fresh start isn't jarring.
//

import SwiftUI

struct DemoClearedTransitionView: View {

    /// Called when the user dismisses this sheet — parent refreshes state.
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: - Milestone model

    private struct Milestone: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let days: String
        let title: String
        let detail: String
    }

    private let milestones: [Milestone] = [
        Milestone(icon: "chart.line.uptrend.xyaxis", color: .orange,
                  days: "3 days",
                  title: "Glucose trend charts",
                  detail: "Your readings plotted over time"),
        Milestone(icon: "fork.knife",                color: .blue,
                  days: "7 days",
                  title: "Similar meal history",
                  detail: "See how past meals with similar glycaemic load affected your glucose"),
        Milestone(icon: "waveform.path.ecg.rectangle", color: .red,
                  days: "14 days",
                  title: "GMI estimate",
                  detail: "Your estimated Glucose Management Indicator from 14 days of readings")
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
                .padding(.bottom, 12)

            // Title
            Text("Your Journey Starts Now")
                .font(.title2).bold()
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            // Subtitle
            Text("The demo data has been cleared. As you log your own readings, meals, and exercise, the app's features unlock automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)

            // Milestone cards
            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    HStack(spacing: 14) {
                        // Day badge
                        Text(LocalizedStringKey(milestone.days))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(milestone.color)
                            .clipShape(Capsule())
                            .frame(width: 68, alignment: .center)
                            .accessibilityLabel(Text(LocalizedStringKey(milestone.days)))

                        // Icon
                        Image(systemName: milestone.icon)
                            .font(.body)
                            .foregroundStyle(milestone.color)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        // Text
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(milestone.title))
                                .font(.subheadline).fontWeight(.medium)
                            Text(LocalizedStringKey(milestone.detail))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    if index < milestones.count - 1 {
                        Divider().padding(.leading, 20)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal, 20)

            // Checklist hint
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("The Getting Started checklist on your dashboard will guide you through the first steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Spacer(minLength: 24)

            // Get Started button
            Button {
                dismiss()
                onDismiss?()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Preview

#Preview {
    DemoClearedTransitionView()
}
