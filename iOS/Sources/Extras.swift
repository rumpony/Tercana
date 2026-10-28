import SwiftUI

/// Recent weeks as a grid of days (rows Mon…Sun), big enough to read; color shows how many trophies.
struct Heatmap: View {
    let counts: [Date: Int]
    var weeks = 15

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let peak = max(counts.values.max() ?? 1, 1)
        // Monday-first column start for the week holding today.
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7
        let lastMonday = calendar.date(byAdding: .day, value: -weekday, to: today)!
        let symbols = S.locale.calendar.veryShortWeekdaySymbols
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Color.clear.frame(width: 14, height: 1)
                ForEach(0..<weeks, id: \.self) { column in
                    let monday = calendar.date(byAdding: .day, value: (column - weeks + 1) * 7, to: lastMonday)!
                    let day = calendar.component(.day, from: monday)
                    Text(day <= 7 ? S.locale.calendar.shortMonthSymbols[calendar.component(.month, from: monday) - 1] : "")
                        .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 4) {
                    Text(symbols[(row + 1) % 7]).font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 14)
                    ForEach(0..<weeks, id: \.self) { column in
                        let day = calendar.date(byAdding: .day, value: (column - weeks + 1) * 7 + row, to: lastMonday)!
                        let value = counts[day] ?? 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day > today ? Color.clear
                                  : value == 0 ? Color.white.opacity(0.07)
                                  : Style.glow.opacity(0.35 + 0.65 * Double(value) / Double(peak)))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if value > 0 { Text("\(value)").font(.system(size: 8, weight: .bold)).foregroundStyle(.black.opacity(0.7)) }
                            }
                    }
                }
            }
        }
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
            ProgressView(value: Double(profile.progress), total: 100).tint(Style.glow)
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
        .background(LinearGradient(colors: [Style.glow.mix(with: .black, by: 0.55), Color(red: 0.09, green: 0.13, blue: 0.30)],
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
