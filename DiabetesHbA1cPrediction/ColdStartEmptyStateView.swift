//
//  ColdStartEmptyStateView.swift
//  DiabetesHbA1cPrediction
//
//  Reusable empty-state view shown when a feature hasn't been unlocked yet.
//  Displays an icon, heading, body text, optional progress bar, and optional
//  action button. Matches the established empty-state pattern in the app.
//

import SwiftUI

/// A reusable empty-state component for cold-start screens.
///
/// Usage:
/// ```
/// ColdStartEmptyStateView(
///     icon: "chart.line.uptrend.xyaxis",
///     heading: "Your trends will appear here",
///     body: "Log blood glucose readings over a few days...",
///     progress: ColdStartEmptyStateView.Progress(current: 1, total: 3, label: "days logged"),
///     actionTitle: "Log glucose reading",
///     action: { /* navigate to glucose log */ }
/// )
/// ```
struct ColdStartEmptyStateView: View {

    struct Progress {
        let current: Int
        let total: Int
        let label: String

        var fraction: Double {
            guard total > 0 else { return 0 }
            return min(Double(current) / Double(total), 1.0)
        }

        var displayText: String {
            // Use positional format so Japanese can reorder the components.
            // xcstrings key: "%1$d of %2$d %3$@"
            // Japanese:       "%2$d日中%1$d日%3$@"
            let localizedLabel = NSLocalizedString(label, comment: "")
            return String(format: NSLocalizedString("%1$d of %2$d %3$@", comment: ""), current, total, localizedLabel)
        }
    }

    let icon: String
    let heading: LocalizedStringKey
    let bodyText: LocalizedStringKey
    var progress: Progress? = nil
    var actionTitle: LocalizedStringKey? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil
    var secondaryTitle: LocalizedStringKey? = nil
    var secondaryAction: (() -> Void)? = nil

    /// Optional pill-style steps (used by Meal Impact screen)
    var steps: [StepPill]? = nil

    struct StepPill: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.6))
                .accessibilityHidden(true)

            // Heading
            Text(heading)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            // Body
            Text(bodyText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Progress bar (optional)
            if let progress = progress {
                VStack(spacing: 6) {
                    Text(progress.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray4))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: geo.size.width * progress.fraction, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 40)
            }

            // Step pills (optional, used by Meal Impact)
            if let steps = steps {
                FlowLayout(spacing: 8) {
                    ForEach(steps) { step in
                        HStack(spacing: 4) {
                            Image(systemName: step.icon)
                                .font(.caption2)
                            Text(step.text)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Primary action button (optional)
            if let title = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        if let icon = actionIcon {
                            Image(systemName: icon)
                                .font(.subheadline)
                        }
                        Text(title)
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }

            // Secondary button (optional, ghost style)
            if let title = secondaryTitle, let action = secondaryAction {
                Button(action: action) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Simple Flow Layout for Step Pills

/// A basic horizontal wrapping layout for the step pill badges.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x,
                                               y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
