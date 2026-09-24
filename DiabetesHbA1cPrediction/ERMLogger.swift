//  ERMLogger.swift  –  DiabetesHbA1cPrediction
//
//  Lightweight timestamped logger for diagnosing the T+90 nudge bug.
//  Writes to <Documents>/erm_debug.log — pull it via Xcode → Devices →
//  Download Container, then open AppData/Documents/erm_debug.log.
//
//  REMOVE (or #if DEBUG-gate) before App Store submission.

import Foundation

final class ERMLogger {

    static let shared = ERMLogger()

    private let logURL: URL
    private let queue = DispatchQueue(label: "com.diabetesfeast.ermlogger", qos: .utility)
    private let df: DateFormatter

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logURL = docs.appendingPathComponent("erm_debug.log")
        df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        df.locale = Locale(identifier: "en_US_POSIX")
        log("=== ERMLogger initialised — log at \(logURL.path) ===")
    }

    func log(_ message: String, file: String = #file, function: String = #function) {
        let shortFile = URL(fileURLWithPath: file).lastPathComponent
        let stamp = df.string(from: Date())
        let line = "[\(stamp)] [\(shortFile):\(function)] \(message)\n"
        queue.async { [weak self] in
            guard let self else { return }
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logURL.path) {
                    if let handle = try? FileHandle(forWritingTo: self.logURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: self.logURL, options: .atomic)
                }
            }
        }
        // Also print to Xcode console
        print(line, terminator: "")
    }

    /// Call from a share sheet or Settings view so the user can AirDrop the log.
    func logFileURL() -> URL { logURL }

    /// Wipes the log file — call before a fresh test run.
    func clearLog() {
        queue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.logURL)
            self.log("=== Log cleared ===")
        }
    }
}
