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
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)

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
                            Button(action: { prepareShareContent(result: result) }) {
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

        var summary = """
        HbA1c Prediction Report
        Generated: \(dateString)

        Predicted HbA1c: \(String(format: "%.1f", result.predictedHbA1c))%
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
            print("Error decoding contributing factors: \(error)")
        }

        return [:]
    }

    /// Determines risk category based on HbA1c value
    /// Uses ADA diagnostic criteria thresholds
    private func determineRiskCategory(hbA1c: Double) -> String {
        if hbA1c < 5.7 {
            return "Normal"
        } else if hbA1c < 6.5 {
            return "Pre-diabetes"
        } else if hbA1c <= 7.0 {
            return "Diabetes - Well Controlled"
        } else if hbA1c <= 8.0 {
            return "Diabetes - Needs Attention"
        } else {
            return "Diabetes - High Risk"
        }
    }
}

// MARK: - Current Prediction Section

/// Displays the current or most recent prediction with detailed visualizations
private struct CurrentPredictionSection: View {
    let result: PredictionResult

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
                // Semicircular Gauge
                GaugeVisualization(value: result.predictedHbA1c)
                    .frame(height: 180)

                // HbA1c Value and Unit
                HStack(alignment: .top, spacing: 4) {
                    Text(String(format: "%.1f", result.predictedHbA1c))
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(hbA1cValueColor(result.predictedHbA1c))

                    Text("%")
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundColor(hbA1cValueColor(result.predictedHbA1c))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)

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

    /// Returns the appropriate color for the HbA1c value based on health zones
    private func hbA1cValueColor(_ value: Double) -> Color {
        if value < 5.7 {
            return .green
        } else if value < 6.4 {
            return .yellow
        } else if value < 7.5 {
            return .orange
        } else {
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

                    // HbA1c Value
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(String(format: "%.1f", prediction.predictedValue))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(hbA1cValueColor(prediction.predictedValue))

                            Text("%")
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

    /// Returns the appropriate color for the HbA1c value
    private func hbA1cValueColor(_ value: Double) -> Color {
        if value < 5.7 {
            return .green
        } else if value < 6.4 {
            return .yellow
        } else if value < 7.5 {
            return .orange
        } else {
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

    /// Computes risk category based on HbA1c value
    private func computeRiskCategory(hbA1c: Double) -> String {
        if hbA1c < 5.7 {
            return "Normal"
        } else if hbA1c < 6.5 {
            return "Pre-diabetes"
        } else if hbA1c <= 7.0 {
            return "Well Controlled"
        } else if hbA1c <= 8.0 {
            return "Needs Attention"
        } else {
            return "High Risk"
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
            print("Error decoding contributing factors: \(error)")
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
