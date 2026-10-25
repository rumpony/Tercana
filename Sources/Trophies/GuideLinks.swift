import Foundation

/// Search links to the usual trophy guide sites. None of them offer an API, so we hand off to the browser.
enum GuideLinks {
    struct Link: Identifiable {
        let id: String
        let title: String
        let url: URL
    }

    static func forGame(_ name: String) -> [Link] {
        let plain = cleanName(name)
        return [
            link("powerpyx", "PowerPyx rehberi", "https://www.powerpyx.com/?s=\(encode(plain + " trophy guide"))"),
            link("psnprofiles", "PSNProfiles rehberleri", "https://psnprofiles.com/search/guides?q=\(encode(plain))"),
            link("playstationtrophies", "PlaystationTrophies", "https://www.playstationtrophies.org/search/?q=\(encode(plain))"),
            link("youtube", "YouTube: platin yol haritası",
                 "https://www.youtube.com/results?search_query=\(encode(plain + " platinum trophy guide"))"),
        ]
    }

    static func forTrophy(_ trophy: String, game: String) -> URL {
        URL(string: "https://www.youtube.com/results?search_query=\(encode("\(cleanName(game)) \(trophy) trophy"))")!
    }

    static func webSearch(_ trophy: String, game: String) -> URL {
        URL(string: "https://www.google.com/search?q=\(encode("\(cleanName(game)) \"\(trophy)\" trophy guide"))")!
    }

    /// Trophy list names often carry suffixes like "Trophies" or "(PS5)" that hurt search results.
    private static func cleanName(_ name: String) -> String {
        name.replacingOccurrences(of: "Trophies", with: "")
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: #"\((PS4|PS5|PS Vita|PS3)\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? text
    }

    private static func link(_ id: String, _ title: String, _ url: String) -> Link {
        Link(id: id, title: title, url: URL(string: url)!)
    }
}
