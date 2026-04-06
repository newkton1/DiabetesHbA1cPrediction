//  WalkRecommendationCard.swift  –  DiabetesHbA1cPrediction
import SwiftUI

struct WalkRecommendationCard: View {
    let recommendation: String
    var onTap: (() -> Void)? = nil

    /// Reads the user's preferred exercise type for dynamic icon & title
    private var exerciseType: ExerciseOffsetType { .current }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: exerciseType.iconName)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Post-Meal \(exerciseType.label)")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(recommendation)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.60, blue: 0.40),
                             Color(red: 0.05, green: 0.45, blue: 0.30)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .green.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Post-meal \(exerciseType.label) recommendation: \(recommendation)")
    }
}

#Preview {
    WalkRecommendationCard(
        recommendation: "Consider a 20 min / 1.7 km walk after this meal.",
        onTap: {}
    ).padding()
}
