//
//  DiabetesHbA1cPredictionTests.swift
//  DiabetesHbA1cPredictionTests
//
//  Created by test2 on 2026/02/14.
//

import Testing
@testable import DiabetesHbA1cPrediction

// MARK: - HbA1c Conversion Tests

struct HbA1cConversionTests {

    /// Tolerance for floating-point comparison
    private let epsilon = 0.1

    // MARK: - NGSP to IFCC

    @Test("NGSP 5.7% converts to approximately 38.8 mmol/mol")
    func ngspToIFCC_prediabetesBoundary() {
        let result = ngspToIFCC(5.7)
        #expect(abs(result - 38.8) < epsilon)
    }

    @Test("NGSP 6.5% converts to approximately 47.5 mmol/mol")
    func ngspToIFCC_diabetesBoundary() {
        let result = ngspToIFCC(6.5)
        #expect(abs(result - 47.5) < epsilon)
    }

    @Test("NGSP 7.0% converts to approximately 53.0 mmol/mol")
    func ngspToIFCC_goodControlBoundary() {
        let result = ngspToIFCC(7.0)
        #expect(abs(result - 53.0) < epsilon)
    }

    @Test("NGSP 10.0% converts to approximately 85.7 mmol/mol")
    func ngspToIFCC_highValue() {
        let result = ngspToIFCC(10.0)
        #expect(abs(result - 85.7) < epsilon)
    }

    // MARK: - IFCC to NGSP

    @Test("IFCC 48 mmol/mol converts to approximately 6.5%")
    func ifccToNGSP_diabetesBoundary() {
        let result = ifccToNGSP(48.0)
        #expect(abs(result - 6.5) < epsilon)
    }

    @Test("IFCC 39 mmol/mol converts to approximately 5.7%")
    func ifccToNGSP_prediabetesBoundary() {
        let result = ifccToNGSP(39.0)
        #expect(abs(result - 5.7) < epsilon)
    }

    // MARK: - Round-trip Accuracy

    @Test("NGSP → IFCC → NGSP round-trip preserves value within tolerance",
          arguments: [4.0, 5.0, 5.7, 6.0, 6.5, 7.0, 8.0, 9.0, 10.0])
    func roundTrip_ngspToIFCCAndBack(ngsp: Double) {
        let roundTripped = ifccToNGSP(ngspToIFCC(ngsp))
        #expect(abs(roundTripped - ngsp) < 0.01,
                "Round-trip for \(ngsp)% returned \(roundTripped)")
    }

    @Test("IFCC → NGSP → IFCC round-trip preserves value within tolerance",
          arguments: [20.0, 30.0, 39.0, 48.0, 53.0, 75.0, 100.0])
    func roundTrip_ifccToNGSPAndBack(ifcc: Double) {
        let roundTripped = ngspToIFCC(ifccToNGSP(ifcc))
        #expect(abs(roundTripped - ifcc) < 0.01,
                "Round-trip for \(ifcc) mmol/mol returned \(roundTripped)")
    }

    // MARK: - eAG Conversions

    @Test("HbA1c 6.5% yields eAG of approximately 140 mg/dL")
    func hba1cToEAG_reference_6_5() {
        let result = hba1cToEAG(ngsp: 6.5)
        #expect(abs(result - 139.85) < epsilon)
    }

    @Test("HbA1c 7.0% yields eAG of approximately 154 mg/dL")
    func hba1cToEAG_reference_7_0() {
        let result = hba1cToEAG(ngsp: 7.0)
        #expect(abs(result - 154.2) < epsilon)
    }

    @Test("HbA1c 8.0% yields eAG of approximately 183 mg/dL")
    func hba1cToEAG_reference_8_0() {
        let result = hba1cToEAG(ngsp: 8.0)
        #expect(abs(result - 182.9) < epsilon)
    }

    @Test("eAG in mmol/L equals mg/dL divided by 18.0182")
    func hba1cToEAGMmol_consistency() {
        let mgdl = hba1cToEAG(ngsp: 7.0)
        let mmol = hba1cToEAGMmol(ngsp: 7.0)
        #expect(abs(mmol - mgdl / 18.0182) < 0.001)
    }

    // MARK: - Canonical Storage Helpers

    @Test("toCanonicalIFCC passes through IFCC values unchanged")
    func toCanonicalIFCC_ifccPassthrough() {
        let result = toCanonicalIFCC(value: 48.0, from: .ifcc)
        #expect(result == 48.0)
    }

    @Test("toCanonicalIFCC converts NGSP to IFCC")
    func toCanonicalIFCC_convertsNGSP() {
        let result = toCanonicalIFCC(value: 6.5, from: .ngsp)
        #expect(abs(result - ngspToIFCC(6.5)) < 0.001)
    }

    @Test("fromCanonicalIFCC passes through IFCC values unchanged")
    func fromCanonicalIFCC_ifccPassthrough() {
        let result = fromCanonicalIFCC(value: 48.0, to: .ifcc)
        #expect(result == 48.0)
    }

    @Test("fromCanonicalIFCC converts IFCC to NGSP")
    func fromCanonicalIFCC_convertsToNGSP() {
        let result = fromCanonicalIFCC(value: 48.0, to: .ngsp)
        #expect(abs(result - ifccToNGSP(48.0)) < 0.001)
    }

    @Test("Canonical round-trip: NGSP → IFCC storage → NGSP display preserves value")
    func canonicalRoundTrip() {
        let original = 7.0
        let stored = toCanonicalIFCC(value: original, from: .ngsp)
        let displayed = fromCanonicalIFCC(value: stored, to: .ngsp)
        #expect(abs(displayed - original) < 0.01)
    }
}

// MARK: - Threshold Classification Tests

struct HbA1cThresholdTests {

    @Test("Value below 39 mmol/mol is classified as Normal")
    func riskCategory_normal() {
        #expect(HbA1cThresholds.riskCategory(forIFCC: 30.0) == "Normal")
        #expect(HbA1cThresholds.riskCategory(forIFCC: 38.9) == "Normal")
    }

    @Test("Value 39-47 mmol/mol is classified as Prediabetes")
    func riskCategory_prediabetes() {
        #expect(HbA1cThresholds.riskCategory(forIFCC: 39.0) == "Prediabetes")
        #expect(HbA1cThresholds.riskCategory(forIFCC: 43.0) == "Prediabetes")
        #expect(HbA1cThresholds.riskCategory(forIFCC: 47.9) == "Prediabetes")
    }

    @Test("Value 48-52 mmol/mol is classified as Diabetes - Good Control")
    func riskCategory_diabetesGoodControl() {
        #expect(HbA1cThresholds.riskCategory(forIFCC: 48.0) == "Diabetes - Good Control")
        #expect(HbA1cThresholds.riskCategory(forIFCC: 52.9) == "Diabetes - Good Control")
    }

    @Test("Value 53+ mmol/mol is classified as Diabetes - Needs Improvement")
    func riskCategory_diabetesNeedsImprovement() {
        #expect(HbA1cThresholds.riskCategory(forIFCC: 53.0) == "Diabetes - Needs Improvement")
        #expect(HbA1cThresholds.riskCategory(forIFCC: 80.0) == "Diabetes - Needs Improvement")
    }

    @Test("Thresholds in IFCC return expected static values")
    func thresholds_ifcc() {
        let t = HbA1cThresholds.thresholds(in: .ifcc)
        #expect(t.normal == 39.0)
        #expect(t.prediabetes == 47.0)
        #expect(t.diabetes == 48.0)
        #expect(t.goodControl == 53.0)
    }

    @Test("Thresholds in NGSP are consistent with IFCC conversion")
    func thresholds_ngsp_consistency() {
        let t = HbA1cThresholds.thresholds(in: .ngsp)
        #expect(abs(t.normal - ifccToNGSP(39.0)) < 0.01)
        #expect(abs(t.prediabetes - ifccToNGSP(47.0)) < 0.01)
        #expect(abs(t.diabetes - ifccToNGSP(48.0)) < 0.01)
        #expect(abs(t.goodControl - ifccToNGSP(53.0)) < 0.01)
    }
}

// MARK: - Formatting Tests

struct HbA1cFormattingTests {

    @Test("NGSP format uses 1 decimal place")
    func formatNGSP() {
        let result = formatHbA1c(6.5, unit: .ngsp)
        #expect(result == "6.5 %")
    }

    @Test("IFCC format uses 0 decimal places")
    func formatIFCC() {
        let result = formatHbA1c(48.0, unit: .ifcc)
        #expect(result == "48 mmol/mol")
    }

    @Test("Format without unit string omits suffix")
    func formatWithoutUnit() {
        let result = formatHbA1c(7.0, unit: .ngsp, includeUnit: false)
        #expect(result == "7.0")
    }
}
