//  ContentView.swift  –  DiabetesHbA1cPrediction
import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard
    @Environment(\.scenePhase) private var scenePhase
    /// Tracks whether we've already reset the tab this launch cycle
    @State private var hasResetOnLaunch = false

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case meals     = "What if?"
        case glucose   = "Glucose"
        case exercise  = "Exercise"
        case profile   = "User"

        var iconName: String {
            switch self {
            case .dashboard: return "heart.text.clipboard"
            case .glucose:   return "drop.fill"
            case .meals:     return "fork.knife.circle.fill"
            case .exercise:  return "figure.run"
            case .profile:   return "person.crop.circle"
            }
        }

        /// Shorter label for the tab bar to prevent truncation
        var tabLabel: String {
            switch self {
            case .exercise: return "Xcise"
            default: return rawValue
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView(selectedTab: $selectedTab) }
                .tabItem { Label(Tab.dashboard.tabLabel, systemImage: Tab.dashboard.iconName) }
                .tag(Tab.dashboard)
            NavigationStack { PlannedMealView(selectedTab: $selectedTab) }
                .tabItem { Label(Tab.meals.tabLabel, systemImage: Tab.meals.iconName) }
                .tag(Tab.meals)
            NavigationStack { GlucoseLogView() }
                .tabItem { Label(Tab.glucose.tabLabel, systemImage: Tab.glucose.iconName) }
                .tag(Tab.glucose)
            NavigationStack { ExerciseLogView() }
                .tabItem { Label(Tab.exercise.tabLabel, systemImage: Tab.exercise.iconName) }
                .tag(Tab.exercise)
            NavigationStack { UserProfileView() }
                .tabItem { Label(Tab.profile.tabLabel, systemImage: Tab.profile.iconName) }
                .tag(Tab.profile)
        }
        .tint(selectedTab == .meals ? .planAccent : .blue)
        .onChange(of: scenePhase) { _, newPhase in
            // Reset to dashboard once per launch cycle when the app becomes active.
            // After the first reset, hasResetOnLaunch prevents the tab from snapping
            // back every time the user briefly switches away (e.g. Control Centre).
            if newPhase == .active && !hasResetOnLaunch {
                selectedTab = .dashboard
                hasResetOnLaunch = true
            }
            // When the app moves to the background, arm the reset for the next launch.
            if newPhase == .background {
                hasResetOnLaunch = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitManager.shared)
}
