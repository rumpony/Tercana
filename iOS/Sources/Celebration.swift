import SwiftUI

/// Falling confetti in trophy colors, drawn with a Canvas; stops by itself.
struct Confetti: View {
    @State private var start = Date()
    private let pieces = (0..<90).map { _ in
        (x: Double.random(in: 0...1), delay: Double.random(in: 0...0.8), speed: Double.random(in: 0.25...0.5),
         spin: Double.random(in: -6...6), color: [TrophyGrade.platinum.color, TrophyGrade.gold.color, .white, .pink].randomElement()!)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let progress = (t - piece.delay) * piece.speed
                    guard progress > 0, progress < 1.3 else { continue }
                    let x = piece.x * size.width + sin(progress * 8 + piece.spin) * 18
                    let y = progress * size.height
                    var shape = context
                    shape.translateBy(x: x, y: y)
                    shape.rotate(by: .radians(progress * piece.spin))
                    shape.fill(Path(CGRect(x: -4, y: -2, width: 8, height: 4)), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Shown once on a game whose platinum came in the last week: confetti plus a card to share.
struct PlatinumMoment: View {
    let game: TrophyGame
    let date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Style.backdrop.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                card
                let image = snapshot(card)
                ShareLink(item: image, preview: SharePreview(M.newPlatinum, image: image)) {
                    Label(M.share, systemImage: "square.and.arrow.up").frame(maxWidth: 220)
                }
                .softButton(prominent: true)
                .controlSize(.large)
                Button(S.close) { dismiss() }.foregroundStyle(.secondary)
                Spacer()
            }
            Confetti()
        }
        .onAppear { Haptic.success() }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill").font(.system(size: 54)).foregroundStyle(TrophyGrade.platinum.color.gradient)
                .shadow(color: TrophyGrade.platinum.color, radius: 20)
            Text(M.newPlatinum).font(.title.bold())
            Artwork(url: game.iconURL, size: 120)
            Text(game.name).font(.headline).multilineTextAlignment(.center)
            Text(date.shown()).font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 320)
        .background(LinearGradient(colors: [Style.glow.mix(with: .black, by: 0.5), Color(red: 0.05, green: 0.06, blue: 0.15)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .foregroundStyle(.white)
    }
}

/// Year in review as full-screen story cards, each one shareable.
struct YearStory: View {
    let earned: [Insights.Earned]
    @State private var year = Calendar.current.component(.year, from: Date())

    var body: some View {
        let years = Insights.years(earned)
        let review = Insights.year(year, earned)
        VStack(spacing: 12) {
            Picker(M.yearReview, selection: $year) {
                ForEach(years, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            TabView {
                ForEach(Array(pages(review).enumerated()), id: \.offset) { _, page in
                    VStack(spacing: 18) {
                        page
                        let image = snapshot(page)
                        ShareLink(item: image, preview: SharePreview(M.yearReview, image: image)) {
                            Label(M.share, systemImage: "square.and.arrow.up")
                        }
                        .softButton()
                    }
                }
            }
            .pagedTabs()
        }
        .background(Style.backdrop.ignoresSafeArea())
        .navigationTitle(M.yearReview)
        .inlineTitle()
        .onAppear { if let first = years.first, !years.contains(year) { year = first } }
    }

    private func pages(_ r: Insights.Year) -> [AnyView] {
        var list: [AnyView] = [
            AnyView(story(String(r.year), "\(r.trophies)", S.totalTrophies, footer: "\(r.points.formatted()) \(M.points.lowercased()) · \(r.games) \(S.gamesPlayed.lowercased())")),
        ]
        if let best = r.bestMonth {
            list.append(AnyView(story(M.bestMonth, S.locale.calendar.monthSymbols[best.month - 1], "\(best.count) \(S.totalTrophies.lowercased())")))
        }
        if !r.platinums.isEmpty {
            list.append(AnyView(storyCard {
                Text(S.platinums).font(.headline).foregroundStyle(.secondary)
                Text("\(r.platinums.count)").font(.system(size: 64, weight: .heavy, design: .rounded))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(52)), count: 4), spacing: 8) {
                    ForEach(r.platinums.prefix(12)) { Artwork(url: $0.iconURL, size: 52) }
                }
            }))
        }
        if let rarest = r.rarest {
            list.append(AnyView(storyCard {
                Text(S.rarestEarned).font(.headline).foregroundStyle(.secondary)
                Artwork(url: rarest.trophy.iconURL, size: 90)
                Text(rarest.trophy.name).font(.title2.bold()).multilineTextAlignment(.center)
                Text(rarest.game.name).font(.subheadline).foregroundStyle(.secondary)
                if let rate = rarest.trophy.earnedRate { Text(S.earnedBy(rate)).font(.caption) }
            }))
        }
        return list
    }

    private func story(_ title: String, _ value: String, _ caption: String, footer: String? = nil) -> some View {
        storyCard {
            Text(title).font(.headline).foregroundStyle(.secondary)
            Text(value).font(.system(size: 64, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            Text(caption).font(.title3.weight(.semibold))
            if let footer { Text(footer).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private func storyCard(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 14) { content() }
            .padding(28)
            .frame(width: 320, height: 420)
            .background(LinearGradient(colors: [Style.glow.mix(with: .black, by: 0.45), Color(red: 0.05, green: 0.06, blue: 0.15)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .foregroundStyle(.white)
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
