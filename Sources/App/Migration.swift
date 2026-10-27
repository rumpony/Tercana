import Foundation

/// The app was called SubLens before 1.1. Bring settings and data over once, so nobody has to
/// set things up again after the rename.
enum Migration {
    static func fromSubLens() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromSubLens") else { return }
        defaults.set(true, forKey: "migratedFromSubLens")

        if let old = UserDefaults(suiteName: "com.rumpony.SubLens")?.dictionaryRepresentation() {
            for (key, value) in old where defaults.object(forKey: key) == nil && !key.hasPrefix("NS") && !key.hasPrefix("Apple") {
                defaults.set(value, forKey: key)
            }
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldFolder = support.appendingPathComponent("SubLens", isDirectory: true)
        let newFolder = support.appendingPathComponent("Tercana", isDirectory: true)
        if FileManager.default.fileExists(atPath: oldFolder.path), !FileManager.default.fileExists(atPath: newFolder.path) {
            try? FileManager.default.moveItem(at: oldFolder, to: newFolder)
        }
    }
}
