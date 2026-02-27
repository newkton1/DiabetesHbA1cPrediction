//
//  PlannedMealView.swift
//  DiabetesHbA1cPrediction
//
//  View for planning a future meal and seeing its predicted impact
//

import SwiftUI
import CoreData

/// Wrapper view for planning a future meal
struct PlannedMealView: View {
    var body: some View {
        MealBuilderView(mealType: .plannedMeal)
    }
}

#Preview {
    PlannedMealView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
