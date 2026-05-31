//
//  DemoDataBannerView.swift
//  DiabetesHbA1cPrediction
//
//  Persistent banner displayed when demo data is loaded, so users
//  never mistake sample data for their own readings. Includes a
//  button to clear demo data and begin logging real data.
//

import SwiftUI

/// A compact banner shown at the top of screens while demo data is active.
struct DemoDataBannerView: View {

    @Environment(\.managedObjectContext) private var viewContext

    /// Callback after demo data is wiped — parent views can refresh state.
    var onDemoDataCleared: (() -> Void)? = nil

    @State private var showConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.subheadline)
                .foregroundColor(.blue)
                .accessibilityHidden(true)

            Text("Demo data")
                .font(.subheadline.bold())
                .foregroundColor(.primary)

            Text("— explore the app, then clear to start logging your own.")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Spacer()

            Button("Clear") {
                showConfirmation = true
            }
            .font(.caption.bold())
            .foregroundColor(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal)
        .alert("Clear demo data?", isPresented: $showConfirmation) {
            Button("Clear", role: .destructive) {
                clearDemoData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all demo data so you can start logging your own glucose, meals, and exercise. This cannot be undone.")
        }
    }

    private func clearDemoData() {
        do {
            try DemoDataManager.wipeAllData(from: viewContext)
            ColdStartManager.shared.resetOnboarding()
            ColdStartManager.shared.refresh(context: viewContext)
            onDemoDataCleared?()
        } catch {
            // Silently handle — the user can retry from Settings
            print("Failed to clear demo data: \(error.localizedDescription)")
        }
    }
}
