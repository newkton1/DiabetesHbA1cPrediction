//  ContentView.swift  –  DiabetesHbA1cPrediction
import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard
    @Environment(\.scenePhase) private var scenePhase
    /// Tracks whether we've already reset the tab this launch cycle
    @State private var hasResetOnLaunch = false

    // MARK: - Subscription gate
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var trialManager        = TrialManager.shared

    /// True when the paywall should be shown
    private var shouldShowPaywall: Bool {
        #if DEBUG
        return false   // always bypass paywall in debug/Xcode builds
        #else
        return !subscriptionManager.isSubscribed && !trialManager.isInTrial
        #endif
    }

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

        /// Label for the tab bar
        var tabLabel: String {
            return rawValue
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
        .fullScreenCover(isPresented: Binding(
            get: { shouldShowPaywall },
            set: { _ in }   // dismissal only via successful purchase
        )) {
            PaywallView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                trialManager.refresh()
                Task { await subscriptionManager.refreshSubscriptionStatus() }
            }
            // Reset to dashboard exactly once per cold launch.
            // @State already initialises hasResetOnLaunch to false on a fresh
            // process launch, so we do NOT clear it when the app backgrounds.
            // Clearing it on .background was causing an intermittent glitch:
            // a brief system event (notification, HealthKit sync, Control Centre)
            // would cycle the scene phase through .background → .active and
            // snap the user back to the Dashboard mid-session.
            if newPhase == .active && !hasResetOnLaunch {
                selectedTab = .dashboard
                hasResetOnLaunch = true
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
