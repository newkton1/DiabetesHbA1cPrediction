//
//  LastMealView.swift
//  DiabetesHbA1cPrediction
//
//  View for logging a recently eaten meal
//

import SwiftUI
import CoreData

/// Wrapper view for logging a last meal
struct LastMealView: View {
    var body: some View {
        MealBuilderView(mealType: .lastMeal)
    }
}

#Preview {
    LastMealView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
