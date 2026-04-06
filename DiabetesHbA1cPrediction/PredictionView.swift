import SwiftUI
import CoreData

/// PredictionView is the main view for displaying HbA1c predictions and prediction history.
/// It provides comprehensive visualization of current predictions, historical data, and options to generate new predictions.
///
/// Features:
/// - Displays history of past predictions with expandable details
/// - Shows current prediction with visual gauge and detailed metrics
/// - Allows generating new predictions with loading state
/// - Provides export/share functionality for prediction summaries
///
/// Environment Requirements:
/// - Requires a valid NSManagedObjectContext from the environment
/// - Requires HbA1cPredictionEngine to be available via dependency injection
struct PredictionView: View {
    // MARK: - Environment & State

    /// The Core Data managed object context for fetching and saving data
    @Environment(\.managedObjectContext) private var managedObjectContext

    /// HbA1c unit profile for locale-aware display
    @ObservedObject private var hba1cProfile = HbA1cUserProfile.shared

    /// Fetches all HbA1cPredictionEntity objects sorted by date in descending order
    @FetchRequest(
        entity: HbA1cPredictionEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \HbA1cPredictionEntity.predictionDate, ascending: false)],
        animation: .easeInOut
    ) private var predictionHistory: FetchedResults<HbA1cPredictionEntity>

    /// Currently selected prediction from history for detailed view
    @State private var selectedPrediction: HbA1cPredictionEntity?

    /// Controls visibility of expanded details for a specific prediction
    @State private var expandedPredictionId: UUID?

    /// Tracks if a new prediction is being generated
    @State private var isGeneratingPrediction: Bool = false

    /// Stores the most recent prediction result for display
    @State private var currentPredictionResult: PredictionResult?

    /// Controls visibility of error alert
    @State private var showErrorAlert: Bool = false

    /// Error message to display in alert
    @State private var errorMessage: String = ""

    /// Controls visibility of share sheet
    @State private var showShareSheet: Bool = false

    /// Controls visibility of share confirmation dialog
    @State private var showShareConfirmation: Bool = false

    /// Temporarily holds the prediction result pending share confirmation
    @State private var pendingShareResult: PredictionResult?

    /// Text content for export/share functionality
    @State private var shareText: String = ""

    /// Reference to the prediction engine (would be injected via EnvironmentObject)
    @StateObject private var predictionEngine = HbA1cPredictionEngine()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Current Prediction Section
                        if let result = currentPredictionResult {
                            CurrentPredictionSection(result: result)
                                .transition(.scale.combined(with: .opacity))
                        } else if let mostRecent = predictionHistory.first {
                            // Show the most recent prediction from history if no new one generated
                            CurrentPredictionSection(
                                result: PredictionResult(
                                    predictedHbA1c: mostRecent.predictedValue,
                                    confidenceLevel: mostRecent.confidenceLevel,
                                    riskCategory: determineRiskCategory(hbA1c: mostRecent.predictedValue),
                                    contributingFactors: decodedContributingFactors(mostRecent),
                                    recommendations: []
                                )
                            )
                        }

                        // Medical Disclaimer
                        MedicalDisclaimerBanner()

                        // Prediction History Section
                        if !predictionHistory.isEmpty {
                            PredictionHistorySection(
                                predictions: Array(predictionHistory),
                                selectedPrediction: $selectedPrediction,
                                expandedPredictionId: $expandedPredictionId
                            )
                        } else {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                    .accessibilityHidden(true)

                                Text("No Predictions Yet")
                                    .font(.headline)
                                    .foregroundColor(.gray)

                                Text("Generate your first HbA1c prediction to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                        }

                        // Generate New Prediction Button
                        Button(action: generateNewPrediction) {
                            HStack(spacing: 12) {
                                if isGeneratingPrediction {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }

                                Text(isGeneratingPrediction ? "Generating..." : "Generate New Prediction")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isGeneratingPrediction)
                        .accessibilityLabel(isGeneratingPrediction ? "Generating prediction" : "Generate new HbA1c prediction")
                        .padding(.horizontal)

                        // Export/Share Button
                        if let result = currentPredictionResult ?? (
                            predictionHistory.first.flatMap { mostRecent in
                                PredictionResult(
                                    predictedHbA1c: mostRecent.predictedValue,
                                    confidenceLevel: mostRecent.confidenceLevel,
                                    riskCategory: determineRiskCategory(hbA1c: mostRecent.predictedValue),
                                    contributingFactors: decodedContributingFactors(mostRecent),
                                    recommendations: []
                                )
                            }
                        ) {
                            Button(action: {
                                pendingShareResult = result
                                showShareConfirmation = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export/Share Prediction")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color(.systemGray5))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Export or share prediction results")
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Glucose Readings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: shareText)
            }
            .alert("Prediction Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                "Share Health Data",
                isPresented: $showShareConfirmation,
                titleVisibility: .visible
            ) {
                Button("Share") {
                    if let result = pendingShareResult {
                        prepareShareContent(result: result)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingShareResult = nil
                }
            } message: {
                Text("This will share your predicted HbA1c value, risk category, and contributing health factors. This data contains sensitive health information.")
            }
        }
    }

    // MARK: - Private Methods

    /// Generates a new prediction by gathering inputs and running the prediction engine
    private func generateNewPrediction() {
        isGeneratingPrediction = true

        Task {
            let result = predictionEngine.runPredictionAndSave(context: managedObjectContext)

            isGeneratingPrediction = false

            if let result = result {
                // Animate the new result into view
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPredictionResult = result
                }
            } else {
                // Show error alert for insufficient data
                errorMessage = "Unable to generate prediction. Please ensure you have glucose readings and a complete user profile."
                showErrorAlert = true
            }
        }
    }

    /// Prepares the share content by creating a text summary of the prediction
    /// - Parameter result: The PredictionResult to summarize
    private func prepareShareContent(result: PredictionResult) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: Date())

        // Convert engine NGSP result to canonical IFCC, then display in user's preferred unit
        let ifccValue = ngspToIFCC(result.predictedHbA1c)
        let displayHbA1c = hba1cProfile.formatHbA1c(ifccValue)

        var summary = """
        HbA1c Prediction Report
        Generated: \(dateString)

        Predicted HbA1c: \(displayHbA1c)
        Confidence Level: \(String(format: "%.0f", result.confidenceLevel * 100))%
        Risk Category: \(result.riskCategory)

        Contributing Factors:
        """

        for (factor, value) in result.contributingFactors.sorted(by: { $0.value > $1.value }) {
            summary += "\n  • \(factor): \(String(format: "%.2f", value))"
        }

        if !result.recommendations.isEmpty {
            summary += "\n\nRecommendations:\n"
            for recommendation in result.recommendations {
                summary += "\n  ✓ \(recommendation)"
            }
        }

        summary += "\n\nNote: This prediction is for informational purposes only and should not replace professional medical advice."

        shareText = summary
        showShareSheet = true
    }

    /// Decodes contributing factors from JSON data stored in Core Data
    /// - Parameter entity: The HbA1cPredictionEntity containing encoded JSON data
    /// - Returns: A dictionary of contributing factors, or empty dictionary if decoding fails
    private func decodedContributingFactors(_ entity: HbA1cPredictionEntity) -> [String: Double] {
        guard let jsonData = entity.contributingFactorsJSON else { return [:] }

        do {
            if let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Double] {
                return decoded
            }
        } catch {
            #if DEBUG
            print("Error decoding contributing factors: \(error)")
            #endif
        }

        return [:]
    }

    /// Determines range category based on HbA1c value in IFCC mmol/mol
    /// Uses ADA-referenced thresholds converted to IFCC:
    /// Normal Range: < 39, Above Typical Range: 39-47,
    /// Moderately Elevated: 48-53, Elevated: 54-64, Significantly Elevated: > 64
    private func determineRiskCategory(hbA1c ifccValue: Double) -> String {
        if ifccValue < HbA1cThresholds.normalUpperBound {           // < 39 mmol/mol
            return "Normal Range"
        } else if ifccValue < HbA1cThresholds.diabetesLowerBound {  // 39-47
            return "Above Typical Range"
        } else if ifccValue <= HbA1cThresholds.goodControlTarget {  // 48-53
            return "Moderately Elevated"
        } else if ifccValue <= 64.0 {                               // 54-64 (~8.0%)
            return "Elevated"
        } else {
            return "Significantly Elevated"
        }
    }
}

// MARK: - Current Prediction Section

/// Displays the current or most recent prediction with detailed visualizations
private struct CurrentPredictionSection: View {
    let result: PredictionResult
    @ObservedObject private var profile = HbA1cUserProfile.shared

    /// The predicted value converted to canonical IFCC for threshold comparisons
    private var ifccValue: Double {
        ngspToIFCC(result.predictedHbA1c)
    }

    /// The display value in the user's preferred unit
    private var displayValue: String {
        let val = fromCanonicalIFCC(value: ifccValue, to: profile.effectiveUnit)
        switch profile.effectiveUnit {
        case .ngsp: return String(format: "%.1f", val)
        case .ifcc: return String(format: "%.0f", val)
        }
    }

    /// The unit suffix for display
    private var unitSuffix: String {
        profile.effectiveUnit.shortUnit
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Current Prediction")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Latest HbA1c Estimate")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)

            // HbA1c Value with Gauge
            VStack(spacing: 20) {
                // Semicircular Gauge — always uses NGSP for the 4-10% scale
                GaugeVisualization(value: result.predictedHbA1c)
                    .frame(height: 180)
                    .accessibilityLabel("HbA1c gauge visualization showing value of \(String(format: "%.1f", result.predictedHbA1c)) percent")
                    .accessibilityHidden(false)

                // HbA1c Value and Unit (unit-aware)
                HStack(alignment: .top, spacing: 4) {
                    Text(displayValue)
                        .font(.largeTitle.bold())
                        .foregroundColor(hbA1cValueColor(ifccValue))

                    Text(unitSuffix)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(hbA1cValueColor(ifccValue))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Predicted HbA1c: \(displayValue) \(unitSuffix)")

            // Confidence Level Progress
            VStack(spacing: 12) {
                HStack {
                    Text("Confidence Level")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(String(format: "%.0f", result.confidenceLevel * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                ProgressView(value: result.confidenceLevel)
                    .tint(.blue)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Confidence level: \(String(format: "%.0f", result.confidenceLevel * 100)) percent")

            // Risk Category Badge
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(riskCategoryColor(result.riskCategory))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Risk Category")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(result.riskCategory)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(riskCategoryBadgeLabel(result.riskCategory))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(riskCategoryColor(result.riskCategory))
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Risk category: \(result.riskCategory)")

            // Contributing Factors Chart
            if !result.contributingFactors.isEmpty {
                VStack(spacing: 12) {
                    Text("Contributing Factors")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    ContributingFactorsChart(factors: result.contributingFactors)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Contributing factors: \(result.contributingFactors.sorted(by: { $0.value > $1.value }).map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", "))")
            }

            // Recommendations
            if !result.recommendations.isEmpty {
                VStack(spacing: 12) {
                    Text("Recommendations")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        ForEach(result.recommendations.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.headline)

                                Text(result.recommendations[index])
                                    .font(.subheadline)
                                    .lineLimit(3)

                                Spacer()
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
    }

    /// Returns the appropriate color for the HbA1c value in IFCC mmol/mol
    /// Thresholds: Green < 39, Yellow 39-47, Orange 48-58, Red > 58
    private func hbA1cValueColor(_ ifccValue: Double) -> Color {
        switch ifccValue {
        case ..<HbA1cThresholds.normalUpperBound:
            return .green
        case HbA1cThresholds.normalUpperBound..<HbA1cThresholds.diabetesLowerBound:
            return .yellow
        case HbA1cThresholds.diabetesLowerBound...58.0:
            return .orange
        default:
            return .red
        }
    }

    /// Returns the appropriate color for risk category
    private func riskCategoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "low":
            return .green
        case "moderate":
            return .yellow
        case "high":
            return .orange
        case "very high":
            return .red
        default:
            return .gray
        }
    }

    /// Returns a readable label for the risk category badge
    private func riskCategoryBadgeLabel(_ category: String) -> String {
        switch category.lowercased() {
        case "low":
            return "LOW"
        case "moderate":
            return "MODERATE"
        case "high":
            return "HIGH"
        case "very high":
            return "CRITICAL"
        default:
            return category.uppercased()
        }
    }
}

// MARK: - Gauge Visualization

/// A semicircular gauge visualization showing HbA1c values with color zones
private struct GaugeVisualization: View {
    let value: Double

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height
            let radius = min(size.width, size.height) / 2 - 20

            // Draw background zones
            drawGaugeZone(context: &context, centerX: centerX, centerY: centerY, radius: radius,
                         startAngle: 0, endAngle: 60, color: .green.opacity(0.3)) // <5.7
            drawGaugeZone(context: &context, centerX: centerX, centerY: centerY, radius: radius,
                         startAngle: 60, endAngle: 100, color: .yellow.opacity(0.3)) // 5.7-6.4
            drawGaugeZone(context: &context, centerX: centerX, centerY: centerY, radius: radius,
                         startAngle: 100, endAngle: 150, color: .orange.opacity(0.3)) // 6.5-7.5
            drawGaugeZone(context: &context, centerX: centerX, centerY: centerY, radius: radius,
                         startAngle: 150, endAngle: 180, color: .red.opacity(0.3)) // >7.5

            // Draw gauge arc outline
            var path = Path()
            path.addArc(center: CGPoint(x: centerX, y: centerY), radius: radius,
                       startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 3)

            // Draw needle
            let normalizedValue = min(max(value, 4.0), 10.0) // Clamp between 4.0 and 10.0
            let valueRange = 6.0 // 10.0 - 4.0
            let anglePercentage = (normalizedValue - 4.0) / valueRange
            let needleAngle = anglePercentage * 180.0

            let needleRadians = CGFloat(needleAngle * .pi / 180.0)
            let needleEndX = centerX + radius * cos(needleRadians)
            let needleEndY = centerY - radius * sin(needleRadians)

            var needlePath = Path()
            needlePath.move(to: CGPoint(x: centerX, y: centerY))
            needlePath.addLine(to: CGPoint(x: needleEndX, y: needleEndY))
            context.stroke(needlePath, with: .color(.black), lineWidth: 4)

            // Draw center circle
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 12, y: centerY - 12, width: 24, height: 24)),
                with: .color(.black)
            )
        }
    }

    /// Helper function to draw a colored zone on the gauge
    private func drawGaugeZone(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat,
                              radius: CGFloat, startAngle: Double, endAngle: Double, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: centerX, y: centerY))

        let startRadians = CGFloat(startAngle * .pi / 180.0)
        let endRadians = CGFloat(endAngle * .pi / 180.0)

        path.addArc(center: CGPoint(x: centerX, y: centerY), radius: radius,
                   startAngle: .radians(startRadians), endAngle: .radians(endRadians), clockwise: false)
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }
}

// MARK: - Prediction History Section

/// Displays a list of historical predictions with expandable details
private struct PredictionHistorySection: View {
    let predictions: [HbA1cPredictionEntity]
    @Binding var selectedPrediction: HbA1cPredictionEntity?
    @Binding var expandedPredictionId: UUID?

    var body: some View {
        VStack(spacing: 12) {
            Text("Prediction History")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(predictions, id: \.id) { prediction in
                    PredictionHistoryRow(
                        prediction: prediction,
                        isExpanded: expandedPredictionId == prediction.id,
                        onTap: {
                            withAnimation(.easeInOut) {
                                if expandedPredictionId == prediction.id {
                                    expandedPredictionId = nil
                                } else {
                                    expandedPredictionId = prediction.id
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// A single row in the prediction history displaying key metrics
private struct PredictionHistoryRow: View {
    let prediction: HbA1cPredictionEntity
    let isExpanded: Bool
    let onTap: () -> Void
    @ObservedObject private var profile = HbA1cUserProfile.shared

    /// The display value in the user's preferred unit (predictedValue is stored as IFCC)
    private var displayValue: String {
        let val = fromCanonicalIFCC(value: prediction.predictedValue, to: profile.effectiveUnit)
        switch profile.effectiveUnit {
        case .ngsp: return String(format: "%.1f", val)
        case .ifcc: return String(format: "%.0f", val)
        }
    }

    /// The unit suffix for display
    private var unitSuffix: String {
        profile.effectiveUnit.shortUnit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed View
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        if let date = prediction.predictionDate {
                            Text(formatPredictionDate(date))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("HbA1c Prediction")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    // HbA1c Value (unit-aware)
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(displayValue)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(hbA1cValueColor(prediction.predictedValue))

                            Text(unitSuffix)
                                .font(.subheadline)
                                .foregroundColor(hbA1cValueColor(prediction.predictedValue))
                        }

                        // Confidence
                        Text("\(String(format: "%.0f", prediction.confidenceLevel * 100))% Confidence")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    // Risk Category Badge
                    let riskCategory = computeRiskCategory(hbA1c: prediction.predictedValue)
                    Text(riskCategoryBadgeLabel(riskCategory))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(riskCategoryColor(riskCategory))
                        .cornerRadius(6)

                    // Expand Indicator
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            // Expanded View
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                        .padding(.vertical, 8)

                    // Contributing Factors
                    let factors = decodedContributingFactors(prediction)
                    if !factors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contributing Factors")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            VStack(spacing: 8) {
                                ForEach(factors.sorted(by: { $0.value > $1.value }), id: \.key) { factor, value in
                                    HStack {
                                        Text(factor)
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        Spacer()

                                        Text(String(format: "%.2f", value))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }

                    // Model Version
                    if let modelVersion = prediction.modelVersion {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Version")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text(modelVersion)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Returns the appropriate color for the HbA1c value in IFCC mmol/mol
    /// Thresholds: Green < 39, Yellow 39-47, Orange 48-58, Red > 58
    private func hbA1cValueColor(_ ifccValue: Double) -> Color {
        switch ifccValue {
        case ..<HbA1cThresholds.normalUpperBound:
            return .green
        case HbA1cThresholds.normalUpperBound..<HbA1cThresholds.diabetesLowerBound:
            return .yellow
        case HbA1cThresholds.diabetesLowerBound...58.0:
            return .orange
        default:
            return .red
        }
    }

    /// Returns the appropriate color for risk category
    private func riskCategoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "low":
            return .green
        case "moderate":
            return .yellow
        case "high":
            return .orange
        case "very high":
            return .red
        default:
            return .gray
        }
    }

    /// Returns a readable label for the risk category badge
    private func riskCategoryBadgeLabel(_ category: String) -> String {
        switch category.lowercased() {
        case "low":
            return "LOW"
        case "moderate":
            return "MODERATE"
        case "high":
            return "HIGH"
        case "very high":
            return "CRITICAL"
        default:
            return category.uppercased()
        }
    }

    /// Computes range category based on HbA1c value in IFCC mmol/mol
    private func computeRiskCategory(hbA1c ifccValue: Double) -> String {
        if ifccValue < HbA1cThresholds.normalUpperBound {           // < 39
            return "Normal Range"
        } else if ifccValue < HbA1cThresholds.diabetesLowerBound {  // 39-47
            return "Above Typical Range"
        } else if ifccValue <= HbA1cThresholds.goodControlTarget {  // 48-53
            return "Moderately Elevated"
        } else if ifccValue <= 64.0 {                               // 54-64 (~8.0%)
            return "Elevated"
        } else {
            return "Significantly Elevated"
        }
    }

    /// Formats a prediction date for display
    private func formatPredictionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Decodes contributing factors from JSON data stored in Core Data
    private func decodedContributingFactors(_ entity: HbA1cPredictionEntity) -> [String: Double] {
        guard let jsonData = entity.contributingFactorsJSON else { return [:] }

        do {
            if let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Double] {
                return decoded
            }
        } catch {
            #if DEBUG
            print("Error decoding contributing factors: \(error)")
            #endif
        }

        return [:]
    }
}

// MARK: - Contributing Factors Chart

/// A horizontal bar chart showing contributing factors and their relative impact
private struct ContributingFactorsChart: View {
    let factors: [String: Double]

    var body: some View {
        let sortedFactors = factors.sorted { $0.value > $1.value }
        let maxValue = sortedFactors.map { $0.value }.max() ?? 1.0

        VStack(spacing: 12) {
            ForEach(sortedFactors.prefix(5), id: \.key) { factor, value in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(factor)
                            .font(.caption)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(String(format: "%.2f", value))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // Bar fill
                            Rectangle()
                                .fill(factorColor(for: factor))
                                .frame(width: geometry.size.width * CGFloat(value / maxValue))

                            Spacer()
                        }
                        .background(Color(.systemGray5))
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                }
            }
        }
    }

    /// Returns an appropriate color for a contributing factor
    private func factorColor(for factor: String) -> Color {
        let lowerFactor = factor.lowercased()

        if lowerFactor.contains("glucose") || lowerFactor.contains("blood glucose") {
            return .blue
        } else if lowerFactor.contains("activity") || lowerFactor.contains("exercise") {
            return .green
        } else if lowerFactor.contains("stress") {
            return .red
        } else if lowerFactor.contains("diet") || lowerFactor.contains("carb") {
            return .orange
        } else if lowerFactor.contains("medication") || lowerFactor.contains("insulin") {
            return .purple
        } else {
            return .gray
        }
    }
}

// MARK: - Share Sheet

/// A wrapper around the system share sheet for exporting prediction summaries
private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}



// MARK: - Preview

#Preview {
    PredictionView()
        .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
