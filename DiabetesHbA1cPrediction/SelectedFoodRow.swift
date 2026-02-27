//
//  SelectedFoodRow.swift
//  DiabetesHbA1cPrediction
//
//  Row component for displaying a selected food item with quantity controls
//

import SwiftUI

/// Row view for displaying a selected food item with quantity adjustment controls
struct SelectedFoodRow: View {
    let selectedFood: SelectedFoodItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Food info
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedFood.foodItem.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(Int(selectedFood.totalCarbs)) g carbs")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("\(formatNumber(Int(selectedFood.totalCalories))) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("\(selectedFood.foodItem.servingSize, specifier: "%.1f") \(selectedFood.foodItem.servingUnit) per serving")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Quantity stepper (matches Exercise Duration style)
            Stepper(
                onIncrement: onIncrement,
                onDecrement: selectedFood.quantity <= 1 ? nil : onDecrement
            ) {
                Text("\(Int(selectedFood.quantity)) serving\(Int(selectedFood.quantity) == 1 ? "" : "s")")
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Format number: only use comma separator for values >= 10,000
    private func formatNumber(_ value: Int) -> String {
        if value >= 10000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        return "\(value)"
    }
}

/// Compact version for summary displays
struct SelectedFoodCompactRow: View {
    let selectedFood: SelectedFoodItem
    
    var body: some View {
        HStack {
            Text(selectedFood.foodItem.name)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(Int(selectedFood.quantity))x")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(selectedFood.totalCarbs)) g")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
    }
}

#Preview {
    let sampleFood = FoodItem(
        name: "White Rice",
        category: "Grains & Cereals",
        servingSize: 1,
        servingUnit: "cup cooked",
        calories: 206,
        carbohydrates: 45,
        protein: 4.3,
        fat: 0.4,
        fiber: 0.6,
        glycemicIndex: 73
    )
    let selectedFood = SelectedFoodItem(foodItem: sampleFood, quantity: 2)
    
    return List {
        SelectedFoodRow(
            selectedFood: selectedFood,
            onIncrement: {},
            onDecrement: {},
            onDelete: {}
        )
    }
}
