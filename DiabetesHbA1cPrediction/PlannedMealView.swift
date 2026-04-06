//  PlannedMealView.swift  –  DiabetesHbA1cPrediction
import SwiftUI
import CoreData

struct PlannedMealView: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showingFeastPlanner = false
    @State private var showFeastWarning = false
    @State private var feastWarningMessage = ""

    private var isLandscape: Bool { verticalSizeClass == .compact }

    // MARK: - Feast Frequency Limits

    /// Number of feasts in the rolling 7-day window
    private var feastsThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let request: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "mealType == %@", "feast"),
            NSPredicate(format: "timestamp >= %@", weekAgo as NSDate)
        ])
        return (try? viewContext.count(for: request)) ?? 0
    }

    /// Builds the multi-colored "Before You Eat" description
    private static var beforeYouEatDescription: AttributedString {
        var part1 = AttributedString("Build your feast treat and see the predicted impact on your glucose and HbA1c ")
        part1.foregroundColor = .secondary

        var part2 = AttributedString("as well as how to offset it")
        part2.foregroundColor = .orange

        var part3 = AttributedString(", before taking a single bite.")
        part3.foregroundColor = .secondary

        return part1 + part2 + part3
    }

    var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // Custom header with back chevron + title
                    HStack {
                        Button(action: { selectedTab = .dashboard }) {
                            Image(systemName: "chevron.left")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.white)
                                .accessibilityLabel("Back to dashboard")
                        }
                        Text("What If?")
                            .font(.title3.bold())
                        Spacer()
                    }
                    .padding(.horizontal)
                    // Explainer banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").foregroundColor(.planAccent).accessibilityHidden(true)
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
                        PlanFeatureRow(icon: "waveform.path.ecg",         color: .orange,     title: "Estimated glucose rise",        detail: "Predicted mg/dL spike from this feast")
                        PlanFeatureRow(icon: "chart.line.uptrend.xyaxis", color: .red,        title: "HbA1c impact",                 detail: "How this feast shifts your 3-month average")
                        PlanFeatureRow(icon: ExerciseOffsetType.current.iconName, color: .green, title: "Personalised exercise plan",   detail: "Minutes & distance for your chosen activity")
                        PlanFeatureRow(icon: "arrow.left.arrow.right",    color: .planAccent, title: "Compared to your typical meal", detail: "Ranks this feast against your last 30 days")
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14).padding(.horizontal)

                    // Feast frequency notice (shown inline when 2+ feasts this week)
                    if feastsThisWeek >= 2 {
                        HStack(spacing: 8) {
                            Image(systemName: feastsThisWeek >= 3 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundColor(feastsThisWeek >= 3 ? .red : .orange)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feastsThisWeek >= 3
                                     ? "Feast frequency is high"
                                     : "Second feast this week")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(feastsThisWeek >= 3 ? .red : .orange)
                                Text(feastsThisWeek >= 3
                                     ? "You have planned \(feastsThisWeek) feasts in the last 7 days. Frequent feasts may impact your glucose management goals."
                                     : "This will be your \(ordinal(feastsThisWeek + 1)) feast in 7 days. Occasional treats are fine — just stay mindful.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(feastsThisWeek >= 3
                                    ? Color.red.opacity(0.08)
                                    : Color.orange.opacity(0.08))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Action button — single feast-focused function
                    Button(action: { handlePlanFeast() }) {
                        Label("Plan Feast Treat", systemImage: "party.popper.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.feastAccent).foregroundColor(.white)
                            .cornerRadius(12).font(.headline)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Spacer(minLength: 24)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingFeastPlanner) {
                MealBuilderView(mealType: .feast)
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert("Feast Frequency Warning", isPresented: $showFeastWarning) {
                Button("Continue Anyway") { showingFeastPlanner = true }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(feastWarningMessage)
            }
    }

    // MARK: - Feast Frequency Logic

    /// Decides whether to show a warning alert or open the planner directly
    private func handlePlanFeast() {
        let count = feastsThisWeek
        if count >= 3 {
            feastWarningMessage = "You have already planned \(count) feasts in the last 7 days. Frequent feast meals may work against your glucose management goals. Consider spacing your treats out more."
            showFeastWarning = true
        } else if count >= 2 {
            feastWarningMessage = "This will be your \(ordinal(count + 1)) feast in the last 7 days. Occasional treats are part of a healthy plan, but try to keep feasts to once or twice a week."
            showFeastWarning = true
        } else {
            showingFeastPlanner = true
        }
    }

    /// Returns ordinal string for a number (1st, 2nd, 3rd, etc.)
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

private struct PlanFeatureRow: View {
    let icon: String; let color: Color; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 28, alignment: .center).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PlannedMealView(selectedTab: .constant(.meals))
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
}
