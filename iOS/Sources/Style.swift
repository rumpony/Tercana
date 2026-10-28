import SwiftUI

/// The app's look: deep navy backdrop, glass cards, trophy-colored accents.
enum Style {
    static let backdrop = LinearGradient(colors: [Color(red: 0.04, green: 0.10, blue: 0.20), Color(red: 0.02, green: 0.03, blue: 0.08)],
                                         startPoint: .top, endPoint: .bottom)
    static let glow = Color(red: 0.20, green: 0.75, blue: 0.80)
}

extension View {
    /// Rounded glass panel used for every block of content.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Lists drawn on the app backdrop instead of the system grey.
    func onBackdrop() -> some View {
        scrollContentBackground(.hidden)
            .background(Style.backdrop.ignoresSafeArea())
    }
}

/// Big level ring with the level in the middle.
struct LevelRing: View {
    let level: Int
    let progress: Int
    var size: CGFloat = 132

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: size * 0.09)
            Circle()
                .trim(from: 0, to: Double(progress) / 100)
                .stroke(AngularGradient(colors: [Style.glow, TrophyGrade.platinum.color, TrophyGrade.gold.color, Style.glow], center: .center),
                        style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Style.glow.opacity(0.6), radius: 10)
            VStack(spacing: 0) {
                Text("\(level)").font(.system(size: size * 0.3, weight: .heavy, design: .rounded)).monospacedDigit()
                Text("%\(progress)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// One trophy grade as a colored chip with its count.
struct GradeChip: View {
    let grade: TrophyGrade
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "trophy.fill").font(.title3).foregroundStyle(grade.color.gradient)
            Text(count.formatted()).font(.headline.monospacedDigit())
            Text(grade.label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Large game tile with its artwork, for horizontal rails.
struct GameTile: View {
    let game: TrophyGame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                Artwork(url: game.iconURL, size: 150)
                Text("\(game.progress)%")
                    .font(.caption.bold()).monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule())
                    .padding(8)
            }
            Text(game.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            ProgressView(value: Double(game.progress), total: 100).tint(Style.glow)
        }
        .frame(width: 150)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    }
}
