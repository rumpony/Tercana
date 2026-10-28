import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, data: WidgetData(level: 312, progress: 64, counts: [27, 121, 352, 1184], huntingName: "Neon Drift", huntingProgress: 97))
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(WidgetData.load().map { Entry(date: .now, data: $0) } ?? placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now, data: WidgetData.load())], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry
    private let colors: [Color] = [Color(red: 0.55, green: 0.72, blue: 0.95), Color(red: 0.95, green: 0.74, blue: 0.20),
                                   Color(red: 0.62, green: 0.66, blue: 0.72), Color(red: 0.80, green: 0.50, blue: 0.27)]

    var body: some View {
        if let data = entry.data {
            switch family {
            case .accessoryCircular:
                Gauge(value: Double(data.progress), in: 0...100) { Text("") } currentValueLabel: { Text("\(data.level)") }
                    .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text("Lv \(data.level) · %\(data.progress)").font(.headline)
                    Text("🏆 \(data.counts[0])  \(data.counts[1]) · \(data.counts[2]) · \(data.counts[3])").font(.caption)
                }
            default:
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.2), lineWidth: 7)
                        Circle().trim(from: 0, to: Double(data.progress) / 100).stroke(.yellow, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(data.level)").font(.title2.bold()).monospacedDigit()
                    }
                    .frame(width: 70, height: 70)
                    if family != .systemSmall {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                ForEach(0..<4, id: \.self) { i in
                                    HStack(spacing: 3) {
                                        Circle().fill(colors[i]).frame(width: 7, height: 7)
                                        Text("\(data.counts[i])").font(.caption).monospacedDigit()
                                    }
                                }
                            }
                            if let name = data.huntingName, let progress = data.huntingProgress {
                                Text(name).font(.caption.weight(.semibold)).lineLimit(1)
                                ProgressView(value: Double(progress), total: 100).tint(.yellow)
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
            }
        } else {
            Text("Tercana").font(.headline)
        }
    }
}

@main
struct TercanaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TercanaLevel", provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.05, green: 0.36, blue: 0.40), Color(red: 0.09, green: 0.13, blue: 0.30)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Tercana")
        .description("Trophy level")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
