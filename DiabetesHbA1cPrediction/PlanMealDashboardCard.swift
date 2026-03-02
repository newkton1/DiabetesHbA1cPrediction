//  PlanMealDashboardCard.swift  –  DiabetesHbA1cPrediction
//  Usage: PlanMealDashboardCard { selectedTab = .meals }
import SwiftUI
import CoreData

struct PlanMealDashboardCard: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: true)],
        predicate: NSPredicate(format: "mealType == %@ AND timestamp > %@",
                               "plannedMeal", Date() as NSDate)
    ) private var upcomingMeals: FetchedResults<MealEntity>

    var onTap: () -> Void
    private var nextMeal: MealEntity? { upcomingMeals.first }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.planAccent.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: nextMeal != nil
                          ? "calendar.badge.clock" : "calendar.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(.planAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let meal = nextMeal, let time = meal.timestamp {
                        Text("Next Planned Meal").font(.headline)
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.caption)
                                .foregroundColor(.planAccent)
                            Text(time, style: .relative).font(.caption)
                                .foregroundColor(.planAccent)
                        }
                    } else {
                        Text("Plan Your Next Meal").font(.headline)
                        Text("See glucose & HbA1c impact before you eat")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

