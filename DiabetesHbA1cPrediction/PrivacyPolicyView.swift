//
//  PrivacyPolicyView.swift
//  DiabetesHbA1cPrediction
//
//  In-app privacy policy explaining how the app handles health data.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("This privacy policy explains how DiabetesHbA1c Prediction handles your data. Your privacy and the security of your health information are important to us.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("What Data We Read")) {
                Text("The app reads the following from Apple Health with your permission: blood glucose readings, weight, height, age, and biological sex. This data is used solely to generate personalised HbA1c predictions.")
                    .font(.subheadline)
            }

            Section(header: Text("What We Do Not Do")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("The app never writes data to Apple Health.", systemImage: "xmark.circle")
                    Label("The app does not transmit your data to any external server.", systemImage: "xmark.circle")
                    Label("The app does not use analytics or advertising frameworks.", systemImage: "xmark.circle")
                }
                .font(.subheadline)
            }

            Section(header: Text("Data Storage")) {
                Text("All data is stored locally on your device using encrypted Core Data storage with iOS file protection. Your health information never leaves your device unless you explicitly choose to share it.")
                    .font(.subheadline)
            }

            Section(header: Text("Sharing")) {
                Text("You can export a summary of your HbA1c predictions using the Share button. Before sharing, the app will ask you to confirm because the export contains sensitive health information. No data is shared without your explicit action.")
                    .font(.subheadline)
            }

            Section(header: Text("Your Control")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Revoke HealthKit access at any time in Settings > Health > Data Access & Devices.", systemImage: "hand.raised")
                    Label("Delete all app data by uninstalling the app.", systemImage: "trash")
                }
                .font(.subheadline)
            }

            Section(header: Text("Medical Disclaimer")) {
                Text("This app provides predictions for informational purposes only. It is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider with questions about your health.")
                    .font(.subheadline)
            }

            Section {
                Text("Last updated: March 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
