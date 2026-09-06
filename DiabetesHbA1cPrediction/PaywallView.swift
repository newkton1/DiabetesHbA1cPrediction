//
//  PaywallView.swift
//  DiabetesHbA1cPrediction
//
//  Full-screen subscription offer shown when the 30-day free trial expires.
//  Presents the annual subscription with a 1-month free trial offer.
//
//  IMPORTANT: All copy avoids predictive/diagnostic language for
//  Apple App Store compliance.
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var trialManager        = TrialManager.shared

    // MARK: - Feature List

    private let features: [(icon: String, text: String)] = [
        ("drop.fill",           "Blood glucose charts and history"),
        ("fork.knife",          "Meal logging with GI and carb tracking"),
        ("figure.run",          "Exercise session tracking"),
        ("scalemass.fill",      "Weight trend indicators"),
        ("waveform.path.ecg",   "GMI (Glucose Management Indicator)"),
        ("square.and.arrow.up", "Export data as JSON or Excel"),
        ("heart.fill",          "Apple Health integration"),
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Header
                headerSection

                // Feature list
                featuresSection

                // Pricing card
                pricingCard

                // Subscribe button
                subscribeButton

                // Trial note
                trialNote

                // Restore + legal
                footerLinks
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .alert("Subscription Error", isPresented: Binding(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK") { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("AppIconImage")
                .resizable()
                .frame(width: 100, height: 100)
                .cornerRadius(22)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.top, 48)

            Text("Diabetes Feast")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your personal blood sugar journal")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.text) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text(feature.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Pricing Card

    private var pricingCard: some View {
        VStack(spacing: 6) {
            Text("Annual Subscription")
                .font(.headline)

            if let product = subscriptionManager.product {
                Text(product.displayPrice + " / year")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Text("after your free trial ends")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task { await subscriptionManager.purchase() }
        } label: {
            Group {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start 1 Month Free Trial")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(subscriptionManager.isPurchasing || subscriptionManager.product == nil)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Trial Note

    private var trialNote: some View {
        Text("Try free for 1 month, then \(subscriptionManager.product?.displayPrice ?? "—")/year.\nCancel anytime in Settings > Apple ID > Subscriptions.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
    }

    // MARK: - Footer Links

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .font(.footnote)
            .foregroundColor(.blue)

            HStack(spacing: 16) {
                Link("Privacy Policy",
                     destination: {
                         let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
                         return isJapanese
                             ? URL(string: "https://newkton1.github.io/diabetes-feast-privacy/PrivacyPolicy_JA.html")!
                             : URL(string: "https://newkton1.github.io/diabetes-feast-privacy/")!
                     }())
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PaywallView()
}
