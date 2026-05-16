//  FeastModeBannerView.swift  –  DiabetesHbA1cPrediction
import SwiftUI

struct FeastModeBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "party.popper.fill")
                .font(.title2)
                .foregroundColor(.feastAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Feast Mode")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.feastAccent)
                Text("Planning a feast or just a special treat? Review how similar past meals appeared in your glucose and GMI trends.")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.feastAccent.opacity(0.10))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.feastAccent.opacity(0.30), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview { FeastModeBannerView().padding() }
