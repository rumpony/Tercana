import SwiftUI

/// The app's look: deep navy backdrop, glass cards, trophy-colored accents.
enum Style {
    /// The color picked in settings; every highlight, chart and ring uses it.
    /// The window is rebuilt when it changes (see TercanaMobileApp), so reading it directly is enough.
    static var glow: Color {
        Theme.colors[min(max(UserDefaults.standard.integer(forKey: "accent"), 0), Theme.colors.count - 1)]
    }

    /// Navy that leans toward the picked color at the top.
    static var backdrop: LinearGradient {
        LinearGradient(colors: [glow.mix(with: Color(red: 0.03, green: 0.06, blue: 0.14), by: 0.8),
                                Color(red: 0.02, green: 0.03, blue: 0.08)],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Rounded glass panel used for every block of content.
    func card(padding: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        #if os(iOS)
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: shape)
        #else
        // On the Mac a plain translucent panel: steadier on a wide window than live glass.
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: shape)
            .overlay(shape.stroke(.white.opacity(0.06)))
        #endif
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
    var showsPercent = true
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: size * 0.09)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(AngularGradient(colors: [Style.glow, TrophyGrade.platinum.color, TrophyGrade.gold.color, Style.glow], center: .center),
                        style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Style.glow.opacity(0.6), radius: 10)
            VStack(spacing: 0) {
                Text(showsPercent ? "\(level)" : "%\(level)")
                    .font(.system(size: size * (showsPercent ? 0.3 : 0.24), weight: .heavy, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                if showsPercent {
                    Text("%\(progress)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        // Fills up when it first appears.
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = Double(progress) / 100 } }
        .onChange(of: progress) { withAnimation(.easeOut(duration: 0.6)) { shown = Double(progress) / 100 } }
    }
}

/// List whose rows sit on glass-like panels over the app backdrop.
struct GlassList<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        List {
            Group { content }.listRowBackground(Color.white.opacity(0.07))
        }
        #if os(macOS)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        #endif
        .onBackdrop()
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

enum Theme {
    static let colors: [Color] = [Color(red: 0.20, green: 0.75, blue: 0.80), .blue, .indigo, .purple, .pink, .orange, .green]
}
