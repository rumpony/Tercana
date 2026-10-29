import SwiftUI

extension TrophyGrade {
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.27)
        case .silver: return Color(red: 0.62, green: 0.66, blue: 0.72)
        case .gold: return Color(red: 0.95, green: 0.74, blue: 0.20)
        case .platinum: return Color(red: 0.55, green: 0.72, blue: 0.95)
        }
    }
}

extension TrophyRarity {
    var title: String {
        switch self {
        case .ultraRare: return S.ultraRare
        case .veryRare: return S.veryRare
        case .rare: return S.rare
        case .common: return S.common
        }
    }
}

/// Game or trophy artwork with a quiet placeholder.
struct Artwork: View {
    let url: URL?
    var size: CGFloat = 48

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.secondary.opacity(0.15)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
}

/// Trophy counts as four colored dots with numbers.
struct GradeCounts: View {
    let counts: TrophyCounts
    var defined: TrophyCounts?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TrophyGrade.allCases, id: \.self) { grade in
                let value = counts.value(grade)
                if let defined, defined.value(grade) == 0 {
                    EmptyView()
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(grade.color).frame(width: 8, height: 8)
                        Text(defined.map { "\(value)/\($0.value(grade))" } ?? "\(value)")
                            .monospacedDigit()
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension TrophyCounts {
    func value(_ grade: TrophyGrade) -> Int {
        switch grade {
        case .bronze: return bronze
        case .silver: return silver
        case .gold: return gold
        case .platinum: return platinum
        }
    }
}

/// One number with a caption, used in small grids.
struct Figure: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Shared look for every tab: small centered title and tight section gaps, so short or
    /// empty pages don't open with a block of empty space.
    func screen(_ title: String) -> some View {
        navigationTitle(title)
            .inlineTitle()
            .compactSections()
            .contentMargins(.top, 8, for: .scrollContent)
    }
}

/// Thin rounded progress bar that looks the same on the phone and the Mac (the system one turns grey on macOS).
struct Bar: View {
    let value: Double
    var color: Color = Style.glow

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule().fill(color.gradient).frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 5)
    }
}

/// Row of capsule buttons for switching a view's scope; the same on the phone and the Mac,
/// with a clear selected state and a roomy hit area.
struct Chips<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @Namespace private var glow

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    withAnimation(.spring(duration: 0.3)) { selection = option.value }
                    Haptic.tap()
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule().fill(Style.glow.opacity(0.3)).matchedGeometryEffect(id: "chip", in: glow)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
        .padding(.vertical, 6)
    }
}
