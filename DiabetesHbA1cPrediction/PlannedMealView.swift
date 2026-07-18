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
    @State private var showHighFeastSheet = false      // 3+ feasts: custom sheet with disclaimer
    @State private var disclaimerAcknowledged = false  // checkbox state inside sheet
    @State private var showDemoAlert = false           // demo mode soft redirect

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

    /// Builds the multi-colored "Before You Eat" description.
    /// Uses historical language ("review", "trends from") rather than predictive claims,
    /// because this is a wellness tracker, not a medical device.
    private static var beforeYouEatDescription: AttributedString {
        var part1 = AttributedString("Build your feast treat and review your glucose and GMI trends from previous meals with similar GI, ")
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
                        PlanFeatureRow(icon: "waveform.path.ecg",         color: .orange,     title: "Your glucose history",           detail: "See how your glucose responded to similar meals in the past")
                        PlanFeatureRow(icon: "chart.line.uptrend.xyaxis", color: .red,        title: "Your GMI trend",                 detail: "Review your 14-day GMI trend alongside similar past meals")
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
                                     ? "You have logged \(feastsThisWeek) feasts in the last 7 days. Please consult your healthcare provider before planning another feast."
                                     : "This is your \(ordinal(feastsThisWeek + 1)) feast in 7 days. You can review how past feasts appeared in your trends.")
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
            .alert("Feast Frequency Notice", isPresented: $showFeastWarning) {
                Button("Continue Anyway") { showingFeastPlanner = true }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(feastWarningMessage)
            }
            .sheet(isPresented: $showHighFeastSheet) {
                HighFeastWarningSheet(
                    feastCount: feastsThisWeek,
                    isAcknowledged: $disclaimerAcknowledged,
                    onContinue: { showingFeastPlanner = true }
                )
            }
            .demoRedirect(isPresented: $showDemoAlert)
    }

    // MARK: - Feast Frequency Logic

    /// Decides whether to show a warning alert, the disclaimer sheet, or open the planner directly
    private func handlePlanFeast() {
        // Soft redirect while demo data is active — no data entry allowed
        guard !DemoDataManager.isDemoDataLoaded else {
            showDemoAlert = true
            return
        }

        let count = feastsThisWeek
        if count >= 3 {
            disclaimerAcknowledged = false
            showHighFeastSheet = true
        } else if count >= 2 {
            feastWarningMessage = "This is your \(ordinal(count + 1)) feast in the last 7 days. You can review your glucose and GMI trends from similar past meals."
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

// MARK: - High Feast Warning Sheet (3+ feasts in 7 days)

private struct HighFeastWarningSheet: View {
    let feastCount: Int
    @Binding var isAcknowledged: Bool
    var onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Warning icon + title
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                            .accessibilityHidden(true)
                        Text("High Feast Frequency")
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Count summary
                    Text("You have already logged \(feastCount) feast meals in the last 7 days.")
                        .font(.body)
                        .foregroundColor(.primary)

                    // Clinical context
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Frequent high-glycaemic meals can significantly affect blood glucose control in people with Type 2 diabetes.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Diabetes Feast is a personal wellness journal, not a medical device. It cannot assess whether planning another feast meal is appropriate for your individual condition, medication, or clinical circumstances.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Healthcare provider prompt
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.red)
                            .font(.body)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
                        Text("Please consult your healthcare provider before planning this meal.")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(10)

                    // Checkbox acknowledgement
                    Button(action: { isAcknowledged.toggle() }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: isAcknowledged ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(isAcknowledged ? .blue : .secondary)
                                .accessibilityHidden(true)
                            Text("I understand that Diabetes Feast is not medical advice and I will consult my healthcare provider before planning this feast meal.")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Acknowledgement checkbox")
                    .accessibilityValue(isAcknowledged ? "Checked" : "Unchecked")
                    .accessibilityHint("Double-tap to toggle")

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            dismiss()
                            onContinue()
                        }) {
                            Text("Continue Anyway")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isAcknowledged ? Color.red : Color(.systemGray4))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!isAcknowledged)
                        .animation(.easeInOut(duration: 0.2), value: isAcknowledged)

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
