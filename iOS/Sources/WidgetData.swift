import Foundation

/// Small summary the app writes for the home screen widget, through the shared App Group.
struct WidgetData: Codable {
    static let group = "group.com.rumpony.TercanaMobile"

    var level: Int
    var progress: Int
    var counts: [Int]   // platinum, gold, silver, bronze
    var huntingName: String?
    var huntingProgress: Int?

    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget.json")
    }

    static func load() -> WidgetData? {
        url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(WidgetData.self, from: $0) }
    }

    func save() {
        guard let url = Self.url, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url)
    }
}
