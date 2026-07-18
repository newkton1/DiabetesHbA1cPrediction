//
//  DataImportView.swift
//  DiabetesHbA1cPrediction
//
//  DEBUG-only view that lets the user pick a previously-exported JSON file
//  and import its data into Core Data. Shows a summary of imported / skipped
//  records and any warnings.
//
//  Phase J.2 of the data-import feature.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct DataImportView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // JSON import state
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importResult: DataImportResult?
    @State private var importError: String?

    // Delete confirmation state
    @State private var fileToDelete: URL?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    /// Bumped to force the file list to refresh after a deletion.
    @State private var fileListRefreshID = UUID()

    /// JSON files sitting in the app's Documents directory (e.g. copied
    /// via `xcrun simctl` or iTunes File Sharing).
    private var documentsJSONFiles: [URL] {
        // fileListRefreshID is read here so SwiftUI re-evaluates after deletion
        let _ = fileListRefreshID
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    var body: some View {
        List {
            Section(header: Text("Import")) {
                Button(action: { showFilePicker = true }) {
                    Label("Choose JSON File to Import", systemImage: "square.and.arrow.down")
                }
                .disabled(isImporting)

                // Direct load from app's Documents folder (useful when
                // file picker can't see the app container, e.g. Simulator).
                // Swipe left on a file to delete it.
                if !documentsJSONFiles.isEmpty {
                    ForEach(documentsJSONFiles, id: \.lastPathComponent) { fileURL in
                        Button(action: { performImport(from: fileURL) }) {
                            Label(fileURL.lastPathComponent, systemImage: "doc.fill")
                                .font(.subheadline)
                        }
                        .disabled(isImporting)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                fileToDelete = fileURL
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    Text("No JSON files found in app Documents folder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Importing…")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let error = importError {
                Section(header: Text("Error")) {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let error = deleteError {
                Section(header: Text("Error")) {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let result = importResult {
                Section(header: Text("Import Summary")) {
                    ImportSummaryRow(label: "Glucose Readings", count: result.glucoseReadings)
                    ImportSummaryRow(label: "Meals", count: result.meals)
                    ImportSummaryRow(label: "Exercise Sessions", count: result.exerciseSessions)
                    ImportSummaryRow(label: "GMI Estimates", count: result.hba1cPredictions)
                    ImportSummaryRow(label: "User Profiles", count: result.userProfiles)
                    ImportSummaryRow(label: "Health Conditions", count: result.healthConditions)

                    HStack {
                        Text("Total imported")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(result.totalImported)")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }

                    if result.totalSkipped > 0 {
                        HStack {
                            Text("Already existed (skipped)")
                            Spacer()
                            Text("\(result.totalSkipped)")
                                .foregroundColor(.orange)
                        }
                    }
                }

                if !result.warnings.isEmpty {
                    Section(header: Text("Warnings")) {
                        ForEach(result.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Section(header: Text("Info")) {
                Text("Import a JSON file previously exported from Diabetes Feast. Records with the same UUID as existing data will be skipped (no duplicates). New records are added to your existing data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Backup?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let url = fileToDelete {
                    deleteBackupFile(url)
                }
                fileToDelete = nil
            }
        } message: {
            Text("Delete \"\(fileToDelete?.lastPathComponent ?? "this file")\"? This cannot be undone.")
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - File Deletion

    /// Deletes a backup JSON file from the Documents directory.
    private func deleteBackupFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            // Trigger the file list to refresh
            fileListRefreshID = UUID()
        } catch {
            deleteError = "Could not delete file: \(error.localizedDescription)"
        }
    }

    // MARK: - File Handling

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        importError = nil
        importResult = nil

        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else {
                importError = "No file selected."
                return
            }
            performImport(from: url)
        }
    }

    // MARK: - JSON Handling

    private func performImport(from url: URL) {
        isImporting = true

        // Access the security-scoped resource (required for files from
        // the document picker on iOS).
        let didStart = url.startAccessingSecurityScopedResource()

        Task { @MainActor in
            defer {
                if didStart { url.stopAccessingSecurityScopedResource() }
                isImporting = false
            }

            do {
                let result = try DataImportEngine.importJSON(from: url, into: viewContext)
                importResult = result
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

// MARK: - Summary Row

private struct ImportSummaryRow: View {
    let label: String
    let count: DataImportResult.ImportCount

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if count.found == 0 {
                Text("—")
                    .foregroundColor(.secondary)
            } else {
                Text("\(count.imported) new")
                    .foregroundColor(count.imported > 0 ? .green : .secondary)
                if count.skipped > 0 {
                    Text("/ \(count.skipped) existed")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
    }
}
