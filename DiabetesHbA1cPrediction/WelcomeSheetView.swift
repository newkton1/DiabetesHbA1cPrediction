//
//  WelcomeSheetView.swift
//  DiabetesHbA1cPrediction
//
//  Full-screen welcome sheet shown once on first launch.
//  Offers a link to the onboarding video guide and a skip option.
//

import SwiftUI

// MARK: - Welcome Sheet View

/// A modal welcome sheet displayed on first launch. Gated by a
/// UserDefaults flag so it only appears once. Provides a prominent
/// "Watch the Guide" button linking to the onboarding video playlist (Parts 1 & 2)
/// and a "Get Started" button to dismiss.
struct WelcomeSheetView: View {

    // MARK: - Constants

    private enum Constants {
        static let videoURL = URL(string: "https://www.youtube.com/watch?v=4XrTVFx0jwc&list=PLEMcKQpcQpgup74VYGWHEFwembOmnPt_U")!
        static let hasSeenWelcomeKey = "hasSeenWelcomeSheet"
    }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // App icon / hero image
            Image(systemName: "fork.knife.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Programmatic.primary)
                .accessibilityHidden(true)

            // Welcome title
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Diabetes Feast")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.textPrimary)

            // Subtitle
            VStack(spacing: 2) {
                Text("Monitor your GMI & glucose trends,")
                Text("plan meals, treats, etc.")
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.textSecondary)

            // Wellness disclaimer — shown prominently on first launch
            VStack(spacing: 4) {
                Image(systemName: "heart.text.square")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("Wellness App")
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text("This app provides estimates for personal wellness tracking only. It does not diagnose conditions or replace laboratory tests. Always consult your healthcare provider for medical advice.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.08))
            )
            .padding(.horizontal, 24)

            Spacer()

            // MARK: Action Buttons

            VStack(spacing: 14) {

                // Primary — Watch the Guide
                Button {
                    markAsSeen()
                    openURL(Constants.videoURL)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Watch the Guide")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.Programmatic.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                }
                .accessibilityHint("Opens the onboarding video on YouTube")

                // Secondary — Get Started (dismiss)
                Button {
                    markAsSeen()
                    dismiss()
                } label: {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.surfaceSecondary)
                        .foregroundStyle(AppTheme.Programmatic.primary)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .interactiveDismissDisabled()  // Prevent swipe-to-dismiss so user makes a conscious choice
    }

    // MARK: - Helpers

    /// Persists that the user has seen the welcome sheet so it never shows again.
    private func markAsSeen() {
        UserDefaults.standard.set(true, forKey: Constants.hasSeenWelcomeKey)
    }

    // MARK: - Static Helpers

    /// Whether the welcome sheet should be presented (i.e. user has NOT seen it yet).
    static var shouldPresent: Bool {
        !UserDefaults.standard.bool(forKey: Constants.hasSeenWelcomeKey)
    }
}

// MARK: - Preview

#Preview {
    WelcomeSheetView()
}
