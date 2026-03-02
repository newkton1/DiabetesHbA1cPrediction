//  ContentView.swift  –  DiabetesHbA1cPrediction
import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case glucose   = "Glucose"
        case meals     = "Plan & Log"
        case exercise  = "Exercise"
        case profile   = "Profile"

        var iconName: String {
            switch self {
            case .dashboard: return "heart.text.clipboard"
            case .glucose:   return "drop.fill"
            case .meals:     return "fork.knife.circle.fill"
            case .exercise:  return "figure.run"
            case .profile:   return "person.crop.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView(selectedTab: $selectedTab) }
                .tabItem { Label(Tab.dashboard.rawValue, systemImage: Tab.dashboard.iconName) }
                .tag(Tab.dashboard)
            NavigationStack { GlucoseLogView() }
                .tabItem { Label(Tab.glucose.rawValue, systemImage: Tab.glucose.iconName) }
                .tag(Tab.glucose)
            NavigationStack { PlannedMealView() }
                .tabItem { Label(Tab.meals.rawValue, systemImage: Tab.meals.iconName) }
                .tag(Tab.meals)
            NavigationStack { ExerciseLogView() }
                .tabItem { Label(Tab.exercise.rawValue, systemImage: Tab.exercise.iconName) }
                .tag(Tab.exercise)
            NavigationStack { UserProfileView() }
                .tabItem { Label(Tab.profile.rawValue, systemImage: Tab.profile.iconName) }
                .tag(Tab.profile)
        }
        .tint(selectedTab == .meals ? .planAccent : .blue)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitManager.shared)
}
