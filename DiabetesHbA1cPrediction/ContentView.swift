//
//  ContentView.swift
//  DiabetesHbA1cPrediction
//
//  The root navigation container for the application.
//  Uses a TabView with five tabs corresponding to the main functional
//  areas of the app: Dashboard, Glucose, Meals, Exercise, and Profile.
//
//  Each tab wraps its content in a NavigationStack so that child views
//  can push detail screens independently within their own tab.
//

import SwiftUI
import CoreData

struct ContentView: View {

    // MARK: - State

    /// Tracks which tab is currently selected.
    @State private var selectedTab: Tab = .dashboard

    // MARK: - Tab Enum

    /// The five primary sections of the app, each with an icon and label.
    enum Tab: String, CaseIterable {
        case dashboard  = "Dashboard"
        case glucose    = "Glucose"
        case meals      = "Meals"
        case exercise   = "Exercise"
        case profile    = "Profile"

        /// SF Symbol name for the tab icon.
        var iconName: String {
            switch self {
            case .dashboard: return "heart.text.clipboard"
            case .glucose:   return "drop.fill"
            case .meals:     return "fork.knife"
            case .exercise:  return "figure.run"
            case .profile:   return "person.crop.circle"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Dashboard Tab ──────────────────────────────────
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label(Tab.dashboard.rawValue, systemImage: Tab.dashboard.iconName)
            }
            .tag(Tab.dashboard)

            // ── Glucose Tab ────────────────────────────────────
            NavigationStack {
                GlucoseLogView()
            }
            .tabItem {
                Label(Tab.glucose.rawValue, systemImage: Tab.glucose.iconName)
            }
            .tag(Tab.glucose)

            // ── Meals Tab ──────────────────────────────────────
            NavigationStack {
                MealLogView()
            }
            .tabItem {
                Label(Tab.meals.rawValue, systemImage: Tab.meals.iconName)
            }
            .tag(Tab.meals)

            // ── Exercise Tab ───────────────────────────────────
            NavigationStack {
                ExerciseLogView()
            }
            .tabItem {
                Label(Tab.exercise.rawValue, systemImage: Tab.exercise.iconName)
            }
            .tag(Tab.exercise)

            // ── Profile Tab ────────────────────────────────────
            NavigationStack {
                UserProfileView()
            }
            .tabItem {
                Label(Tab.profile.rawValue, systemImage: Tab.profile.iconName)
            }
            .tag(Tab.profile)
        }
        // Use the iOS 18 tinted tab bar appearance.
        .tint(.blue)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitManager.shared)
}
