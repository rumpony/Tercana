import AppKit
import SwiftUI

struct SubtitleLogView: View {
    private let log = SubtitleLog.shared
    @State private var showOriginal = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Orijinali de göster", isOn: $showOriginal)
                Spacer()
                Button("Temizle") { log.clear() }
                    .disabled(log.entries.isEmpty)
            }
            .padding(12)
            Divider()
            if log.entries.isEmpty {
                ContentUnavailableView("Henüz altyazı yok", systemImage: "captions.bubble",
                                       description: Text("Canlı çeviri çalışırken çevrilen satırlar burada birikir."))
            } else {
                List(log.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.translation)
                            .font(.system(size: 15))
                            .textSelection(.enabled)
                        if showOriginal {
                            Text(entry.original)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(entry.time.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 300)
    }
}
