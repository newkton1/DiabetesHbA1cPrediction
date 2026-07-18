//
//  CGMSetupView.swift
//  DiabetesHbA1cPrediction
//
//  Presented as a sheet from the Glucose tab toolbar.
//  Guides the user through the three supported CGM data paths:
//    1. Zukka (recommended) — near real-time via BLE → HealthKit
//    2. Official Dexcom G7 app → Apple Health (3-hour batch delay)
//    3. Manual finger-stick entry (no CGM hardware required)
//
//  No diagnostic or predictive language — App Store compliant.
//

import SwiftUI

struct CGMSetupView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var expandedPath: CGMPath? = .zukka

    enum CGMPath: CaseIterable {
        case zukka, dexcomHealth, libre3, manual

        var title: String {
            switch self {
            case .zukka:        return "Zukka (Recommended)"
            case .dexcomHealth: return "Dexcom App + Apple Health"
            case .libre3:       return "Libre 3 / Lingo + Apple Health"
            case .manual:       return "Manual Finger-Stick Entry"
            }
        }

        var subtitle: String {
            switch self {
            case .zukka:        return "Near real-time · Dexcom G7"
            case .dexcomHealth: return "Batch delay · Dexcom G7"
            case .libre3:       return "Batch delay, or ~5–20 min via Zukka"
            case .manual:       return "No CGM hardware needed"
            }
        }

        var icon: String {
            switch self {
            case .zukka:        return "wave.3.right.circle.fill"
            case .dexcomHealth: return "heart.text.clipboard.fill"
            case .libre3:       return "waveform.path.ecg.rectangle.fill"
            case .manual:       return "pencil.and.list.clipboard"
            }
        }

        var iconColor: Color {
            switch self {
            case .zukka:        return .blue
            case .dexcomHealth: return .green
            case .libre3:       return .teal
            case .manual:       return .orange
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    ForEach(CGMPath.allCases, id: \.title) { path in
                        pathCard(path)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("CGM Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Connect your CGM")
                    .font(.headline)
            }
            Text("Diabetes Feast reads glucose data from Apple Health. Choose how you'd like to get your CGM readings into Apple Health.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Path card

    private func pathCard(_ path: CGMPath) -> some View {
        let isExpanded = expandedPath == path

        return VStack(spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedPath = isExpanded ? nil : path
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(path.iconColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: path.icon)
                            .font(.system(size: 18))
                            .foregroundColor(path.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(path.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(path.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                Divider().padding(.horizontal)
                pathDetail(path)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Path detail content

    @ViewBuilder
    private func pathDetail(_ path: CGMPath) -> some View {
        switch path {
        case .zukka:
            zukkaDetail
        case .dexcomHealth:
            dexcomHealthDetail
        case .libre3:
            libre3Detail
        case .manual:
            manualDetail
        }
    }

    // MARK: - Zukka detail

    private var zukkaDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoBox(
                icon: "info.circle",
                color: .blue,
                text: "Zukka connects directly to your Dexcom G7 sensor over Bluetooth and writes readings to Apple Health every 5 minutes. Diabetes Feast then reads them automatically."
            )

            Text("Setup steps")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            stepRow(number: 1, text: "Install Zukka from the App Store")
            stepRow(number: 2, text: "Open Zukka and follow its sensor pairing instructions — you'll need to forget the sensor in Bluetooth settings first, then let Zukka pair")
            stepRow(number: 3, text: "In Zukka settings, confirm Apple Health writing is enabled")
            stepRow(number: 4, text: "Return here and tap Sync on the Glucose tab — your readings will appear")

            HStack(spacing: 10) {
                actionButton(
                    label: "Get Zukka",
                    icon: "arrow.down.app.fill",
                    color: .blue
                ) {
                    openURL(URL(string: "https://apps.apple.com/us/app/zukka/id6743448282")!)
                }

                actionButton(
                    label: "Open Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }

            infoBox(
                icon: "exclamationmark.triangle",
                color: .orange,
                text: "Zukka must remain active in the background while your sensor is in use. Enable Background App Refresh for Zukka in iOS Settings."
            )
        }
    }

    // MARK: - Dexcom App + Apple Health detail

    private var dexcomHealthDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoBox(
                icon: "clock",
                color: .green,
                text: "The official Dexcom G7 app syncs glucose readings to Apple Health in 3-hour batches. Diabetes Feast reads them automatically once they arrive. This path requires no extra apps but data will be up to 3 hours behind."
            )

            Text("Setup steps")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            stepRow(number: 1, text: "Install the official Dexcom G7 app from the App Store and complete sensor setup")
            stepRow(number: 2, text: "In the Dexcom G7 app, go to Connections → Apple Health → tap Activate")
            stepRow(number: 3, text: "On the Health permissions screen that appears, enable Blood Glucose and tap Allow")
            stepRow(number: 4, text: "Open Diabetes Feast and grant HealthKit permission when prompted")
            stepRow(number: 5, text: "Glucose readings will begin appearing within 3 hours of your next sensor reading")

            HStack(spacing: 10) {
                actionButton(
                    label: "Get Dexcom G7 App",
                    icon: "arrow.down.app.fill",
                    color: .green
                ) {
                    openURL(URL(string: "https://apps.apple.com/us/app/dexcom-g7/id1569432518")!)
                }

                actionButton(
                    label: "Open Health",
                    icon: "heart.fill",
                    color: .pink
                ) {
                    // Opens the Health app directly
                    if let url = URL(string: "x-apple-health://") {
                        openURL(url)
                    }
                }
            }

            infoBox(
                icon: "info.circle",
                color: .secondary,
                text: "Because data arrives in batches, post-meal glucose correlations in Diabetes Feast may not appear until several hours after a meal. For timely meal analysis, consider using Zukka instead."
            )
        }
    }

    // MARK: - Libre 3 / Lingo detail

    private var libre3Detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoBox(
                icon: "info.circle",
                color: .teal,
                text: "There are two ways to get Libre 3 / Lingo readings into Apple Health. The official LibreLink/Lingo app syncs in batches. Zukka can also follow your Libre 3 readings through Abbott's LibreLinkUp cloud service — faster, but still cloud-polled rather than a direct Bluetooth connection, since Abbott does not allow third-party apps to read Libre 3 over Bluetooth."
            )

            Text("Option A — Official LibreLink / Lingo App")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            stepRow(number: 1, text: "Install the FreeStyle LibreLink app (Libre 3) or the Abbott Lingo app from the App Store and complete sensor setup")
            stepRow(number: 2, text: "In the app, go to Settings → Connected Apps → Apple Health and tap Connect")
            stepRow(number: 3, text: "On the Health permissions screen, enable Blood Glucose and tap Allow")
            stepRow(number: 4, text: "Open Diabetes Feast and grant HealthKit permission when prompted")
            stepRow(number: 5, text: "Glucose readings will begin appearing once the app completes its next Health sync — this can take up to 3 hours")

            HStack(spacing: 10) {
                actionButton(
                    label: "Get LibreLink",
                    icon: "arrow.down.app.fill",
                    color: .teal
                ) {
                    openURL(URL(string: "https://apps.apple.com/us/app/freestyle-librelink-us/id1292816380")!)
                }

                actionButton(
                    label: "Open Health",
                    icon: "heart.fill",
                    color: .pink
                ) {
                    if let url = URL(string: "x-apple-health://") {
                        openURL(url)
                    }
                }
            }

            Divider()

            Text("Option B — Zukka (LibreLinkUp Follower)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            stepRow(number: 1, text: "Install Zukka from the App Store")
            stepRow(number: 2, text: "In the LibreLinkUp app (or on libreview.com), invite yourself as a Follower of your own Libre 3 account, then accept that invite")
            stepRow(number: 3, text: "In Zukka, choose the LibreLinkUp follower option and sign in with your Follower account credentials")
            stepRow(number: 4, text: "In Zukka settings, confirm Apple Health writing is enabled")
            stepRow(number: 5, text: "Return here and tap Sync on the Glucose tab — readings typically appear within 5–20 minutes of each scan")

            actionButton(
                label: "Get Zukka",
                icon: "arrow.down.app.fill",
                color: .blue
            ) {
                openURL(URL(string: "https://apps.apple.com/us/app/zukka/id6743448282")!)
            }

            infoBox(
                icon: "exclamationmark.triangle",
                color: .orange,
                text: "Zukka's Libre 3 support pulls data from Abbott's LibreLinkUp cloud service, not a direct Bluetooth connection. Expect roughly 5–20 minutes of lag end-to-end — much faster than the official app's batch sync, but not true real-time like Dexcom G7 over Bluetooth. This fits how Diabetes Feast is meant to be used: reviewing patterns over time rather than watching moment-to-moment numbers. If you want to see live changes, the LibreLink app running alongside Zukka still shows real-time readings. For tighter post-meal pattern review, consider supplementing with manual entries."
            )
        }
    }

    // MARK: - Manual detail

    private var manualDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoBox(
                icon: "info.circle",
                color: .orange,
                text: "You can log glucose readings by hand at any time — no CGM required. Three or more readings per day builds a meaningful history for GMI estimation."
            )

            Text("How to log a reading")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            stepRow(number: 1, text: "Tap the + button in the top-right of the Glucose tab")
            stepRow(number: 2, text: "Enter your reading from a finger-stick meter")
            stepRow(number: 3, text: "Set the source to \"Manual Finger Stick\" and adjust the timestamp if needed")
            stepRow(number: 4, text: "Tap Save — the reading appears on your chart immediately")

            infoBox(
                icon: "lightbulb",
                color: .yellow,
                text: "For best GMI estimates, aim to log readings before meals, 2 hours after meals, and before bed — capturing daily highs, lows, and post-meal responses."
            )
        }
    }

    // MARK: - Reusable sub-views

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func infoBox(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 18)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(color.opacity(0.07))
        .cornerRadius(8)
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CGMSetupView()
}
