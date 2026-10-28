import SwiftUI

/// GitHub-style year of trophy days: one column per week, darker means more trophies.
struct Heatmap: View {
    let counts: [Date: Int]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let peak = max(counts.values.max() ?? 1, 1)
        Canvas { context, size in
            let weeks = 53
            let gap: CGFloat = 2
            let cell = min((size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks), (size.height - gap * 6) / 7)
            let todayColumn = weeks - 1
            let todayRow = calendar.component(.weekday, from: today) - 1
            for column in 0..<weeks {
                for row in 0..<7 {
                    let back = (todayColumn - column) * 7 + (todayRow - row)
                    guard back >= 0, let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
                    let value = counts[day] ?? 0
                    let rect = CGRect(x: CGFloat(column) * (cell + gap), y: CGFloat(row) * (cell + gap), width: cell, height: cell)
                    let color = value == 0 ? Color.secondary.opacity(0.15)
                        : Color.accentColor.opacity(0.3 + 0.7 * Double(value) / Double(peak))
                    context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.25), with: .color(color))
                }
            }
        }
        .frame(height: 64)
    }
}

/// Image made for sharing: level, counts and the latest platinums.
struct ProfileCard: View {
    let profile: TrophyProfile
    let platinums: [TrophyGame]
    let name: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image("Mark").resizable().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
                Text(name ?? "Tercana").font(.headline)
                Spacer()
                Text(S.trophyLevel(profile.level)).font(.headline)
            }
            ProgressView(value: Double(profile.progress), total: 100).tint(.yellow)
            HStack(spacing: 18) {
                ForEach(TrophyGrade.allCases.reversed(), id: \.self) { grade in
                    VStack(spacing: 2) {
                        Text("\(profile.earnedTrophies.value(grade))").font(.title2.bold()).monospacedDigit()
                        Text(grade.label).font(.caption2).foregroundStyle(grade.color)
                    }
                }
            }
            if !platinums.isEmpty {
                HStack(spacing: 8) {
                    ForEach(platinums.prefix(6)) { Artwork(url: $0.iconURL, size: 44) }
                }
            }
            Text("\(M.points): \(Level.points(profile.earnedTrophies).formatted())")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        .padding(24)
        .foregroundStyle(.white)
        .frame(width: 380)
        .background(LinearGradient(colors: [Color(red: 0.05, green: 0.36, blue: 0.40), Color(red: 0.09, green: 0.13, blue: 0.30)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

/// Renders a view to an image that ShareLink can send. Artwork must already be cached to show up.
@MainActor
func snapshot(_ view: some View) -> Image {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    return renderer.uiImage.map(Image.init(uiImage:)) ?? Image(systemName: "photo")
}

struct PlatinumWall: View {
    let games: [TrophyGame]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                ForEach(games) { game in
                    NavigationLink(value: game) { Artwork(url: game.iconURL, size: 72) }
                }
            }
            .padding()
        }
        .navigationTitle("\(M.platinumWall) (\(games.count))")
        .toolbar {
            let image = snapshot(wallImage)
            ShareLink(item: image, preview: SharePreview(M.platinumWall, image: image))
        }
    }

    private var wallImage: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(56), spacing: 6), count: 6), spacing: 6) {
            ForEach(games) { Artwork(url: $0.iconURL, size: 56) }
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.13, blue: 0.30))
    }
}

struct YearReview: View {
    let earned: [Insights.Earned]
    @State private var year = Calendar.current.component(.year, from: Date())

    var body: some View {
        let years = Insights.years(earned)
        let review = Insights.year(year, earned)
        List {
            Picker(M.yearReview, selection: $year) {
                ForEach(years, id: \.self) { Text(String($0)).tag($0) }
            }
            Section {
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 16) {
                    Figure(value: "\(review.trophies)", caption: S.totalTrophies)
                    Figure(value: "\(review.platinums.count)", caption: S.platinums)
                    Figure(value: review.points.formatted(), caption: M.points)
                    Figure(value: "\(review.games)", caption: S.gamesPlayed)
                }
                .padding(.vertical, 4)
                if let best = review.bestMonth {
                    LabeledContent(M.bestMonth, value: "\(S.locale.calendar.monthSymbols[best.month - 1]) · \(best.count)")
                }
            }
            if let rarest = review.rarest {
                Section(S.rarestEarned) { TrophyRow(trophy: rarest.trophy, subtitle: rarest.game.name) }
            }
            if !review.platinums.isEmpty {
                Section(S.platinums) {
                    ForEach(review.platinums) { game in NavigationLink(value: game) { GameRow(game: game) } }
                }
            }
        }
        .navigationTitle(M.yearReview)
        .onAppear { if let first = years.first, !years.contains(year) { year = first } }
    }
}

struct NextUpView: View {
    let items: [(trophy: Trophy, game: TrophyGame)]

    var body: some View {
        List {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    NavigationLink(value: item.game) { TrophyRow(trophy: item.trophy, subtitle: item.game.name) }
                }
            } footer: {
                Text(M.nextUpHint)
            }
        }
        .navigationTitle(M.nextUp)
    }
}
