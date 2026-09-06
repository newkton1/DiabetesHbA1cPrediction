//
//  XLSXExporter.swift
//  DiabetesHbA1cPrediction
//
//  Generates a doctor-friendly .xlsx file with 3 sheets:
//    Sheet 1: GMI & Lab HbA1c History
//    Sheet 2: Meals
//    Sheet 3: Exercise
//
//  Uses minimal OOXML (Office Open XML) — xlsx is just zipped XML.
//  ZIP is written in pure Swift (Store method + CRC-32) — no external dependencies.
//

import Foundation

// MARK: - Public API

enum XLSXExporter {

    /// Exports data to a .xlsx file and returns the file URL.
    ///
    /// - Parameters:
    ///   - gmiEstimates: GMI estimate records sorted by date.
    ///   - labHbA1cReadings: GlucoseReadingEntity records with source "Hospital Lab Test".
    ///   - meals: Meal records sorted by date.
    ///   - exercises: Exercise records sorted by date.
    /// - Returns: URL of the generated .xlsx file in the temp directory.
    static func export(
        gmiEstimates: [GmiExportRow],
        labHbA1cReadings: [LabHbA1cExportRow],
        meals: [MealExportRow],
        exercises: [ExerciseExportRow]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent("xlsx_build_\(UUID().uuidString)")
        let fm = FileManager.default

        // Clean up any previous build
        try? fm.removeItem(at: workDir)

        // Create OOXML directory structure
        let xlDir = workDir.appendingPathComponent("xl")
        let wsDir = xlDir.appendingPathComponent("worksheets")
        let relsRoot = workDir.appendingPathComponent("_rels")
        let relsXl = xlDir.appendingPathComponent("_rels")

        for dir in [wsDir, relsRoot, relsXl] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // 1. [Content_Types].xml
        try contentTypesXML().write(to: workDir.appendingPathComponent("[Content_Types].xml"),
                                     atomically: true, encoding: .utf8)

        // 2. _rels/.rels
        try rootRelsXML().write(to: relsRoot.appendingPathComponent(".rels"),
                                 atomically: true, encoding: .utf8)

        // 3. xl/workbook.xml
        try workbookXML().write(to: xlDir.appendingPathComponent("workbook.xml"),
                                 atomically: true, encoding: .utf8)

        // 4. xl/_rels/workbook.xml.rels
        try workbookRelsXML().write(to: relsXl.appendingPathComponent("workbook.xml.rels"),
                                     atomically: true, encoding: .utf8)

        // 5. xl/styles.xml
        try stylesXML().write(to: xlDir.appendingPathComponent("styles.xml"),
                               atomically: true, encoding: .utf8)

        // 6. Worksheets
        try buildGmiSheet(gmiEstimates: gmiEstimates, labReadings: labHbA1cReadings)
            .write(to: wsDir.appendingPathComponent("sheet1.xml"),
                   atomically: true, encoding: .utf8)

        try buildMealsSheet(meals: meals)
            .write(to: wsDir.appendingPathComponent("sheet2.xml"),
                   atomically: true, encoding: .utf8)

        try buildExerciseSheet(exercises: exercises)
            .write(to: wsDir.appendingPathComponent("sheet3.xml"),
                   atomically: true, encoding: .utf8)

        // 7. ZIP it all up
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let filename = "DiabetesFeast_ForDoctor_\(dateFormatter.string(from: Date())).xlsx"
        let xlsxURL = tempDir.appendingPathComponent(filename)
        try? fm.removeItem(at: xlsxURL)

        try zipDirectory(workDir, to: xlsxURL)

        // Clean up build directory
        try? fm.removeItem(at: workDir)

        return xlsxURL
    }
}

// MARK: - Export Row Types

/// Lightweight structs to decouple from Core Data entities.
extension XLSXExporter {

    struct GmiExportRow {
        let date: Date
        let gmiValue: Double      // NGSP %
        let confidence: Double
    }

    struct LabHbA1cExportRow {
        let date: Date
        let value: Double
        let unit: String          // "NGSP %" or "mmol/mol"
    }

    struct MealExportRow {
        let date: Date
        let name: String
        let mealType: String
        let foods: String         // comma-joined food names
        let totalCarbs: Double
        let totalProtein: Double
        let totalFat: Double
        let totalFiber: Double
        let totalCalories: Double
        let avgGlycemicIndex: Double
    }

    struct ExerciseExportRow {
        let date: Date
        let type: String
        let durationMinutes: Double
        let distance: Double
        let intensity: Double
        let caloriesBurned: Double
        let notes: String
    }
}

// MARK: - OOXML Boilerplate

private extension XLSXExporter {

    static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
    }

    static func rootRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    static func workbookXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="GMI &amp; Lab HbA1c" sheetId="1" r:id="rId1"/>
            <sheet name="Meals" sheetId="2" r:id="rId2"/>
            <sheet name="Exercise" sheetId="3" r:id="rId3"/>
          </sheets>
        </workbook>
        """
    }

    static func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
          <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border>
              <left/><right/><top/><bottom/><diagonal/>
            </border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
        </styleSheet>
        """
    }
}

// MARK: - Sheet Builders

private extension XLSXExporter {

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    static let datOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    // MARK: Sheet 1 — GMI & Lab HbA1c

    static func buildGmiSheet(
        gmiEstimates: [GmiExportRow],
        labReadings: [LabHbA1cExportRow]
    ) -> String {
        var rows: [String] = []
        var rowNum = 1

        // Header
        let headers = ["Date", "Type", "Value", "Unit", "Confidence"]
        rows.append(buildRow(rowNum, cells: headers, style: "1"))
        rowNum += 1

        // Lab HbA1c rows
        for lab in labReadings {
            let cells: [String] = [
                datOnlyFormatter.string(from: lab.date),
                "Lab HbA1c",
                String(format: "%.1f", lab.value),
                lab.unit,
                ""
            ]
            rows.append(buildRow(rowNum, cells: cells))
            rowNum += 1
        }

        // GMI rows
        for gmi in gmiEstimates {
            let cells: [String] = [
                datOnlyFormatter.string(from: gmi.date),
                "GMI Estimate",
                String(format: "%.1f", gmi.gmiValue),
                "NGSP %",
                String(format: "%.0f%%", gmi.confidence * 100)
            ]
            rows.append(buildRow(rowNum, cells: cells))
            rowNum += 1
        }

        return wrapSheet(rows: rows, colWidths: [14, 14, 10, 12, 12])
    }

    // MARK: Sheet 2 — Meals

    static func buildMealsSheet(meals: [MealExportRow]) -> String {
        var rows: [String] = []
        var rowNum = 1

        let headers = [
            "Date/Time", "Meal Name", "Type", "Foods",
            "Carbs (g)", "Protein (g)", "Fat (g)", "Fiber (g)",
            "Calories", "Avg GI"
        ]
        rows.append(buildRow(rowNum, cells: headers, style: "1"))
        rowNum += 1

        for meal in meals {
            let cells: [String] = [
                dateFormatter.string(from: meal.date),
                meal.name,
                meal.mealType,
                meal.foods,
                String(format: "%.1f", meal.totalCarbs),
                String(format: "%.1f", meal.totalProtein),
                String(format: "%.1f", meal.totalFat),
                String(format: "%.1f", meal.totalFiber),
                String(format: "%.0f", meal.totalCalories),
                meal.avgGlycemicIndex > 0 ? String(format: "%.0f", meal.avgGlycemicIndex) : ""
            ]
            rows.append(buildRow(rowNum, cells: cells))
            rowNum += 1
        }

        return wrapSheet(rows: rows, colWidths: [18, 20, 12, 40, 10, 10, 10, 10, 10, 8])
    }

    // MARK: Sheet 3 — Exercise

    static func buildExerciseSheet(exercises: [ExerciseExportRow]) -> String {
        var rows: [String] = []
        var rowNum = 1

        let headers = ["Date/Time", "Type", "Duration (min)", "Distance", "Intensity", "Calories Burned", "Notes"]
        rows.append(buildRow(rowNum, cells: headers, style: "1"))
        rowNum += 1

        for ex in exercises {
            let cells: [String] = [
                dateFormatter.string(from: ex.date),
                ex.type,
                String(format: "%.0f", ex.durationMinutes),
                ex.distance > 0 ? String(format: "%.2f", ex.distance) : "",
                String(format: "%.0f", ex.intensity),
                String(format: "%.0f", ex.caloriesBurned),
                ex.notes
            ]
            rows.append(buildRow(rowNum, cells: cells))
            rowNum += 1
        }

        return wrapSheet(rows: rows, colWidths: [18, 16, 14, 10, 10, 14, 30])
    }
}

// MARK: - XML Helpers

private extension XLSXExporter {

    /// Builds a single <row> element with inline string cells.
    static func buildRow(_ rowNum: Int, cells: [String], style: String? = nil) -> String {
        var xml = "      <row r=\"\(rowNum)\">"
        for (colIdx, value) in cells.enumerated() {
            let colLetter = columnLetter(colIdx)
            let ref = "\(colLetter)\(rowNum)"
            let escaped = xmlEscape(value)
            let styleAttr = style.map { " s=\"\($0)\"" } ?? ""
            xml += "<c r=\"\(ref)\" t=\"inlineStr\"\(styleAttr)><is><t>\(escaped)</t></is></c>"
        }
        xml += "</row>\n"
        return xml
    }

    /// Wraps rows into a complete worksheet XML document.
    static func wrapSheet(rows: [String], colWidths: [Double]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <cols>

        """

        for (i, width) in colWidths.enumerated() {
            xml += "    <col min=\"\(i + 1)\" max=\"\(i + 1)\" width=\"\(width)\" customWidth=\"1\"/>\n"
        }

        xml += """
          </cols>
          <sheetData>

        """

        for row in rows {
            xml += row
        }

        xml += """
          </sheetData>
        </worksheet>
        """

        return xml
    }

    /// Converts 0-based column index to Excel column letter (A, B, ... Z, AA, ...).
    static func columnLetter(_ index: Int) -> String {
        var result = ""
        var i = index
        repeat {
            result = String(UnicodeScalar(65 + (i % 26))!) + result
            i = i / 26 - 1
        } while i >= 0
        return result
    }

    /// Escapes XML special characters.
    static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Pure-Swift ZIP Writer (replaces ZIPFoundation dependency)

private extension XLSXExporter {

    /// Creates a ZIP archive at `destinationURL` containing all files under `sourceDir`.
    /// Uses Store (no compression) so no external library is needed.
    static func zipDirectory(_ sourceDir: URL, to destinationURL: URL) throws {
        var zipData = Data()
        var centralDirectory = Data()
        var entryCount: UInt16 = 0

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            throw NSError(domain: "XLSXExporter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot enumerate xlsx build directory"])
        }

        for case let fileURL as URL in enumerator {
            let rv = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if rv.isDirectory == true { continue }

            // Relative path inside the zip (forward slashes, no leading slash)
            let relativePath = String(fileURL.path.dropFirst(sourceDir.path.count + 1))
            let fileData = try Data(contentsOf: fileURL)
            let crc = crc32Swift(fileData)
            let fileSize = UInt32(fileData.count)
            let nameData = Data(relativePath.utf8)
            let localHeaderOffset = UInt32(zipData.count)

            // Local file header
            var lh = Data()
            lh.appendLE32(0x04034b50) // signature
            lh.appendLE16(20)          // version needed
            lh.appendLE16(0)           // flags
            lh.appendLE16(0)           // method: Store
            lh.appendLE16(0)           // mod time
            lh.appendLE16(0)           // mod date
            lh.appendLE32(crc)
            lh.appendLE32(fileSize)    // compressed size
            lh.appendLE32(fileSize)    // uncompressed size
            lh.appendLE16(UInt16(nameData.count))
            lh.appendLE16(0)           // extra length
            lh.append(nameData)
            zipData.append(lh)
            zipData.append(fileData)

            // Central directory entry
            var cd = Data()
            cd.appendLE32(0x02014b50) // signature
            cd.appendLE16(20)          // version made by
            cd.appendLE16(20)          // version needed
            cd.appendLE16(0)           // flags
            cd.appendLE16(0)           // method: Store
            cd.appendLE16(0)           // mod time
            cd.appendLE16(0)           // mod date
            cd.appendLE32(crc)
            cd.appendLE32(fileSize)    // compressed size
            cd.appendLE32(fileSize)    // uncompressed size
            cd.appendLE16(UInt16(nameData.count))
            cd.appendLE16(0)           // extra length
            cd.appendLE16(0)           // comment length
            cd.appendLE16(0)           // disk number start
            cd.appendLE16(0)           // internal attrs
            cd.appendLE32(0)           // external attrs
            cd.appendLE32(localHeaderOffset)
            cd.append(nameData)
            centralDirectory.append(cd)
            entryCount += 1
        }

        let cdOffset = UInt32(zipData.count)
        let cdSize   = UInt32(centralDirectory.count)
        zipData.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.appendLE32(0x06054b50) // signature
        eocd.appendLE16(0)           // disk number
        eocd.appendLE16(0)           // disk with CD
        eocd.appendLE16(entryCount)  // entries this disk
        eocd.appendLE16(entryCount)  // total entries
        eocd.appendLE32(cdSize)
        eocd.appendLE32(cdOffset)
        eocd.appendLE16(0)           // comment length
        zipData.append(eocd)

        try zipData.write(to: destinationURL)
    }

    /// CRC-32/ISO-HDLC — pure Swift, no imports needed.
    static func crc32Swift(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

// MARK: - Data little-endian helpers

private extension Data {
    mutating func appendLE16(_ value: UInt16) {
        let v = value.littleEndian
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
    }
    mutating func appendLE32(_ value: UInt32) {
        let v = value.littleEndian
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF))
        append(UInt8((v >> 24) & 0xFF))
    }
}
