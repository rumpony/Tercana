import AppKit
import SwiftUI

struct SubtitleLogView: View {
    private let log = SubtitleLog.shared
    @State private var showOriginal = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(S.showOriginal, isOn: $showOriginal)
                Spacer()
                Button(S.clear) { log.clear() }
                    .disabled(log.entries.isEmpty)
            }
            .padding(12)
            Divider()
            if log.entries.isEmpty {
                ContentUnavailableView(S.noSubtitlesYet, systemImage: "captions.bubble",
                                       description: Text(S.noSubtitlesHint))
            } else {
                List(log.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        SpeakerLine(text: entry.translation)
                            .font(.system(size: 15))
                            .textSelection(.enabled)
                        if showOriginal {
                            Text(entry.original)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(entry.time.formatted(Date.FormatStyle(date: .omitted, time: .standard).locale(S.locale)))
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

/// "ENZO: …" with the name in the same colour the subtitle overlay uses.
struct SpeakerLine: View {
    let text: String

    var body: some View {
        let parts = SubtitleText.splitSpeaker(text)
        if let speaker = parts.speaker {
            let name = Text(speaker + ": ").foregroundColor(Color(red: 0.85, green: 0.62, blue: 0.0)).bold()
            Text("\(name)\(parts.line)")
        } else {
            Text(text)
        }
    }
}
