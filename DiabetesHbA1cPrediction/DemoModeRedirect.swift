//
//  DemoModeRedirect.swift
//  DiabetesHbA1cPrediction
//
//  Reusable soft-redirect logic for data-entry buttons while demo data
//  is active. Shows a "You're in Demo Mode" alert and optionally clears
//  demo data (with the standard DemoClearedTransitionView) if the user
//  chooses to proceed.
//
//  Usage in any data-entry view:
//
//    // 1. Add state
//    @State private var showDemoAlert = false
//
//    // 2. Guard the entry-point button
//    Button(action: {
//        if DemoDataManager.isDemoDataLoaded {
//            showDemoAlert = true
//        } else {
//            showAddSheet = true      // ← your normal action
//        }
//    }) { ... }
//
//    // 3. Attach the modifier to the view (or its NavigationStack)
//    .demoRedirect(isPresented: $showDemoAlert)
//

import SwiftUI

// MARK: - ViewModifier

struct DemoModeRedirectModifier: ViewModifier {

    @Environment(\.managedObjectContext) private var viewContext

    /// Set to true from a button action to trigger the alert.
    @Binding var isPresented: Bool

    /// Called after demo data is cleared and the user dismisses the
    /// transition sheet — use to update local isDemoData state if needed.
    var onDemoCleared: (() -> Void)? = nil

    @State private var showTransition = false

    func body(content: Content) -> some View {
        content
            .alert("You're in Demo Mode", isPresented: $isPresented) {
                Button("Clear Demo Data", role: .destructive) {
                    clearDemoData()
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Clear the demo data first to start logging your own readings.")
            }
            .sheet(isPresented: $showTransition) {
                DemoClearedTransitionView(onDismiss: onDemoCleared)
            }
    }

    private func clearDemoData() {
        do {
            try DemoDataManager.wipeAllData(from: viewContext)
            ColdStartManager.shared.resetOnboarding()
            ColdStartManager.shared.refresh(context: viewContext)
            showTransition = true
        } catch {
            print("DemoModeRedirect: failed to clear demo data: \(error.localizedDescription)")
        }
    }
}

// MARK: - View extension

extension View {
    /// Attaches a soft demo-mode redirect to a view.
    ///
    /// When `isPresented` is set to true (from a button action), shows an
    /// alert offering to clear demo data before proceeding. If the user
    /// clears, the `DemoClearedTransitionView` is shown and `onDemoCleared`
    /// is called when they dismiss it.
    func demoRedirect(
        isPresented: Binding<Bool>,
        onDemoCleared: (() -> Void)? = nil
    ) -> some View {
        modifier(DemoModeRedirectModifier(
            isPresented: isPresented,
            onDemoCleared: onDemoCleared
        ))
    }
}
