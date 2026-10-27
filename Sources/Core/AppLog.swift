import Foundation

/// Plain-text event log for diagnosing problems outside live translation (sign-in, sync…).
/// Written only while debug recording is on: ~/Library/Application Support/Tercana/Logs/app.log
enum AppLog {
    private static let queue = DispatchQueue(label: "Tercana.AppLog")

    static func write(_ message: String) {
        guard UserDefaults.standard.bool(forKey: "debugRecording"),
              ProcessInfo.processInfo.environment["TERCANA_PREVIEW"] == nil else { return }
        let line = "\(Date().formatted(.iso8601)) \(message)\n"
        queue.async {
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tercana/Logs", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("app.log")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
