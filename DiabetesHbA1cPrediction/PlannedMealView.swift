//  PlannedMealView.swift  –  DiabetesHbA1cPrediction
import SwiftUI
import CoreData

struct PlannedMealView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingStandardPlanner = false
    @State private var showingFeastPlanner    = false

    /// Builds the multi-colored "Before You Eat" description without using deprecated Text `+` operator
    private static var beforeYouEatDescription: AttributedString {
        var part1 = AttributedString("Build your planned meal or Feast treat and see the predicted impact on your glucose and HbA1c ")
        part1.foregroundColor = .secondary

        var part2 = AttributedString("as well as how to prevent the worst effects")
        part2.foregroundColor = .orange

        var part3 = AttributedString(", before taking a single bite.")
        part3.foregroundColor = .secondary

        return part1 + part2 + part3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Explainer banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").foregroundColor(.planAccent)
                            Text("Before You Eat")
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(.planAccent)
                        }
                        Text(Self.beforeYouEatDescription)
                            .font(.caption)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.planAccent.opacity(0.08))
                    .cornerRadius(14).padding(.horizontal)

                    // Feature highlights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What you'll see").font(.headline).padding(.horizontal, 4)
                        PlanFeatureRow(icon: "waveform.path.ecg",         color: .orange,     title: "Estimated glucose rise",        detail: "Predicted mg/dL spike from this meal")
                        PlanFeatureRow(icon: "chart.line.uptrend.xyaxis", color: .red,        title: "HbA1c impact",                 detail: "How this meal shifts your 3-month average")
                        PlanFeatureRow(icon: "figure.walk.circle.fill",   color: .green,      title: "Personalised walk plan",        detail: "Minutes & distance based on your walking history")
                        PlanFeatureRow(icon: "arrow.left.arrow.right",    color: .planAccent, title: "Compared to your typical meal", detail: "Ranks this meal against your last 30 days")
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14).padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { showingStandardPlanner = true }) {
                            Label("Plan a Meal", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.planAccent).foregroundColor(.white)
                                .cornerRadius(12).font(.headline)
                        }.buttonStyle(.plain)

                        Button(action: { showingFeastPlanner = true }) {
                            Label("Plan a Feast", systemImage: "party.popper.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.feastAccent.opacity(0.13))
                                .foregroundColor(.feastAccent)
                                .cornerRadius(12).font(.headline)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.feastAccent.opacity(0.40), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Text("Feast mode uses relaxed thresholds — ideal for holiday or celebration meals.")
                            .font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 8)
                    }.padding(.horizontal)

                    Spacer(minLength: 24)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan Ahead")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingStandardPlanner) {
                MealBuilderView(mealType: .plannedMeal)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingFeastPlanner) {
                MealBuilderView(mealType: .feast)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

private struct PlanFeatureRow: View {
    let icon: String; let color: Color; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PlannedMealView()
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
}
